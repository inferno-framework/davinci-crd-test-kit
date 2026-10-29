module DaVinciCRDTestKit
  # Inferno's HTTP and FHIR clients raise rather than return a response when the server doesn't respond
  # in time, which would make the test error. These helpers report the timeout against the system under
  # test instead.
  module RequestTimeoutHandling
    # `get` reports a read timeout as a Faraday::TimeoutError, and the FHIR client (`fhir_read`, etc.),
    # which uses RestClient, as a RestClient::Exceptions::Timeout. Connection timeouts from `get` already
    # fail the test through Inferno's TCP exception handler.
    REQUEST_TIMEOUT_ERRORS = [Faraday::TimeoutError, RestClient::Exceptions::Timeout].freeze

    def request_timed_out_message(target)
      "Timed out waiting for a response from #{target}."
    end
  end
end
