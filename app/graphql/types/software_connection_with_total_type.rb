# frozen_string_literal: true

class SoftwareConnectionWithTotalType < BaseConnection
  edge_type(SoftwareEdgeType)
  field_class GraphQL::Cache::Field

  field :total_count, Integer, null: false, cache: true
  field :published, [FacetType], null: true, cache: true
  field :registration_agencies, [FacetType], null: true, cache: true
  field :repositories, [FacetType], null: true, cache: true
  field :affiliations, [FacetType], null: true, cache: true
  field :fields_of_science, [FacetType], null: true, cache: true
  field :licenses, [FacetType], null: true, cache: true
  field :languages, [FacetType], null: true, cache: true

  field :software_connection_count, Integer, null: false, cache: true
  field :publication_connection_count, Integer, null: false, cache: true
  field :dataset_connection_count, Integer, null: false, cache: true
  field :person_connection_count, Integer, null: false, cache: true
  field :funder_connection_count, Integer, null: false, cache: true
  field :organization_connection_count, Integer, null: false, cache: true

  def total_count
    object.total_count
  end

  def published
    if object.aggregations.published
      facet_by_range(object.aggregations.published.buckets)
    else
      []
    end
  end

  def registration_agencies
    if object.aggregations.registration_agencies
      facet_by_registration_agency(
        object.aggregations.registration_agencies.buckets
      )
    else
      []
    end
  end

  def repositories
    if object.aggregations.clients
      facet_by_combined_key(object.aggregations.clients.buckets)
    else
      []
    end
  end

  def affiliations
    if object.aggregations.affiliations
      facet_by_combined_key(object.aggregations.affiliations.buckets)
    else
      []
    end
  end

  def licenses
    if object.aggregations.licenses
      facet_by_license(object.aggregations.licenses.buckets)
    else
      []
    end
  end

  def fields_of_science
    if object.aggregations.fields_of_science
      facet_by_fos(object.aggregations.fields_of_science.subject.buckets)
    else
      []
    end
  end

  def languages
    if object.aggregations.languages
      facet_by_language(object.aggregations.languages.buckets)
    else
      []
    end
  end

  def software_connection_count
    Event.query(
      nil,
      citation_type: "SoftwareSourceCode-SoftwareSourceCode",
      page: { number: 1, size: 0 },
    ).
      results.
      total
  end

  def publication_connection_count
    Event.query(
      nil,
      citation_type: "ScholarlyArticle-SoftwareSourceCode",
      page: { number: 1, size: 0 },
    ).
      results.
      total
  end

  def dataset_connection_count
    Event.query(
      nil,
      citation_type: "Dataset-SoftwareSourceCode", page: { number: 1, size: 0 },
    ).
      results.
      total
  end

  def person_connection_count
    Event.query(
      nil,
      citation_type: "Person-SoftwareSourceCode", page: { number: 1, size: 0 },
    ).
      results.
      total
  end

  def funder_connection_count
    Event.query(
      nil,
      citation_type: "Funder-SoftwareSourceCode", page: { number: 1, size: 0 },
    ).
      results.
      total
  end

  def organization_connection_count
    Event.query(
      nil,
      citation_type: "Organization-SoftwareSourceCode",
      page: { number: 1, size: 0 },
    ).
      results.
      total
  end
end
