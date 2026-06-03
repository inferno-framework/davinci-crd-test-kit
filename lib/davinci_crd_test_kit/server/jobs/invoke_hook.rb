# frozen_string_literal: true

require_relative '../../cross_suite/tags'
require_relative '../../cross_suite/base_urls'
require_relative '../../cross_suite/cards_identification'
require_relative '../endpoints/mock_ehr/fhir_request_handler'
require_relative '../server_base_urls'

module DaVinciCRDTestKit
  module Jobs
    class InvokeHook
      include Sidekiq::Job
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ServerBaseURLs

      sidekiq_options retry: false

      def perform(test_session_id, request_bodies, service_endpoint, inferno_base_url, jwks_kid,
                  encryption_method, request_tag, continuation_url, failure_url, acknowledge_before_continuing,
                  coverage_info_configuration_supported)
        @test_session_id = test_session_id
        @service_endpoint = service_endpoint
        @inferno_base_url = inferno_base_url
        @jwks_kid = jwks_kid
        @encryption_method = encryption_method
        @request_tag = request_tag
        @continuation_url = continuation_url
        @failure_url = failure_url
        @acknowledge_before_continuing = acknowledge_before_continuing
        @coverage_info_configuration_supported = coverage_info_configuration_supported

        perform_hook_invocations(request_bodies)
      end

      def perform_hook_invocations(request_bodies)
        await_test_waiting # let Inferno start waiting so it can respond to FHIR requests

        request_bodies.each do |request|
          break unless test_waiting?

          request_body = prepare_hook_request(request)
          response = send_hook_invocation(request_body.to_json)
          send_coverage_info_configuration_invocation(request_body, response)
          send_unknown_configuration_invocation(request_body, response)
          send_unknown_context_invocation(request_body, response)
          send_unknown_cds_hooks_element_invocation(request_body, response)
        end

        return unless test_waiting?

        # end the wait to continue the tests
        Faraday.get(@continuation_url) unless @acknowledge_before_continuing
      rescue StandardError => e
        Faraday.get(@failure_url, { message: "Hook invocation failed: #{e.message}" })
      end

      def test_run_id
        @test_run_id ||= test_runs_repo.last_test_run(@test_session_id).id
      end

      def test_runs_repo
        @test_runs_repo ||= Inferno::Repositories::TestRuns.new
      end

      def requests_repo
        @requests_repo ||= Inferno::Repositories::Requests.new
      end

      def results_repo
        @results_repo ||= Inferno::Repositories::Results.new
      end

      def service_connection
        @service_connection ||= Faraday.new(url: @service_endpoint, request: { open_timeout: 30 })
      end

      def test_done?
        test_runs_repo.status_for_test_run(test_run_id) == 'done'
      end

      def await_test_waiting
        sleep 0.5 until test_waiting? || test_done?

        @result_id = results_repo.find_waiting_result(test_run_id:)&.id
      end

      def test_waiting?
        results_repo.find_waiting_result(test_run_id:).present?
      end

      def prepare_hook_request(parsed_request)
        parsed_request['hookInstance'] = SecureRandom.uuid
        parsed_request['fhirServer'] = fhir_url
        update_simulated_server_token(parsed_request)
        parsed_request
      end

      def update_simulated_server_token(parsed_request)
        parsed_request['fhirAuthorization'] = {} if parsed_request['fhirAuthorization'].nil?
        fhir_authorization = parsed_request['fhirAuthorization']

        fhir_authorization['expires_in'] = 300 unless fhir_authorization['expires_in'].present?
        fhir_authorization['access_token'] =
          MockEHR::FHIRRequestHandler.session_id_to_token(@test_session_id, fhir_authorization['expires_in'].to_i / 60)
      end

      def send_hook_invocation(request_body, extra_tags = [])
        token = JwtHelper.build(
          aud: @service_endpoint,
          iss: @inferno_base_url,
          jku: "#{@inferno_base_url}/jwks.json",
          kid: @jwks_kid,
          encryption_method: @encryption_method
        )
        headers = { 'Content-type' => 'application/json', 'Authorization' => "Bearer #{token}" }
        response = invoke_hook(request_body, headers)
        persist_hook_request(response, [@request_tag] + extra_tags, headers)
        response
      end

      def send_coverage_info_configuration_invocation(request_body, response)
        return unless @coverage_info_configuration_supported
        return if @coverage_info_configuration_invoked
        return unless response.status == 200
        return unless coverage_info_response?(parsed_response_body(response))
        return unless test_waiting?

        configured_request_body = JSON.parse(request_body.to_json)
        prepare_hook_request(configured_request_body)
        disable_coverage_info_configuration!(configured_request_body)
        send_hook_invocation(configured_request_body.to_json, [COVERAGE_INFO_DISABLED_TAG])
        @coverage_info_configuration_invoked = true
      end

      def send_unknown_configuration_invocation(request_body, response)
        return if @unknown_configuration_invoked
        return unless response.status == 200
        return unless coverage_info_system_action_response?(parsed_response_body(response))
        return unless test_waiting?

        request_body = JSON.parse(request_body.to_json)
        prepare_hook_request(request_body)
        add_unknown_configuration(request_body)
        send_hook_invocation(request_body.to_json, [UNKNOWN_CONFIGURATION_TAG])

        @unknown_configuration_invoked = true
      end

      def send_unknown_context_invocation(request_body, response)
        return if @unknown_context_invoked
        return unless response.status == 200
        return unless coverage_info_system_action_response?(parsed_response_body(response))
        return unless test_waiting?

        request_body = JSON.parse(request_body.to_json)
        prepare_hook_request(request_body)
        add_unknown_context(request_body)
        send_hook_invocation(request_body.to_json, [UNKNOWN_CONTEXT_TAG])

        @unknown_context_invoked = true
      end

      def send_unknown_cds_hooks_element_invocation(request_body, response)
        return if @unknown_cds_hooks_element_invoked
        return unless response.status == 200
        return unless coverage_info_system_action_response?(parsed_response_body(response))
        return unless test_waiting?

        request_body = JSON.parse(request_body.to_json)
        prepare_hook_request(request_body)
        add_unknown_element(request_body)
        send_hook_invocation(request_body.to_json, [UNKNOWN_ELEMENT_TAG])

        @unknown_cds_hooks_element_invoked = true
      end

      def random_key
        ('a'..'z').to_a.sample(16).join
      end

      def add_unknown_configuration(request_body)
        request_body['extension'] ||= {}
        request_body['extension']['davinci-crd.configuration'] ||= {}
        request_body['extension']['davinci-crd.configuration'][random_key] = true
      end

      def add_unknown_context(request_body)
        request_body['context'] ||= {}
        request_body['context'][random_key] ||= random_key
      end

      def add_unknown_element(request_body)
        request_body[random_key] ||= random_key
      end

      def parsed_response_body(response)
        JSON.parse(response.env.response_body.to_s)
      rescue JSON::ParserError, TypeError
        nil
      end

      def invoke_hook(request_body, headers)
        service_connection.post('', request_body, headers)
      end

      def persist_hook_request(response, tags, headers)
        inferno_request_headers = headers.map { |name, value| { name:, value: } }
        inferno_response_headers = response.headers&.map { |name, value| { name:, value: } }
        requests_repo.create(
          verb: 'POST',
          url: response.env.url.to_s,
          direction: 'outgoing',
          status: response.status,
          request_body: response.env.request_body,
          response_body: response.env.response_body,
          test_session_id: @test_session_id,
          result_id: @result_id,
          request_headers: inferno_request_headers,
          response_headers: inferno_response_headers,
          tags:
        )
      end
    end
  end
end
