require_relative '../client_hook_request_validation'

module DaVinciCRDTestKit
  class HookRequestValidPrefetchTest < Inferno::Test
    include ClientHookRequestValidation
    include URLs

    id :crd_hook_request_valid_prefetch
    title 'Hook contains valid prefetched data'
    description %(
      As stated in the [CDS hooks specification](https://cds-hooks.hl7.org/2.0#http-request), a CDS service request's
      `prefetch` field is an optional field that contains key/value pairs of FHIR queries that the service is requesting
      the CDS Client to perform and provide on each service call. The key is a string that describes the type of data
      being requested and the value is a string representing the FHIR query. See [Prefetch Template](https://cds-hooks.hl7.org/2.0#prefetch-template)
      for more information about how the `prefetch` formatting works.

      This test verifies that the incoming hook request's `prefetch` field is in a valid JSON format,
      validates each contained resource against its corresponding CRD resource profile, and checks
      that the data matches what is requested in by the
      [prefetch templates published by Inferno's simulated CRD Server](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/routes/cds-services.json).
      Since prefetch support is not required, this test will pass if `prefetch` is not present or has no entries.
    )
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@43', 'cds-hooks_2.0@47'

    input :contexts, :prefetches

    def hook_name
      config.options[:hook_name]
    end

    def cds_services_json
      JSON.parse(File.read(File.join(
                             __dir__, '..', 'routes', 'cds-services.json'
                           )))['services']
    end

    def advertised_prefetch_fields
      advertised_hook_service = cds_services_json.find { |service| service['hook'] == hook_name }
      advertised_hook_service['prefetch']
    end

    run do
      hook_contexts = json_parse(contexts)
      hook_prefetches = json_parse(prefetches)

      pass_if hook_prefetches.blank?, 'No prefetched data provided.'

      hook_prefetches.each_with_index do |prefetch, index|
        next if prefetch.blank?

        @request_number = index + 1
        context = hook_contexts[index].present? ? hook_contexts[index] : {}
        hook_request_prefetch_check(advertised_prefetch_fields, prefetch, context)
      end
      no_error_validation('Prefetch is not valid.')
    end
  end
end
