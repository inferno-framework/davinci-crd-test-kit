require 'yaml'
require_relative '../../resource_extractor'
require_relative '../../server_test_helper'
require_relative '../../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    class SupportedUSCoreVersionsTest < Inferno::Test
      include DaVinciCRDTestKit::ResourceExtractor
      include DaVinciCRDTestKit::ServerTestHelper

      title 'Provided resources demonstrate support for all required US Core versions'
      id :crd_v221_supported_us_core_versions
      description <<~DESCRIPTION
        Checks whether the embedded FHIR resources provided across hook requests during this test
        session demonstrate support for all US Core versions required by the CRD implementation
        guide: 3.1.1, 6.1.0, and 7.0.0.

        This test does not verify exhaustive support for each US Core version. It inspects FHIR
        resources included in successful hook request `context` and `prefetch` data and verifies
        that at least one provided resource validates against a US Core profile for each required
        version.
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-2'

      US_CORE_VERSIONS = {
        '3.1.1' => 'v3.1.1',
        '6.1.0' => 'v6.1.0',
        '7.0.0' => 'v7.0.0'
      }.freeze

      GENERATED_METADATA_DIR = File.join(
        Gem::Specification.find_by_name('us_core_test_kit').gem_dir,
        'lib', 'us_core_test_kit', 'generated'
      ).freeze

      run do
        ALL_HOOK_TAGS.each { |hook_tag| load_tagged_requests(hook_tag) }
        skip_if requests.empty?, 'No requests were made in a previous test as expected.'

        successful_requests = requests.select { |request| request.status == 200 }
        skip_if successful_requests.empty?, 'All service requests were unsuccessful.'

        embedded_resources = successful_requests.each.flat_map { |request| resources_from_request(request) }

        skip_if embedded_resources.blank?,
                'No embedded FHIR resources were found in successful hook requests.'

        version_matches = determine_version_matches(embedded_resources)
        missing_versions = US_CORE_VERSIONS.keys - version_matches.keys

        missing_versions.each do |version|
          add_message('error', "Support for US Core #{version} was not demonstrated.")
        end

        assert missing_versions.empty?,
               'Support for one or more required US Core versions was not demonstrated.'
      end

      private

      def determine_version_matches(embedded_resources)
        embedded_resources.each_with_object({}) do |resource, matches|
          US_CORE_VERSIONS.each_key do |version|
            next if matches.key?(version)

            matching_profile = us_core_profiles_by_version
              .dig(version, resource.resourceType)
              &.find { |profile_url| resource_valid_for_profile?(resource, profile_url) }

            next unless matching_profile.present?

            matches[version] = matching_profile
          end
        end
      end

      def resource_valid_for_profile?(resource, profile_url)
        validation_details = []
        resource_is_valid?(
          resource:,
          profile_url:,
          validator_response_details: validation_details,
          add_messages_to_runnable: false
        )
      end

      def us_core_profiles_by_version
        @us_core_profiles_by_version ||= US_CORE_VERSIONS.transform_values do |directory|
          version_profile_metadata(directory).each_with_object(
            Hash.new { |hash, key| hash[key] = [] }
          ) do |metadata, profiles_by_resource|
            profile_identifier = versioned_profile_identifier(metadata)
            next unless profile_identifier.present?

            profiles_by_resource[metadata[:resource]] << profile_identifier
          end.transform_values(&:uniq)
        end
      end

      def version_profile_metadata(directory)
        Dir.glob(File.join(GENERATED_METADATA_DIR, directory, '*', 'metadata.yml')).map do |path|
          YAML.load_file(path, aliases: true)
        end
      end

      def versioned_profile_identifier(metadata)
        resource_type = metadata[:resource]
        profile_url = metadata[:profile_url]
        profile_version = metadata[:profile_version]
        return if resource_type.blank? || profile_url.blank? || profile_version.blank?

        "#{profile_url}|#{profile_version}"
      end
    end
  end
end
