# frozen_string_literal: true

class FunderSoftwareConnectionWithMetaType < BaseConnection
  edge_type(EventDataEdgeType, edge_class: EventDataEdge)
  field_class GraphQL::Cache::Field
  
  field :total_count, Integer, null: false, cache: true

  def total_count
    Event.query(nil, obj_id: object.parent[:id], citation_type: "Funder-SoftwareSourceCode").dig(:meta, "total").to_i
  end
end