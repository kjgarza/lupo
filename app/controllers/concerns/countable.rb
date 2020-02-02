module Countable
  extend ActiveSupport::Concern

  included do
    def doi_count(client_id: nil, provider_id: nil, consortium_id: nil, user_id: nil, state: nil)
      if client_id
        response = Doi.query(nil, client_id: client_id, page: { number: 1, size: 0 })
      elsif provider_id
        response = Doi.query(nil, provider_id: provider_id, page: { number: 1, size: 0 })
      elsif consortium_id
        response = Doi.query(nil, consortium_id: consortium_id, page: { number: 1, size: 0 })
      elsif user_id
        response = Doi.query(nil, user_id: user_id, state: state, page: { number: 1, size: 0 })
      else
        response = Doi.query(nil, page: { number: 1, size: 0 })
      end
      
      response.results.total.positive? ? facet_by_year(response.response.aggregations.created.buckets) : []
    end

    def view_count(client_id: nil, provider_id: nil, consortium_id: nil, user_id: nil, state: nil)
      if client_id
        response = Doi.query(nil, client_id: client_id, page: { number: 1, size: 0 })
      elsif provider_id
        response = Doi.query(nil, provider_id: provider_id, page: { number: 1, size: 0 })
      elsif consortium_id
        response = Doi.query(nil, consortium_id: consortium_id, page: { number: 1, size: 0 })
      elsif user_id
        response = Doi.query(nil, user_id: user_id, state: state, page: { number: 1, size: 0 })
      else
        response = Doi.query(nil, page: { number: 1, size: 0 })
      end
      
      response.results.total.positive? ? facet_by_year(response.response.aggregations.views.buckets) : 0
    end

    def download_count(client_id: nil, provider_id: nil, consortium_id: nil, user_id: nil, state: nil)
      if client_id
        response = Doi.query(nil, client_id: client_id, page: { number: 1, size: 0 })
      elsif provider_id
        response = Doi.query(nil, provider_id: provider_id, page: { number: 1, size: 0 })
      elsif consortium_id
        response = Doi.query(nil, consortium_id: consortium_id, page: { number: 1, size: 0 })
      elsif user_id
        response = Doi.query(nil, user_id: user_id, state: state, page: { number: 1, size: 0 })
      else
        response = Doi.query(nil, page: { number: 1, size: 0 })
      end
      
      response.results.total.positive? ? facet_by_year(response.response.aggregations.downloads.buckets) : 0
    end

    def citation_count(client_id: nil, provider_id: nil, consortium_id: nil, user_id: nil, state: nil)
      if client_id
        response = Doi.query(nil, client_id: client_id, page: { number: 1, size: 0 })
      elsif provider_id
        response = Doi.query(nil, provider_id: provider_id, page: { number: 1, size: 0 })
      elsif consortium_id
        response = Doi.query(nil, consortium_id: consortium_id, page: { number: 1, size: 0 })
      elsif user_id
        response = Doi.query(nil, user_id: user_id, state: state, page: { number: 1, size: 0 })
      else
        response = Doi.query(nil, page: { number: 1, size: 0 })
      end
      
      response.results.total.positive? ? facet_by_year(response.response.aggregations.citations.buckets) : 0
    end

    # cumulative count clients by year
    # count until the previous year if client has been deleted
    # show all clients for admin
    def client_count(provider_id: nil, consortium_id: nil)
      if provider_id
        response = Client.query(nil, provider_id: provider_id, include_deleted: true, page: { number: 1, size: 0 })
      elsif consortium_id
        response = Client.query(nil, consortium_id: consortium_id, include_deleted: true, page: { number: 1, size: 0 })
      else
        response = Client.query(nil, include_deleted: true, page: { number: 1, size: 0 })
      end 

      response.results.total.positive? ? facet_by_cumulative_year(response.response.aggregations.cumulative_years.buckets) : []
    end

    # count active clients by provider. Provider can only be deleted when there are no active clients.
    def active_client_count(provider_id: nil)
      return 0 unless provider_id.present?

      response = Client.query(nil, provider_id: provider_id, page: { number: 1, size: 0 })
      response.results.total
    end

    # show provider counts for admin and consortium
    # count until the previous year if provider has been deleted
    def provider_count(consortium_id: nil)
      if consortium_id
        response = Provider.query(nil, consortium_id: consortium_id, include_deleted: true, page: { number: 1, size: 0 })
        response.results.total.positive? ? facet_by_cumulative_year(response.response.aggregations.cumulative_years.buckets) : []
      else
        response = Provider.query(nil, include_deleted: true, page: { number: 1, size: 0 })
        response.results.total.positive? ? facet_by_cumulative_year(response.response.aggregations.cumulative_years.buckets) : []
      end
    end

    def resource_type_count(client_id: nil, provider_id: nil, consortium_id: nil, user_id: nil, state: nil)
      if client_id
        response = Doi.query(nil, client_id: client_id, page: { number: 1, size: 0 })
      elsif provider_id
        response = Doi.query(nil, provider_id: provider_id, page: { number: 1, size: 0 })
      elsif consortium_id
        response = Doi.query(nil, consortium_id: consortium_id, page: { number: 1, size: 0 })
      elsif user_id
        response = Doi.query(nil, user_id: user_id, state: state, page: { number: 1, size: 0 })
      else
        response = Doi.query(nil, page: { number: 1, size: 0 })
      end
      
      response.results.total.positive? ? facet_by_resource_type(response.response.aggregations.resource_types.buckets) : []
    end
  end
end
