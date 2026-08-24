require_relative '../../tagged_request_load_helper'
require_relative '../../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    # Simulation verification (ID-216 test 3): confirms the full-access and limited-access hook
    # requests represent the same underlying scenario (hook, order/appointment/encounter context,
    # patient) so that any observed access difference is attributable to the user, not the scenario.
    class AccessLevelSameScenarioTest < Inferno::Test
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_access_level_same_scenario
      title 'Full-access and limited-access requests represent the same scenario'
      description %(
        This test compares the full-access and limited-access hook requests made earlier in this
        scenario and confirms that they invoke the same hook, for the same patient, referencing the
        same primary context resource (the order(s) for order hooks, the appointment for
        appointment-book, or the encounter for encounter hooks). This test does not check any other
        aspect of the requests for conformance.
      )
      simulation_verification

      # order-select/order-sign reference their orders via context.draftOrders; order-dispatch
      # references a single order via context.order; appointment-book references its appointment(s)
      # via context.appointments; encounter-start/encounter-discharge reference a single encounter id.
      def primary_context_ids(body)
        case body['hook']
        when 'appointment-book'
          bundle_entry_ids(body.dig('context', 'appointments'))
        when 'encounter-start', 'encounter-discharge'
          [body.dig('context', 'encounterId')].compact
        when 'order-select', 'order-sign'
          bundle_entry_ids(body.dig('context', 'draftOrders'))
        when 'order-dispatch'
          [body.dig('context', 'order')].compact
        else
          []
        end
      end

      def bundle_entry_ids(bundle)
        return [] unless bundle.is_a?(Hash) && bundle['entry'].is_a?(Array)

        bundle['entry'].filter_map do |entry|
          resource = entry['resource']
          next unless resource.is_a?(Hash) && resource['resourceType'].present? && resource['id'].present?

          "#{resource['resourceType']}/#{resource['id']}"
        end.sort
      end

      run do
        full_requests = load_tagged_requests(ACCESS_LEVEL_FULL_GROUP_TAG)
        limited_requests = load_tagged_requests(ACCESS_LEVEL_LIMITED_GROUP_TAG)

        skip_if full_requests.blank?,
                'No full-access hook request received - run the previous interaction tests first.'
        skip_if limited_requests.blank?,
                'No limited-access hook request received - run the previous interaction tests first.'

        full_body = JSON.parse(full_requests.first.request_body)
        limited_body = JSON.parse(limited_requests.first.request_body)

        assert full_body['hook'] == limited_body['hook'],
               "The full-access request invoked the '#{full_body['hook']}' hook, but the " \
               "limited-access request invoked the '#{limited_body['hook']}' hook. Both runs " \
               'must invoke the same hook.'

        full_patient_id = full_body.dig('context', 'patientId')
        limited_patient_id = limited_body.dig('context', 'patientId')
        assert full_patient_id.present? && full_patient_id == limited_patient_id,
               'The full-access and limited-access requests were made for different patients ' \
               "(#{full_patient_id.inspect} vs #{limited_patient_id.inspect})."

        full_context_ids = primary_context_ids(full_body)
        limited_context_ids = primary_context_ids(limited_body)
        assert full_context_ids.present? && full_context_ids == limited_context_ids,
               'The full-access and limited-access requests do not reference the same order, ' \
               "appointment, or encounter (#{full_context_ids} vs #{limited_context_ids})."
      rescue JSON::ParserError => e
        assert false, "Unable to parse a hook request body as JSON: #{e.message}"
      end
    end
  end
end
