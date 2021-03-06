# frozen_string_literal: true

namespace :contact do
  desc "Create index for contacts"
  task create_index: :environment do
    puts Contact.create_index
  end

  desc "Delete index for contacts"
  task delete_index: :environment do
    puts Contact.delete_index(index: ENV["INDEX"])
  end

  desc "Upgrade index for contacts"
  task upgrade_index: :environment do
    puts Contact.upgrade_index
  end

  desc "Show index stats for contacts"
  task index_stats: :environment do
    puts Contact.index_stats
  end

  desc "Switch index for contacts"
  task switch_index: :environment do
    puts Contact.switch_index
  end

  desc "Return active index for contacts"
  task active_index: :environment do
    puts Contact.active_index + " is the active index."
  end

  desc "Monitor reindexing for contacts"
  task monitor_reindex: :environment do
    puts Contact.monitor_reindex
  end

  desc "Create alias for contacts"
  task create_alias: :environment do
    puts Contact.create_alias(index: ENV["INDEX"], alias: ENV["ALIAS"])
  end

  desc "List aliases for contacts"
  task list_aliases: :environment do
    puts Contact.list_aliases
  end

  desc "Delete alias for contacts"
  task delete_alias: :environment do
    puts Contact.delete_alias(index: ENV["INDEX"], alias: ENV["ALIAS"])
  end

  desc "Import all contacts"
  task import: :environment do
    Contact.import(index: Contact.inactive_index)
  end

  desc "Import contacts from providers"
  task import_from_providers: :environment do
    Contact.import_from_providers
  end
end
