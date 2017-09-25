require "countries"

class Provider < ActiveRecord::Base
  # include helper module for caching infrequently changing resources
  include Cacheable

  # include helper module for counting registered DOIs
  include Countable

  # define table and attribute names
  # uid is used as unique identifier, mapped to id in serializer

  self.table_name = "allocator"
  alias_attribute :uid, :symbol
  alias_attribute :created_at, :created
  alias_attribute :updated_at, :updated

  validates_presence_of :symbol, :name, :contact_name, :contact_email
  validates_uniqueness_of :symbol, message: "This name has already been taken"
  validates_format_of :contact_email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, message: "contact_email should be an email"
  validates_format_of :website, :with => /https?:\/\/[\S]+/ , if: :website?, message: "Website should be an url"
  validates_numericality_of :doi_quota_allowed, :doi_quota_used
  validates_numericality_of :version, if: :version?
  validates_inclusion_of :role_name, :in => %w( ROLE_ALLOCATOR ROLE_ADMIN ROLE_DEV ), :message => "Role %s is not included in the list", if: :role_name?
  validate :freeze_uid, :on => :update

  has_many :clients, foreign_key: :allocator
  has_many :provider_prefixes, foreign_key: :allocator
  has_many :prefixes, through: :provider_prefixes

  before_validation :set_region, :set_defaults
  before_create :set_test_prefix
  before_create { self.created = Time.zone.now.utc.iso8601 }
  before_save { self.updated = Time.zone.now.utc.iso8601 }
  accepts_nested_attributes_for :prefixes

  default_scope { where("allocator.role_name = 'ROLE_ALLOCATOR'").where(deleted_at: nil) }
  scope :query, ->(query) { where("allocator.symbol like ? OR allocator.name like ?", "%#{query}%", "%#{query}%") }

  def year
    created.year
  end

  def country_name
    return nil unless country_code.present?

    ISO3166::Country[country_code].name
  end

  def regions
    { "AMER" => "Americas",
      "APAC" => "Asia Pacific",
      "EMEA" => "EMEA" }
  end

  def region_name
    regions[region]
  end

  def logo_url
    "#{ENV['CDN_URL']}/images/members/#{uid.downcase}.png"
  end

  def query_filter
    "allocator_symbol:#{symbol}"
  end

  # cumulative count deleted clients in the previous year
  def client_count
    clients.unscoped.where("datacentre.allocator = ?", id)
      .pluck(:symbol, :created, :deleted_at)
      .group_by { |c| c[2].present? ? c[2].year - 1 : c[1].year }
      .sort { |a, b| a.first <=> b.first }
      .reduce([]) do |sum, c|
        deleted = c[1].select { |s| s[2].present? }.count
        count = c[1].count + sum.last.to_h["count"].to_i - sum.last.to_h["deleted"].to_i
        sum << { "id" => c[0], "title" => c[0], "count" => count, "deleted" => deleted }
        sum
      end
      .map { |c| c.except("deleted") }
  end

  def freeze_uid
    errors.add(:symbol, "cannot be changed") if self.symbol_changed?
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

  def set_test_prefix
    return if prefixes.where(prefix: "10.5072").first

    prefixes << cached_prefix_response("10.5072")
  end

  def set_defaults
    self.symbol = symbol.upcase
    self.is_active = is_active ? "\x01" : "\x00"
    self.contact_name = "" unless contact_name.present?
    self.role_name = "ROLE_ALLOCATOR" unless role_name.present?
    self.doi_quota_used = 0 unless doi_quota_used.to_i > 0
    self.doi_quota_allowed = -1 unless doi_quota_allowed.to_i > 0
  end
end
