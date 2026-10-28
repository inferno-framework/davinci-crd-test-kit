begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
  task default: :spec
rescue LoadError # rubocop:disable Lint/SuppressedException
end

namespace :crd do
  desc 'Regenerate must support metadata and the must support tests that read it'
  task :generate do
    require_relative 'lib/davinci_crd_test_kit/generator/must_support_metadata_generator'
    DaVinciCRDTestKit::Generator::MustSupportMetadataGenerator.new.run

    # Loaded after the metadata is written
    require_relative 'lib/davinci_crd_test_kit/generator/must_support_test_generator'
    puts 'Must support tests'
    DaVinciCRDTestKit::Generator::MustSupportTestGenerator.new.run
  end
end

namespace :db do
  desc 'Apply changes to the database'
  task :migrate do
    require 'inferno/config/application'
    require 'inferno/utils/migration'
    Inferno::Utils::Migration.new.run
  end
end
