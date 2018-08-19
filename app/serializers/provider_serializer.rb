class ProviderSerializer
  include FastJsonapi::ObjectSerializer
  set_key_transform :dash
  set_type :providers
  set_id :uid
  #cache_options enabled: true, cache_length: 24.hours

  attributes :name, :symbol, :website, :contact_name, :contact_email, :phone, :description, :country, :logo_url, :institution_type, :is_active, :has_password, :joined, :created, :updated

  attribute :country do |object|
    object.country_code
  end

  attribute :is_active do |object|
    object.is_active == "\u0001" ? true : false
  end

  attribute :has_password do |object|
    object.password.present?
  end
end
