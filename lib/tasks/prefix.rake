namespace :client_prefix do
  desc 'Make id for datacentre_prefixes table random'
  task :random => :environment do
    ClientPrefix.find_each do |cp|
      cp.send(:set_id)
      cp.save
    end
  end

  desc 'Set created date from prefix'
  task :created => :environment do
    ClientPrefix.find_each do |cp|
      cp.update_column(:created, cp.prefix.created)
    end
  end
end

namespace :provider_prefix do
  desc 'Make id for allocator_prefixes table random'
  task :random => :environment do
    ProviderPrefix.find_each do |pp|
      pp.send(:set_id)
      pp.save
    end
  end

  desc 'Set created date from prefix'
  task :created => :environment do
    ProviderPrefix.find_each do |pp|
      pp.update_column(:created, pp.prefix.created)
    end
  end
end
