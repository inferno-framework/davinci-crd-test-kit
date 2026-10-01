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
          { key: 'vision_prescription', package: :crd, id: 'profile-visionprescription' },
          { key: 'service_request', package: :crd, id: 'profile-servicerequest' },
          { key: 'nutrition_order', package: :crd, id: 'profile-nutritionorder' },
          { key: 'medication_request', package: :crd, id: 'profile-medicationrequest' },
          { key: 'device_request', package: :crd, id: 'profile-devicerequest' },
          { key: 'communication_request', package: :crd, id: 'profile-communicationrequest' },
          { key: 'appointment_with_order', package: :crd, id: 'profile-appointment-with-order' },
          { key: 'appointment_without_order', package: :crd, id: 'profile-appointment-no-order' },
          { key: 'encounter', package: :crd, id: 'profile-encounter' },
          # Supporting profiles.
          { key: 'coverage', package: :crd, id: 'profile-coverage' },
          { key: 'location', package: :crd, id: 'profile-location' },
          { key: 'organization', package: :crd, id: 'profile-organization' },
          { key: 'patient', package: :crd, id: 'profile-patient' },
          { key: 'practitioner', package: :crd, id: 'profile-practitioner' },
          { key: 'practitioner_role', package: :hrex, id: 'hrex-practitionerrole' }
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
        implementation_guide = igs_for(ig_version).fetch(config[:package])
        profile = implementation_guide.profiles.find { |candidate| candidate.id == config[:id] }
        raise "Profile #{config[:id]} not found in the #{config[:package]} package" if profile.nil?

        elements = profile.snapshot&.element
        raise "Profile #{config[:id]} has no elements" if elements.blank?

        extractor =
          Inferno::DSL::MustSupportMetadataExtractor.new(elements, profile, profile.type, implementation_guide)

        ProfileMetadata.new(
          resource: extractor.resource,
          profile_url: extractor.profile_url,
          # Titles in the published IGs occasionally carry stray whitespace.
          profile_name: extractor.profile_name&.strip,
          profile_version: extractor.profile_version,
          must_supports: normalize(extractor.must_supports, profile, implementation_guide, ig_version)
        )
      end

      # Sorts each collection and forces the sub-keys to be present even when empty, so that the
      # output is stable across runs and the must support assessment never has to nil-check them.
      def normalize(must_supports, profile, implementation_guide, ig_version)
        slices = Array(must_supports[:slices]).filter_map do |slice|
          slice = add_reference_target(slice, profile, ig_version)
          add_binding_systems(slice, profile, implementation_guide)
        end

        {
          extensions: Array(must_supports[:extensions]).sort_by { |extension| extension[:id].to_s },
          slices: slices.sort_by { |slice| slice[:slice_id].to_s },
          elements: Array(must_supports[:elements]).sort_by { |element| element[:path].to_s },
          recursive_elements: Array(must_supports[:recursive_elements]).sort
        }
      end

      def add_binding_systems(slice, profile, implementation_guide)
        discriminator = slice[:discriminator]

        return slice if discriminator&.dig(:type) != 'requiredBinding' || discriminator[:values].present?

        includes = binding_includes(slice[:slice_id], profile, implementation_guide)

        if includes.empty?
          @dropped_slices << slice[:slice_id]
          return nil
        end

        systems = includes.map { |include| { system: include.system } }.uniq
        slice.merge(discriminator: discriminator.merge(values: systems))
      end

      def add_reference_target(slice, profile, ig_version)
        return slice if slice.dig(:discriminator, :type) != 'unsupported'

        resource_type = actor_resource_type(slice[:slice_id], profile, ig_version)
        return slice if resource_type.blank?

        slice.merge(discriminator: slice[:discriminator].merge(type: 'referenceTarget', resource_type:))
      end

      def actor_resource_type(slice_id, profile, ig_version) # rubocop:disable Metrics/CyclomaticComplexity
        actor = profile.snapshot.element.find { |candidate| candidate.id == "#{slice_id}.actor" }
        targets = Array(actor&.type).flat_map { |type| Array(type.targetProfile) }.compact.uniq
        return unless targets.one?

        igs_for(ig_version).values.flat_map(&:profiles).find { |one| one.url == targets.first }&.type
      end

      def binding_includes(slice_id, profile, implementation_guide)
        element = profile.snapshot.element.find { |candidate| candidate.id == slice_id }
        value_set = implementation_guide.value_set_by_url(element&.binding&.valueSet)

        Array(value_set&.compose&.include).reject { |include| include.concept.present? }
      end

      def write(ig_version, key, metadata)
        directory = File.join(OUTPUT_DIRECTORY, "v#{ig_version}", key)
        FileUtils.mkdir_p(directory)
        File.write(File.join(directory, 'metadata.yml'), metadata.to_hash.to_yaml)
      end
    end
  end
end
