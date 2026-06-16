require_relative 'invoke_hook_no_special_requests'

module DaVinciCRDTestKit
  module Jobs
    class InvokeHookWithBadAuth < InvokeHookNoSpecialRequests
      def prepare_hook_request(parsed_request)
        super

        parsed_request['fhirAuthorization']['access_token'] = 'TRIGGER_500_STATUS'
        parsed_request
      end
    end
  end
end
