require_relative '../../client_base_urls'
require_relative '../../tagged_request_load_helper'
require_relative '../../../cross_suite/tags'
require_relative '../../../cross_suite/prefetch_completeness_checker'
require_relative 'access_level_target_reference'

module DaVinciCRDTestKit
  module V221
    class AccessLevelSameScenarioTest < Inferno::Test
      include DaVinciCRDTestKit::TaggedRequestLoadHelper
      include AccessLevelTargetReference

      id :crd_v221_access_level_same_scenario
      title 'Full-access and limited-access requests represent the same scenario'
      description %(
        This test compares the full-access and limited-access hook requests made earlier in this
        scenario and confirms that they invoke the same hook for the same patient, on the same
        Inferno simulated CRD server, with the same content. See
        [Matching Requests in the User Access Level Scoping Scenario](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#matching-requests-in-the-user-access-level-scoping-scenario)
        for what is compared for each hook, and where those details are taken from.

        This test does not check any other aspect of the requests for conformance.
      )

      ORDER_CONTENT_FIELDS = ['code', 'medicationCodeableConcept', 'medicationReference',
                              'codeCodeableConcept', 'codeReference'].freeze
      COMMUNICATION_REQUEST_CONTENT_FIELDS = ['payload'].freeze
      NUTRITION_ORDER_CONTENT_FIELDS = ['foodPreferenceModifier', 'excludeFoodModifier', 'oralDiet',
                                        'supplement', 'enteralFormula'].freeze
      VISION_PRESCRIPTION_CONTENT_FIELDS = ['lensSpecification'].freeze
      FHIR_ID_PATTERN = /\A[A-Za-z0-9\-.]{1,64}\z/
      PARTICIPATION_TYPE_SYSTEM = 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType'.freeze
      PRIMARY_PERFORMER_CODE = 'PPRF'.freeze

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

        invalid = orders.reject { |order| order.is_a?(String) && order.match?(TARGET_REFERENCE_PATTERN) }
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

        bundle['entry'].select { |entry| entry.is_a?(Hash) }
          .map { |entry| entry['resource'] }.select { |resource| resource.is_a?(Hash) }
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

        summaries = resources.map { |resource| resource_summary(resource) }
        if summaries.any? { |summary| summary[:elements].blank? }
          add_message('error',
                      "The #{role} hook request does not describe #{references.join(', ')} in enough " \
                      'detail for Inferno to compare it against the other request.')
          return
        end

        summaries.sort_by { |summary| canonical(summary[:elements]).to_s }
      end

      def resource_summary(resource)
        { resource_type: resource['resourceType'], elements: resource_content(resource) }
      end

      # a request may list the resources it was invoked for in either order, so sort the content
      # before comparing. Hashes are not comparable, and their keys may be in any order, so sort
      # on a rendering that does not depend on either.
      def canonical(content)
        case content
        when Hash then content.sort.map { |key, value| [key, canonical(value)] }
        when Array then content.map { |element| canonical(element) }
        else content
        end
      end

      def resource_content(resource)
        case resource['resourceType']
        when 'Appointment' then appointment_content(resource)
        when 'Encounter' then encounter_content(resource)
        when 'CommunicationRequest' then order_elements(resource, COMMUNICATION_REQUEST_CONTENT_FIELDS)
        when 'NutritionOrder' then order_elements(resource, NUTRITION_ORDER_CONTENT_FIELDS)
        when 'VisionPrescription' then order_elements(resource, VISION_PRESCRIPTION_CONTENT_FIELDS)
        else order_elements(resource, ORDER_CONTENT_FIELDS)
        end
      end

      # what was ordered is not always captured by a code, so compare the whole structure under the
      # elements that describe it rather than pulling particular codings out of them
      def order_elements(resource, fields)
        fields.index_with { |field| resource[field] }.compact_blank.presence
      end

      # request content comes from the tester, so walk it without assuming any element's type
      def nested(value, *keys)
        keys.reduce(value) { |element, key| element.is_a?(Hash) ? element[key] : nil }
      end

      # at least one primary performer is required, while the appointment's type and date are not
      def appointment_content(resource)
        performers = Array.wrap(resource['participant'])
          .select { |participant| primary_performer?(participant) }
          .filter_map { |participant| nested(participant, 'actor', 'reference') }

        { 'participant:PrimaryPerformer' => performers.sort }.compact_blank
      end

      def primary_performer?(participant)
        return false unless participant.is_a?(Hash)

        Array.wrap(participant['type']).any? do |type|
          codeable_concept_codes(type).include?("#{PARTICIPATION_TYPE_SYSTEM}|#{PRIMARY_PERFORMER_CODE}")
        end
      end

      def encounter_content(resource)
        { 'class' => coding_code(resource['class']),
          'type' => Array.wrap(resource['type']).flat_map { |type| codeable_concept_codes(type) }.sort }
          .compact_blank
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

      # the two services request different prefetch data sets, so invoking one of each would
      # produce prefetch differences that have nothing to do with the user's access level
      def check_same_service(full_request, limited_request)
        return if subset_prefetch_service?(full_request) == subset_prefetch_service?(limited_request)

        add_message('error',
                    'The full-access and limited-access requests were made to different Inferno ' \
                    'simulated CRD servers, one requesting the complete prefetch data set and the ' \
                    'other a subset. Both runs must invoke the same service.')
      end

      def subset_prefetch_service?(request)
        request.url.to_s.include?(PREFETCH_SUBSET_PREFIX)
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
        full_summaries = scenario_content(full_body, 'full-access')
        limited_summaries = scenario_content(limited_body, 'limited-access')
        return if full_summaries.blank? || limited_summaries.blank?
        return unless same_resource_types?(full_summaries, limited_summaries)

        full_summaries.zip(limited_summaries).each do |full_summary, limited_summary|
          check_same_elements(full_summary, limited_summary)
        end
      end

      def same_resource_types?(full_summaries, limited_summaries)
        full_types = full_summaries.map { |summary| summary[:resource_type] }.sort
        limited_types = limited_summaries.map { |summary| summary[:resource_type] }.sort
        return true if full_types == limited_types

        add_message('error',
                    'The full-access and limited-access requests were made for different kinds of ' \
                    "resource (#{full_types.to_sentence} vs #{limited_types.to_sentence}). Both runs " \
                    'must be performed for the same order(s), appointment(s), or encounter.')
        false
      end

      def check_same_elements(full_summary, limited_summary)
        full_elements = full_summary[:elements]
        limited_elements = limited_summary[:elements]
        differing = (full_elements.keys | limited_elements.keys)
          .reject { |element| full_elements[element] == limited_elements[element] }
        return if differing.blank?

        add_message('error',
                    "The #{full_summary[:resource_type]} in the full-access request differs from the " \
                    "one in the limited-access request in #{quoted_list(differing)}. Both runs must " \
                    'be performed for content that matches, such as an order for the same service.')
      end

      def quoted_list(elements)
        elements.map { |element| "`#{element}`" }.to_sentence
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

        assert full_body['context'].is_a?(Hash) && limited_body['context'].is_a?(Hash),
               'A hook request did not provide an object in `context`, so Inferno could not confirm ' \
               'that both runs represent the same scenario.'

        check_same_service(full_requests.first, limited_requests.first)
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
