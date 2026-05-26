require_relative 'gather_response_generation_data'
require_relative 'mock_service_response'
require_relative 'custom_service_response'
require_relative '../../cross_suite/cards_identification'
require_relative '../../cross_suite/tags'

module DaVinciCRDTestKit
  class HookRequestEndpoint < Inferno::DSL::SuiteEndpoint
    include DaVinciCRDTestKit::MockServiceResponse
    include DaVinciCRDTestKit::GatherResponseGenerationData
    include DaVinciCRDTestKit::CustomServiceResponse
    include DaVinciCRDTestKit::CardsIdentification

    AVAILABLE_HOOKS = [
      'appointment-book',
      'encounter-start',
      'encounter-discharge',
      'order-select',
      'order-sign',
      'order-dispatch'
    ].freeze

    def ig_version
      @ig_version ||= requested_version || request.env['PATH_INFO'].match(/(v\d+)/)&.[](1) || 'v201'
    end

    # JSON round-trip normalizes the Hanami params object to a plain string-keyed Hash
    def request_body
      @request_body ||= JSON.parse(request.params.to_json)
    end

    def requested_version
      requested = request_body.dig('extension', 'davinci-crd.requestedVersion').to_s
      if requested == '2.2'
        'v221'
      elsif requested == '2.0'
        'v201'
      end
    end

    def test_run_identifier
      iss
    end

    def iss
      @iss ||=
        begin
          payload, = JWT.decode(token, nil, false)
          payload['iss']
        rescue JWT::DecodeError
          nil
        end
    end

    def token
      @token ||= request.headers['authorization']&.delete_prefix('Bearer ')
    end

    # from the hook body
    def requested_hook
      @requested_hook ||= request_body['hook']
    end

    # from the url
    def invoked_hook
      @invoked_hook ||= request.env['PATH_INFO'].match(%r{/([^/]+)-(?:service|subset)$})&.[](1)
    end

    # from the waiting test
    def tested_hook
      @tested_hook ||= test.config.options[:hook_name]
    end

    def wrong_hook_for_test?
      tested_hook.present? && tested_hook != ANY_HOOK_TAG && requested_hook != tested_hook
    end

    def make_response
      if invoked_hook != requested_hook
        error_response("#{request.env['PATH_INFO']} serves the #{invoked_hook}, but the client " \
                       "requested the #{requested_hook} hook.",
                       code: 400,
                       outcome_code: 'value')
      elsif wrong_hook_for_test?
        error_response("Hook '#{requested_hook}' is not being tested in the current session. " \
                       "This session is currently testing the '#{tested_hook}' hook.",
                       code: 422,
                       outcome_code: 'value')
      elsif hook_instance_already_used?
        error_response(
          "Invalid Request: Hook instance `#{request_body['hookInstance']}` has already been used in this session.",
          outcome_code: 'value'
        )
      elsif AVAILABLE_HOOKS.include?(requested_hook)
        process_valid_hook
      else
        error_response("Invalid Request: hook `#{requested_hook}` is not supported by this server.",
                       outcome_code: 'value')
      end
    rescue StandardError => e
      error_response("Inferno failed to generate a response: #{e.message} at #{e.backtrace.first}",
                     code: 500,
                     outcome_code: 'exception')
    end

    def process_valid_hook
      if ig_version == 'v201'
        send(:"gather_#{requested_hook.gsub('-', '_')}_data")
        request_coverage
      elsif ig_version == 'v221'
        request_additional_fhir_data
      end
      response_body = apply_hook_configuration(hook_response)
      return unless response_body.present?

      response.body = response_body.to_json
      response.headers.merge!({ 'Content-Type' => 'application/json', 'Access-Control-Allow-Origin' => '*' })
      response.status = 200
      response.format = :json
    end

    def response_approach
      JSON.parse(result.input_json)
        .find { |input| input['name'].ends_with?('_response_approach') }
        &.dig('value')
    end

    def hook_response
      if response_approach == 'custom'
        build_custom_hook_response
      else
        build_mock_hook_response
      end
    rescue StandardError => e
      error_response("Inferno failed to generate a response: #{e.message} at #{e.backtrace.first}", code: 500)
      nil
    end

    def apply_hook_configuration(response_body)
      return response_body unless response_body.present? && coverage_info_disabled?

      cards = response_body['cards']
      response_body['cards'] = cards.reject { |card| coverage_info_card_type?(card) } if cards.is_a?(Array)

      system_actions = response_body['systemActions']
      if system_actions.is_a?(Array)
        response_body['systemActions'] = system_actions.reject { |action| coverage_info_system_action_type?(action) }
      end

      response_body
    end

    def coverage_info_disabled?
      request_body.dig('extension', 'davinci-crd.configuration', COVERAGE_INFO_CONFIGURATION_CODE) == false
    end

    def hook_instance_already_used?
      requests_repo.tagged_requests(test_run.test_session_id, [hook_instance_tag]).present?
    end

    def tags
      return [LONG_RUNNING_GROUP_TAG] if long_running_group?
      return [DUPLICATED_HOOK_INSTANCE_TAG] if hook_instance_already_used?

      return [] if invoked_hook != requested_hook ||
                   wrong_hook_for_test? ||
                   !AVAILABLE_HOOKS.include?(requested_hook)

      [hook_instance_tag, hook_or_group_tag]
    end

    def hook_instance_tag
      TagMethods.hook_instance_tag(request_body['hookInstance'])
    end

    def hook_or_group_tag
      if test.config.options[:crd_test_group].present?
        test.config.options[:crd_test_group]
      else
        DaVinciCRDTestKit.const_get(:"#{name.upcase}_TAG")
      end
    end

    def error_response(error_message, code: 400, outcome_code: 'invalid')
      response.status = code
      response.body = error_operation_outcome(outcome_code, error_message).to_json
      response.headers.merge!({ 'Content-Type' => 'application/json', 'Access-Control-Allow-Origin' => '*' })
      response.format = :json
    end

    def error_operation_outcome(code, text)
      {
        resourceType: 'OperationOutcome',
        issue: [
          {
            severity: 'error',
            code:,
            details: {
              text:
            }
          }
        ]
      }
    end

    def name
      requested_hook.gsub('-', '_')
    end

    # -----------------------
    # Long Running Group handling
    # -----------------------

    def long_running_group?
      test.config.options[:crd_test_group] == LONG_RUNNING_GROUP_TAG
    end

    def long_running_pause_time
      JSON.parse(result.input_json)
        .find { |input| input['name'].include?('long_running_pause_time') }
        &.dig('value').to_i
    end

    # end the wait immediately after the long-running request returns
    # pause here because update_result runs before response generation
    def update_result
      return unless long_running_group?

      sleep long_running_pause_time
      results_repo.update(result.id, result: 'pass', result_message: '')
    end
  end
end
