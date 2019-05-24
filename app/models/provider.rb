require "countries"

class Provider < ActiveRecord::Base

  # include helper module for caching infrequently changing resources
  include Cacheable

  # include helper module for managing associated users
  include Userable

  # include helper module for setting password
  include Passwordable

  # include helper module for authentication
  include Authenticable

  # include helper module for Elasticsearch
  include Indexable

  # include helper module for sending emails
  include Mailable

  include Elasticsearch::Model

  # define table and attribute names
  # uid is used as unique identifier, mapped to id in serializer
  self.table_name = "allocator"
  alias_attribute :flipper_id, :symbol
  alias_attribute :created_at, :created
  alias_attribute :updated_at, :updated
  attr_readonly :symbol
  attr_accessor :password_input

  validates_presence_of :symbol, :name, :contact_name, :contact_email
  validates_uniqueness_of :symbol, message: "This name has already been taken"
  validates_format_of :contact_email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, message: "contact_email should be an email"
  validates_format_of :website, :with => /https?:\/\/[\S]+/ , if: :website?, message: "Website should be an url"
  validates_inclusion_of :role_name, :in => %w( ROLE_FOR_PROFIT_PROVIDER ROLE_CONTRACTUAL_PROVIDER ROLE_CONSORTIUM_LEAD ROLE_ALLOCATOR ROLE_MEMBER ROLE_ADMIN ROLE_DEV ), :message => "Role %s is not included in the list"
  validates_inclusion_of :organization_type, :in => %w(nationalInstitution nationalLibrary academicInstitution academicLibrary researchInstitution governmentAgency publisher professionalSociety serviceProvider vendor), :message => "organization type %s is not included in the list", if: :organization_type?
  validates_inclusion_of :focus_area, :in => %w(biomedicalAndHealthSciences earthSciences humanities mathematicsAndComputerScience physicalSciencesAndEngineering socialSciences general), :message => "focus area %s is not included in the list", if: :focus_area?
  validate :freeze_symbol, :on => :update
  validates_format_of :ror_id, :with => /\A(?:(http|https):\/\/)?(?:ror\.org\/)?(0\w{6}\d{2})\z/, if: :ror_id?
  validates_format_of :twitter_handle, :with => /\A@[a-zA-Z0-9_]{1,15}\z/, if: :twitter_handle?

  # validates :technical_contact, contact: true
  # validates :billing_contact, contact: true
  # validates :secondary_billing_contact, contact: true
  # validates :service_contact, contact: true
  # validates :voting_contact, contact: true
  #validates :billing_information, billing_information: true

  before_validation :set_region

  strip_attributes

  has_many :clients, foreign_key: :allocator
  has_many :dois, through: :clients
  has_many :provider_prefixes, foreign_key: :allocator, dependent: :destroy
  has_many :prefixes, through: :provider_prefixes

  before_validation :set_region, :set_defaults
  before_create { self.created = Time.zone.now.utc.iso8601 }
  before_save { self.updated = Time.zone.now.utc.iso8601 }

  after_create :send_welcome_email, unless: Proc.new { Rails.env.test? }

  accepts_nested_attributes_for :prefixes

  #default_scope { where("allocator.role_name IN ('ROLE_ALLOCATOR', 'ROLE_DEV')").where(deleted_at: nil) }

  #scope :query, ->(query) { where("allocator.symbol like ? OR allocator.name like ?", "%#{query}%", "%#{query}%") }

  # use different index for testing
  index_name Rails.env.test? ? "providers-test" : "providers"

  settings index: {
    analysis: {
      analyzer: {
        string_lowercase: { tokenizer: 'keyword', filter: %w(lowercase ascii_folding) }
      },
      filter: { ascii_folding: { type: 'asciifolding', preserve_original: true } }
    }
  } do
    mapping dynamic: 'false' do
      indexes :id,            type: :keyword
      indexes :uid,           type: :keyword
      indexes :symbol,        type: :keyword
      indexes :client_ids,    type: :keyword
      indexes :prefix_ids,    type: :keyword
      indexes :name,          type: :text, fields: { keyword: { type: "keyword" }, raw: { type: "text", "analyzer": "string_lowercase", "fielddata": true }}
      indexes :contact_name,  type: :text
      indexes :contact_email, type: :text, fields: { keyword: { type: "keyword" }}
      indexes :version,       type: :integer
      indexes :is_active,     type: :keyword
      indexes :year,          type: :integer
      indexes :description,   type: :text
      indexes :website,       type: :text, fields: { keyword: { type: "keyword" }}
      indexes :phone,         type: :text
      indexes :logo_url,      type: :text
      indexes :region,        type: :keyword
      indexes :focus_area,    type: :keyword
      indexes :organization_type, type: :keyword
      indexes :member_type,   type: :keyword
      indexes :country_code,  type: :keyword
      indexes :role_name,     type: :keyword
      indexes :cache_key,     type: :keyword
      indexes :joined,        type: :date
      indexes :twitter_handle,type: :keyword
      indexes :ror_id,        type: :keyword
      indexes :billing_information, type: :object, properties: {
        postCode: { type: :keyword },
        state: { type: :text},
        organization: { type: :text},
        department: { type: :text},
        city: { type: :text },
        country: { type: :text },
        address: { type: :text }}
      indexes :technical_contact, type: :object, properties: {
        email: { type: :text },
        given_name: { type: :text},
        family_name: { type: :text }
      }
      indexes :billing_contact, type: :object, properties: {
        email: { type: :text },
        given_name: { type: :text},
        family_name: { type: :text }
      }
      indexes :secondary_billing_contact, type: :object, properties: {
        email: { type: :text },
        given_name: { type: :text},
        family_name: { type: :text }
      }
      indexes :service_contact, type: :object, properties: {
        email: { type: :text },
        given_name: { type: :text},
        family_name: { type: :text }
      }
      indexes :voting_contact, type: :object, properties: {
        email: { type: :text },
        given_name: { type: :text},
        family_name: { type: :text }
      }
      indexes :created,       type: :date
      indexes :updated,       type: :date
      indexes :deleted_at,    type: :date
      indexes :cumulative_years, type: :integer, index: "false"
    end
  end

  # also index id as workaround for finding the correct key in associations
  def as_indexed_json(options={})
    {
      "id" => uid,
      "uid" => uid,
      "name" => name,
      "client_ids" => client_ids,
      "prefix_ids" => prefix_ids,
      "symbol" => symbol,
      "year" => year,
      "contact_name" => contact_name,
      "contact_email" => contact_email,
      "is_active" => is_active,
      "description" => description,
      "website" => website,
      "phone" => phone,
      "region" => region,
      "country_code" => country_code,
      "logo_url" => logo_url,
      "focus_area" => focus_area,
      "organization_type" => organization_type,
      "member_type" => member_type,
      "role_name" => role_name,
      "password" => password,
      "cache_key" => cache_key,
      "joined" => joined,
      "twitter_handle" => twitter_handle,
      "ror_id" => ror_id,
      "billing_information" => {
        "address" => billing_address,
        "organization" => billing_organization,
        "department" => billing_department,
        "postCode" => billing_post_code,
        "state" => billing_state,
        "country" => billing_country,
        "city" => billing_city
      },
      "technical_contact" => technical_contact,
      "billing_contact" => billing_contact,
      "secondary_billing_contact" => secondary_billing_contact,
      "service_contact" => service_contact,
      "voting_contact" => voting_contact,
      "created" => created,
      "updated" => updated,
      "deleted_at" => deleted_at,
      "cumulative_years" => cumulative_years
    }
  end

  def self.query_fields
    ['uid^10', 'symbol^10', 'name^5', 'contact_name^5', 'contact_email^5', '_all']
  end

  def self.query_aggregations
    {
      years: { date_histogram: { field: 'created', interval: 'year', min_doc_count: 1 } },
      cumulative_years: { terms: { field: 'cumulative_years', min_doc_count: 1, order: { _count: "asc" } } },
      regions: { terms: { field: 'region', size: 10, min_doc_count: 1 } },
      member_types: { terms: { field: 'member_type', size: 10, min_doc_count: 1 } },
      organization_types: { terms: { field: 'organization_type', size: 10, min_doc_count: 1 } },
      focus_areas: { terms: { field: 'focus_area', size: 10, min_doc_count: 1 } }
    }
  end

  def csv
    provider = {
      name: name,
      provider_id: symbol,
      year: year,
      is_active: is_active,
      description: description,
      website: website,
      region: region_human_name,
      country: country_code,
      logo_url: logo_url,
      focus_area: focus_area,
      organization_type: organization_type,
      member_type: member_type_label,
      contact_email: contact_email,
      technical_contact_email: technical_contact_email,
      technical_contact_given_name: technical_contact_given_name,
      technical_contact_family_name: technical_contact_family_name,
      service_contact_email: service_contact_email,
      service_contact_given_name: service_contact_given_name,
      service_contact_family_name: service_contact_family_name,
      voting_contact_email: voting_contact_email,
      voting_contact_given_name: voting_contact_given_name,
      voting_contact_family_name: voting_contact_family_name,
      billing_address: billing_address,
      billing_post_code: billing_post_code,
      billing_city: billing_city,
      billing_department: billing_department,
      billing_organization: billing_organization,
      billing_state: billing_state,
      billing_country: billing_country,
      billing_contact_email: billing_contact_email,
      billing_contact_given_name: billing_contact_given_name,
      billing_contact_family_name: billing_contact_family_name,
      secondary_billing_contact_email: secondary_billing_contact_email,
      secondary_billing_contact_given_name: secondary_billing_contact_given_name,
      secondary_billing_contact_family_name: secondary_billing_contact_family_name,
      twitter_handle: twitter_handle,
      ror_id: ror_id,
      role_name: role_name,
      joined: joined,
      created: created,
      updated: updated,
      deleted_at: deleted_at,
    }.values

    CSV.generate { |csv| csv << provider }
  end

  def uid
    symbol.downcase
  end

  def cache_key
    "providers/#{uid}-#{updated.iso8601}"
  end

  def year
    joined.year if joined.present?
  end

  def technical_contact_email
    technical_contact.fetch("email",nil) if technical_contact.present?
  end

  def technical_contact_given_name
    technical_contact.fetch("given_name",nil) if technical_contact.present?
  end

  def technical_contact_family_name
    technical_contact.fetch("family_name",nil) if technical_contact.present?
  end

  def service_contact_email
    service_contact.fetch("email",nil) if service_contact.present?
  end

  def service_contact_given_name
    service_contact.fetch("given_name",nil) if service_contact.present?
  end

  def service_contact_family_name
    service_contact.fetch("family_name",nil) if service_contact.present?
  end

  def voting_contact_email
    voting_contact.fetch("email",nil) if voting_contact.present?
  end

  def voting_contact_given_name
    voting_contact.fetch("given_name",nil) if voting_contact.present?
  end

  def voting_contact_family_name
    voting_contact.fetch("family_name",nil) if voting_contact.present?
  end

  def billing_department
    billing_information.fetch("department",nil) if billing_information.present?
  end

  def billing_organization
    billing_information.fetch("organization",nil) if billing_information.present?
  end

  def billing_address
    billing_information.fetch("address",nil) if billing_information.present?
  end

  def billing_state
    billing_information.fetch("state",nil) if billing_information.present?
  end

  def billing_city
    billing_information.fetch("city",nil) if billing_information.present?
  end

  def billing_post_code
    billing_information.fetch("post_code",nil) if billing_information.present?
  end

  def billing_country
    billing_information.fetch("country",nil) if billing_information.present?
  end

  def billing_contact_email
    billing_contact.fetch("email",nil) if billing_contact.present?
  end

  def billing_contact_given_name
    billing_contact.fetch("given_name",nil) if billing_contact.present?
  end

  def billing_contact_family_name
    billing_contact.fetch("family_name",nil) if billing_contact.present?
  end

  def secondary_billing_contact_email
    secondary_billing_contact.fetch("email",nil) if secondary_billing_contact.present?
  end

  def secondary_billing_contact_given_name
    secondary_billing_contact.fetch("given_name",nil) if secondary_billing_contact.present?
  end

  def secondary_billing_contact_family_name
    secondary_billing_contact.fetch("family_name",nil) if secondary_billing_contact.present?
  end

  def member_type_label
    member_type_labels[role_name]
  end

  def member_type_labels
    {
      "ROLE_MEMBER"               => "Member Only",
      "ROLE_ALLOCATOR"            => "Member Provider",
      "ROLE_CONSORTIUM_LEAD"      => "Consortium Lead",
      "ROLE_CONTRACTUAL_PROVIDER" => "Contractual Provider",
      "ROLE_ADMIN"                => "DataCite admin",
      "ROLE_DEV"                  => "DataCite admin",
      "ROLE_FOR_PROFIT_PROVIDER"  => "For-profit Provider"
     }
  end

  def member_type
    member_types[role_name]
  end

  def member_type=(value)
    role_name = member_types.invert.fetch(value, nil)
    write_attribute(:role_name, role_name) if role_name.present?
  end

  def member_types
    {
      "ROLE_MEMBER"               => "member_only",
      "ROLE_ALLOCATOR"            => "provider",
      "ROLE_CONSORTIUM_LEAD"      => "consortium_lead",
      "ROLE_CONTRACTUAL_PROVIDER" => "contractual_provider",
      "ROLE_FOR_PROFIT_PROVIDER"  => "for_profit_provider"
     }
  end

  # count years account has been active. Ignore if deleted the same year as created
  def cumulative_years
    if deleted_at && deleted_at.year > created_at.year
      (created_at.year...deleted_at.year).to_a
    elsif deleted_at
      []
    else
      (created_at.year..Date.today.year).to_a
    end
  end

  # def country=(value)
  #   write_attribute(:country_code, value["code"]) if value.present?
  # end

  def country_name
    ISO3166::Country[country_code].name if country_code.present?
  end

  def set_region
    if country_code.present?
      r = ISO3166::Country[country_code].world_region
    else
      r = nil
    end
    write_attribute(:region, r)
  end

  def regions
    { "AMER" => "Americas",
      "APAC" => "Asia Pacific",
      "EMEA" => "EMEA" }
  end

  def region_human_name
    regions[region]
  end

  def logo_url
    "#{ENV['CDN_URL']}/images/members/#{logo}" if logo.present?
  end

  def password_input=(value)
    write_attribute(:password, encrypt_password_sha256(value)) if value.present?
  end

  def client_ids
    clients.where(deleted_at: nil).pluck(:symbol).map(&:downcase)
  end

  def prefix_ids
    prefixes.pluck(:prefix)
  end

  def freeze_symbol
    errors.add(:symbol, "cannot be changed") if self.symbol_changed?
  end

  def user_url
    ENV["VOLPINO_URL"] + "/users?provider-id=" + symbol.downcase
  end

  # attributes to be sent to elasticsearch index
  def to_jsonapi
    attributes = {
      "symbol" => symbol,
      "name" => name,
      "website" => website,
      "contact-name" => contact_name,
      "contact-email" => contact_email,
      "contact-phone" => phone,
      "prefixes" => prefixes.map { |p| p.prefix },
      "country-code" => country_code,
      "role_name" => role_name,
      "description" => description,
      "is-active" => is_active == "\x01",
      "version" => version,
      "joined" => joined && joined.iso8601,
      "twitter_handle" => twitter_handle,
      "ror_id" => ror_id,
      "created" => created.iso8601,
      "updated" => updated.iso8601,
      "deleted_at" => deleted_at ? deleted_at.iso8601 : nil }

    { "id" => symbol.downcase, "type" => "providers", "attributes" => attributes }
  end

  private

  def set_region
    if country_code.present?
      r = ISO3166::Country[country_code].world_region
    else
      r = nil
    end
    write_attribute(:region, r)
  end

  # def set_provider_type
  #   if doi_quota_allowed != 0
  #     r = "allocating"
  #   else
  #     r = "non_allocating"
  #   end
  #   write_attribute(:provider_type, r)
  # end

  def set_defaults
    self.symbol = symbol.upcase if symbol.present?
    self.is_active = is_active ? "\x01" : "\x00"
    self.version = version.present? ? version + 1 : 0
    self.contact_name = "" unless contact_name.present?
    self.role_name = "ROLE_ALLOCATOR" unless role_name.present?
    self.doi_quota_used = 0 unless doi_quota_used.to_i > 0
    self.doi_quota_allowed = -1 unless doi_quota_allowed.to_i > 0
    self.billing_information = {} unless billing_information.present?
  end
end
