require_relative '../server_urls'
require_relative '../../server_abstract_invoke_hook_test'

module DaVinciCRDTestKit
  module V221
    class ServerInvokeHookTest < ServerAbstractInvokeHookTest
      include ServerURLs

      title 'Inferno invokes the selected hook'
      id :crd_v221_server_invoke_hook_test

      def coverage_info_configuration_supported?
        true
      end
    end
  end
end
