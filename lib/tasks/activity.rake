namespace :activity do
  desc "Create index for activities"
  task :create_index => :environment do
    Activity.__elasticsearch__.create_index!
  end

  desc "Delete index for activities"
  task :delete_index => :environment do
    Activity.__elasticsearch__.delete_index!
  end

  desc "Refresh index for activities"
  task :refresh_index => :environment do
    Activity.__elasticsearch__.refresh_index!
  end

  desc 'Import all activities'
  task :import => :environment do
    Activity.import
  end

  desc 'Index all activities'
  task :index => :environment do
    from_id = (ENV['FROM_ID'] || 1).to_i
    until_id = (ENV['UNTIL_ID'] || from_id + 499).to_i

    Activity.index_by_ids(from_id: from_id, until_id: until_id)
  end
end