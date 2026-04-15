require_relative 'mock_ehr/fhir_read_endpoint'
require_relative 'mock_ehr/fhir_search_endpoint'
require_relative 'mock_ehr/fhir_create_endpoint'
require_relative 'mock_ehr/fhir_update_endpoint'
require_relative 'mock_ehr/fhir_delete_endpoint'
require_relative 'mock_ehr/fhir_metadata_endpoint'

module DaVinciCRDTestKit
  # Include this module within a suite class to add Mock FHIR Server
  # endpoints with data supplied by an input containing a Bundle
  # that can be accessed and updated by calls to the suite's endpoints.
  # Defaults to driving the CapabilityStatement and supported search
  # parameters off of US Core 6.1.0, but a different set of metadata
  # can be provided at inclusion time by using `with` and specifying
  # either a `metadata_dir:` or providing a block that resolves to
  # a list of metadata files to use.
  #
  # @example Default US Core 6.1.0 metadata
  #   class MyTestSuite < Inferno::TestSuite
  #     include MockEHREndpoints
  #   end
  #
  # @example Custom metadata directory (e.g. US Core 7.0.0)
  #   US_CORE_7_DIR = File.join(
  #     Gem::Specification.find_by_name('us_core_test_kit').gem_dir,
  #     'lib', 'us_core_test_kit', 'generated', 'v7.0.0'
  #   )
  #
  #   class MyTestSuite < Inferno::TestSuite
  #     include MockEHREndpoints.with(metadata_dir: US_CORE_7_DIR)
  #   end
  #
  # @example Custom file list via block
  #   class MyTestSuite < Inferno::TestSuite
  #     include(MockEHREndpoints.with { Dir.glob('/path/to/my/metadata/**/metadata.yml') })
  #   end
  module MockEHREndpoints
    def self.included(base)
      configure(base)
    end

    def self.with(metadata_dir: nil, &block)
      Module.new do
        define_singleton_method(:included) do |base|
          MockEHREndpoints.send(:configure, base, metadata_dir:, metadata_files_proc: block)
        end
      end
    end

    def self.configure(base, metadata_dir: nil, metadata_files_proc: nil)
      base.route :get, FHIR_METADATA_ROUTE, build_metadata_endpoint(metadata_dir:, metadata_files_proc:)
      search_endpoint =
        if metadata_dir || metadata_files_proc
          build_search_endpoint(metadata_dir:, metadata_files_proc:)
        else
          MockEHR::FHIRSearchEndpoint
        end
      base.suite_endpoint :post, FHIR_SEARCH_POST_ROUTE, search_endpoint
      base.suite_endpoint :get, FHIR_RESOURCE_TYPE_ROUTE, search_endpoint
      base.suite_endpoint :get, FHIR_INSTANCE_ROUTE, MockEHR::FHIRReadEndpoint
      base.suite_endpoint :post, FHIR_RESOURCE_TYPE_ROUTE, MockEHR::FHIRCreateEndpoint
      base.suite_endpoint :put, FHIR_INSTANCE_ROUTE, MockEHR::FHIRUpdateEndpoint
      base.suite_endpoint :delete, FHIR_INSTANCE_ROUTE, MockEHR::FHIRDeleteEndpoint
    end
    private_class_method :configure

    def self.build_metadata_endpoint(metadata_dir: nil, metadata_files_proc: nil)
      return MockEHR::FHIRMetadataEndpoint unless metadata_dir || metadata_files_proc

      if metadata_files_proc
        Class.new(MockEHR::FHIRMetadataEndpoint) do
          define_singleton_method(:metadata_files) { metadata_files_proc.call }
        end
      else
        Class.new(MockEHR::FHIRMetadataEndpoint) do
          define_singleton_method(:metadata_dir) { metadata_dir }
        end
      end
    end
    private_class_method :build_metadata_endpoint

    def self.build_search_endpoint(metadata_dir: nil, metadata_files_proc: nil)
      if metadata_files_proc
        Class.new(MockEHR::FHIRSearchEndpoint) do
          define_singleton_method(:metadata_files) { metadata_files_proc.call }
        end
      else
        Class.new(MockEHR::FHIRSearchEndpoint) do
          define_method(:metadata_directory) { metadata_dir }
        end
      end
    end
    private_class_method :build_search_endpoint
  end
end
