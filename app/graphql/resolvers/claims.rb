# frozen_string_literal: true

class Claims < Base
  type [ClaimType], null: false

  def resolve
    return [] if context[:current_user].blank?

    # Use DataCite Claims API call to get all ORCID claims for a given DOI
    api_url =
      if Rails.env.production?
        "https://api.datacite.org"
      else
        "https://api.stage.datacite.org"
      end
    url =
      "#{api_url}/claims?user-id=#{context[:current_user].uid}&dois=#{
        object.doi.downcase
      }"
    response = Maremma.get(url, bearer: context[:current_user].jwt)
    if response.status != 200
      Rails.logger.error "Error retrieving claims for user #{
                           context[:current_user].uid
                         } and doi #{object.doi.downcase}: " +
        response.body["errors"].inspect
      return []
    end

    if response.body["data"].present?
      Rails.logger.info "Claims for user #{
                          context[:current_user].uid
                        } and doi #{object.doi.downcase} retrieved: " +
        response.body["data"].inspect
    end

    Array.wrap(response.body.dig("data")).map do |claim|
      {
        id: claim["id"],
        source_id: claim.dig("attributes", "sourceId"),
        state: claim.dig("attributes", "state"),
        claim_action: claim.dig("attributes", "claimAction"),
        claimed: claim.dig("attributes", "claimed"),
        error_messages: claim.dig("attributes", "errorMessages"),
      }
    end
  end
end
