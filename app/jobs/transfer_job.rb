class TransferJob < ActiveJob::Base
  queue_as :lupo_background

  def perform(doi_id, options={})
    doi = Doi.where(doi: doi_id).first

    if doi.present?
      doi.update_attributes(datacentre: options[:target_id])
    else
      logger = Logger.new(STDOUT)
      logger.info "[Transfer] Error transferring DOI " + doi_id + ": not found"
    end
  end
end