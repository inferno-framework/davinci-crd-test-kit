require_relative 'invoke_hook'

module DaVinciCRDTestKit
  module Jobs
    class InvokeHookNoSpecialRequests < InvokeHook
      def perform(*)
        # Skip all of the special hook invocations.
        @coverage_info_configuration_invoked = true
        @unknown_configuration_invoked = true
        @unknown_context_invoked = true
        @unknown_cds_hooks_element_invoked = true

        super
      end
    end
  end
end
