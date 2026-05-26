require_relative '../../tagged_request_load_helper'
require_relative '../../multi_request_message_helper'
require_relative '../../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    class ClientHookInstancesUniqueTest < Inferno::Test
      include TaggedRequestLoadHelper
      include MultiRequestMessageHelper

      title 'Client does not reuse hookInstance values'
      id :crd_v221_client_hook_instances_unique
      description <<~DESCRIPTION
        The CDS Hooks specification requires that the `hookInstance` field of each hook
        request be globally unique so that it can be used for tracking
        and auditing.

        During this test, Inferno will check that across all hook invocations performed during these
        tests, the `hookInstance` field was never reused.
      DESCRIPTION

      verifies_requirements 'cds-hooks_3.0.0-ballot@25'

      config(
        options: {
          crd_test_group: DUPLICATED_HOOK_INSTANCE_TAG
        }
      )

      run do
        duplicated_hook_instance_requests = load_hook_requests
        reused_values = duplicated_hook_instance_requests.map.with_index do |request, request_index|
          request_body = parse_json_request_entity(request.request_body, 'Request body', request_index)
          next nil unless request_body.present?

          request_body['hookInstance']
        end.compact.uniq
        reused_values.each { |hook_instance| load_tagged_requests(TagMethods.hook_instance_tag(hook_instance)) }

        assert duplicated_hook_instance_requests.blank?,
               "Inferno received hook requests that re-used `hookInstance` values: #{reused_values.join(', ')}"
      end
    end
  end
end
