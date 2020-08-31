class Person
  # include helper module for PORO models
  include Modelable

  # include helper module for dates
  include Dateable

  # include helper module for working with Wikidata
  include Wikidatable

  def self.find_by_id(id)
    orcid = orcid_from_url(id)
    return {} unless orcid.present?

    person = get_orcid(orcid: orcid, endpoint: "person")
    return {} unless person.present?

    employments = get_orcid(orcid: orcid, endpoint: "employments")

    other_name = Array.wrap(person.dig("data", "other-names", "other-name")).map do |n|
      n["content"]
    end

    researcher_urls = Array.wrap(person.dig("data", "researcher-urls", "researcher-url")).map do |r|
      { "name" => r["url-name"],
        "url"  => r.dig("url", "value") }
    end

    identifiers = Array.wrap(person.dig("data", "external-identifiers", "external-identifier")).map do |i|
      { "identifierType" => i["external-id-type"],
        "identifierUrl"  => i.dig("external-id-url", "value"),
        "identifier"  => i["external-id-value"] }
    end

    employment = get_employments(employments)
    wikidata_employment = wikidata_query(employment)

    message = {
      "orcid-id" => person.dig("data", "name", "path"),
      "credit-name" => person.dig("data", "name", "credit-name", "value"),
      "given-names" => person.dig("data", "name", "given-names", "value"),
      "family-names" => person.dig("data", "name", "family-name", "value"),
      "other-name" => other_name,
      "description" => person.dig("data", "biography", "content"),
      "researcher-urls" => researcher_urls,
      "identifiers" => identifiers,
      "country-code" => person.dig("data", "addresses", "address", 0, "country", "value"),
      "employment" => wikidata_employment,
    }
    
    data = [parse_message(message: message)]

    errors = person.fetch("errors", nil)

    { data: data, errors: errors }
  end

  def self.query(query, options={})
    options[:limit] ||= 25
    options[:offset] ||= 0

    params = {
      q: query || "*",
      "rows" => options[:limit],
      "start" => options[:offset].to_i * options[:limit].to_i }.compact

    url = "https://pub.orcid.org/v3.0/expanded-search/?" + URI.encode_www_form(params)

    response = Maremma.get(url, accept: "json")
    if response.status >= 400
      message = response.body.dig("errors", 0, "title", "developer-message") || "Something went wrong in ORCID"
      fail ::Faraday::ClientError, message
    end 

    return [] if response.status != 200
    
    data = Array.wrap(response.body.dig("data", "expanded-result")).map do |message|
      parse_message(message: message)
    end
    meta = { "total" => response.body.dig("data", "num-found").to_i }
    errors = response.body.fetch("errors", nil)

    { 
      data: data, 
      meta: meta, 
      errors: errors }
  end

  def self.get_orcid(orcid: nil, endpoint: nil)
    url = "https://pub.orcid.org/v3.0/#{orcid}/#{endpoint}"
    response = Maremma.get(url, accept: "json")

    if response.status >= 405
      message = response.body.dig("errors", 0, "title", "developer-message") || "Something went wrong in ORCID"
      fail ::Faraday::ClientError, message
    end 

    return {} if response.status != 200
    
    response.body
  end

  def self.get_employments(employments)
    Array.wrap(employments.dig("data", "affiliation-group")).map do |a|
      i = a.dig("summaries", 0, "employment-summary", "organization", "disambiguated-organization") || {}
      s = a.dig("summaries", 0, "employment-summary", "start-date") || {}
      e = a.dig("summaries", 0, "employment-summary", "end-date") || {}
      
      { "organizationName" => a.dig("summaries", 0, "employment-summary", "organization", "name"),
        "ringgold"  => i.dig("disambiguation-source") == "RINGGOLD" ? i.dig("disambiguated-organization-identifier") : nil,
        "grid"  => i.dig("disambiguation-source") == "GRID" ? i.dig("disambiguated-organization-identifier") : nil,
        "roleTitle" => a.dig("summaries", 0, "employment-summary", "role-title"),
        "startDate" => get_date_from_parts(s.dig("year", "value"), s.dig("month", "value"), s.dig("day", "value")),
        "endDate" => get_date_from_parts(e.dig("year", "value"), e.dig("month", "value"), e.dig("day", "value")) }.compact
    end
  end

  def self.parse_message(message: nil)
    orcid = message.fetch("orcid-id", nil)

    given_name = message.fetch("given-names", nil)
    family_name = message.fetch("family-names", nil)
    alternate_name = Array.wrap(message.fetch("other-name", nil))
    description = message.fetch("description", nil)
    links = message.fetch("researcher-urls", [])
    identifiers = message.fetch("identifiers", [])
    employment = message.fetch("employment", [])

    if message.fetch("credit-name", nil).present?
      name = message.fetch("credit-name")
    elsif given_name.present? || family_name.present?
      name = [given_name, family_name].join(" ")
    else
      name = orcid
    end

    if message.fetch("country-code", nil).present?
      c = ISO3166::Country[message.fetch("country-code")]
      country = {
        id: message.fetch("country-code"),
        name: c.present? ? c.name : message.fetch("country-code") }
    else
      country = nil
    end
    
    Hashie::Mash.new({
      id: orcid_as_url(orcid),
      type: "Person",
      orcid: orcid,
      name: name,
      given_name: given_name,
      family_name: family_name,
      alternate_name: alternate_name,
      description: description,
      links: links,
      identifiers: identifiers,
      country: country,
      employment: employment }.compact)
  end
end
