class ClientSerializer
  include FastJsonapi::ObjectSerializer
  set_key_transform :dash
  set_type :clients
  set_id :uid
  #cache_options enabled: true, cache_length: 24.hours
  
  attributes :name, :symbol, :year, :contact_name, :contact_email, :domains, :url, :created, :updated

  belongs_to :provider, record_type: :providers
  belongs_to :repository, record_type: :repositories

  attribute :is_active do |object|
    object.is_active == "\u0001" ? true : false
  end

  attribute :has_password do |object|
    object.password.present?
  end
end
