require_relative '../../../cross_suite/cards_validation'
require_relative '../../../cross_suite/response_logical_model_validation'
require_relative '../../server_hook_helper'

module DaVinciCRDTestKit
  module V221
    class ServiceResponseValidationTest < Inferno::Test
      include DaVinciCRDTestKit::CardsValidation
      include DaVinciCRDTestKit::ResponseLogicalModelValidation
      include DaVinciCRDTestKit::ServerHookHelper

      title 'Service responses contain valid cards and systemActions'
      id :crd_v221_service_response_validation
      description %(
        This test validates the responses against the [CRD v2.2.1 logical
        models](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/artifacts.html#4).

        This test implements [corrections to errors in the logical
        models](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Logical-Model-Validation-Changes).
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-4',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-5',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-13',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-22',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-24',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-56'

      input :invoked_hook

      run do
        load_tagged_requests(tested_hook_name)

        skip_if requests.blank?, "No #{tested_hook_name} request was made in a previous test as expected."

        successful_requests = requests.select { |request| request.status == 200 }

        skip_if successful_requests.empty?, 'All service requests were unsuccessful.'

        info do
          unsuccessful_count = (requests - successful_requests).length

          assert unsuccessful_count.zero?, "#{unsuccessful_count} out of #{requests.length} requests were unsuccessful"
        end

        successful_requests.each_with_index do |request, index|
          service_response = JSON.parse(request.response_body)

          conforms_to_logical_model?(
            service_response,
            'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponseBase|2.2.1',
            message_prefix: "Request #{index}: "
          )
        rescue JSON::ParserError
          add_message('error', "Invalid JSON: server response #{index + 1} is not valid JSON.")
        end

        no_error_validation('Some service responses are not valid. Check messages for issues found.')
      end
    end
  end
end
