require_relative '../../cross_suite/request_timeout_handling'
require_relative '../../cross_suite/resource_identity'
require_relative '../../cross_suite/tags'
require_relative '../prefetched_coverage_value'

module DaVinciCRDTestKit
  # Reads data from the CRD client while a hook request is being processed, using the `fhirServer`
  # and `fhirAuthorization` the request provides, and records each read so that tests can check
  # them later. Shared by the data gathering for each CRD version, and by response generation,
  # which needs the Coverage the request is for.
  module HookRequestDataAccess
    include RequestTimeoutHandling

    # Reads happen before the hook response is sent, so a server that stops responding must not
    # hold the response indefinitely.
    FHIR_SERVER_TIMEOUT_SECONDS = 10

    # Runs a step that reads data only so that later tests can check it. Such a step must not cost
    # the CRD client its hook response, so an unexpected error is logged rather than raised, and the
    # tests that rely on the step report what it did not record. Those reports would read as the CRD
    # client's fault, so the waiting test is also given a warning naming the internal error.
    def continue_after_failure(step)
      yield
    rescue StandardError => e
      Inferno::Application['logger'].error("Hook request #{request_body&.dig('hookInstance')}: " \
                                           "#{step} failed: #{e.full_message}")
      warn_waiting_test_of_failure(step, e)
      nil
    end

    # The warning carries only the error's message, since the full trace is in the server log.
    def warn_waiting_test_of_failure(step, error)
      return unless respond_to?(:result) && result.present?

      Inferno::Repositories::Messages.new.create(
        result_id: result.id,
        type: 'warning',
        message: "Inferno encountered an internal error while #{step} for hook request " \
                 "`#{request_body&.dig('hookInstance')}`: `#{error.class}: #{error.message}`. Tests " \
                 'that check this data may report it as missing even though the CRD client is not at ' \
                 'fault. Re-sending the request may not help; please report this issue.'
      )
    rescue StandardError => e
      Inferno::Application['logger'].error("Could not record the failure of #{step}: #{e.full_message}")
    end

    def hook_instance_data_fetch_tag
      @hook_instance_data_fetch_tag ||= TagMethods.hook_instance_data_fetch_tag(request_body['hookInstance'])
    end

    # turn absolute references into relative if
    # for the fhir server indicated in the request, and give any other in its normalized form
    def normalize_reference(reference)
      ResourceIdentity.relative_to(reference, request_body['fhirServer']) || ResourceIdentity.normalized_url(reference)
    end

    # A reference to a server other than the FHIR server named in the request is read without the
    # access token, which is only for that FHIR server. A normalized reference that is still
    # absolute points to such a server.
    def fetch_reference(reference, additional_tag: nil, parse_as_fhir: false)
      reference = normalize_reference(reference)
      fetched_references << reference
      external = ResourceIdentity.absolute_url?(reference)
      connection = external ? external_connection : fhir_server_connection
      response = execute_request(reference, connection:)
      return nil unless response.present?

      persist_query_request(response, fetch_tags(additional_tag, with_token: !external),
                            url: requested_url(reference, connection),
                            request_headers: external ? {} : data_request_headers)
      return nil unless response.status.to_s.starts_with?('2')

      begin
        parse_as_fhir ? FHIR.from_contents(response.body) : JSON.parse(response.body)
      rescue JSON::ParserError
        nil
      end
    end

    # Every read carries the hook instance tag. Only reads made with the access token carry
    # DATA_FETCH_TAG, since that tag is what shows the token gave access to the CRD client's data.
    def fetch_tags(additional_tag, with_token:)
      [(DATA_FETCH_TAG if with_token), hook_instance_data_fetch_tag, additional_tag].compact_blank
    end

    def fetched_references
      @fetched_references ||= Set.new
    end

    def request_coverage
      @request_coverage ||= find_coverage_for_request
    end

    def prefetched_coverage
      @prefetched_coverage ||= begin
        coverage = PrefetchedCoverageValue.find(request_body['prefetch'])
        FHIR.from_contents(coverage.to_json) if coverage.present?
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
      return unreadable_scheme_response(query) if unreadable_scheme?(query)

      connection&.get(query)
    rescue Faraday::Error, URI::InvalidURIError => e
      timed_out_servers << server_for(query, connection) if timeout?(e)
      # Warning: This is a hack. If there is an error with the request such that we never get a response, we have
      #          no clean way to persist that information for the Inferno test to check later. The solution here
      #          is to persist the request anyway with a status of nil, using the error message as response body
      url = ResourceIdentity.absolute_url?(query) ? query : connection.url_prefix.to_s
      Faraday::Response.new(response_body: e.message, url:)
    end

    # An absolute reference with a scheme other than http(s), such as `urn:uuid:`, names a resource
    # without saying where it can be read from, so no request is made for it.
    def unreadable_scheme?(query)
      ResourceIdentity.absolute_url?(query) && !ResourceIdentity.http_url?(query)
    end

    # Recorded like a request that got no response, so that tests report the reference as not read.
    def unreadable_scheme_response(query)
      Faraday::Response.new(response_body: "Inferno cannot read `#{query}`: only http(s) URLs can be read.",
                            url: query.to_s)
    end

    # The servers that have timed out while processing this request, each identified by scheme,
    # host, and port.
    def timed_out_servers
      @timed_out_servers ||= Set.new
    end

    def server_for(query, connection = fhir_server_connection)
      uri = ResourceIdentity.absolute_url?(query) ? URI(query.to_s) : connection&.url_prefix
      "#{uri.scheme}://#{uri.host&.downcase}:#{uri.port}" if uri.present?
    rescue URI::InvalidURIError
      nil
    end

    def server_timed_out?(query)
      timed_out_servers.include?(server_for(query))
    end

    # Redirects are followed, and, as Inferno's FHIR client does, the read is recorded under the URL
    # requested rather than the one it ended at, so that tests can match a reference to its read.
    # A query that is not a valid URL, or cannot be read, is recorded as given.
    def requested_url(query, connection)
      return query.to_s if unreadable_scheme?(query)

      connection.build_exclusive_url(query).to_s
    rescue URI::InvalidURIError
      query.to_s
    end

    def persist_query_request(response, tags, url:, request_headers: data_request_headers)
      inferno_request_headers = request_headers.map { |name, value| { name:, value: } }
      inferno_response_headers = response.headers&.map { |name, value| { name:, value: } }
      requests_repo.create(
        verb: 'GET',
        url:,
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

      persist_query_request(response, [DATA_FETCH_TAG, hook_instance_data_fetch_tag],
                            url: requested_url(query, fhir_server_connection))
      return nil unless response.status.to_s.starts_with?('2')

      FHIR.from_contents(response.body)
    end
  end
end
