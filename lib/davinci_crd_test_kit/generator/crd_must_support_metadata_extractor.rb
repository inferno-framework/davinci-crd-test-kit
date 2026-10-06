require 'inferno/dsl/must_support_metadata_extractor'

module DaVinciCRDTestKit
  module Generator
    # Extends the extractor inferno_core provides with the handling CRD's profiles need.
    class CRDMustSupportMetadataExtractor < Inferno::DSL::MustSupportMetadataExtractor
      US_CORE_CATEGORY_SYSTEM = 'http://hl7.org/fhir/us/core/CodeSystem/us-core-category'.freeze
      SNOMED_SYSTEM = 'http://snomed.info/sct'.freeze
      V3_ACT_CODE_SYSTEM = 'http://terminology.hl7.org/CodeSystem/v3-ActCode'.freeze
      MEDICATION_REQUEST_CATEGORY_SYSTEM =
        'http://terminology.hl7.org/CodeSystem/medicationrequest-category'.freeze

      # Value sets the CRD profiles bind to that are not in the packages Inferno loads, so nothing
      # can resolve them at generation time. This is a short term solution for now, so the concepts are listed
      # here until the packages they live in are available and until inferno-core metadata extractor
      # logic is reworked to handle this better.
      # - https://hl7.org/fhir/us/core/STU7/ValueSet-us-core-servicerequest-category.html
      # - https://terminology.hl7.org/7.1.0/en/ValueSet-v3-ActEncounterCode.html
      # - https://hl7.org/fhir/R4/valueset-medicationrequest-category.html
      UNRESOLVABLE_VALUE_SETS = {
        'http://hl7.org/fhir/us/core/ValueSet/us-core-servicerequest-category' => [
          { system: US_CORE_CATEGORY_SYSTEM, code: 'sdoh' },
          { system: US_CORE_CATEGORY_SYSTEM, code: 'functional-status' },
          { system: US_CORE_CATEGORY_SYSTEM, code: 'disability-status' },
          { system: US_CORE_CATEGORY_SYSTEM, code: 'cognitive-status' },
          { system: US_CORE_CATEGORY_SYSTEM, code: 'treatment-intervention-preference' },
          { system: US_CORE_CATEGORY_SYSTEM, code: 'care-experience-preference' },
          { system: SNOMED_SYSTEM, code: '386053000' },
          { system: SNOMED_SYSTEM, code: '410606002' },
          { system: SNOMED_SYSTEM, code: '108252007' },
          { system: SNOMED_SYSTEM, code: '363679005' },
          { system: SNOMED_SYSTEM, code: '409063005' },
          { system: SNOMED_SYSTEM, code: '409073007' },
          { system: SNOMED_SYSTEM, code: '387713003' }
        ].freeze,
        'http://terminology.hl7.org/ValueSet/v3-ActEncounterCode' => [
          { system: V3_ACT_CODE_SYSTEM, code: 'AMB' },
          { system: V3_ACT_CODE_SYSTEM, code: 'EMER' },
          { system: V3_ACT_CODE_SYSTEM, code: 'FLD' },
          { system: V3_ACT_CODE_SYSTEM, code: 'HH' },
          { system: V3_ACT_CODE_SYSTEM, code: 'IMP' },
          { system: V3_ACT_CODE_SYSTEM, code: 'ACUTE' },
          { system: V3_ACT_CODE_SYSTEM, code: 'NONAC' },
          { system: V3_ACT_CODE_SYSTEM, code: 'OBSENC' },
          { system: V3_ACT_CODE_SYSTEM, code: 'PRENC' },
          { system: V3_ACT_CODE_SYSTEM, code: 'SS' },
          { system: V3_ACT_CODE_SYSTEM, code: 'VR' }
        ].freeze,
        'http://hl7.org/fhir/ValueSet/medicationrequest-category' => [
          { system: MEDICATION_REQUEST_CATEGORY_SYSTEM, code: 'inpatient' },
          { system: MEDICATION_REQUEST_CATEGORY_SYSTEM, code: 'outpatient' },
          { system: MEDICATION_REQUEST_CATEGORY_SYSTEM, code: 'community' },
          { system: MEDICATION_REQUEST_CATEGORY_SYSTEM, code: 'discharge' }
        ].freeze
      }.freeze

      # Must support elements of the CRD Timing profile, which the extractor does not follow into
      # because it stops at the type boundary.
      # - https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-timing.html
      TIMING_MUST_SUPPORTS = [
        'event', 'repeat', 'repeat.bounds[x]:boundsPeriod', 'repeat.count', 'repeat.duration',
        'repeat.durationUnit', 'repeat.frequency', 'repeat.period', 'repeat.periodUnit'
      ].freeze

      # Elements across the CRD profiles whose type is the CRD Timing profile.
      TIMING_ELEMENT_PATHS = [
        'dosageInstruction.timing', 'occurrenceTiming', 'oralDiet.schedule', 'supplement.schedule',
        'enteralFormula.administration.schedule'
      ].freeze

      def extract_required_binding_values(pattern_element, _metadata)
        hand_coded_values(pattern_element).presence ||
          Inferno::DSL::ValueExtractor.new(ig_resources, resource, profile_elements)
            .codings_from_value_set_binding(pattern_element)
            .presence || []
      end

      def hand_coded_values(pattern_element)
        UNRESOLVABLE_VALUE_SETS[pattern_element.binding&.valueSet&.split('|')&.first]
      end

      def must_supports
        @expanded_must_supports ||= # rubocop:disable Naming/MemoizedInstanceVariableName
          super.merge(elements: super[:elements].flat_map { |element| with_timing(element) })
      end

      def with_timing(element)
        return [element] unless TIMING_ELEMENT_PATHS.include?(element[:path])

        [element] + TIMING_MUST_SUPPORTS.map { |sub_path| { path: "#{element[:path]}.#{sub_path}" } }
      end
    end
  end
end
