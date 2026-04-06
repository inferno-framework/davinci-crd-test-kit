require_relative 'gather_response_generation_data'
require_relative 'mock_service_response'
require_relative 'custom_service_response'
require_relative '../../cross_suite/tags'

module DaVinciCRDTestKit
  class HookRequestEndpoint < Inferno::DSL::SuiteEndpoint
    include DaVinciCRDTestKit::MockServiceResponse
    include DaVinciCRDTestKit::GatherResponseGenerationData
    include DaVinciCRDTestKit::CustomServiceResponse

    AVAILABLE_HOOKS = [
      'appointment-book',
      'encounter-start',
      'encounter-discharge',
      'order-select',
      'order-sign',
      'order-dispatch'
    ].freeze

    def ig_version
      @ig_version ||= request.env['PATH_INFO'].match(/(v\d+)/)&.[](1) || 'v201'
    end

    def request_body
      @request_body ||=
        JSON.parse(request.params.to_json)
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
        error_response(
          "Invalid Request: Hook instance `#{request_body['hookInstance']}` has already been used in this session."
        )
      elsif AVAILABLE_HOOKS.include?(hook_name)
        if ig_version == 'v201'
          send(:"gather_#{hook_name.gsub('-', '_')}_data")
          request_coverage
        end
        response_body = hook_response
        if response_body.present?
          response.body = response_body.to_json
          response.headers.merge!({ 'Content-Type' => 'application/json', 'Access-Control-Allow-Origin' => '*' })
          response.status = 200
          response.format = :json
        end
      else
        error_response("Invalid Request: hook `#{hook_name}` is not supported by this server.")
      end
    rescue StandardError => e
      error_response("Inferno failed to generate a response: #{e.message} at #{e.backtrace.first}", code: 500)
      nil
    end

    def hook_response
      if custom_response_template.present?
        build_custom_hook_response
      else
        build_mock_hook_response
      end
    rescue StandardError => e
      error_response("Inferno failed to generate a response: #{e.message} at #{e.backtrace.first}", code: 500)
      nil
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
        error_response('Invalid Request: Request did not contain a valid hook in the `hook` field.')
      end
    end

    def error_response(error_message, code: 400)
      response.status = code
      response.body = error_message
    end

    def name
      hook_name.gsub('-', '_')
    end
  end
end
