module DaVinciCRDTestKit
  # Make requests to client's FHIR server to use in building responses
  module GatherResponseGenerationData
    def request_coverage
      @request_coverage ||= query_for_coverages&.entry&.first&.resource
    end

    def fhir_server_connection
      @fhir_server_connection ||=
        if request_body['fhirServer'].present? &&
           request_body['fhirAuthorization'].present? &&
           request_body['fhirAuthorization']['access_token'].present?
          Faraday.new(url: request_body['fhirServer'], request: { open_timeout: 10 },
                      headers: data_request_headers)
        end
    end

    def data_request_headers
      @data_request_headers ||=
        { 'Authorization' => "Bearer #{request_body['fhirAuthorization']['access_token']}" }
    end

    def execute_request(query)
      fhir_server_connection.get(query)
    rescue Faraday::Error => e
      # Warning: This is a hack. If there is an error with the request such that we never get a response, we have
      #          no clean way to persist that information for the Inferno test to check later. The solution here
      #          is to persist the request anyway with a status of nil, using the error message as response body
      Faraday::Response.new(response_body: e.message, url: fhir_server_connection.url_prefix.to_s)
    end

    def persist_query_request(response, tags)
      inferno_request_headers = data_request_headers.map { |name, value| { name:, value: } }
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
      persist_query_request(response, ['coverage', request_body['hookInstance']])

      return nil unless response.status.to_s.starts_with?('2')

      FHIR.from_contents(response.body)
    end
  end
end
