require_relative '../gather_response_generation_data'
require_relative '../mock_service_response'
require_relative '../tags'
module DaVinciCRDTestKit
  class HookRequestEndpoint < Inferno::DSL::SuiteEndpoint
    include DaVinciCRDTestKit::MockServiceResponse
    include DaVinciCRDTestKit::GatherResponseGenerationData

    AVAILABLE_HOOKS = [
      'appointment-book',
      'encounter-start',
      'encounter-discharge',
      'order-select',
      'order-sign',
      'order-dispatch'
    ].freeze

    def selected_response_types
      @selected_response_types ||=
        JSON.parse(result.input_json)
          .find { |input| input['name'].include?('selected_response_types') }
          &.dig('value')
    end

    def custom_response
      @custom_response ||=
        JSON.parse(result.input_json)
          .find { |input| input['name'].include?('custom_response') }
          &.dig('value')
    end

    def test_run_identifier
      "#{hook_name} #{iss}"
    end

    def hook_name
      @hook_name ||= request.params[:hook]
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

    def make_response
      if hook_instance_already_used?
        response.status = 400
        response.body =
          "Invalid Request: Hook instance `#{request_body['hookInstance']}` has already been used in this session."
      elsif AVAILABLE_HOOKS.include?(hook_name)
        send(:"gather_#{hook_name.gsub('-', '_')}_data")
        request_coverage
        hook_response
      else
        response.status = 400
        response.body = "Invalid Request: hook `#{hook_name}` is not supported by this server."
      end
    end

    def hook_instance_already_used?
      requests_repo.tagged_requests(test_run.test_session_id, [hook_instance_tag]).present?
    end

    def tags
      if hook_instance_already_used?
        response.status = 400
        response.body =
          "Invalid Request: Hook instance `#{request_body['hookInstance']}` has already been used in this session."
        []
      elsif AVAILABLE_HOOKS.include?(hook_name)
        [hook_instance_tag, DaVinciCRDTestKit.const_get(:"#{name.upcase}_TAG")]
      else
        response.status = 400
        response.body = 'Invalid Request: Request did not contain a valid hook in the `hook` field.'
        []
      end
    end

    def name
      hook_name.gsub('-', '_')
    end
  end
end
