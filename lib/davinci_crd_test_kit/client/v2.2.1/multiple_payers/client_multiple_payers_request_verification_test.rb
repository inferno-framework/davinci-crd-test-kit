require_relative '../../../cross_suite/cards_identification'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class ClientMultiplePayersRequestVerificationTest < Inferno::Test
      include CardsIdentification
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      # elements that may legitimately differ between the requests made to the two payers: unique
      # request identifiers, authorization tokens, prefetched data carrying the payer's coverage,
      # and the extension carrying the `davinci-crd.configuration` settings checked separately
      IGNORED_COMPARISON_ELEMENTS = ['hookInstance', 'fhirAuthorization', 'prefetch', 'extension'].freeze

      id :crd_v221_client_multiple_payers_request_verification
      title 'Client solicits coverage information from only one payer'
      description %(
        When a patient has multiple active coverages that could be relevant to the current action,
        the CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/deviations.html#ci-c-dev-28)
        that client systems select from those coverages which is most likely to be primary and only
        solicit coverage information for that one payer. If clients invoke CRD on other payers, the
        CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/deviations.html#ci-c-dev-30)
        that response types that return coverage information are disabled for those 'likely
        secondary' payers. During this test, Inferno verifies that the client made one or two hook
        requests when the tester performed a workflow for a patient with two payer coverages during
        the previous test. If a single request was received, it must not disable coverage
        information. If two requests were received, each must have been made to a different payer,
        they must be the same except for their coverage details, and exactly one of them must
        disable coverage information using the `davinci-crd.configuration` extension.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-28', 'hl7.fhir.us.davinci-crd_2.2.1@dev-30'

      def parse_request_bodies(hook_requests)
        hook_requests.map do |request|
          body = JSON.parse(request.request_body)
          body if body.is_a?(Hash)
        rescue JSON::ParserError
          nil
        end
      end

      def check_solitary_request(request_body)
        return unless coverage_info_configuration_disabled?(request_body)

        add_message('error',
                    'The hook request disables coverage information in its `davinci-crd.configuration` ' \
                    'extension. The client must solicit coverage information from the payer associated ' \
                    'with the coverage most likely to be primary.')
      end

      def check_request_pair(hook_requests, request_bodies)
        check_distinct_payers(hook_requests)
        check_matching_workflows(request_bodies)
        check_single_solicitation(request_bodies)
      end

      def check_distinct_payers(hook_requests)
        return if hook_requests.map { |request| request.url.include?(PREFETCH_SUBSET_PREFIX) }.uniq.length == 2

        add_message('error',
                    'Both hook requests were made to the same Inferno simulated CRD server. Each request ' \
                    'must be directed at a different payer: one to a service on each of the two simulated ' \
                    'CRD servers.')
      end

      def check_matching_workflows(request_bodies)
        first, second = request_bodies.map { |request_body| comparable_request_content(request_body) }
        return if first == second

        differing_elements = (first.keys | second.keys).reject { |key| first[key] == second[key] }
        add_message('error',
                    "The two hook requests differ in #{quoted_list(differing_elements)} and so do not " \
                    'appear to invoke CRD for the same workflow action. The requests made to the two ' \
                    'payers must be the same except for their coverage details.')
      end

      def check_single_solicitation(request_bodies)
        disabled_count = request_bodies.count { |request_body| coverage_info_configuration_disabled?(request_body) }
        if disabled_count.zero?
          add_message('error',
                      'Neither hook request disables coverage information. The request made to the payer ' \
                      'associated with the likely secondary coverage must set `coverage-info` to `false` ' \
                      'in its `davinci-crd.configuration` extension.')
        elsif disabled_count == 2
          add_message('error',
                      'Both hook requests disable coverage information in their `davinci-crd.configuration` ' \
                      'extensions. The client must solicit coverage information from the payer associated ' \
                      'with the coverage most likely to be primary.')
        end
      end

      def comparable_request_content(request_body)
        strip_coverage_references(request_body.except(*IGNORED_COMPARISON_ELEMENTS))
      end

      # `insurance` elements on resources within the hook context reference the coverage
      # relevant to the request, so they may differ between the two payers' requests
      def strip_coverage_references(value)
        case value
        when Hash
          value.except('insurance').transform_values { |element| strip_coverage_references(element) }
        when Array
          value.map { |element| strip_coverage_references(element) }
        else
          value
        end
      end

      def quoted_list(names)
        names.map { |name| "`#{name}`" }.to_sentence
      end

      run do
        hook_requests = load_interaction_group_requests

        assert hook_requests.present?,
               'Inferno did not receive any hook requests during the previous test. The client must ' \
               'solicit coverage information from the payer associated with the coverage most likely ' \
               'to be primary.'
        assert hook_requests.length <= 2,
               "Inferno received #{hook_requests.length} hook requests, but expected at most one for " \
               'each of the two payers.'

        request_bodies = parse_request_bodies(hook_requests)
        assert request_bodies.all?(&:present?), 'Received hook requests do not contain valid JSON bodies.'

        if hook_requests.one?
          check_solitary_request(request_bodies.first)
        else
          check_request_pair(hook_requests, request_bodies)
        end

        assert_no_error_messages('Received hook requests do not demonstrate solicitation of coverage ' \
                                 'information from a single payer. See Messages for details.')
      end
    end
  end
end
