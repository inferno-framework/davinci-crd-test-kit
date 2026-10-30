module DaVinciCRDTestKit
  # Inferno's HTTP and FHIR clients raise rather than return a response when the server doesn't respond
  # in time, which would make the test error. These helpers report the timeout against the system under
  # test instead.
  module RequestTimeoutHandling
    # How long a test waits to connect to a server, and then for its response, when making a request
    # with its own Faraday connection.
    REQUEST_TIMEOUT_SECONDS = 10

    # `get` reports a read timeout as a Faraday::TimeoutError, and the FHIR client (`fhir_read`, etc.),
    # which uses RestClient, as a RestClient::Exceptions::Timeout. Connection timeouts from `get` are
    # turned into a failure by Inferno's TCP exception handler.
    REQUEST_TIMEOUT_ERRORS = [Faraday::TimeoutError, RestClient::Exceptions::Timeout].freeze

    def request_timed_out_message(target)
      "Timed out waiting for a response from #{target}."
    end

    # Faraday reports a read timeout as a TimeoutError, but a connection timeout as a
    # ConnectionFailed wrapping Net::OpenTimeout.
    def timeout?(error)
      error.is_a?(Faraday::TimeoutError) ||
        (error.is_a?(Faraday::Error) && error.wrapped_exception.is_a?(Net::OpenTimeout))
    end
  end
end
