require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class ClientLongRunningReceiveRequestTest < Inferno::Test
      include ClientURLs

      id :crd_v221_client_long_running_receive_request
      title 'Client invokes any hook'
      description %(
        During this test, Inferno will wait while the client makes a single hook requests of any type.
        Inferno will return a [mocked response](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
        but only after pausing for a configured amount of time, which must be 5 seconds or longer. The details
        of the request and its response do not matter for the purposes of this test and they will not be
        evaluated, checked for conformance, or included in cross-hook evaluations. The test will automatically
        continue after Inferno receives a hook request, the configured pause time has elapsed,
        and a response has been returned.
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
      input :long_running_pause_time,
            title: 'Long-running Request Pause Time',
            description: %(
              Time in seconds to wait before returning a response to a hook invocation
              made when testing a long-running request. Must be at least 5 seconds,
              which is the minimum threshold for a long-running response as defined by CRD.
            ),
            default: '5'

      run do
        verify_long_running_pause_time_input

        identifier = cds_jwt_iss
        wait(
          identifier:,
          message: %(
            **Long Running Hook Request Test**:

            Invoke any supported hook. This test will
            automatically continue once Inferno has received a request, paused
            for #{long_running_pause_time.to_i} seconds, and returned a response.

            Users must have the option to continue
            their workflow before Inferno's response is returned. Testers will be asked to
            attest that this was demonstrated in the next test.
          )
        )
      end

      def verify_long_running_pause_time_input
        assert long_running_pause_time.to_i >= 5,
               'The **Long-running Request Pause Time** input must be at least 5 seconds.'
      end
    end
  end
end
