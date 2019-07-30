class PeriodicalsController < ApplicationController
  include Countable

  before_action :set_periodical, only: [:show, :update, :destroy]
  before_action :authenticate_user!
  before_action :set_include
  load_and_authorize_resource :client, :parent => false, :except => [:index, :show, :totals]

  def index
    sort = case params[:sort]
           when "relevance" then { "_score" => { order: 'desc' }}
           when "name" then { "name.raw" => { order: 'asc' }}
           when "-name" then { "name.raw" => { order: 'desc' }}
           when "created" then { created: { order: 'asc' }}
           when "-created" then { created: { order: 'desc' }}
           else { "name.raw" => { order: 'asc' }}
           end

    page = page_from_params(params)

    if params[:id].present?
      response = Client.find_by_id(params[:id]) 
    elsif params[:ids].present?
      response = Client.find_by_id(params[:ids], page: page, sort: sort)
    else
      response = Client.query(params[:query], 
        year: params[:year], 
        provider_id: params[:provider_id],
        issn: params[:issn],
        client_type: "periodical", 
        page: page, 
        sort: sort)
    end

    begin
      total = response.results.total
      total_pages = page[:size] > 0 ? (total.to_f / page[:size]).ceil : 0
      years = total > 0 ? facet_by_year(response.response.aggregations.years.buckets) : nil
      providers = total > 0 ? facet_by_provider(response.response.aggregations.providers.buckets) : nil
      software = total > 0 ? facet_by_software(response.response.aggregations.software.buckets) : nil

      options = {}
      options[:meta] = {
        total: total,
        "totalPages" => total_pages,
        page: page[:number],
        years: years,
        providers: providers,
        software: software
      }.compact

      options[:links] = {
        self: request.original_url,
        next: response.results.blank? ? nil : request.base_url + "/periodicals?" + {
          query: params[:query],
          "provider-id" => params[:provider_id],
          software: params[:software],
          year: params[:year],
          "page[number]" => page[:number] + 1,
          "page[size]" => page[:size],
          sort: params[:sort] }.compact.to_query
        }.compact
      options[:include] = @include
      options[:is_collection] = true

      fields = fields_from_params(params)
      if fields
        render json: PeriodicalSerializer.new(response.results, options.merge(fields: fields)).serialized_json, status: :ok
      else
        render json: PeriodicalSerializer.new(response.results, options).serialized_json, status: :ok
      end
    rescue Elasticsearch::Transport::Transport::Errors::BadRequest => exception
      Raven.capture_exception(exception)

      message = JSON.parse(exception.message[6..-1]).to_h.dig("error", "root_cause", 0, "reason")

      render json: { "errors" => { "title" => message }}.to_json, status: :bad_request
    end
  end

  def show
    options = {}
    options[:meta] = { dois: doi_count(client_id: params[:id]) }
    options[:include] = @include
    options[:is_collection] = false

    render json: PeriodicalSerializer.new(@client, options).serialized_json, status: :ok
  end

  def create
    logger = Logger.new(STDOUT)
    @client = Client.new(safe_params)
    authorize! :create, @client

    if @client.save
      options = {}
      options[:is_collection] = false
  
      render json: PeriodicalSerializer.new(@client, options).serialized_json, status: :created
    else
      logger.warn @client.errors.inspect
      render json: serialize_errors(@client.errors), status: :unprocessable_entity
    end
  end

  def update
    logger = Logger.new(STDOUT)
    if @client.update_attributes(safe_params)
      options = {}
      options[:meta] = { dois: doi_count(client_id: params[:id]) }
      options[:is_collection] = false
  
      render json: PeriodicalSerializer.new(@client, options).serialized_json, status: :ok
    else
      logger.warn @client.errors.inspect
      render json: serialize_errors(@client.errors), status: :unprocessable_entity
    end
  end

  # don't delete, but set deleted_at timestamp
  # a periodical with dois or prefixes can't be deleted
  def destroy
    logger = Logger.new(STDOUT)
    if @client.dois.present?
      message = "Can't delete periodical that has DOIs."
      status = 400
      logger.warn message
      render json: { errors: [{ status: status.to_s, title: message }] }.to_json, status: status
    elsif @client.update_attributes(is_active: nil, deleted_at: Time.zone.now)
      @client.send_delete_email unless Rails.env.test?
      head :no_content
    else
      logger.warn @client.errors.inspect
      render json: serialize_errors(@client.errors), status: :unprocessable_entity
    end
  end

  def totals
    page = { size: 0, number: 1}

    state =  current_user.present? && current_user.is_admin_or_staff? && params[:state].present? ? params[:state] : "registered,findable"
    response = Doi.query(nil, provider_id: params[:provider_id], state: state, page: page, totals_agg: true)

    total = response.results.total

    registrant = total > 0 ? clients_totals(response.response.aggregations.clients_totals.buckets) : nil
    render json: registrant, status: :ok
  end

  protected

  def set_include
    if params[:include].present?
      @include = params[:include].split(",").map { |i| i.downcase.underscore.to_sym }
      @include = @include & [:provider]
    else
      @include = [:provider]
    end
  end

  def set_periodical
    @client = Client.where(symbol: params[:id]).where(client_type: "periodical").where(deleted_at: nil).first
    fail ActiveRecord::RecordNotFound unless @client.present?
  end

  private

  def safe_params
    fail JSON::ParserError, "You need to provide a payload following the JSONAPI spec" unless params[:data].present?
    ActiveModelSerializers::Deserialization.jsonapi_parse!(
      params, only: [:symbol, :name, "contactName", "contactEmail", :domains, :provider, :url, "repositoryType", { "repositoryType" => [] }, :description, :language, { language: [] }, "alternateName", :software, "targetId", "isActive", "passwordInput", "clientType", :re3data, :opendoar, :issn, { issn: [] }, :certificate, { certificate: [] }],
              keys: { "contactName" => :contact_name, "contactEmail" => :contact_email, "targetId" => :target_id, "isActive" => :is_active, "passwordInput" => :password_input, "clientType" => :client_type, "alternateName" => :alternate_name, "repositoryType" => :repository_type }
    )
  end
end