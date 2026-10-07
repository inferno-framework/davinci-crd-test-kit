require 'erb'
require 'fileutils'
require_relative '../cross_suite/profile_metadata'
require_relative '../client/v2.2.1/must_support/request_must_support_with_attestation_option'

module DaVinciCRDTestKit
  module Generator
    # Generates the must support group and the one test per resource type it holds. Run as part of
    # `bundle exec rake crd:generate`.
    class MustSupportTestGenerator
      CONF_3 = 'hl7.fhir.us.davinci-crd_2.2.1@conf-3'.freeze
      HOOK_3 = 'hl7.fhir.us.davinci-crd_2.2.1@hook-3'.freeze

      # One test per request type, plus one for each profile that is referenced from within a
      # request rather than being a request itself. Order here is the order in the UI.
      TEST_DEFINITIONS = [
        { id: :crd_v221_vision_prescription_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'VisionPrescription', profile_keys: ['vision_prescription'] }] },
        { id: :crd_v221_service_request_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'ServiceRequest', profile_keys: ['service_request'] }] },
        { id: :crd_v221_nutrition_order_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'NutritionOrder', profile_keys: ['nutrition_order'] }] },
        { id: :crd_v221_medication_request_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'MedicationRequest', profile_keys: ['medication_request'] }] },
        { id: :crd_v221_device_request_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'DeviceRequest', profile_keys: ['device_request'] }] },
        { id: :crd_v221_communication_request_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'CommunicationRequest', profile_keys: ['communication_request'] }] },
        { id: :crd_v221_appointment_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Appointment', title: 'CRD Appointment', supporting_profile: true,
                       profile_keys: %w[appointment_with_order appointment_without_order] }] },
        { id: :crd_v221_encounter_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Encounter', supporting_profile: true, profile_keys: ['encounter'] }] },
        { id: :crd_v221_coverage_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Coverage', supporting_profile: true, profile_keys: ['coverage'] }] },
        { id: :crd_v221_location_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Location', supporting_profile: true, profile_keys: ['location'] }] },
        { id: :crd_v221_organization_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Organization', supporting_profile: true, profile_keys: ['organization'] }] },
        { id: :crd_v221_patient_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Patient', supporting_profile: true, profile_keys: ['patient'] }] },
        { id: :crd_v221_practitioner_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Practitioner', supporting_profile: true, profile_keys: ['practitioner'] }] },
        { id: :crd_v221_practitioner_role_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'PractitionerRole', supporting_profile: true,
                       profile_keys: ['practitioner_role'] }] }
      ].freeze

      # The order types a tester can declare support for, and the supporting types that are not
      # required of every client.
      ORDER_TYPE_OPTIONS = %w[
        VisionPrescription ServiceRequest NutritionOrder MedicationRequest DeviceRequest
        CommunicationRequest
      ].freeze
      SUPPORTING_TYPE_OPTIONS = %w[Location Organization Practitioner PractitionerRole].freeze

      REQUIRING_HOOKS = {
        'Appointment' => ['APPOINTMENT_BOOK_TAG'],
        'Encounter' => %w[ENCOUNTER_START_TAG ENCOUNTER_DISCHARGE_TAG]
      }.freeze

      IG_VERSION = 'v2.2.1'.freeze
      MODULE_NAME = 'V221'.freeze
      GROUP_ID = 'crd_v221_client_cross_hook_must_support'.freeze
      ORDER_TYPES_SIGNED_TEST_ID = 'crd_v221_client_order_types_signed'.freeze
      COVERAGE_INFORMATION_TEST_ID = 'crd_v221_client_card_must_support_coverage_information'.freeze

      GROUP_DIRECTORY = File.join(__dir__, '..', 'client', 'v2.2.1').freeze
      TEST_DIRECTORY = File.join(GROUP_DIRECTORY, 'must_support', 'generated').freeze

      # Generated files are linted along with the rest of the project.
      MAX_LINE_LENGTH = 120

      def run
        FileUtils.mkdir_p(TEST_DIRECTORY)

        TEST_DEFINITIONS.each do |definition|
          File.write(File.join(TEST_DIRECTORY, file_name_for(definition)), render_test(definition))
          puts "  #{file_name_for(definition)}"
        end

        File.write(File.join(GROUP_DIRECTORY, 'client_cross_hook_must_support_group.rb'), render_group)
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

      def render_group
        render('must_support_group.rb.erb',
               module_name: MODULE_NAME,
               group_id: GROUP_ID,
               test_file_names: TEST_DEFINITIONS.map { |definition| file_name_for(definition).delete_suffix('.rb') },
               test_ids: TEST_DEFINITIONS.map { |definition| definition[:id] },
               order_type_options: ORDER_TYPE_OPTIONS,
               supporting_type_options: SUPPORTING_TYPE_OPTIONS,
               requiring_hooks: REQUIRING_HOOKS,
               order_types_signed_test_id: ORDER_TYPES_SIGNED_TEST_ID,
               coverage_information_test_id: COVERAGE_INFORMATION_TEST_ID)
      end

      def test_class
        V221::RequestMustSupportWithAttestationOption
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
