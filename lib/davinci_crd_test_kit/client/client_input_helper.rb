module DaVinciCRDTestKit
  # Descriptions and options shared by the declarations of client suite inputs.
  module ClientInputHelper
    COVERAGE_INFORMATION_LINK =
      '[Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)'
        .freeze
    INSTRUCTIONS_LINK =
      '[Instructions](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#instructions-response-type)'.freeze
    MOCKED_RESPONSES_LINK =
      '[mock](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)'
        .freeze
    CUSTOM_RESPONSES_LINK =
      '[custom response template](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/' \
      'Controlling-Simulated-Responses#tester-directed-custom-responses)'.freeze

    # For optional inputs that the suite can execute without but that are needed for the tests to pass.
    def self.required_to_pass_note
      'The client suite may be run without this input, but it is required for the tests to pass.'
    end

    # For locked inputs that are set by the v2.2.1 "Registration" group.
    def self.rerun_registration_note
      'Re-run the "Registration" group to provide this detail.'
    end

    def self.locked_cds_jwt_iss_description
      'Value of the `iss` claim that must be present in the JWT used to authorize the CRD client\'s hook ' \
        'request sent as the Bearer token in the `Authorization` header. ' \
        'Run or re-run the "Registration" group to set or change this value.'
    end

    def self.v201_locked_cds_jwt_iss_description
      'Value of the `iss` claim that must be sent on the Bearer token in the `Authorization` ' \
        'header of all requests. Run or re-run the **Client Registration** group to set or change this value.'
    end

    def self.registration_cds_jwk_set_description
      "The CRD client's JWK Set containing its public key. May be either a publicly accessible URL " \
        "containing the JWKS, or the raw JWKS. #{required_to_pass_note}"
    end

    # @param server [String] 'complete' or 'subset'
    def self.service_organization_id_intro(server)
      "The FHIR Organization id associated with Inferno's simulated #{server} prefetch CRD server."
    end

    # @param server [String] 'complete' or 'subset'
    # @param discovery_url [String] discovery endpoint of the simulated server
    # @param locked [Boolean] whether the input is locked, so must be set by re-running registration
    def self.service_organization_id_description(server, discovery_url, locked: false)
      description =
        "#{service_organization_id_intro(server)} This Organization must be referenced as the payer on Coverages " \
        "in hook requests made to services described by the `#{discovery_url}` discovery endpoint. " \
        "#{required_to_pass_note}"
      locked ? "#{description} #{rerun_registration_note}" : description
    end

    # @param hooks [String] hook name, e.g. 'order-sign', or 'all' for every hook
    def self.response_approach_description(hooks)
      "Determines how Inferno will generate responses for #{hooks} hook invocations."
    end

    def self.response_approach_options
      {
        list_options: [
          {
            label: 'Create simple mocks based on selected response types',
            value: 'mocked'
          },
          {
            label: 'Generate responses based on a tester-provided template',
            value: 'custom'
          }
        ]
      }
    end

    def self.mocked_response_types_intro
      "Select the CRD response types that the simulated Inferno CRD server will #{MOCKED_RESPONSES_LINK} " \
        'when responding to hook invocations.'
    end

    def self.coverage_information_always_included_note
      "Because CRD clients must support the #{COVERAGE_INFORMATION_LINK} response type on this primary hook, " \
        'Inferno will always include a Coverage Information response, even if it is not selected.'
    end

    def self.default_response_type_note(primary:)
      if primary
        "If no types are selected, Inferno will mock and return a #{COVERAGE_INFORMATION_LINK} " \
          'response for this primary hook.'
      else
        "If no types are selected, Inferno will mock and return an #{INSTRUCTIONS_LINK} " \
          'response for this secondary hook.'
      end
    end

    def self.custom_response_template_description
      "Provide a #{CUSTOM_RESPONSES_LINK} in JSON form for Inferno to use when responding to hook invocations."
    end
  end
end
