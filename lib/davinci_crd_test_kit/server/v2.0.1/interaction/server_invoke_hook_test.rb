require_relative '../server_urls'
require_relative '../../server_abstract_invoke_hook_test'

module DaVinciCRDTestKit
  module V201
    class ServerInvokeHookTest < ServerAbstractInvokeHookTest
      include ServerURLs

      id :crd_v201_server_invoke_hook_test
    end
  end
end
