require_relative '../server_urls'
require_relative '../../jobs/invoke_hook_no_special_requests'
require_relative '../../server_abstract_invoke_hook_test'

module DaVinciCRDTestKit
  module V221
    class InvokeHookSingleTest < ServerAbstractInvokeHookTest
      include ServerURLs

      title 'Inferno invokes the selected hook with the provided request body'
      id :crd_v221_server_invoke_hook_single_request_test

      def perform_invoke_hook_job(*)
        Inferno::Jobs.perform(DaVinciCRDTestKit::Jobs::InvokeHookNoSpecialRequests, *)
      end

      def check_request_length(payloads)
        skip_if payloads.length != 1, 'This test supports only one request body.'
      end
    end
  end
end
