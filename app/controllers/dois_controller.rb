require 'uri'

class DoisController < ApplicationController
  prepend_before_action :authenticate_user!
  before_action :set_doi, only: [:show, :update, :destroy]
  before_action :set_user_hash, only: [:create, :update, :destroy]
  before_action :set_include, only: [:index, :show]
  # before_action :set_format, only: [:show]
  authorize_resource :except => [:index, :show, :random]

  def index
    # support nested routes
    if params[:client_id].present?
      client = Client.where('datacentre.symbol = ?', params[:client_id]).first
      collection = client.present? ? client.dois : Doi.none
      total = client.cached_doi_count.reduce(0) { |sum, d| sum + d[:count].to_i }
    elsif params[:provider_id].present? && params[:provider_id] != "admin"
      provider = Provider.where('allocator.symbol = ?', params[:provider_id]).first
      collection = provider.present? ? Doi.joins(:client).where("datacentre.allocator = ?", provider.id) : Doi.none
      total = provider.cached_doi_count.reduce(0) { |sum, d| sum + d[:count].to_i }
    elsif params[:id].present?
      collection = Doi.where(doi: params[:id])
      total = collection.all.size
    else
      provider = Provider.unscoped.where('allocator.symbol = ?', "ADMIN").first
      total = provider.present? ? provider.cached_doi_count.reduce(0) { |sum, d| sum + d[:count].to_i } : 0
      collection = Doi
    end

    if params[:query].present?
      collection = Doi.query(params[:query])
      total = collection.all.size
    end

    page = params[:page] || {}
    page[:number] = page[:number] && page[:number].to_i > 0 ? page[:number].to_i : 1
    page[:size] = page[:size] && (1..1000).include?(page[:size].to_i) ? page[:size].to_i : 25
    total_pages = (total.to_f / page[:size]).ceil

    order = case params[:sort]
            when "name" then "dataset.doi"
            when "-name" then "dataset.doi DESC"
            when "created" then "dataset.created"
            else "dataset.created DESC"
            end

    @dois = collection.order(order).page(page[:number]).per(page[:size]).without_count

    meta = { total: total,
             total_pages: total_pages,
             page: page[:number].to_i }

    render jsonapi: @dois, meta: meta, include: @include, each_serializer: DoiSerializer
  end

  # we support DOI content negotiation in show action
  def show
    #if @content_type == :json
    render jsonapi: @doi, include: @include, serializer: DoiSerializer
    # else
    #   format = Mime::Type.lookup(@content_type.split(";").first).to_sym
    #
    #   if format == :citation
    #     # set style and locale later so that we can take advantage of caching
    #     hsh = @content_type.split(";").reduce({}) do |sum, i|
    #       k, v = i.strip.split("=")
    #       sum[k] = v if v.present?
    #       sum
    #     end
    #     @doi.style = hsh["style"] || "apa"
    #     @doi.locale = hsh["locale"] || "en-US"
    #   end
    #
    #   response.set_header("Accept", @content_type)
    #
    #   render format => @doi
    # end
  end

  def preview
    puts safe_params
    @doi = Doi.new(safe_params.merge(@user_hash))
    authorize! :create, @doi

    @doi.valid?

    render jsonapi: @doi, serializer: DoiSerializer
  end

  def create
    @doi = Doi.new(safe_params.merge(@user_hash))
    authorize! :create, @doi

    if @doi.save
      @doi.start
      render jsonapi: @doi, status: :created, location: @doi
    else
      Rails.logger.warn @doi.errors.inspect
      render jsonapi: serialize(@doi.errors), status: :unprocessable_entity
    end
  end

  def update
    if @doi.update_attributes(safe_params.merge(@user_hash))
      render jsonapi: @doi
    else
      Rails.logger.warn @doi.errors.inspect
      render jsonapi: serialize(@doi.errors), status: :unprocessable_entity
    end
  end

  def destroy
    if @doi.draft?
      if @doi.destroy
        head :no_content
      else
        Rails.logger.warn @doi.errors.inspect
        render jsonapi: serialize(@doi.errors), status: :unprocessable_entity
      end
    else
      response.headers["Allow"] = "HEAD, GET, POST, PATCH, PUT, OPTIONS"
      render json: { errors: [{ status: "405", title: "Method not allowed" }] }.to_json, status: :method_not_allowed
    end
  end

  def status
    doi = Doi.where(doi: params[:id]).first
    status = Doi.get_landing_page_info(doi: doi, url: params[:url])
    render json: status.to_json, status: :ok
  end

  def random
    prefix = params[:prefix].presence || "10.5072"
    doi = generate_random_doi(prefix, number: params[:number])

    render json: { doi: doi }.to_json
  end

  def set_state
    authorize! :update, Doi
    Doi.set_state
    render json: { message: "DOI state updated." }.to_json, status: :ok
  end

  def set_minted
    authorize! :update, Doi
    Doi.set_minted
    render json: { message: "DOI minted timestamp added." }.to_json, status: :ok
  end

  def set_url
    authorize! :update, Doi
    from_date = Time.zone.now - 1.day
    Doi.where(url: nil).where(aasm_state: ["registered", "findable"]).where("updated >= ?", from_date).find_each do |doi|
      UrlJob.perform_later(doi)
    end
    render json: { message: "Adding missing URLs queued." }.to_json, status: :ok
  end

  def delete_test_dois
    authorize! :delete, Doi
    Doi.delete_test_dois
    render json: { message: "Test DOIs deleted." }.to_json, status: :ok
  end

  protected

  def set_doi
    @doi = Doi.where(doi: params[:id]).first
    fail ActiveRecord::RecordNotFound unless @doi.present?
  end

  # capture username and password for client_admins for reuse in the handle system
  def set_user_hash
    if current_user.role_id == "client_admin"
      @user_hash = { username: current_user.uid, password: current_user.password }
    else
      @user_hash = {}
    end
  end

  def set_include
    if params[:include].present?
      @include = params[:include].split(",").map { |i| i.downcase.underscore }.join(",")
      @include = [@include]
    else
      @include = ["client,provider,resource_type"]
    end
  end

  def set_format
    # get all accept headers provided by client
    @accept_headers = request.accepts.map { |i| i.to_s }

    # select first match as content_type, handle text/x-bibliography differently
    if @accept_headers.first.to_s.starts_with?("text/x-bibliography")
      request.format = :citation
    else
      #request.format = (@accept_headers & AVAILABLE_CONTENT_TYPES.keys).first || :json
    end
  end

  private

  def safe_params
    fail JSON::ParserError, "You need to provide a payload following the JSONAPI spec" unless params[:data].present?
    ActiveModelSerializers::Deserialization.jsonapi_parse!(
      params, only: [:doi, :url, :title, :publisher, "date-published", "resource-type", "resource-type-subtype", "last-landing-page", "last-landing-page-status", "last-landing-page-status-check", "last-landing-page-content-type", :description, :license, :xml, :reason, :event, :regenerate, :client, creator: []],
              keys: { "date-published" => :date_published, :resource_type_subtype => :additional_type, :creator => :author, "last-landing-page" => :last_landing_page, "last-landing-page-status" => :last_landing_page_status, "last-landing-page-status-check" => :last_landing_page_status_check, "last-landing-page-content-type" => :last_landing_page_content_type }
    )
  end
end
