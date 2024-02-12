require_relative '../client_hook_request_validation'

module DaVinciCRDTestKit
  class HookRequestRequiredFieldsTest < Inferno::Test
    include DaVinciCRDTestKit::ClientHookRequestValidation
    include URLs

    id :crd_hook_request_required_fields
    title 'Hook request contains required fields'
    description %(
      Under the [CDS hooks HTTP Request section](https://cds-hooks.hl7.org/2.0/#http-request_1), the specification
      requires that a CDS service request SHALL include a JSON POST body with the following input fields:
        * `hook` - *string*
        * `hookInstance` - *string*
        * `context` - *object*

        Additionally, if the optional `fhirAuthorization` field is present, then the `fhirServer` field is required.

        This test also checks that the `hook` field contains the correct CDS service name that the CDS client is sending
        a request for
    )

    uses_request :hook_request

    def hook_url
      base_url + config.options[:hook_path]
    end

    def hook_name
      config.options[:hook_name]
    end

    run do
      assert_valid_json(request.request_body)
      request_body = JSON.parse(request.request_body)

      hook_request_required_fields_check(request_body, hook_name)
    end
  end
end
