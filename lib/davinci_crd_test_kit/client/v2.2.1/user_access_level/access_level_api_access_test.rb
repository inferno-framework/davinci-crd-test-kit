require_relative '../../tagged_request_load_helper'
require_relative '../../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    class AccessLevelApiAccessTest < Inferno::Test
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_access_level_api_access
      title 'FHIR API access to the target resource is scoped to the EHR user'
      description %(
        This test compares the FHIR reads that Inferno made, during hook processing, of the
        **Target Resource Reference** using the access token supplied in each of the full-access and
        limited-access hook requests. For this test to pass, the full-access read must return the
        target resource and the limited-access read must not. The manner in which the limited-access
        read is denied is not checked, as the specification does not require a particular approach.
      )

      verifies_requirements 'cds-hooks_3.0.0-ballot@63', 'cds-hooks_3.0.0-ballot@64',
                            'cds-hooks_3.0.0-ballot@173'

      input :access_level_target_reference,
            title: 'Target Resource Reference',
            locked: true

      def target_fetch_request(hook_requests)
        hook_instance = JSON.parse(hook_requests.first.request_body)['hookInstance']
        load_tagged_requests(TagMethods.hook_instance_data_fetch_tag(hook_instance), ACCESS_LEVEL_TARGET_FETCH_TAG)
          .first
      rescue JSON::ParserError
        nil
      end

      def parse_fhir_resource(body)
        FHIR.from_contents(body)
      rescue StandardError
        nil
      end

      def target_resource_returned?(fetch_request)
        expected_type, expected_id = access_level_target_reference.split('/')
        resource = parse_fhir_resource(fetch_request.response_body)

        resource.present? && resource.resourceType == expected_type && resource.id == expected_id
      end

      run do
        full_hook_requests = load_tagged_requests(ACCESS_LEVEL_FULL_GROUP_TAG)
        limited_hook_requests = load_tagged_requests(ACCESS_LEVEL_LIMITED_GROUP_TAG)

        skip_if full_hook_requests.blank?,
                'Full-access hook request was not successful. Check the response for details and re-try.'
        skip_if limited_hook_requests.blank?,
                'Limited-access hook request was not successful. Check the response for details and re-try.'

        full_fetch = target_fetch_request(full_hook_requests)
        limited_fetch = target_fetch_request(limited_hook_requests)

        # request_access_level_target is called unconditionally while processing these hook requests, so a
        # missing fetch here means Inferno itself failed to make it, not a tester-controlled condition.
        if full_fetch.blank?
          raise Inferno::Exceptions::TestSuiteImplementationException.new(
            'FHIR request',
            "Expected FHIR read of `#{access_level_target_reference}` not performed during the full-access " \
            'hook request.'
          )
        end

        if limited_fetch.blank?
          raise Inferno::Exceptions::TestSuiteImplementationException.new(
            'FHIR request',
            "Expected FHIR read of `#{access_level_target_reference}` not performed during the " \
            'limited-access hook request.'
          )
        end

        unless target_resource_returned?(full_fetch)
          add_message('error',
                      "The full-access read of `#{access_level_target_reference}` did not return that " \
                      "resource (HTTP #{full_fetch.status}), but the full-access user is expected to be " \
                      'able to read it.')
        end

        if target_resource_returned?(limited_fetch)
          add_message('error',
                      "The limited-access read of `#{access_level_target_reference}` returned that " \
                      "resource (HTTP #{limited_fetch.status}), but access is expected to be denied for " \
                      'the limited-access user.')
        end

        assert_no_error_messages("Access to `#{access_level_target_reference}` was not correctly scoped to " \
                                 'the EHR user. See Messages for details.')
      end
    end
  end
end
