require_relative '../server_hook_request_validation'
require_relative '../test_helper'

module DaVinciCRDTestKit
  class CoverageInformationSystemActionValidationTest < Inferno::Test
    include DaVinciCRDTestKit::ServerHookRequestValidation
    include DaVinciCRDTestKit::TestHelper

    title 'All Coverage Information system actions received are valid'
    id :crd_coverage_info_system_action_validation
    description %(
      This test validates all [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)
      system actions received. It verifies the following for each action:
      - The action type is `update`.
      - The resource within the action conforms its respective FHIR profile.

      Additionally, the test examines the `coverage-info` extensions within the resource to ensure that:
      - Entries referencing differing coverage have distinct `coverage-assertion-ids` and `satisfied-pa-ids`
      (if present).
      - Entries referencing the same coverage have the same `coverage-assertion-ids` and `satisfied-pa-ids`
      (if present).
    )
    input :coverage_info
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@264', 'hl7.fhir.us.davinci-crd_2.0.1@265'

    def find_extension_value(extension, url, *properties)
      found_extension = extension.extension.find { |ext| ext.url == url }
      return nil unless found_extension

      properties.reduce(found_extension) do |current, prop|
        return current unless current.respond_to?(prop)

        current.send(prop)
      end
    end

    def extract_and_group_coverage_info(resource)
      resource.extension.each_with_object({}) do |extension, grouped_extensions|
        next unless extension.url == 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'

        coverage_key = find_extension_value(extension, 'coverage', 'valueReference', 'reference')
        grouped_extensions[coverage_key] ||= []
        grouped_extensions[coverage_key] << extension
      end
    end

    # For the same coverage, ensure coverage-assertion-ids and satisfied-pa-ids are the same.
    # For different coverages, ensure coverage-assertion-ids and satisfied-pa-ids are distinct.
    def multiple_extensions_conformance_check(grouped_coverage_info, resource)
      resource_ref = "#{resource.resourceType}/#{resource.id}"
      assertion_ids_across_coverages = Set.new
      pa_ids_across_coverages = Set.new

      grouped_coverage_info.each do |coverage, extensions|
        coverage_assertion_ids = collect_extensions_id(extensions, 'coverage-assertion-id', 'valueString').uniq
        satisfied_pa_ids = collect_extensions_id(extensions, 'satisfied-pa-id', 'valueString').uniq.compact
        assert coverage_assertion_ids.length == 1,
               same_coverage_conformance_error_msg(resource_ref, coverage, 'coverage-assertion-ids')

        assert satisfied_pa_ids.length <= 1,
               same_coverage_conformance_error_msg(resource_ref, coverage, 'satisfied-pa-ids')

        assertion_id = coverage_assertion_ids.first
        assert !assertion_ids_across_coverages.include?(assertion_id),
               different_coverage_conformance_error_msg(resource_ref, 'coverage-assertion-ids')
        assertion_ids_across_coverages.add(assertion_id)
        pa_id = satisfied_pa_ids.first
        next unless pa_id

        assert !pa_ids_across_coverages.include?(pa_id),
               different_coverage_conformance_error_msg(resource_ref, 'satisfied-pa-ids')
        pa_ids_across_coverages.add(pa_id)
      end
    end

    def collect_extensions_id(extensions, url, *properties)
      extensions.map do |extension|
        find_extension_value(extension, url, *properties)
      end
    end

    def same_coverage_conformance_error_msg(resource_ref, coverage, id_name)
      "#{resource_ref}: extension has multiple repetitions of coverage `#{coverage}` with different #{id_name}."
    end

    def different_coverage_conformance_error_msg(resource_ref, id_name)
      "#{resource_ref}: extensions referencing differing coverage SHALL have distinct #{id_name}."
    end

    def coverage_info_system_action_check(coverage_info_system_action)
      type = coverage_info_system_action['type']
      assert type, '`type` field is missing.'
      assert type == 'update', "`type` must be `update`, but was `#{type}`"

      resource = FHIR.from_contents(coverage_info_system_action['resource'].to_json)
      profile_url = structure_definition_map[resource.resourceType]
      assert_valid_resource(resource:, profile_url:)

      grouped_coverage_info = extract_and_group_coverage_info(resource)
      multiple_extensions_conformance_check(grouped_coverage_info, resource)
    end

    run do
      parsed_coverage_info = parse_json(coverage_info)
      error_messages = []
      parsed_coverage_info.each do |action|
        coverage_info_system_action_check(action)
      rescue Inferno::Exceptions::AssertionException => e
        error_messages << "Coverage Info system action `#{action}`: #{e.message}"
      end

      error_messages.each do |msg|
        messages << { type: 'error', message: msg }
      end
      assert error_messages.empty?, 'Some Coverage Info system actions are not valid.'
    end
  end
end
