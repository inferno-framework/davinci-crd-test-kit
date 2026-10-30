module DaVinciCRDTestKit
  # Inferno's HTTP and FHIR clients raise rather than return a response when the server doesn't respond
  # in time, which would make the test error. These helpers report the timeout against the system under
  # test instead.
  module RequestTimeoutHandling
    # How long a test waits to connect to a server, and then for its response, when making a request
    # with its own Faraday connection.
    REQUEST_TIMEOUT_SECONDS = 10

    def request_timed_out_message(target)
      "Timed out waiting for a response from #{target}."
    end

    # Faraday, used by `get`, reports a read timeout as a TimeoutError, but a connection timeout as a
    # ConnectionFailed wrapping Net::OpenTimeout. RestClient, used by the FHIR client (`fhir_read`,
    # etc.), reports either as a RestClient::Exceptions::Timeout. Inferno's TCP exception handler turns
    # some connection timeouts from `get` into a failure first.
    def timeout?(error)
      error.is_a?(Faraday::TimeoutError) ||
        (error.is_a?(Faraday::Error) && error.wrapped_exception.is_a?(Net::OpenTimeout)) ||
        error.is_a?(RestClient::Exceptions::Timeout)
    end
  end
end
