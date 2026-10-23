module DaVinciCRDTestKit
  # Text shared by the wait dialogs of tests that receive hook requests. Requires the `cds_jwt_iss` input.
  module ClientWaitMessages
    # A single line so that it can be interpolated into both indented `%()` messages and heredocs.
    def session_identification_message
      'For Inferno to recognize CRD requests made during this test and associate them with this session, ' \
        'the authentication JWT sent as a Bearer token in the Authorization header must have ' \
        "`#{cds_jwt_iss}` as the `iss` claim in the JWT payload."
    end

    # For tests that accept requests for any hook. Multi-line, so only interpolate it into heredoc messages
    # whose lines are flush left.
    def service_discovery_endpoints_section
      <<~ENDPOINTS
        #### Service Discovery Endpoints

        - Complete Prefetch Services Discovery Endpoint: `#{discovery_url}`
        - Subset Prefetch Services Discovery Endpoint: `#{prefetch_subset_discovery_url}`
      ENDPOINTS
    end
  end
end
