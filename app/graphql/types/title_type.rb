# frozen_string_literal: true

class TitleType < BaseObject
  description "Information about titles"

  field :title, String, null: true, description: "Title"
  field :title_type,
        String,
        null: true, hash_key: "titleType", description: "Title type"
  field :lang, ID, null: true, description: "Language"
end
