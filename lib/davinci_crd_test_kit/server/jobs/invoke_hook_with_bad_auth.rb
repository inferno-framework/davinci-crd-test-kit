require_relative 'invoke_hook'

module DaVinciCRDTestKit
  module Jobs
    class InvokeHookWithBadAuth < InvokeHook
      def perform(*)
        # Skip all of the special hook invocations
        @coverage_info_configuration_invoked = true
        @unknown_configuration_invoked = true
        @unknown_context_invoked = true
        @unknown_cds_hooks_element_invoked = true

        super
      end

      def prepare_hook_request(parsed_request)
        super

        parsed_request['fhirAuthorization']['access_token'] = 'TRIGGER_500_STATUS'
        parsed_request
      end
    end
  end
end
