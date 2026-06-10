require_relative '../server_urls'
require_relative '../../jobs/invoke_hook_with_bad_auth'
require_relative '../../server_abstract_invoke_hook_test'

module DaVinciCRDTestKit
  module V221
    class TechnicalIssuesInvokeHookTest < ServerAbstractInvokeHookTest
      include ServerURLs

      title 'Inferno invokes the selected hook with invalid authorization'
      id :crd_v221_server_technical_issues_invoke_hook_test

      def perform_invoke_hook_job(*)
        Inferno::Jobs.perform(DaVinciCRDTestKit::Jobs::InvokeHookWithBadAuth, *)
      end

      def check_request_length(payloads)
        skip_if payloads.length != 1, 'The *Technical Issues* test supports only one request body.'
      end
    end
  end
end
