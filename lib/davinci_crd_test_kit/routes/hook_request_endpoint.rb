require_relative '../gather_response_generation_data'
require_relative '../mock_service_response'
require_relative '../tags'
module DaVinciCRDTestKit
  class HookRequestEndpoint < Inferno::DSL::SuiteEndpoint
    include DaVinciCRDTestKit::MockServiceResponse
    include DaVinciCRDTestKit::GatherResponseGenerationData

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
      case hook_name
      when 'appointment-book', 'encounter-start', 'encounter-discharge', 'order-select', 'order-sign', 'order-dispatch'
        send(:"gather_#{hook_name.gsub('-', '_')}_data")
        request_coverage
        hook_response
      else
        response.status = 400
        response.body = 'Invalid Request: Request did not contain a valid hook in the `hook` field.'
      end
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
        response.status = 400
        response.body = 'Invalid Request: Request did not contain a valid hook in the `hook` field.'
      end
    end

    def name
      hook_name.gsub('-', '_')
    end
  end
end
