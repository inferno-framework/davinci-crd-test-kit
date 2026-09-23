require_relative '../../anterior_workspace_token'

module DaVinciCRDTestKit
  module V221
    class DiscoveryEndpointTest < Inferno::Test
      title 'Server returns a discovery response'
      id :crd_v221_discovery_endpoint_test
      description %(
        A CDS Service provider must expose its discovery endpoint at `{baseURL}/cds-services`
        as specified in the [CDS Hooks Specification](https://cds-hooks.hl7.org/2.0/#discovery).

        This test checks that the server responds to a GET request at the following endpoint:

        `GET {baseURL}/cds-services`

        It does this by checking that the server responds with an HTTP OK 200 status code
        and that the body of the response is a valid JSON object. This test does not
        inspect the structure and content of the response body to see if it contains the required information.
        It only checks to see if the RESTful interaction is supported and returns a valid JSON object.
      )

      input_order :base_url, :authentication_required
      input :base_url
      input :authentication_required,
            title: 'Discovery endpoint requires authentication?',
            type: 'radio',
            default: 'no',
            options: {
              list_options: [
                {
                  label: 'No',
                  value: 'no'
                },
                {
                  label: 'Yes',
                  value: 'yes'
                }
              ]
            }
      output :cds_services

      run do
        discovery_url = "#{base_url.chomp('/')}/cds-services"
        headers = { 'Accept' => 'application/json' }

        if authentication_required == 'yes'
          headers['Authorization'] = AnteriorWorkspaceToken.authorization_header(discovery_url)
        end
        get(discovery_url, headers:, tags: [DISCOVERY_TAG])
        assert_response_status(200)
        assert_valid_json(request.response_body)

        output cds_services: request.response_body
      end
    end
  end
end
