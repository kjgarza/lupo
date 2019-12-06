# frozen_string_literal: true

class DataCatalogDatasetConnectionWithMetaType < BaseConnection
  edge_type(DatasetEdgeType)
  field_class GraphQL::Cache::Field
  
  field :total_count, Integer, null: false, cache: true

  def total_count
    args = object.arguments

    Doi.query(args[:query], re3data_id: doi_from_url(object.parent[:id]), resource_type_id: "Dataset", state: "findable", page: { number: 1, size: 0 }).results.total
  end
end
