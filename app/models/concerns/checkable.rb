module Checkable
  extend ActiveSupport::Concern

  module ClassMethods
    def get_landing_page_info(doi: nil, url: nil, keep: true)
      uri = doi.present? ? doi.url : url
      return { "status" => 404, "content-type" => nil, "checked" => Time.zone.now.utc.iso8601 } unless
        uri.present?

      return { "status" => doi.landing_page['status'], "content-type" => doi.landing_page['content_type'], "checked" => doi.landing_page['checked'] } if
        doi.present? && keep && doi.landing_page.present? && doi.landing_page['checked'].present? && doi.landing_page['checked'] > (Time.zone.now - 7.days)

      response = Maremma.head(uri, timeout: 5)
      if response.headers && response.headers["Content-Type"].present?
        content_type = response.headers["Content-Type"].split(";").first
      else
        content_type = nil
      end

      checked = Time.zone.now

      { "status" => response.status,
        "content-type" => content_type,
        "checked" => checked.utc.iso8601 }
    rescue URI::InvalidURIError => e
      logger = Logger.new(STDOUT)
      logger.error e.message

      { "status" => 404,
        "content_type" => nil,
        "checked" => Time.zone.now.utc.iso8601 }
    end
  end
end
