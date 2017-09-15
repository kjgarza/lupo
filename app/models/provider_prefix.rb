require 'base32/crockford'

class ProviderPrefix < ApplicationRecord
  self.table_name = "allocator_prefixes"

  belongs_to :provider, foreign_key: :allocator
  belongs_to :prefix, foreign_key: :prefixes

  alias_attribute :created_at, :created
  alias_attribute :updated_at, :updated

  before_create :set_id
  before_create { self.created = Time.zone.now.utc.iso8601 }
  before_save { self.updated = Time.zone.now.utc.iso8601 }

  scope :query, ->(query) { where("prefix.prefix like ?", "%#{query}%") }

  # use base32-encode id as uid, with pretty formatting and checksum
  def uid
    Base32::Crockford.encode(id, split: 4, length: 16, checksum: true).downcase
  end

  private

  # random number that fits into MySQL bigint field (8 bytes)
  def set_id
    self.id = SecureRandom.random_number(9223372036854775807)
  end
end
