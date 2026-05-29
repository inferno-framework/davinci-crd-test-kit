require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    class VerifyResponseWithoutBillingOptionsTest < Inferno::Test
      include DaVinciCRDTestKit::ServerHookHelper

      title 'Server does not require the billing-options extension'
      id :verify_response_without_billing_options
      description <<~DESCRIPTION
        The IG states that, "CRD servers **SHALL NOT** depend on the
        billing-options extension being present in order to provide a response."

        This test verifies that a successful response was received for a request
        without any billing-options extensions.
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@billopt-2'

      BILLING_OPTIONS_URL = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-billing-options'.freeze

      run do
        ALL_HOOK_TAGS.each do |tag|
          load_tagged_requests(tag)
        end

        skip_if requests.blank?, 'No requests were made in a previous test as expected.'

        successful_requests = requests.select { |request| request.status == 200 }
        skip_if successful_requests.empty?, 'All service requests were unsuccessful.'

        requests_without_billing_options =
          successful_requests.reject { |request| request.request_body.include? BILLING_OPTIONS_URL }

        skip_if requests_without_billing_options.blank?,
                'All successful requests included the billing options extension. ' \
                'Provide service call inputs which do not include the billing options extension ' \
                'to verify that the server does not require the extension.'
      end
    end
  end
end
