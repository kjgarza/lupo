# frozen_string_literal: true

class OrganizationType < BaseObject
  implements ActorItem

  description "Information about organizations"

  field :identifiers, [IdentifierType], null: true, description: "The identifier(s) for the organization."
  field :url, [Url], null: true, hash_key: "links", description: "URL of the organization."
  field :wikipedia_url, Url, null: true, hash_key: "wikipedia_url", description: "Wikipedia URL of the organization."
  field :types, [String], null: true, description: "The type of organization."
  field :address, AddressType, null: true, description: "Physical address of the organization."
<<<<<<< Updated upstream
=======
  field :inception, GraphQL::Types::ISO8601Date, null: true, description: "Date or point in time when the organization came into existence ."
  field :geolocation, GeolocationPointType, null: true, description: "Geolocation of the organization."
>>>>>>> Stashed changes
  field :view_count, Integer, null: true, description: "The number of views according to the Counter Code of Practice."
  field :download_count, Integer, null: true, description: "The number of downloads according to the Counter Code of Practice."
  field :citation_count, Integer, null: true, description: "The number of citations."

  field :datasets, DatasetConnectionWithTotalType, null: true, description: "Datasets from this organization" do
    argument :query, String, required: false
    argument :ids, [String], required: false
    argument :published, String, required: false
    argument :user_id, String, required: false
    argument :funder_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :registration_agency, String, required: false
    argument :license, String, required: false
    argument :language, String, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :field_of_science, String, required: false
    argument :first, Int, required: false, default_value: 25
    argument :after, String, required: false
  end

  field :publications, PublicationConnectionWithTotalType, null: true, description: "Publications from this organization" do
    argument :query, String, required: false
    argument :ids, [String], required: false
    argument :published, String, required: false
    argument :user_id, String, required: false
    argument :funder_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :registration_agency, String, required: false
    argument :license, String, required: false
    argument :language, String, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :field_of_science, String, required: false
    argument :first, Int, required: false, default_value: 25
    argument :after, String, required: false
  end

  field :softwares, SoftwareConnectionWithTotalType, null: true, description: "Software from this organization" do
    argument :query, String, required: false
    argument :ids, [String], required: false
    argument :published, String, required: false
    argument :user_id, String, required: false
    argument :funder_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :registration_agency, String, required: false
    argument :license, String, required: false
    argument :language, String, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :field_of_science, String, required: false
    argument :first, Int, required: false, default_value: 25
    argument :after, String, required: false
  end

  field :works, WorkConnectionWithTotalType, null: true, description: "Works from this organization" do
    argument :query, String, required: false
    argument :ids, [String], required: false
    argument :published, String, required: false
    argument :user_id, String, required: false
    argument :funder_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :registration_agency, String, required: false
    argument :resource_type_id, String, required: false
    argument :license, String, required: false
    argument :language, String, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :field_of_science, String, required: false
    argument :first, Int, required: false, default_value: 2
    argument :after, String, required: false
  end

  def alternate_name
    object.aliases + object.acronyms
  end

  def identifiers
    object.fundref.map { |o| { "identifierType" => "fundref", "identifier" => o } } + 
    Array.wrap(object.wikidata).map { |o| { "identifierType" => "wikidata", "identifier" => o } } + 
    Array.wrap(object.grid).map { |o| { "identifierType" => "grid", "identifier" => o } } + 
    object.isni.map { |o| { "identifierType" => "isni", "identifier" => o } } 
  end

  def address
    { "type" => "postalAddress",
      "country" => object.country.to_h.fetch("name", nil) }
  end

  def publications(**args)
    args[:resource_type_id] = "Text"
    ElasticsearchModelResponseConnection.new(response(args), context: self.context, first: args[:first], after: args[:after])
  end

  def datasets(**args)
    args[:resource_type_id] = "Dataset"
    ElasticsearchModelResponseConnection.new(response(args), context: self.context, first: args[:first], after: args[:after])
  end

  def softwares(**args)
    args[:resource_type_id] = "Software"
    ElasticsearchModelResponseConnection.new(response(args), context: self.context, first: args[:first], after: args[:after])
  end

  def works(**args)
    ElasticsearchModelResponseConnection.new(response(args), context: self.context, first: args[:first], after: args[:after])
  end

  def view_count
    args = { first: 0 }
    r = response(args)
    r.results.total.positive? ? aggregate_count(r.response.aggregations.views.buckets) : 0
  end

  def download_count
    args = { first: 0 }
    r = response(args)
    r.results.total.positive? ? aggregate_count(r.response.aggregations.downloads.buckets) : 0
  end

  def citation_count
    args = { first: 0 }
    r = response(args)
    r.results.total.positive? ? aggregate_count(r.response.aggregations.citations.buckets) : 0
  end

  def response(**args)
    Doi.gql_query(args[:query], ids: args[:ids], affiliation_id: object.id, user_id: args[:user_id], client_id: args[:repository_id], provider_id: args[:member_id], funder_id: args[:funder_id] || object.fundref.join(","), resource_type_id: args[:resource_type_id], agency: args[:registration_agency], language: args[:language], license: args[:license], has_person: args[:has_person], has_funder: args[:has_funder], has_citations: args[:has_citations], has_parts: args[:has_parts], has_versions: args[:has_versions], has_views: args[:has_views], has_downloads: args[:has_downloads], field_of_science: args[:field_of_science], published: args[:published], state: "findable", page: { cursor: args[:after].present? ? Base64.urlsafe_decode64(args[:after]) : [], size: args[:first] })
  end
end
