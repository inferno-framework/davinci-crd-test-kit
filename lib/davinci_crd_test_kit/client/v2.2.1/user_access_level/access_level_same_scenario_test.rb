require_relative '../../tagged_request_load_helper'
require_relative '../../../cross_suite/tags'
require_relative '../../../cross_suite/prefetch_completeness_checker'

module DaVinciCRDTestKit
  module V221
    class AccessLevelSameScenarioTest < Inferno::Test
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_access_level_same_scenario
      title 'Full-access and limited-access requests represent the same scenario'
      description %(
        This test compares the full-access and limited-access hook requests made earlier in this
        scenario and confirms that they invoke the same hook for the same patient, with the same
        content. Systems do not always allow the same workflow action to be repeated, so rather
        than requiring that both runs reference the same resources, Inferno compares the details of
        the resources they do reference: the codes of the order(s), or the type of the appointment
        or encounter.

        Where a hook provides only a reference to those resources, Inferno takes their details from
        the prefetch data, which its services always request. If a request does not contain enough
        detail to make the comparison, this test will fail. This test does not check any other
        aspect of the requests for conformance.
      )
      simulation_verification

      ORDER_CODE_FIELDS = ['code', 'medicationCodeableConcept', 'codeCodeableConcept'].freeze
      ORDER_REFERENCE_FIELDS = ['medicationReference', 'codeReference'].freeze
      RELATIVE_REFERENCE_PATTERN = %r{\A[A-Z][A-Za-z]*/[A-Za-z0-9\-.]{1,64}\z}
      FHIR_ID_PATTERN = /\A[A-Za-z0-9\-.]{1,64}\z/
      PARTICIPATION_TYPE_SYSTEM = 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType'.freeze
      PRIMARY_PERFORMER_CODE = 'PPRF'.freeze
      COMMUNICATION_PAYLOAD_CONTENT_EXTENSION =
        'http://hl7.org/fhir/5.0/StructureDefinition/extension-CommunicationRequest.payload.content'.freeze

      def malformed_request(role, detail)
        add_message('error',
                    "The #{role} hook request #{detail}, so Inferno could not confirm that both runs " \
                    'represent the same scenario.')
        nil
      end

      # the resources the hook was invoked for, as `ResourceType/id` references
      def primary_context_references(body, role)
        case body['hook']
        when 'appointment-book'
          bundle_entry_references(body.dig('context', 'appointments'), role, 'appointments')
        when 'encounter-start', 'encounter-discharge'
          encounter_references(body, role)
        when 'order-select', 'order-sign'
          bundle_entry_references(body.dig('context', 'draftOrders'), role, 'draftOrders')
        when 'order-dispatch'
          dispatched_order_references(body, role)
        else
          malformed_request(role, "invoked the unsupported hook '#{body['hook']}'")
        end
      end

      def encounter_references(body, role)
        encounter_id = body.dig('context', 'encounterId')
        return malformed_request(role, 'did not provide `context.encounterId`') if encounter_id.blank?

        unless encounter_id.is_a?(String) && encounter_id.match?(FHIR_ID_PATTERN)
          return malformed_request(role, "provided `context.encounterId` as #{encounter_id.inspect}, " \
                                         'which is not a FHIR id')
        end

        ["Encounter/#{encounter_id}"]
      end

      def dispatched_order_references(body, role)
        orders = body.dig('context', 'dispatchedOrders')
        return malformed_request(role, 'did not provide `context.dispatchedOrders`') if orders.blank?

        unless orders.is_a?(Array)
          return malformed_request(role, 'did not provide `context.dispatchedOrders` as a list')
        end

        invalid = orders.reject { |order| order.is_a?(String) && order.match?(RELATIVE_REFERENCE_PATTERN) }
        if invalid.present?
          return malformed_request(role, 'provided `context.dispatchedOrders` entries that are not relative ' \
                                         "references: #{invalid.map(&:inspect).join(', ')}")
        end

        orders.sort
      end

      def bundle_entry_references(bundle, role, context_key)
        resources = bundle_resources(bundle)
        if resources.blank?
          return malformed_request(role, "did not provide a Bundle of resources in `context.#{context_key}`")
        end

        unless resources.all? { |resource| resource['resourceType'].present? && resource['id'].present? }
          return malformed_request(role, "provided entries in `context.#{context_key}` without a " \
                                         'resourceType and id')
        end

        resources.map { |resource| "#{resource['resourceType']}/#{resource['id']}" }.sort
      end

      def bundle_resources(bundle)
        return [] unless bundle.is_a?(Hash) && bundle['entry'].is_a?(Array)

        bundle['entry'].map { |entry| entry['resource'] }.select { |resource| resource.is_a?(Hash) }
      end

      # order and appointment hooks carry the resources themselves, while encounter and
      # order-dispatch hooks carry only references, whose details come from the prefetch
      def scenario_resources(body, references, role)
        case body['hook']
        when 'appointment-book'
          bundle_resources(body.dig('context', 'appointments'))
        when 'order-select', 'order-sign'
          bundle_resources(body.dig('context', 'draftOrders'))
        else
          prefetched_scenario_resources(body, references, role)
        end
      end

      def prefetched_scenario_resources(body, references, role)
        checker = PrefetchCompletenessChecker.new(body, nil, nil)
        resources = references.index_with { |reference| checker.prefetched_resource(reference) }
        missing = resources.select { |_, resource| resource.blank? }.keys

        if missing.present?
          add_message('error',
                      "The #{role} hook request did not provide #{missing.join(', ')} in its prefetch data, " \
                      'so Inferno could not compare the details of the two requests. Inferno\'s services ' \
                      'request this data via prefetch.')
          return
        end

        resources.values
      end

      def scenario_content(body, role)
        references = primary_context_references(body, role)
        return if references.blank?

        resources = scenario_resources(body, references, role)
        return if resources.blank?

        contents = resources.map { |resource| resource_content(resource) }
        if contents.any?(&:blank?)
          add_message('error',
                      "The #{role} hook request does not describe #{references.join(', ')} in enough " \
                      'detail for Inferno to compare it against the other request.')
          return
        end

        contents.sort
      end

      def resource_content(resource)
        case resource['resourceType']
        when 'Appointment' then appointment_content(resource)
        when 'Encounter' then encounter_content(resource)
        when 'CommunicationRequest' then communication_request_content(resource)
        when 'NutritionOrder' then nutrition_order_content(resource)
        when 'VisionPrescription' then vision_prescription_content(resource)
        else order_content(resource)
        end
      end

      # request content comes from the tester, so walk it without assuming any element's type
      def nested(value, *keys)
        keys.reduce(value) { |element, key| element.is_a?(Hash) ? element[key] : nil }
      end

      def order_content(resource)
        codes = ORDER_CODE_FIELDS.flat_map { |field| codeable_concept_codes(resource[field]) }
        references = ORDER_REFERENCE_FIELDS.filter_map { |field| nested(resource, field, 'reference') }

        (codes + references).sort.presence
      end

      # at least one primary performer is required, while the appointment's type and date are not
      def appointment_content(resource)
        Array.wrap(resource['participant'])
          .select { |participant| primary_performer?(participant) }
          .filter_map { |participant| nested(participant, 'actor', 'reference') }
          .sort.presence
      end

      def primary_performer?(participant)
        return false unless participant.is_a?(Hash)

        Array.wrap(participant['type']).any? do |type|
          codeable_concept_codes(type).include?("#{PARTICIPATION_TYPE_SYSTEM}|#{PRIMARY_PERFORMER_CODE}")
        end
      end

      # the code is carried by an R5 extension on the payload rather than by an element
      def communication_request_content(resource)
        Array.wrap(resource['payload']).flat_map do |payload|
          Array.wrap(nested(payload, 'extension'))
            .select { |extension| nested(extension, 'url') == COMMUNICATION_PAYLOAD_CONTENT_EXTENSION }
            .flat_map { |extension| codeable_concept_codes(extension['valueCodeableConcept']) }
        end.sort.presence
      end

      # no single element defines the order, so combine the optional ones that describe the diet
      def nutrition_order_content(resource)
        codes =
          Array.wrap(resource['foodPreferenceModifier']).flat_map { |item| codeable_concept_codes(item) } +
          Array.wrap(resource['excludeFoodModifier']).flat_map { |item| codeable_concept_codes(item) } +
          Array.wrap(nested(resource, 'oralDiet', 'type')).flat_map { |item| codeable_concept_codes(item) } +
          Array.wrap(resource['supplement']).flat_map { |item| codeable_concept_codes(nested(item, 'type')) } +
          codeable_concept_codes(nested(resource, 'enteralFormula', 'baseFormulaType'))

        codes.sort.presence
      end

      def vision_prescription_content(resource)
        specifications = Array.wrap(resource['lensSpecification'])
        return if specifications.blank?

        contents = specifications.map do |specification|
          product = codeable_concept_codes(nested(specification, 'product'))
          eye = nested(specification, 'eye')
          next if product.blank? || eye.blank?

          "#{eye}|#{product.sort.join(',')}"
        end

        contents.any?(&:blank?) ? nil : contents.sort
      end

      def encounter_content(resource)
        types = Array.wrap(resource['type']).flat_map { |type| codeable_concept_codes(type) } +
                [coding_code(resource['class'])].compact

        types.sort.presence
      end

      def codeable_concept_codes(codeable_concept)
        return [] unless codeable_concept.is_a?(Hash)

        Array.wrap(codeable_concept['coding']).filter_map { |coding| coding_code(coding) }
      end

      def coding_code(coding)
        return unless coding.is_a?(Hash) && coding['code'].present? && coding['system'].present?

        "#{coding['system']}|#{coding['code']}"
      end

      def same_hook?(full_body, limited_body)
        return true if full_body['hook'] == limited_body['hook']

        add_message('error',
                    "The full-access request invoked the '#{full_body['hook']}' hook, but the " \
                    "limited-access request invoked the '#{limited_body['hook']}' hook. Both runs " \
                    'must invoke the same hook.')
        false
      end

      def check_same_patient(full_body, limited_body)
        full_patient_id = full_body.dig('context', 'patientId')
        limited_patient_id = limited_body.dig('context', 'patientId')
        return if full_patient_id.present? && full_patient_id == limited_patient_id

        add_message('error',
                    'The full-access and limited-access requests were made for different patients ' \
                    "(#{full_patient_id.inspect} vs #{limited_patient_id.inspect}).")
      end

      def check_same_content(full_body, limited_body)
        full_content = scenario_content(full_body, 'full-access')
        limited_content = scenario_content(limited_body, 'limited-access')
        return if full_content.blank? || limited_content.blank?
        return if full_content == limited_content

        add_message('error',
                    'The full-access and limited-access requests do not describe the same order, ' \
                    "appointment, or encounter (#{full_content.join(', ')} vs " \
                    "#{limited_content.join(', ')}). Both runs must be performed for content that " \
                    'matches, such as an order for the same service.')
      end

      run do
        full_requests = load_tagged_requests(ACCESS_LEVEL_FULL_GROUP_TAG)
        limited_requests = load_tagged_requests(ACCESS_LEVEL_LIMITED_GROUP_TAG)

        skip_if full_requests.blank?,
                'Full-access hook request was not successful. Check the response for details and re-try.'
        skip_if limited_requests.blank?,
                'Limited-access hook request was not successful. Check the response for details and re-try.'

        full_body = JSON.parse(full_requests.first.request_body)
        limited_body = JSON.parse(limited_requests.first.request_body)

        check_same_patient(full_body, limited_body)
        # comparing content across two different hooks is not meaningful
        check_same_content(full_body, limited_body) if same_hook?(full_body, limited_body)

        assert_no_error_messages('The full-access and limited-access requests do not represent the same ' \
                                 'scenario. See Messages for details.')
      rescue JSON::ParserError => e
        assert false, "Unable to parse a hook request body as JSON: #{e.message}"
      end
    end
  end
end
