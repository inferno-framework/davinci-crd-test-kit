require_relative '../../../cross_suite/cards_identification'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class ClientHookResponseSupportCoverageInformationTest < Inferno::Test
      include CardsIdentification
      include TaggedRequestLoadHelper

      title 'Client supports the Coverage Information response type on this hook'
      id :crd_v221_client_hook_response_support_coverage_information
      description <<~DESCRIPTION
        During this test, Inferno will verify that the client demonstrated support for the [Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information)
        response type. At least one hook invocation performed during this group must have returned a Coverage Information action.

        If this test fails, adjust the [cards returned by Inferno's simulated CRD server](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)
        and/or the hook requests made by the client during this group such that a Coverage Information action is returned.
      DESCRIPTION

      run do
        hook_requests = load_hook_requests
        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        sorted_cards = sorted_cards_from_requests(hook_requests)
        assert sorted_cards['actions'][COVERAGE_INFORMATION_RESPONSE_TYPE].present?,
               "Support for the Coverage Information response type not demonstrated for the #{hook_name} hook."
      end
    end
  end
end
