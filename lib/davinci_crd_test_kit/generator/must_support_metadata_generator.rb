require 'inferno'
require 'yaml'
require_relative '../cross_suite/profile_metadata'

module DaVinciCRDTestKit
  module Generator
    # Run with `bundle exec rake crd:generate_must_support_metadata`.
    class MustSupportMetadataGenerator
      IG_VERSIONS = ['2.2.1'].freeze

      IG_DIRECTORY = File.join(__dir__, '..', 'igs').freeze
      OUTPUT_DIRECTORY = File.join(__dir__, '..', 'cross_suite', 'generated').freeze

      PACKAGES = {
        '2.2.1' => {
          crd: 'davinci_crd_2.2.1.tgz',
          hrex: 'davinci_hrex_1.2.0.tgz'
        }
      }.freeze

      PROFILES = {
        '2.2.1' => [
          # Request types.
          { key: 'vision_prescription', package: :crd, id: 'profile-visionprescription',
            element_scope: :snapshot },
          { key: 'service_request', package: :crd, id: 'profile-servicerequest',
            element_scope: :differential },
          { key: 'nutrition_order', package: :crd, id: 'profile-nutritionorder',
            element_scope: :snapshot },
          { key: 'medication_request', package: :crd, id: 'profile-medicationrequest',
            element_scope: :differential },
          { key: 'device_request', package: :crd, id: 'profile-devicerequest',
            element_scope: :snapshot },
          { key: 'communication_request', package: :crd, id: 'profile-communicationrequest',
            element_scope: :snapshot },
          { key: 'appointment_with_order', package: :crd, id: 'profile-appointment-with-order',
            element_scope: :snapshot },
          { key: 'appointment_without_order', package: :crd, id: 'profile-appointment-no-order',
            element_scope: :snapshot },
          { key: 'encounter', package: :crd, id: 'profile-encounter',
            element_scope: :differential },
          # Supporting profiles.
          { key: 'coverage', package: :crd, id: 'profile-coverage', element_scope: :snapshot },
          { key: 'location', package: :crd, id: 'profile-location', element_scope: :snapshot },
          { key: 'organization', package: :crd, id: 'profile-organization',
            element_scope: :snapshot },
          { key: 'patient', package: :crd, id: 'profile-patient', element_scope: :snapshot },
          { key: 'practitioner', package: :crd, id: 'profile-practitioner',
            element_scope: :snapshot },
          { key: 'practitioner_role', package: :hrex, id: 'hrex-practitionerrole',
            element_scope: :snapshot }
        ]
      }.freeze

      def run
        IG_VERSIONS.each do |ig_version|
          puts "CRD v#{ig_version}"
          PROFILES.fetch(ig_version).each do |config|
            @dropped_slices = []
            metadata = extract(ig_version, config)
            write(ig_version, config[:key], metadata)
            puts "  #{config[:key].ljust(26)} #{metadata.must_support_strings.length} must support element(s)"
            @dropped_slices.each { |slice_id| puts "    dropped unmatchable required binding slice: #{slice_id}" }
          end
        end
      end

      private

      def igs_for(ig_version)
        @igs ||= {}
        @igs[ig_version] ||= PACKAGES.fetch(ig_version).transform_values do |file_name|
          Inferno::Entities::IG.from_file(File.join(IG_DIRECTORY, file_name))
        end
      end

      def extract(ig_version, config)
        ig = igs_for(ig_version).fetch(config[:package])
        profile = ig.profiles.find { |candidate| candidate.id == config[:id] }
        raise "Profile #{config[:id]} not found in the #{config[:package]} package" if profile.nil?

        elements = profile.send(config[:element_scope])&.element
        raise "Profile #{config[:id]} has no #{config[:element_scope]} elements" if elements.blank?

        extractor =
          Inferno::DSL::MustSupportMetadataExtractor.new(elements, profile, profile.type, ig)

        ProfileMetadata.new(
          resource: extractor.resource,
          profile_url: extractor.profile_url,
          # Titles in the published IGs occasionally carry stray whitespace.
          profile_name: extractor.profile_name&.strip,
          profile_version: extractor.profile_version,
          must_supports: normalize(extractor.must_supports)
        )
      end

      # Sorts each collection and forces the sub-keys to be present even when empty, so that the
      # output is stable across runs and the must support assessment never has to nil-check them.
      def normalize(must_supports)
        {
          extensions: Array(must_supports[:extensions]).sort_by { |extension| extension[:id].to_s },
          slices: matchable_slices(must_supports[:slices]).sort_by { |slice| slice[:slice_id].to_s },
          elements: Array(must_supports[:elements]).sort_by { |element| element[:path].to_s },
          recursive_elements: Array(must_supports[:recursive_elements]).sort
        }
      end

      # Drops slices that no resource could ever satisfy.
      def matchable_slices(slices)
        Array(slices).reject do |slice|
          unmatchable = slice.dig(:discriminator, :type) == 'requiredBinding' &&
                        slice.dig(:discriminator, :values).blank?
          @dropped_slices << slice[:slice_id] if unmatchable
          unmatchable
        end
      end

      def write(ig_version, key, metadata)
        directory = File.join(OUTPUT_DIRECTORY, "v#{ig_version}", key)
        FileUtils.mkdir_p(directory)
        File.write(File.join(directory, 'metadata.yml'), metadata.to_hash.to_yaml)
      end
    end
  end
end
