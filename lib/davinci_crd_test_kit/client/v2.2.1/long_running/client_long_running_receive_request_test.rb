require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class ClientLongRunningReceiveRequestTest < Inferno::Test
      include ClientURLs

      id :crd_v221_client_long_running_receive_request
      title 'Send a Hook Request that will take a long time to return'
      description %(
        This test waits for a single incoming hook request of any type and will return a mocked response
        but only after pausing for a configured amount of time, which must be 5 seconds or longer. The details
        of the request and its response do not matter for the purposes of this test and they will not be
        evaluated. The test will automatically continue after Inferno receives a hook request, the
        configured pause time has elapsed, and a response has been returned.
      )
      config options: { accepts_multiple_requests: true }
      # verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@171',
      #                       'hl7.fhir.us.davinci-crd_2.0.1@183', 'hl7.fhir.us.davinci-crd_2.0.1@243',
      #                       'hl7.fhir.us.davinci-crd_2.0.1@244', 'hl7.fhir.us.davinci-crd_2.0.1@245',
      #                       'cds-hooks_2.0@15'

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: %(
              Value of the `iss` claim that must be sent on the Bearer token in the `Authorization`
              header of all requests. Run or re-run the **Client Registration** group to set or
              change this value.
            ),
            locked: true
      input :long_running_pause_time,
            title: 'Long-running Request Pause Time',
            description: %(
              Time in seconds to wait before returning a response to a hook request
              made during this time. Must be at least 5 seconds which is the minimum
              threshold for a long-running response as defined by CRD.
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
            their workflow before the response returns. Testers will be asked to
            attest that this was demonstrated in the next test.
          )
        )
      end

      def verify_long_running_pause_time_input
        assert long_running_pause_time.to_i >= 5,
               "The 'Long-running Request Pause Time' input must be at lesat 5 seconds."
      end
    end
  end
end
