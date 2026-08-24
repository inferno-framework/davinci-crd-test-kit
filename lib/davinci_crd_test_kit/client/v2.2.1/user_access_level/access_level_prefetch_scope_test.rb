require_relative '../../tagged_request_load_helper'
require_relative '../../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    # Behavior verification (ID-216 test 5): if the target resource is present in the full-access
    # run's prefetch, it must be absent from the limited-access run's prefetch. Otherwise, the
    # tester attests that prefetch scoping by user access level could not be demonstrated.
    # Mechanically/attestation-verifies cds-hooks_3.0.0-ballot@42.
    class AccessLevelPrefetchScopeTest < Inferno::Test
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_access_level_prefetch_scope
      title 'Prefetched data access is scoped to the EHR user'
      description %(
        This test compares the prefetch data included with the full-access and limited-access hook
        requests. If the **Target Resource Reference** is present in the full-access request's
        prefetch, it must be absent from the limited-access request's prefetch. If it is not present
        in the full-access request's prefetch, the tester attests whether prefetch data can be
        limited by the user's access level for resources of that kind.
      )
      attestation

      verifies_requirements 'cds-hooks_3.0.0-ballot@42'

      input :access_level_target_reference,
            title: 'Target Resource Reference',
            locked: true
      input :access_level_prefetch_attestation,
            title: "Health IT module limits prefetched data to the user's authorized access scope",
            description: %(
              The target resource was not present in the full-access request's prefetch, so this
              scenario could not directly demonstrate that prefetch data is scoped by user access. I
              attest that the Health IT module limits the data made available via prefetch to what
              the current user is authorized to access.
            ),
            type: 'radio',
            optional: true,
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }

      def prefetch_contains_reference?(request_body, reference)
        request_body['prefetch'].to_h.values.any? do |prefetched|
          next false unless prefetched.is_a?(Hash)

          if prefetched['resourceType'] == 'Bundle'
            prefetched['entry'].to_a.any? { |entry| entry_matches_reference?(entry['resource'], reference) }
          else
            entry_matches_reference?(prefetched, reference)
          end
        end
      end

      def entry_matches_reference?(resource, reference)
        resource.is_a?(Hash) && "#{resource['resourceType']}/#{resource['id']}" == reference
      end

      run do
        full_requests = load_tagged_requests(ACCESS_LEVEL_FULL_GROUP_TAG)
        limited_requests = load_tagged_requests(ACCESS_LEVEL_LIMITED_GROUP_TAG)

        skip_if full_requests.blank?,
                'No full-access hook request received - run the previous interaction tests first.'
        skip_if limited_requests.blank?,
                'No limited-access hook request received - run the previous interaction tests first.'

        full_body = JSON.parse(full_requests.first.request_body)
        limited_body = JSON.parse(limited_requests.first.request_body)

        if prefetch_contains_reference?(full_body, access_level_target_reference)
          assert !prefetch_contains_reference?(limited_body, access_level_target_reference),
                 "`#{access_level_target_reference}` is present in both the full-access and " \
                 'limited-access prefetch data, but was expected to be restricted for the ' \
                 'limited-access user.'
        else
          assert access_level_prefetch_attestation == 'true',
                 "`#{access_level_target_reference}` was not present in the full-access request's " \
                 'prefetch, so this scenario could not demonstrate that prefetch data is scoped by ' \
                 'user access.'
        end
      rescue JSON::ParserError => e
        assert false, "Unable to parse a hook request body as JSON: #{e.message}"
      end
    end
  end
end
