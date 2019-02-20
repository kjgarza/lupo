class TransferJob < ActiveJob::Base
  queue_as :lupo_background

  # retry_on ActiveRecord::RecordNotFound, wait: 10.seconds, attempts: 3
  # retry_on Faraday::TimeoutError, wait: 10.minutes, attempts: 3

  # discard_on ActiveJob::DeserializationError

  def perform(doi_id, options={})
    logger = Logger.new(STDOUT)
    doi = Doi.where(doi: doi_id).first

    if doi.present? && options[:target_id].present?
      doi.update_attributes(datacentre: options[:target_id])

      doi.__elasticsearch__.index_document

      logger.info "[Transfer] Transferred DOI #{doi.doi}."
    elsif doi.present?
      logger.info "[Transfer] Error transferring DOI " + doi_id + ": no target client"
    else
      logger.info "[Transfer] Error transferring DOI " + doi_id + ": not found"
    end
  end
end