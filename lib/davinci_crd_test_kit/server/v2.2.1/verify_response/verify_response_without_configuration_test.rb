require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    class VerifyResponseWithoutConfigurationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerHookHelper

      title 'Server does not require configuration options'
      id :verify_response_without_configuration
      description <<~DESCRIPTION
        The IG states that, "CRD Servers SHALL NOT require the inclusion of
        configuration information in a hook call (i.e. no hook invocation is
        permitted to fail because configuration information was not included)."

        This test verifies that a successful response was received for a request
        without any configuration options.
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-15'

      CONFIGURATION_KEY = 'davinci-crd.configuration'.freeze

      run do
        ALL_HOOK_TAGS.each do |tag|
          load_tagged_requests(tag)
        end

        skip_if requests.blank?, 'No requests were made in a previous test as expected.'

        successful_requests = requests.select { |request| request.status == 200 }
        skip_if successful_requests.empty?, 'All service requests were unsuccessful.'

        requests_without_configuration_options =
          successful_requests.reject { |request| request.request_body.include? CONFIGURATION_KEY }

        skip_if requests_without_configuration_options.blank?,
                'All successful requests included configuration options. ' \
                'Provide service call inputs which do not include any configuration options ' \
                'to verify that the server does not require them.'
      end
    end
  end
end
