require_relative '../mock_service_response'
require_relative '../custom_service_response'
require_relative '../tags'

module DaVinciCRDTestKit
  class HookRequestEndpoint < Inferno::DSL::SuiteEndpoint
    include DaVinciCRDTestKit::MockServiceResponse
    include DaVinciCRDTestKit::CustomServiceResponse

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
      case hook_name
      when 'appointment-book', 'encounter-start', 'encounter-discharge', 'order-select', 'order-sign', 'order-dispatch'
        response_body = hook_response
        if response_body.present?
          response.body = response_body.to_json
          response.headers.merge!({ 'Content-Type' => 'application/json', 'Access-Control-Allow-Origin' => '*' })
          response.status = 200
          response.format = :json
        end
      else
        error_response('Invalid Request: Request did not contain a valid hook in the `hook` field.')
      end
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

    def tags
      case hook_name
      when 'appointment-book'
        [APPOINTMENT_BOOK_TAG]
      when 'encounter-start'
        [ENCOUNTER_START_TAG]
      when 'encounter-discharge'
        [ENCOUNTER_DISCHARGE_TAG]
      when 'order-select'
        [ORDER_SELECT_TAG]
      when 'order-sign'
        [ORDER_SIGN_TAG]
      when 'order-dispatch'
        [ORDER_DISPATCH_TAG]
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
