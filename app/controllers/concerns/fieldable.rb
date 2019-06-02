module Fieldable
  extend ActiveSupport::Concern

  included do
    def fields_from_params(params)
      fields = params.to_unsafe_h.dig(:fields)
      return nil unless fields.is_a?(Hash)

      fields.each { |k, v| fields[k] = v.split(",") }
      fields
    end
  end
end
