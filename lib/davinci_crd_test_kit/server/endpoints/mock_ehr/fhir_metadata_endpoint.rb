require 'yaml'
require 'us_core_test_kit'
require_relative '../../../version'

module DaVinciCRDTestKit
  module MockEHR
    class FHIRMetadataEndpoint
      MOCK_EHR_INTERACTIONS = %w[read search-type create update delete].freeze

      US_CORE_METADATA_DIR = File.join(
        Gem::Specification.find_by_name('us_core_test_kit').gem_dir,
        'lib', 'us_core_test_kit', 'generated', 'v6.1.0'
      ).freeze

      SEARCH_PARAM_TYPES = {
        'string' => 'string', 'HumanName' => 'string', 'Address' => 'string',
        'http://hl7.org/fhirpath/System.String' => 'string',
        'code' => 'token', 'CodeableConcept' => 'token', 'Coding' => 'token',
        'Identifier' => 'token', 'patternCodeableConcept' => 'token',
        'patternCoding' => 'token', 'patternIdentifier' => 'token', 'requiredBinding' => 'token',
        'date' => 'date', 'dateTime' => 'date', 'instant' => 'date', 'Period' => 'date',
        'Reference' => 'reference',
        'uri' => 'uri', 'canonical' => 'uri',
        'number' => 'number', 'integer' => 'number', 'decimal' => 'number',
        'quantity' => 'quantity'
      }.freeze

      def self.call(...)
        new.call(...)
      end

      def call(env)
        request = Rack::Request.new(env)
        [200, { 'Content-Type' => 'application/fhir+json' }, [capability_statement_json(request)]]
      end

      def capability_statement_json(request)
        fhir_base_url = request.url.delete_suffix('/metadata')
        suite_id = request.path.split('/')[2]
        suite_title = Inferno::Repositories::TestSuites.new.find(suite_id)&.title
        fhir_server_name = 'Inferno US Core FHIR Server Simulation'

        FHIR::CapabilityStatement.new(
          status: 'active',
          kind: 'instance',
          date: LAST_UPDATED,
          software: FHIR::CapabilityStatement::Software.new(
            name: fhir_server_name
          ),
          implementation: FHIR::CapabilityStatement::Implementation.new(
            description: "#{suite_title} #{fhir_server_name} hosted at #{fhir_base_url}",
            url: fhir_base_url
          ),
          fhirVersion: '4.0.1',
          format: ['application/fhir+json'],
          instantiates: ['http://hl7.org/fhir/us/core/CapabilityStatement/us-core-server'],
          rest: [FHIR::CapabilityStatement::Rest.new(mode: 'server', resource: self.class.resource_entries)]
        ).to_json
      end

      def self.metadata_dir
        US_CORE_METADATA_DIR
      end

      def self.metadata_files
        Dir.glob(File.join(metadata_dir, '*', 'metadata.yml'))
      end

      def self.resource_entries
        @resource_entries ||= build_resource_entries
      end

      def self.search_param_type(type)
        SEARCH_PARAM_TYPES.fetch(type, 'string')
      end

      def self.collect_search_params(metadata_list)
        metadata_list.each_with_object({}) do |metadata, params|
          metadata.search_definitions&.each do |name, definition|
            params[name.to_s] ||= definition[:type]
          end
        end
      end

      def self.build_resource_entry(resource_type, metadata_list)
        search_params = collect_search_params(metadata_list)
        profile_urls = metadata_list.map(&:profile_url).compact
        FHIR::CapabilityStatement::Rest::Resource.new(
          type: resource_type,
          supportedProfile: profile_urls,
          interaction: MOCK_EHR_INTERACTIONS.map do |code|
            FHIR::CapabilityStatement::Rest::Resource::Interaction.new(code:)
          end,
          searchParam: search_params.map do |name, type|
            FHIR::CapabilityStatement::Rest::Resource::SearchParam.new(
              name:,
              type: search_param_type(type)
            )
          end
        )
      end

      def self.build_resource_entries
        by_type = metadata_files.each_with_object(Hash.new { |h, k| h[k] = [] }) do |path, types|
          metadata = USCoreTestKit::Generator::GroupMetadata.new(YAML.load_file(path, aliases: true))
          types[metadata.resource] << metadata
        end
        by_type.map { |resource_type, metadata_list| build_resource_entry(resource_type, metadata_list) }
      end
    end
  end
end
