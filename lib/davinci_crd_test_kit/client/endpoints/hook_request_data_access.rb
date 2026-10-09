require_relative '../../cross_suite/tags'

module DaVinciCRDTestKit
  # Reads data from the CRD client while a hook request is being processed, using the `fhirServer`
  # and `fhirAuthorization` the request provides, and records each read so that tests can check
  # them later. Shared by the data gathering for each CRD version, and by response generation,
  # which needs the Coverage the request is for.
  module HookRequestDataAccess
    # Reads happen before the hook response is sent, so a server that stops responding must not
    # hold the response indefinitely.
    FHIR_SERVER_TIMEOUT_SECONDS = 10

    def hook_instance_data_fetch_tag
      @hook_instance_data_fetch_tag ||= TagMethods.hook_instance_data_fetch_tag(request_body['hookInstance'])
    end

    # A normalized reference that is still absolute points to a server other than the FHIR server
    # named in the request.
    def absolute_url?(reference)
      reference.match?(%r{\Ahttps?://})
    end

    # turn absolute references into relative if
    # for the fhir server indicated in the request
    def normalize_reference(reference)
      server = "#{request_body['fhirServer']&.chomp('/')}/"

      if request_body['fhirServer'].present? && reference.starts_with?(server)
        reference[server.length..]
      else
        reference
      end
    end

    # A reference to a server other than the FHIR server named in the request is read without the
    # access token, which is only for that FHIR server.
    def fetch_reference(reference, additional_tag: nil, parse_as_fhir: false)
      reference = normalize_reference(reference)
      fetched_references << reference
      external = absolute_url?(reference)
      response = execute_request(reference, connection: external ? external_connection : fhir_server_connection)
      return nil unless response.present?

      persist_query_request(response, fetch_tags(additional_tag), request_headers: external ? {} : data_request_headers)
      return nil unless response.status.to_s.starts_with?('2')

      begin
        parse_as_fhir ? FHIR.from_contents(response.body) : JSON.parse(response.body)
      rescue JSON::ParserError
        nil
      end
    end

    def fetch_tags(additional_tag)
      [DATA_FETCH_TAG, hook_instance_data_fetch_tag, additional_tag].compact_blank
    end

    def fetched_references
      @fetched_references ||= Set.new
    end

    def request_coverage
      @request_coverage ||= find_coverage_for_request
    end

    def prefetched_coverage
      @prefetched_coverage ||=
        if request_body.dig('prefetch', 'coverage').present?
          FHIR.from_contents(request_body.dig('prefetch', 'coverage').to_json)
        elsif request_body.dig('prefetch', 'cov').present?
          FHIR.from_contents(request_body.dig('prefetch', 'cov').to_json)
        end
    end

    def find_coverage_for_request
      resource =
        if prefetched_coverage.present?
          prefetched_coverage
        else
          query_for_coverages
        end

      return unless resource.is_a?(FHIR::Bundle)

      resource.entry&.first&.resource
    end

    def fhir_server_connection
      @fhir_server_connection ||=
        if request_body['fhirServer'].present? &&
           request_body['fhirAuthorization'].present? &&
           request_body['fhirAuthorization']['access_token'].present?
          Faraday.new(url: request_body['fhirServer'],
                      request: { open_timeout: FHIR_SERVER_TIMEOUT_SECONDS, timeout: FHIR_SERVER_TIMEOUT_SECONDS },
                      headers: data_request_headers) do |f|
            f.request :url_encoded
            f.use FaradayMiddleware::FollowRedirects
          end
        end
    end

    def external_connection
      @external_connection ||=
        Faraday.new(request: { open_timeout: FHIR_SERVER_TIMEOUT_SECONDS, timeout: FHIR_SERVER_TIMEOUT_SECONDS }) do |f|
          f.request :url_encoded
          f.use FaradayMiddleware::FollowRedirects
        end
    end

    def data_request_headers
      @data_request_headers ||=
        { 'Authorization' => "Bearer #{request_body['fhirAuthorization']['access_token']}" }
    end

    def execute_request(query, connection: fhir_server_connection)
      connection&.get(query)
    rescue Faraday::Error => e
      timed_out_servers << server_for(query, connection) if timeout?(e)
      # Warning: This is a hack. If there is an error with the request such that we never get a response, we have
      #          no clean way to persist that information for the Inferno test to check later. The solution here
      #          is to persist the request anyway with a status of nil, using the error message as response body
      url = query.to_s.match?(%r{\Ahttps?://}) ? query : connection.url_prefix.to_s
      Faraday::Response.new(response_body: e.message, url:)
    end

    # The servers that have timed out while processing this request, each identified by scheme,
    # host, and port.
    def timed_out_servers
      @timed_out_servers ||= Set.new
    end

    def server_for(query, connection = fhir_server_connection)
      uri = query.to_s.match?(%r{\Ahttps?://}) ? URI(query.to_s) : connection&.url_prefix
      "#{uri.scheme}://#{uri.host}:#{uri.port}" if uri.present?
    rescue URI::InvalidURIError
      nil
    end

    def server_timed_out?(query)
      timed_out_servers.include?(server_for(query))
    end

    # Faraday reports a read timeout as a TimeoutError, but a connection timeout as a
    # ConnectionFailed wrapping Net::OpenTimeout.
    def timeout?(error)
      error.is_a?(Faraday::TimeoutError) || error.wrapped_exception.is_a?(Net::OpenTimeout)
    end

    def persist_query_request(response, tags, request_headers: data_request_headers)
      inferno_request_headers = request_headers.map { |name, value| { name:, value: } }
      inferno_response_headers = response.headers&.map { |name, value| { name:, value: } }
      requests_repo.create(
        verb: 'GET',
        url: response.env.url.to_s,
        direction: 'outgoing',
        status: response.status,
        request_body: response.env.request_body,
        response_body: response.env.response_body,
        test_session_id: test_run.test_session_id,
        result_id: result.id,
        request_headers: inferno_request_headers,
        response_headers: inferno_response_headers,
        tags:
      )
    end

    def query_for_coverages
      query = "Coverage?patient=#{request_body.dig('context', 'patientId')}&status=active"
      response = execute_request(query)
      return nil unless response.present?

      persist_query_request(response, [DATA_FETCH_TAG, hook_instance_data_fetch_tag])
      return nil unless response.status.to_s.starts_with?('2')

      FHIR.from_contents(response.body)
    end
  end
end
