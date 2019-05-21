# frozen_string_literal: true

class PublicationConnectionWithMetaType < BaseConnection
  edge_type(DatasetEdgeType)
  field_class GraphQL::Cache::Field

  field :total_count, Integer, null: false, cache: true

  def total_count
    args = object.arguments
    
    Doi.query(args[:query], resource_type_id: "Text", state: "findable", page: { number: 1, size: args[:first] }).results.total
  end
end
