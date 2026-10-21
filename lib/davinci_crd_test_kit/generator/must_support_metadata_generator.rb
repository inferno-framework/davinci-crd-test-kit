require 'inferno'
require 'yaml'
require_relative 'crd_must_support_metadata_extractor'
require_relative '../cross_suite/must_support_references'
require_relative '../cross_suite/profile_metadata'

module DaVinciCRDTestKit
  module Generator
    # Run with `bundle exec rake crd:generate`.
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

      # Must support references can target US Core profiles, which are not in the packages above,
      # so the US Core package the CRD IG depends on is read from the US Core test kit when writing
      # stubs for those targets.
      US_CORE_PACKAGES = {
        '2.2.1' => 'us_core_700.tgz'
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
          { key: 'device', package: :crd, id: 'profile-device' },
          { key: 'location', package: :crd, id: 'profile-location' },
          { key: 'medication', package: :crd, id: 'profile-medication' },
          { key: 'organization', package: :crd, id: 'profile-organization' },
          { key: 'patient', package: :crd, id: 'profile-patient' },
          { key: 'practitioner', package: :crd, id: 'profile-practitioner' },
          { key: 'practitioner_role', package: :hrex, id: 'hrex-practitionerrole' }
        ]
      }.freeze

      def run
        IG_VERSIONS.each do |ig_version|
          puts "CRD v#{ig_version}"
          generated = PROFILES.fetch(ig_version).map do |config|
            metadata = extract(ig_version, config)
            write(ig_version, config[:key], metadata)
            puts "  #{config[:key].ljust(26)} #{metadata.must_support_strings.length} must support element(s)"
            metadata
          end
          write_target_profile_stubs(ig_version, generated)
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
          CRDMustSupportMetadataExtractor.new(elements, profile, profile.type, implementation_guide)

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
          choices: Array(must_supports[:choices]).sort_by do |choice|
            [choice[:element].to_s, (choice[:paths] || choice[:slice_names]).to_a.first.to_s]
          end,
          recursive_elements: Array(must_supports[:recursive_elements]).sort
        }
      end

      # A must support reference test looks up each target profile by URL to learn its resource
      # type, so a target profile without generated metadata of its own gets a stub carrying just
      # its identifying details and no must supports.
      def write_target_profile_stubs(ig_version, generated)
        generated_urls = generated.map(&:profile_url)
        target_urls = generated.flat_map { |metadata| target_profile_urls(metadata) }.uniq - generated_urls

        target_urls.sort.each do |url|
          profile = target_igs_for(ig_version).flat_map(&:profiles).find { |one| one.url == url }
          raise "Target profile #{url} not found in any package" if profile.nil?

          key = stub_key(profile)
          write(ig_version, key, stub_metadata(profile))
          puts "  #{key.ljust(26)} stub for target profile"
        end
      end

      # Base FHIR resource definitions are identified by their URL alone, so they need no stub.
      def target_profile_urls(metadata)
        metadata.must_supports[:elements]
          .flat_map { |element| Array(element[:target_profiles]) + Array(element[:allowed_target_profiles]) }
          .map { |target_profile| target_profile.split('|').first }
          .reject { |url| MustSupportReferences.base_resource_type(url) }
      end

      def stub_key(profile)
        profile.id.delete_prefix('profile-').tr('-', '_')
      end

      def stub_metadata(profile)
        ProfileMetadata.new(
          resource: profile.type,
          profile_url: profile.url,
          profile_name: profile.title&.strip,
          profile_version: profile.version
        )
      end

      def target_igs_for(ig_version)
        @target_igs ||= {}
        @target_igs[ig_version] ||= igs_for(ig_version).values + [us_core_ig(ig_version)]
      end

      def us_core_ig(ig_version)
        directory = File.join(Gem.loaded_specs['us_core_test_kit'].full_gem_path, 'lib', 'us_core_test_kit', 'igs')
        Inferno::Entities::IG.from_file(File.join(directory, US_CORE_PACKAGES.fetch(ig_version)))
      end

      def add_binding_systems(slice, profile, implementation_guide)
        discriminator = slice[:discriminator]

        return slice if discriminator&.dig(:type) != 'requiredBinding' || discriminator[:values].present?

        includes = binding_includes(slice[:slice_id], profile, implementation_guide)
        return nil if includes.empty?

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
