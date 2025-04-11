require_relative '../client_hook_request_validation'

module DaVinciCRDTestKit
  class HookRequestValidContextTest < Inferno::Test
    include URLs
    include ClientHookRequestValidation

    id :crd_hook_request_valid_context
    title 'Hook contains valid context'
    description %(
      As stated in the [CDS hooks specification](https://cds-hooks.hl7.org/2.0#http-request), a CDS service request's
      `context` field contains hook-specific contextual data that the CDS service will need. The context is specified
      in the hook definition to guide developers on the information available at the point in the workflow when the hook
      is triggered.

      The `context` requirements for each [hook specified in the CRD IG](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html)
      can be found below:
      * [appointment-book](https://cds-hooks.hl7.org/hooks/appointment-book/2023SepSTU1Ballot/appointment-book/)
      * [encounter-start](https://cds-hooks.hl7.org/hooks/encounter-start/2023SepSTU1Ballot/encounter-start/)
      * [encounter-discharge](https://cds-hooks.hl7.org/hooks/encounter-discharge/2023SepSTU1Ballot/encounter-discharge/)
      * [order-select](https://cds-hooks.hl7.org/hooks/order-select/2023SepSTU1Ballot/order-select/)
      * [order-dispatch](https://cds-hooks.hl7.org/hooks/order-dispatch/2023SepSTU1Ballot/order-dispatch/)
      * [order-sign](https://cds-hooks.org/hooks/order-sign/)

      This test performs the following:
        * Verifies that the incoming hook request's `context` field contains the fields required by each hook and
        that they are in the correct format
        * Checks the optional fields and ensures they are in the correct format
        * Validates any resources contained in a `context` field that contains a Bundle or FHIR resource
        * Makes FHIR requests for any `context` fields that contain an id or reference and validates each resource
        response against its corresponding CRD resource profile
        * Check some specific `context` requirements for hooks that have special requirements for certain fields

      The client must provide its FHIR server URL and access token in the hook request in order to run
      this test.
    )
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@254'

    input :contexts, :client_fhir_server
    input :client_access_token,
          optional: true

    fhir_client do
      url :client_fhir_server
      bearer_token :client_access_token
    end

    def hook_name
      config.options[:hook_name]
    end

    run do
      hook_contexts = json_parse(contexts)
      if hook_contexts
        skip_if(hook_contexts.none?(&:present?), "No #{hook_name} requests contained the `context` field.")
        hook_contexts.each_with_index do |context, index|
          @request_number = index + 1
          if context.blank?
            add_message('error', "#{request_number}Missing required context field.")
            next
          end
          hook_request_context_check(context, hook_name)
        end
      end
      no_error_validation('Context is not valid.')
    end
  end
end
