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
        scenario and confirms that they invoke the same hook for the same patient, referencing the
        same order(s), appointment, or encounter.

        Systems do not always allow the same workflow action to be repeated, so the two runs may
        legitimately reference different resources. When they do, Inferno compares the details of
        those resources instead - the order codes, or the type and date of the appointment or
        encounter - and the test passes if they match. If those details are not available, because
        the hook carries only a reference and the resource was not prefetched, Inferno reports a
        warning rather than failing. This test does not check any other aspect of the requests for
        conformance.
      )
      simulation_verification

      ORDER_CODE_FIELDS = ['code', 'medicationCodeableConcept', 'codeCodeableConcept'].freeze
      ORDER_REFERENCE_FIELDS = ['medicationReference', 'codeReference'].freeze

      # the resources the hook was invoked for, as `ResourceType/id` references
      def primary_context_references(body)
        case body['hook']
        when 'appointment-book'
          bundle_entry_references(body.dig('context', 'appointments'))
        when 'encounter-start', 'encounter-discharge'
          [body.dig('context', 'encounterId')].compact.map { |id| "Encounter/#{id}" }
        when 'order-select', 'order-sign'
          bundle_entry_references(body.dig('context', 'draftOrders'))
        when 'order-dispatch'
          Array.wrap(body.dig('context', 'dispatchedOrders')).compact.sort
        else
          []
        end
      end

      def bundle_resources(bundle)
        return [] unless bundle.is_a?(Hash) && bundle['entry'].is_a?(Array)

        bundle['entry'].map { |entry| entry['resource'] }
      end

      def bundle_entry_references(bundle)
        bundle_resources(bundle).filter_map do |resource|
          next unless resource.is_a?(Hash) && resource['resourceType'].present? && resource['id'].present?

          "#{resource['resourceType']}/#{resource['id']}"
        end.sort
      end

      # order and appointment hooks carry the resources themselves, while encounter and
      # order-dispatch hooks carry only references, which may have been prefetched
      def scenario_resources(body, references)
        case body['hook']
        when 'appointment-book'
          bundle_resources(body.dig('context', 'appointments'))
        when 'order-select', 'order-sign'
          bundle_resources(body.dig('context', 'draftOrders'))
        else
          checker = PrefetchCompletenessChecker.new(body, nil, nil)
          references.map { |reference| checker.prefetched_resource(reference) }
        end
      end

      def scenario_content(body, references)
        resources = scenario_resources(body, references)
        return if resources.blank? || resources.any? { |resource| !resource.is_a?(Hash) }

        contents = resources.map { |resource| resource_content(resource) }
        return if contents.any?(&:blank?)

        contents.sort
      end

      def resource_content(resource)
        case resource['resourceType']
        when 'Appointment' then appointment_content(resource)
        when 'Encounter' then encounter_content(resource)
        else order_content(resource)
        end
      end

      def order_content(resource)
        codes = ORDER_CODE_FIELDS.flat_map { |field| codeable_concept_codes(resource[field]) }
        references = ORDER_REFERENCE_FIELDS.filter_map { |field| resource.dig(field, 'reference') }

        (codes + references).presence&.sort
      end

      def appointment_content(resource)
        types = Array.wrap(resource['serviceType']).flat_map { |type| codeable_concept_codes(type) } +
                codeable_concept_codes(resource['appointmentType'])

        combine_content(types, resource['start'])
      end

      def encounter_content(resource)
        types = Array.wrap(resource['type']).flat_map { |type| codeable_concept_codes(type) } +
                [coding_code(resource['class'])].compact

        combine_content(types, resource.dig('period', 'start'))
      end

      # dates are compared by day so that the two runs need not have been performed at the same time
      def combine_content(codes, start)
        date = start.to_s[0, 10].presence
        return if codes.blank? && date.blank?

        codes.sort + [date].compact
      end

      def codeable_concept_codes(codeable_concept)
        return [] unless codeable_concept.is_a?(Hash)

        codings = Array.wrap(codeable_concept['coding']).filter_map { |coding| coding_code(coding) }
        codings.presence || [codeable_concept['text']].compact
      end

      def coding_code(coding)
        return unless coding.is_a?(Hash) && (coding['code'].present? || coding['system'].present?)

        "#{coding['system']}|#{coding['code']}"
      end

      def check_same_hook(full_body, limited_body)
        return if full_body['hook'] == limited_body['hook']

        add_message('error',
                    "The full-access request invoked the '#{full_body['hook']}' hook, but the " \
                    "limited-access request invoked the '#{limited_body['hook']}' hook. Both runs " \
                    'must invoke the same hook.')
      end

      def check_same_patient(full_body, limited_body)
        full_patient_id = full_body.dig('context', 'patientId')
        limited_patient_id = limited_body.dig('context', 'patientId')
        return if full_patient_id.present? && full_patient_id == limited_patient_id

        add_message('error',
                    'The full-access and limited-access requests were made for different patients ' \
                    "(#{full_patient_id.inspect} vs #{limited_patient_id.inspect}).")
      end

      def check_same_scenario(full_body, limited_body)
        full_references = primary_context_references(full_body)
        limited_references = primary_context_references(limited_body)

        if full_references.blank? || limited_references.blank?
          add_message('error',
                      'Inferno could not identify the order, appointment, or encounter that one or both ' \
                      'of the requests were made for, so it could not confirm that both runs represent ' \
                      'the same scenario.')
          return
        end

        return if full_references == limited_references

        compare_scenario_content(full_body, limited_body, full_references, limited_references)
      end

      def compare_scenario_content(full_body, limited_body, full_references, limited_references)
        full_content = scenario_content(full_body, full_references)
        limited_content = scenario_content(limited_body, limited_references)
        referenced = "#{full_references.join(', ')} vs #{limited_references.join(', ')}"

        if full_content.blank? || limited_content.blank?
          add_message('warning',
                      'The full-access and limited-access requests reference different resources ' \
                      "(#{referenced}). Inferno could not compare their details because they were not " \
                      'included in the requests or their prefetch. Confirm that both runs were performed ' \
                      'for the same kind of order, appointment, or encounter.')
          return
        end

        return if full_content == limited_content

        add_message('error',
                    'The full-access and limited-access requests reference different resources ' \
                    "(#{referenced}) whose details also differ, so they do not appear to represent the " \
                    'same scenario. Both runs must be performed for the same order, appointment, or ' \
                    'encounter, or for ones with the same clinical details.')
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

        check_same_hook(full_body, limited_body)
        check_same_patient(full_body, limited_body)
        check_same_scenario(full_body, limited_body)

        assert_no_error_messages('The full-access and limited-access requests do not represent the same ' \
                                 'scenario. See Messages for details.')
      rescue JSON::ParserError => e
        assert false, "Unable to parse a hook request body as JSON: #{e.message}"
      end
    end
  end
end
