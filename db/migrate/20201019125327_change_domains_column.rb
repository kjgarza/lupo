# frozen_string_literal: true

class ChangeDomainsColumn < ActiveRecord::Migration[5.2]
  def up
    change_column :datacentre, :domains, :text, limit: 65_535
  end

  def down
    change_column :datacentre, :domains, :string
  end
end
