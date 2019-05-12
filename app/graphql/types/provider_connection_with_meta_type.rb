# frozen_string_literal: true

class ProviderConnectionWithMetaType < GraphQL::Types::Relay::BaseConnection
  edge_type(ProviderEdgeType)

  field :total_count, Integer, null: false

  def total_count
    object.nodes.size
  end
end