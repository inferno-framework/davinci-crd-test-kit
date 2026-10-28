require 'erb'
require 'fileutils'
require_relative '../cross_suite/profile_metadata'
require_relative '../client/v2.2.1/must_support/request_must_support_with_attestation_option'
require_relative '../client/v2.2.1/must_support/request_must_support_reference_resolution'

module DaVinciCRDTestKit
  module Generator
    # Generates the must support group, the must support element test for each resource type it
    # holds, and a reference resolution test for each of those types with must support Reference
    # elements. Run as part of `bundle exec rake crd:generate`.
    class MustSupportTestGenerator
      CONF_3 = 'hl7.fhir.us.davinci-crd_2.2.1@conf-3'.freeze
      HOOK_3 = 'hl7.fhir.us.davinci-crd_2.2.1@hook-3'.freeze
      # billing-options is must support on the profiles that can carry billing codes, so their must
      # support tests show whether the CRD client conveys them
      BILLOPT_1 = 'hl7.fhir.us.davinci-crd_2.2.1@billopt-1'.freeze

      # One test per request type, plus one for each profile that is referenced from within a
      # request rather than being a request itself. Order here is the order in the UI, which is
      # alphabetical by resource type.
      TEST_DEFINITIONS = [
        { id: :crd_v221_appointment_must_support, requirements: [CONF_3, BILLOPT_1],
          profiles: [{ resource_type: 'Appointment', title: 'CRD Appointment', supporting_profile: true,
                       profile_keys: %w[appointment_with_order appointment_without_order] }] },
        { id: :crd_v221_communication_request_must_support, requirements: [CONF_3, HOOK_3, BILLOPT_1],
          profiles: [{ resource_type: 'CommunicationRequest', profile_keys: ['communication_request'] }] },
        { id: :crd_v221_coverage_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Coverage', supporting_profile: true, profile_keys: ['coverage'] }] },
        { id: :crd_v221_device_must_support, requirements: [CONF_3, BILLOPT_1],
          profiles: [{ resource_type: 'Device', supporting_profile: true, profile_keys: ['device'] }] },
        { id: :crd_v221_device_request_must_support, requirements: [CONF_3, HOOK_3, BILLOPT_1],
          profiles: [{ resource_type: 'DeviceRequest', profile_keys: ['device_request'] }] },
        { id: :crd_v221_encounter_must_support, requirements: [CONF_3, BILLOPT_1],
          profiles: [{ resource_type: 'Encounter', supporting_profile: true, profile_keys: ['encounter'] }] },
        { id: :crd_v221_location_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Location', supporting_profile: true, profile_keys: ['location'] }] },
        { id: :crd_v221_medication_must_support, requirements: [CONF_3, BILLOPT_1],
          profiles: [{ resource_type: 'Medication', supporting_profile: true, profile_keys: ['medication'] }] },
        { id: :crd_v221_medication_request_must_support, requirements: [CONF_3, HOOK_3, BILLOPT_1],
          profiles: [{ resource_type: 'MedicationRequest', profile_keys: ['medication_request'] }] },
        { id: :crd_v221_nutrition_order_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'NutritionOrder', profile_keys: ['nutrition_order'] }] },
        { id: :crd_v221_organization_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Organization', supporting_profile: true, profile_keys: ['organization'] }] },
        { id: :crd_v221_patient_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Patient', supporting_profile: true, profile_keys: ['patient'] }] },
        { id: :crd_v221_practitioner_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Practitioner', supporting_profile: true, profile_keys: ['practitioner'] }] },
        { id: :crd_v221_practitioner_role_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'PractitionerRole', supporting_profile: true,
                       profile_keys: ['practitioner_role'] }] },
        { id: :crd_v221_service_request_must_support, requirements: [CONF_3, HOOK_3, BILLOPT_1],
          profiles: [{ resource_type: 'ServiceRequest', profile_keys: ['service_request'] }] },
        { id: :crd_v221_vision_prescription_must_support, requirements: [CONF_3, HOOK_3, BILLOPT_1],
          profiles: [{ resource_type: 'VisionPrescription', profile_keys: ['vision_prescription'] }] }
      ].freeze

      # The order types a tester can declare support for, and the supporting types that are not
      # required of every client.
      ORDER_TYPE_OPTIONS = %w[
        CommunicationRequest DeviceRequest MedicationRequest NutritionOrder ServiceRequest
        VisionPrescription
      ].freeze
      SUPPORTING_TYPE_OPTIONS = %w[
        Appointment Device Encounter Location Medication Organization Practitioner PractitionerRole
      ].freeze

      REQUIRING_HOOKS = {
        'Appointment' => ['APPOINTMENT_BOOK_TAG'],
        'Encounter' => %w[ENCOUNTER_START_TAG ENCOUNTER_DISCHARGE_TAG]
      }.freeze

      IG_VERSION = 'v2.2.1'.freeze
      MODULE_NAME = 'V221'.freeze
      GROUP_ID = 'crd_v221_client_cross_hook_must_support'.freeze
      REQUESTS_GROUP_ID = "#{GROUP_ID}_requests".freeze
      RESPONSES_GROUP_ID = "#{GROUP_ID}_responses".freeze
      ORDER_TYPES_SIGNED_TEST_ID = 'crd_v221_client_order_types_signed'.freeze
      COVERAGE_INFORMATION_TEST_ID = 'crd_v221_client_card_must_support_coverage_information'.freeze

      # The group is written alongside its tests so that every generated file sits in one folder.
      OUTPUT_DIRECTORY = File.join(__dir__, '..', 'client', 'v2.2.1', 'must_support', 'generated').freeze

      # Generated files are linted along with the rest of the project.
      MAX_LINE_LENGTH = 120

      def run
        FileUtils.mkdir_p(OUTPUT_DIRECTORY)

        TEST_DEFINITIONS.each do |definition|
          File.write(File.join(OUTPUT_DIRECTORY, file_name_for(definition)), render_test(definition))
          puts "  #{file_name_for(definition)}"
          next unless references?(definition)

          File.write(File.join(OUTPUT_DIRECTORY, reference_file_name_for(definition)),
                     render_reference_test(definition))
          puts "  #{reference_file_name_for(definition)}"
        end

        File.write(File.join(OUTPUT_DIRECTORY, 'client_cross_hook_must_support_group.rb'), render_group)
        puts '  client_cross_hook_must_support_group.rb'
      end

      private

      def render(template_name, variables)
        template = File.read(File.join(__dir__, 'templates', template_name))
        ERB.new(template, trim_mode: '-').result_with_hash(variables)
      end

      def render_test(definition)
        profile = definition[:profiles].first
        options = { ig_version: IG_VERSION, profiles: definition[:profiles] }

        render('must_support_test.rb.erb',
               module_name: MODULE_NAME,
               class_name: class_name_for(definition),
               test_id: definition[:id],
               title: title_for(profile, definition),
               indented_description: indent(description_for(options), 8),
               requirements: definition[:requirements],
               ig_version: IG_VERSION,
               profiles_literal: profiles_literal(definition[:profiles]))
      end

      # Each reference resolution test follows the element test for the same resource type.
      def render_reference_test(definition)
        profile = definition[:profiles].first
        options = { ig_version: IG_VERSION, profiles: definition[:profiles] }
        metadata = test_class.metadata_for(IG_VERSION, profile)

        render('reference_resolution_test.rb.erb',
               module_name: MODULE_NAME,
               class_name: reference_class_name_for(definition),
               test_id: reference_test_id_for(definition),
               title: "#{definition[:title] || test_class.title_for(metadata, profile)} must support references " \
                      'resolve',
               indented_description: indent(reference_test_class.build_description(options), 8),
               requirements: [CONF_3],
               ig_version: IG_VERSION,
               profiles_literal: profiles_literal(definition[:profiles]))
      end

      def render_group
        render('must_support_group.rb.erb',
               module_name: MODULE_NAME,
               group_id: GROUP_ID,
               requests_group_id: REQUESTS_GROUP_ID,
               responses_group_id: RESPONSES_GROUP_ID,
               test_file_names: group_file_names,
               test_ids: group_test_ids,
               order_type_options: ORDER_TYPE_OPTIONS,
               supporting_type_options: SUPPORTING_TYPE_OPTIONS,
               requiring_hooks: REQUIRING_HOOKS,
               order_types_signed_test_id: ORDER_TYPES_SIGNED_TEST_ID,
               coverage_information_test_id: COVERAGE_INFORMATION_TEST_ID)
      end

      def group_test_ids
        TEST_DEFINITIONS.flat_map do |definition|
          [definition[:id], (reference_test_id_for(definition) if references?(definition))].compact
        end
      end

      def group_file_names
        file_names = TEST_DEFINITIONS.flat_map do |definition|
          [file_name_for(definition), (reference_file_name_for(definition) if references?(definition))].compact
        end
        file_names.map { |file_name| file_name.delete_suffix('.rb') }
      end

      def references?(definition)
        definition[:profiles].any? do |profile|
          MustSupportReferences.reference_elements(test_class.metadata_for(IG_VERSION, profile)).present?
        end
      end

      def test_class
        V221::RequestMustSupportWithAttestationOption
      end

      def reference_test_class
        V221::RequestMustSupportReferenceResolution
      end

      def reference_test_id_for(definition)
        :"#{definition[:id]}_reference_resolution"
      end

      def reference_class_name_for(definition)
        "#{definition[:profiles].first[:resource_type]}ReferenceResolutionTest"
      end

      def reference_file_name_for(definition)
        "#{reference_class_name_for(definition).underscore}.rb"
      end

      def description_for(options)
        test_class.build_description(options)
      end

      def title_for(profile, definition)
        return definition[:title] if definition[:title].present?

        metadata = test_class.metadata_for(IG_VERSION, profile)
        "#{test_class.title_for(metadata, profile)} must support elements are observed"
      end

      def class_name_for(definition)
        "#{definition[:profiles].first[:resource_type]}MustSupportTest"
      end

      def file_name_for(definition)
        "#{class_name_for(definition).underscore}.rb"
      end

      def indent(text, spaces)
        text.each_line.map { |line| line.strip.empty? ? line : "#{' ' * spaces}#{line}" }.join
      end

      # The profiles are written back out as Ruby so the generated test carries them literally
      # rather than reaching for the generator at boot.
      def profiles_literal(profiles)
        entries = profiles.map { |profile| profile_literal(profile) }

        "[\n#{entries.join(",\n")}\n          ]"
      end

      # One pair per line once the whole hash will not fit, so the generated file stays within the
      # line length the project lints for.
      def profile_literal(profile)
        pairs = profile.map { |key, value| "#{key}: #{ruby_literal(value)}" }
        single_line = "            { #{pairs.join(', ')} }"
        return single_line if single_line.length <= MAX_LINE_LENGTH

        "            { #{pairs.join(",\n              ")} }"
      end

      def ruby_literal(value)
        case value
        when String then "'#{value}'"
        when Array then "[#{value.map { |entry| ruby_literal(entry) }.join(', ')}]"
        else value.inspect
        end
      end
    end
  end
end
