require_relative '../client_urls'
require_relative '../../tagged_request_load_helper'
require_relative '../../../cross_suite/tags'
require_relative 'access_level_target_reference'

module DaVinciCRDTestKit
  module V221
    # Used for both the full-access and limited-access interaction tests; each usage configures a
    # distinct `crd_interaction_group` tag (full vs limited) via `config`.
    class AccessLevelReceiveRequestTest < Inferno::Test
      include ClientURLs
      include DaVinciCRDTestKit::TaggedRequestLoadHelper
      include AccessLevelTargetReference

      id :crd_v221_access_level_receive_request
      title 'Client invokes a hook as an EHR user'
      description %(
        During this test, Inferno will wait while the client makes a single hook request of any type,
        made while the tester is signed in as the EHR user role configured for this test instance
        (full-access or limited-access). Both instances of this test should reference the same order,
        appointment, or encounter and the same patient.

        Inferno will use the access token in the request to attempt to read the **Target Resource
        Reference** and will return a [mocked](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
        coverage-information response. The details of the request and its response are not evaluated
        or checked for conformance in this test. The test will automatically continue once Inferno
        has received a single valid hook request.
      )

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            locked: true
      input :access_level_target_reference,
            title: 'Target Resource Reference',
            description: %(
              Relative reference (e.g. `Observation/123`) that Inferno will read using the access
              token supplied in the hook request. This resource is expected to be readable by the
              full-access user and denied to the limited-access user.
            )

      def limited_access_run?
        crd_interaction_group == ACCESS_LEVEL_LIMITED_GROUP_TAG
      end

      def access_level_role
        crd_interaction_group == ACCESS_LEVEL_FULL_GROUP_TAG ? 'full-access' : 'limited-access'
      end

      run do
        assert_target_reference_valid

        # the limited-access run is only meaningful alongside a successful full-access one, so don't
        # make the tester stage a second workflow that cannot be evaluated
        if limited_access_run?
          skip_if load_tagged_requests(ACCESS_LEVEL_FULL_GROUP_TAG).blank?,
                  'Full-access hook request was not successful. Check the response for details and re-try.'
        end

        identifier = cds_jwt_iss
        wait(
          identifier:,
          message: %(
            **Invoke a hook as a #{access_level_role} user**:

            Invoke any supported hook, while signed in as a **#{access_level_role}** user, on one of
            the two Inferno simulated CRD servers discoverable at the following endpoints:

            - Complete Prefetch: `#{discovery_url}`
            - Subset Prefetch: `#{prefetch_subset_discovery_url}`

            For Inferno to recognize these requests and associate them with this session,
            the authentication JWT sent as a Bearer token in the Authorization header
            must have `#{cds_jwt_iss}` as the `iss` claim in the JWT payload. The test
            will automatically continue once Inferno has received a request and returned
            a response.

            Invoke the hook for the same order, appointment, or encounter used for the other user
            role in this scenario. Inferno will use the access token in the request to attempt to
            read `#{access_level_target_reference}` and will return a mocked coverage-information
            response.
          )
        )
      end
    end
  end
end
