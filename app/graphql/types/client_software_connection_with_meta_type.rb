# frozen_string_literal: true

class ClientSoftwareConnectionWithMetaType < BaseConnection
  edge_type(DatasetEdgeType)

  field :total_count, Integer, null: false

  def total_count
    args = object.arguments

    Doi.query(args[:query], client_id: object.parent.uid, resource_type_id: "Software", state: "findable", page: { number: 1, size: args[:first] }).results.total
  end
end