class ProvidersController < ApplicationController
  include Countable

  before_action :set_provider, only: [:show, :update, :destroy]
  before_action :authenticate_user!
  load_and_authorize_resource :except => [:index, :show]

  def index
    sort = case params[:sort]
           when "relevance" then { "_score" => { order: 'desc' }}
           when "name" then { "name.raw" => { order: 'asc' }}
           when "-name" then { "name.raw" => { order: 'desc' }}
           when "created" then { created: { order: 'asc' }}
           when "-created" then { created: { order: 'desc' }}
           else { "name.raw" => { order: 'asc' }}
           end

    page = params[:page] || {}
    if page[:size].present? 
      page[:size] = [page[:size].to_i, 1000].min
      max_number = page[:size] > 0 ? 10000/page[:size] : 1
    else
      page[:size] = 25
      max_number = 10000/page[:size]
    end
    page[:number] = page[:number].to_i > 0 ? [page[:number].to_i, max_number].min : 1

    if params[:id].present?
      response = Provider.find_by_id(params[:id])
    elsif params[:ids].present?
      response = Provider.find_by_ids(params[:ids], page: page, sort: sort)
    else
      response = Provider.query(params[:query], year: params[:year], region: params[:region], organization_type: params[:organization_type], focus_area: params[:focus_area], include_deleted: params[:include_deleted], fields: params[:fields], page: page, sort: sort)
    end

    total = response.results.total
    total_pages = page[:size] > 0 ? (total.to_f / page[:size]).ceil : 0
    years = total > 0 ? facet_by_year(response.response.aggregations.years.buckets) : nil
    regions = total > 0 ? facet_by_region(response.response.aggregations.regions.buckets) : nil
    organization_types = total > 0 ? facet_by_key(response.response.aggregations.organization_types.buckets) : nil
    focus_areas = total > 0 ? facet_by_key(response.response.aggregations.focus_areas.buckets) : nil

    @providers = response.results.results

    options = {}
    options[:meta] = {
      total: total,
      "total-pages" => total_pages,
      page: page[:number],
      years: years,
      regions: regions,
      "organization-types" => organization_types,
      "focus-areas" => focus_areas
    }.compact

    options[:links] = {
      self: request.original_url,
      next: @providers.blank? ? nil : request.base_url + "/providers?" + {
        query: params[:query],
        year: params[:year],
        region: params[:region],
        "organization_type" => params[:organization_type],
        "focus-area" => params[:focus_area],
        fields: params[:fields],
        "page[number]" => params.dig(:page, :number),
        "page[size]" => params.dig(:page, :size),
        sort: sort }.compact.to_query
      }.compact
    options[:include] = @include
    options[:is_collection] = true

    render json: ProviderSerializer.new(@providers, options).serialized_json, status: :ok
  end

  def show
    options = {}
    options[:meta] = { 
      providers: provider_count(provider_id: params[:id] == "admin" ? nil : params[:id]),
      clients: client_count(provider_id: params[:id] == "admin" ? nil : params[:id]),
      dois: doi_count(provider_id: params[:id] == "admin" ? nil : params[:id]) }.compact
    options[:include] = @include
    options[:is_collection] = false

    render json: ProviderSerializer.new(@provider, options).serialized_json, status: :ok
  end

  def create
    logger = Logger.new(STDOUT)
    @provider = Provider.new(safe_params)
    authorize! :create, @provider

    if @provider.save
      options = {}
      options[:include] = @include
      options[:is_collection] = false
  
      render json: ProviderSerializer.new(@provider, options).serialized_json, status: :ok
    else
      logger.warn @provider.errors.inspect
      render json: serialize(@provider.errors), status: :unprocessable_entity
    end
  end

  def update
    logger = Logger.new(STDOUT)
    # logger.debug safe_params.inspect
    if @provider.update_attributes(safe_params)
      options = {}
      options[:meta] = { 
        providers: provider_count(provider_id: params[:id] == "admin" ? nil : params[:id]),
        clients: client_count(provider_id: params[:id] == "admin" ? nil : params[:id]),
        dois: doi_count(provider_id: params[:id] == "admin" ? nil : params[:id]) }.compact
      options[:include] = @include
      options[:is_collection] = false
  
      render json: ProviderSerializer.new(@provider, options).serialized_json, status: :ok
    else
      logger.warn @provider.errors.inspect
      render json: serialize(@provider.errors), status: :unprocessable_entity
    end
  end

  # don't delete, but set deleted_at timestamp
  # a provider with clients or prefixes can't be deleted
  def destroy
    logger = Logger.new(STDOUT)
    if @provider.client_count.present?
      message = "Can't delete provider that has clients."
      status = 400
      logger.warn message
      render json: { errors: [{ status: status.to_s, title: message }] }.to_json, status: status
    elsif @provider.update_attributes(is_active: "\x00", deleted_at: Time.zone.now)
      @provider.remove_users(id: "provider_id", jwt: current_user.jwt) unless Rails.env.test?
      head :no_content
    else
      logger.warn @provider.errors.inspect
      render json: serialize(@provider.errors), status: :unprocessable_entity
    end
  end

  protected

  # Use callbacks to share common setup or constraints between actions.
  def set_provider
    @provider = Provider.unscoped.where("allocator.role_name IN ('ROLE_ALLOCATOR', 'ROLE_ADMIN')").where(deleted_at: nil).where(symbol: params[:id]).first
    fail ActiveRecord::RecordNotFound unless @provider.present?
  end

  private

  def safe_params
    fail JSON::ParserError, "You need to provide a payload following the JSONAPI spec" unless params[:data].present?
    ActiveModelSerializers::Deserialization.jsonapi_parse!(
      params, only: [:name, :symbol, :description, :website, :joined, "organization-type", "focus-area", :phone, "contact-name", "contact-email", "is_active", "password-input", :country],
              keys: { "organization-type" => :organization_type, "focus-area" => :focus_area, "contact-name" => :contact_name, "contact-email" => :contact_email, :country => :country_code, "is-active" => :is_active, "password-input" => :password_input }
    )
  end
end
