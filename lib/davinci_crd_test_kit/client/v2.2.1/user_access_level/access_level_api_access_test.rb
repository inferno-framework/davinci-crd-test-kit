require_relative '../../tagged_request_load_helper'
require_relative '../../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    # Behavior verification (ID-216 test 4): the tester-specified target resource must be readable
    # via the FHIR API for the full-access user and denied for the limited-access user.
    # Mechanically verifies cds-hooks_3.0.0-ballot@63, @64, @173.
    class AccessLevelApiAccessTest < Inferno::Test
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_access_level_api_access
      title 'FHIR API access to the target resource is scoped to the EHR user'
      description %(
        This test compares the FHIR reads that Inferno made, during hook processing, of the
        **Target Resource Reference** using the access token supplied in each of the full-access and
        limited-access hook requests. For this test to pass, the full-access read must succeed
        (HTTP 2xx) and return the expected resource, and the limited-access read must be denied with
        an HTTP status of exactly 401, 403, or 404.
      )

      verifies_requirements 'cds-hooks_3.0.0-ballot@63', 'cds-hooks_3.0.0-ballot@64',
                            'cds-hooks_3.0.0-ballot@173'

      input :access_level_target_reference,
            title: 'Target Resource Reference',
            locked: true

      VALID_DENIAL_STATUSES = [401, 403, 404].freeze

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

      run do
        full_hook_requests = load_tagged_requests(ACCESS_LEVEL_FULL_GROUP_TAG)
        limited_hook_requests = load_tagged_requests(ACCESS_LEVEL_LIMITED_GROUP_TAG)

        skip_if full_hook_requests.blank?,
                'No full-access hook request received - run the previous interaction tests first.'
        skip_if limited_hook_requests.blank?,
                'No limited-access hook request received - run the previous interaction tests first.'

        full_fetch = target_fetch_request(full_hook_requests)
        limited_fetch = target_fetch_request(limited_hook_requests)

        assert full_fetch.present?,
               "Inferno did not attempt to read `#{access_level_target_reference}` during the " \
               'full-access hook request.'
        assert limited_fetch.present?,
               "Inferno did not attempt to read `#{access_level_target_reference}` during the " \
               'limited-access hook request.'

        assert full_fetch.status.to_s.starts_with?('2'),
               "The full-access read of `#{access_level_target_reference}` failed with status " \
               "#{full_fetch.status}, but was expected to succeed."

        expected_type, expected_id = access_level_target_reference.split('/')
        full_resource = parse_fhir_resource(full_fetch.response_body)
        assert full_resource.present? && full_resource.resourceType == expected_type && full_resource.id == expected_id,
               "The full-access read of `#{access_level_target_reference}` succeeded, but did not " \
               'return the expected resource.'

        assert VALID_DENIAL_STATUSES.include?(limited_fetch.status.to_i),
               "The limited-access read of `#{access_level_target_reference}` returned status " \
               "#{limited_fetch.status}, but access should have been denied with one of " \
               "#{VALID_DENIAL_STATUSES.join(', ')}."
      end
    end
  end
end
