namespace :doi do
  desc 'Index all DOIs'
  task :index => :environment do
    if ENV['YEAR'].present?
      from_date = "#{ENV['YEAR']}-01-01"
      until_date = "#{ENV['YEAR']}-12-31"
    else
      from_date = ENV['FROM_DATE'] || Date.current.strftime("%F")
      until_date = ENV['UNTIL_DATE'] || Date.current.strftime("%F")
    end

    index_time = ENV['INDEX_TIME'] || Time.zone.now.utc.iso8601
    client_id = ENV['CLIENT_ID']

    Doi.index(from_date: from_date, until_date: until_date, index_time: index_time, client_id: client_id)
  end

  desc 'Index DOIs per day'
  task :index_by_day => :environment do
    from_date = ENV['FROM_DATE'] || Date.current.strftime("%F")

    Doi.index_by_day(from_date: from_date)
    puts "DOIs created on #{from_date} indexed."
  end

  desc 'Index DOIs by ID'
  task :index_by_ids => :environment do
    from_id = (ENV['FROM_ID'] || 1).to_i
    until_id = (ENV['UNTIL_ID'] || from_id + 499).to_i

    Doi.index_by_ids(from_id: from_id, until_id: until_id)
  end

  desc 'Import all dois'
  task :import => :environment do
    Doi.__elasticsearch__.create_index!
    Doi.import
  end

  desc 'Import all DOIs'
  task :import_all => :environment do
    if ENV['YEAR'].present?
      from_date = "#{ENV['YEAR']}-01-01"
      until_date = "#{ENV['YEAR']}-12-31"
    else
      from_date = ENV['FROM_DATE'] || Date.current.strftime("%F")
      until_date = ENV['UNTIL_DATE'] || Date.current.strftime("%F")
    end

    Doi.import_all(from_date: from_date, until_date: until_date)
  end

  desc 'Import DOIs per day'
  task :import_by_day => :environment do
    from_date = ENV['FROM_DATE'] || Date.current.strftime("%F")

    Doi.import_by_day(from_date: from_date)
    puts "DOIs created on #{from_date} imported."
  end

  desc 'Import missing DOIs'
  task :import_missing => :environment do
    if ENV['YEAR'].present?
      from_date = "#{ENV['YEAR']}-01-01"
      until_date = "#{ENV['YEAR']}-12-31"
    else
      from_date = ENV['FROM_DATE'] || Date.current.strftime("%F")
      until_date = ENV['UNTIL_DATE'] || Date.current.strftime("%F")
    end

    Doi.import_missing(from_date: from_date, until_date: until_date)
  end

  desc 'Import one DOI'
  task :import_one => :environment do
    if ENV['DOI'].nil?
      puts "ENV['DOI'] is required"
      exit
    end

    Doi.import_one(doi_id: ENV['DOI'])
  end

  desc "Create index for dois"
  task :create_index => :environment do
    Doi.__elasticsearch__.create_index!
  end

  desc "Delete index for dois"
  task :delete_index => :environment do
    Doi.__elasticsearch__.delete_index!
  end

  desc "Refresh index for dois"
  task :refresh_index => :environment do
    Doi.__elasticsearch__.refresh_index!
  end

  desc 'Store handle URL'
  task :set_url => :environment do
    Doi.set_url
  end

  desc 'Set handle'
  task :set_handle => :environment do
    Doi.set_handle
  end

  desc 'Delete DOIs with test prefix older than one month'
  task :delete_test_dois => :environment do
    from_date = ENV['FROM_DATE'] || Time.zone.now - 1.month
    Doi.delete_test_dois(from_date: from_date)
  end

  desc 'Migrates landing page data handling camelCase changes at same time'
  task :migrate_landing_page => :environment do
    Doi.migrate_landing_page
  end
end
