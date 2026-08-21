require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class ClientUnknownContentReceiveRequestTest < Inferno::Test
      include ClientURLs

      id :crd_v221_client_unknown_content_receive_request
      title 'Client invokes any hook'
      description %(
        During this test, Inferno will wait while the client makes a single hook request of any type.
        Inferno will return a fixed [mocked response](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
        containing a coverage information system action along with content that the client is not
        expected to recognize: an element added to the system action and a custom extension added to
        the response, both with randomly generated names. This content is added at the CRD response
        level rather than within the FHIR resources carried in the response, and testers cannot change
        the response that is returned. The details of the request and its response do not matter for
        the purposes of this test and they will not be evaluated, checked for conformance, or included
        in cross-hook evaluations. The test will automatically continue after Inferno receives a hook
        request and returns a response.
      )
      config options: { accepts_multiple_requests: true }

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: %(
              Value of the `iss` claim that must be present in the JWT used to authorize the client's hook
              request sent as the Bearer token in the `Authorization` header.
              Run or re-run the "Registration" group to set or change this value.
            ),
            locked: true

      run do
        identifier = cds_jwt_iss
        wait(
          identifier:,
          message: %(
            **Unknown Response Content Test**:

            Invoke any supported hook. This test will automatically continue once
            Inferno has received a request and returned a response.

            The response will include coverage information alongside an element and a
            custom extension whose names are not defined by CRD or CDS Hooks. Clients
            must ignore the content they do not recognize and process the coverage
            information as usual. Testers will be asked to attest that this was
            demonstrated in the next test.
          )
        )
      end
    end
  end
end
