require_relative '../mock_service_response'
require_relative '../tags'
module DaVinciCRDTestKit
  class HookRequestEndpoint < Inferno::DSL::SuiteEndpoint
    include DaVinciCRDTestKit::MockServiceResponse

    def selected_response_types
      inputs = JSON.parse(result.input_json)
      selected_response_types_input = inputs.detect { |input| input['name'].include?('selected_response_types') }
      selected_response_types_input['value']
    end

    def test_run_identifier
      extract_iss_claim_and_hook(request)
    end

    def extract_iss_claim_and_hook(request)
      hook = extract_hook_name(request).to_s
      iss = extract_iss_claim_from_token(request).to_s

      "#{hook} #{iss}"
    end

    def extract_iss_claim_from_token(request)
      token = extract_bearer_token(request)
      begin
        payload, = JWT.decode(token, nil, false)
        payload['iss']
      rescue JWT::DecodeError
        nil
      end
    end

    # Header expected to be a bearer token of the form "Bearer <token>"
    def extract_bearer_token(request)
      request.headers['authorization']&.delete_prefix('Bearer ')
    end

    def extract_hook_name(request)
      request.params[:hook]
    end

    def make_response
      hook_name = extract_hook_name(request)
      case hook_name
      when 'appointment-book'
        appointment_book_response(selected_response_types)
      when 'encounter-start'
        encounter_start_response(selected_response_types)
      when 'encounter-discharge'
        encounter_discharge_response(selected_response_types)
      when 'order-select'
        order_select_response(selected_response_types)
      when 'order-sign'
        order_sign_response(selected_response_types)
      when 'order-dispatch'
        order_dispatch_response(selected_response_types)
      else
        response.status = 400
        response.body = 'Invalid Request: Request did not contain a valid hook in the `hook` field.'
      end
    end

    def tags
      hook_name = extract_hook_name(request)
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
      extract_hook_name(request).gsub('-', '_')
    end

    def update_result
      results_repo.update(result.id, result: 'pass')
    end
  end
end
