# frozen_string_literal: true

require_relative '../../cross_suite/tags'
require_relative '../../cross_suite/base_urls'

module DaVinciCRDTestKit
  module Jobs
    class InvokeHook
      include Sidekiq::Job

      sidekiq_options retry: false

      def perform(test_session_id, request_bodies, service_endpoint, inferno_base_url, jwks_kid,
                  encryption_method, request_tag, continuation_url, failure_url, acknowledge_before_continuing)
        @test_session_id = test_session_id
        @service_endpoint = service_endpoint
        @inferno_base_url = inferno_base_url
        @jwks_kid = jwks_kid
        @encryption_method = encryption_method
        @request_tag = request_tag
        @continuation_url = continuation_url
        @failure_url = failure_url
        @acknowledge_before_continuing = acknowledge_before_continuing

        perform_hook_invocations(request_bodies)
      end

      def perform_hook_invocations(request_bodies)
        await_test_waiting # let Inferno start waiting so it can respond to FHIR requests

        request_bodies.each do |request|
          break unless test_waiting?

          send_hook_invocation(request.to_json)
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

      def send_hook_invocation(request_body)
        token = JwtHelper.build(
          aud: @service_endpoint,
          iss: @inferno_base_url,
          jku: "#{@inferno_base_url}/jwks.json",
          kid: @jwks_kid,
          encryption_method: @encryption_method
        )
        headers = { 'Content-type' => 'application/json', 'Authorization' => "Bearer #{token}" }
        response = invoke_hook(request_body, headers)
        persist_hook_request(response, [@request_tag], headers)
        response
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
