module DaVinciCRDTestKit
  # Text shared by the wait dialogs of tests that receive hook requests. Requires the `cds_jwt_iss` input,
  # and the payer Organization id inputs declared by `payer_organization_id_inputs` for the endpoint sections.
  module ClientWaitMessages
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Locked inputs set by the "Registration" group so that wait dialogs can show the payer associated
      # with each simulated CRD server.
      def payer_organization_id_inputs
        input :complete_prefetch_service_organization_id,
              title: 'Complete Prefetch Service Organization id',
              description: %(
                The FHIR Organization id associated with Inferno's simulated
                complete prefetch CRD server.
                Re-run the "Registration" group to provide this detail.
              ),
              type: 'text',
              optional: true,
              locked: true
        input :subset_prefetch_service_organization_id,
              title: 'Subset Prefetch Service Organization id',
              description: %(
                The FHIR Organization id associated with Inferno's simulated
                subset prefetch CRD server.
                Re-run the "Registration" group to provide this detail.
              ),
              type: 'text',
              optional: true,
              locked: true
      end
    end

    # A single line so that it can be interpolated into both indented `%()` messages and heredocs.
    def session_identification_message
      'For Inferno to recognize CRD requests made during this test and associate them with this session, ' \
        'the authentication JWT sent as a Bearer token in the Authorization header must have ' \
        "`#{cds_jwt_iss}` as the `iss` claim in the JWT payload."
    end

    def payer_organization_note(organization_id)
      return '' if organization_id.blank?

      " (associated with payer `Organization/#{organization_id}`)"
    end

    def complete_prefetch_payer_note
      payer_organization_note(complete_prefetch_service_organization_id)
    end

    def subset_prefetch_payer_note
      payer_organization_note(subset_prefetch_service_organization_id)
    end

    # For tests that accept requests for any hook. Multi-line, so only interpolate it into heredoc messages
    # whose lines are flush left.
    def service_discovery_endpoints_section
      <<~ENDPOINTS
        #### Service Discovery Endpoints

        - Complete Prefetch Services Discovery Endpoint#{complete_prefetch_payer_note}: `#{discovery_url}`
        - Subset Prefetch Services Discovery Endpoint#{subset_prefetch_payer_note}: `#{prefetch_subset_discovery_url}`
      ENDPOINTS
    end
  end
end
