require_relative '../../client_wait_messages'
require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class ClientLongRunningReceiveRequestTest < Inferno::Test
      include ClientURLs
      include DaVinciCRDTestKit::ClientWaitMessages

      # CRD expects responses within a 5 or 10 second window depending on the hook. The minimum pause
      # exceeds the longer window with enough margin for the CRD client to recognize the response as late.
      MINIMUM_PAUSE_SECONDS = 15

      id :crd_v221_client_long_running_receive_request
      title 'CRD client invokes any hook'
      description %(
        During this test, Inferno will wait while the CRD client makes a single hook requests of any type.
        Inferno will return a [mocked response](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
        but only after pausing for a configured amount of time, which must be #{MINIMUM_PAUSE_SECONDS} seconds or
        longer so that it exceeds the [5 or 10 second response window](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#ci-c-found-3)
        CRD defines for each hook. The details of the request and its response do not matter for the purposes
        of this test and they will not be evaluated, checked for conformance, or included in cross-hook
        evaluations. The test will automatically continue after Inferno receives a hook request, the
        configured pause time has elapsed, and a response has been returned.
      )
      config options: { accepts_multiple_requests: true }

      input :long_running_pause_time,
            title: 'Long-running Request Pause Time',
            description: %(
              Time in seconds to wait before returning a response to a hook invocation
              made when testing a long-running request. Must be at least #{MINIMUM_PAUSE_SECONDS} seconds,
              which exceeds the 5 or 10 second response window CRD defines for each hook with enough
              margin for the CRD client to recognize that the response is taking too long.
            ),
            default: MINIMUM_PAUSE_SECONDS.to_s
      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: %(
              Value of the `iss` claim that must be present in the JWT used to authorize the CRD client's hook
              request sent as the Bearer token in the `Authorization` header.
              Run or re-run the "Registration" group to set or change this value.
            ),
            locked: true
      payer_organization_id_inputs
      flag_as_tester_initiated_exchange

      run do
        verify_long_running_pause_time_input

        identifier = cds_jwt_iss
        wait(identifier:, message: wait_message)
      end

      # wait messages are rendered as given, so keep every line flush to avoid markdown reading
      # the indentation as a code block
      def wait_message
        <<~MESSAGE
          #### Long Running Hook Request Test

          Invoke any supported hook on one of the two Inferno simulated
          CRD servers. This test will automatically continue once Inferno
          has received a request, paused for #{long_running_pause_time.to_i}
          seconds, and returned a response.

          Users must have the option to continue working while waiting for Inferno's
          response to be returned. Testers will be asked to certify that this was
          demonstrated in the next test.

          #{service_discovery_endpoints_section}
          #### Authentication and Identification

          #{session_identification_message}

          #### Responses

          Inferno will return a mocked coverage-information response.
        MESSAGE
      end

      def verify_long_running_pause_time_input
        assert long_running_pause_time.to_i >= MINIMUM_PAUSE_SECONDS,
               "The **Long-running Request Pause Time** input must be at least #{MINIMUM_PAUSE_SECONDS} seconds."
      end
    end
  end
end
