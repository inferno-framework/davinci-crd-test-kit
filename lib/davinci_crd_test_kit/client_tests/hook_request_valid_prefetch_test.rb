require_relative '../urls'

module DaVinciCRDTestKit
  class HookRequestValidPrefetchTest < Inferno::Test
    include DaVinciCRDTestKit::ClientHookRequestValidation
    include URLs

    id :crd_hook_request_valid_prefetch
    title 'Hook contains valid prefetch response'
    description %(
      As stated in the [CDS hooks specification](https://cds-hooks.hl7.org/2.0#http-request), a CDS service request's
      `prefetch` field is an optional field that contains key/value pairs of FHIR queries that the service is requesting
      the CDS Client to perform and provide on each service call. The key is a string that describes the type of data
      being requested and the value is a string representing the FHIR query. See [Prefetch Template](https://cds-hooks.hl7.org/2.0#prefetch-template)
      for more information about how the `prefetch` formatting works.

      This test verifies that the incoming hook request's `prefetch` field is in a valid JSON format and validates each
      contained resource against its corresponding CRD resource profile. This test is optional and will be skipped if no
      `prefetch` field is contained in the hook request.
    )
    optional

    input :contexts_prefetches

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
      assert_valid_json(contexts_prefetches)
      hook_contexts_prefetches = JSON.parse(contexts_prefetches)
      skip_if(hook_contexts_prefetches.none? do |context_prefetch|
                context_prefetch['prefetch'].present? && context_prefetch['context'].present?
              end,
              "No #{hook_name} requests contained both the `context` and `prefetch` field.")
      error_messages = []
      hook_contexts_prefetches.each_with_index do |context_prefetch, index|
        received_prefetch = context_prefetch['prefetch']
        received_context = context_prefetch['context']

        info do
          assert received_prefetch.present?, "Received hook request #{index + 1} does not contain the `prefetch` field."
          assert received_context.present?, %(Received hook request  #{index + 1} does not contain the `context` field
          which is needed to validate the `prefetch` field)
        end

        next if received_prefetch.blank? || received_context.blank?

        hook_request_prefetch_check(advertised_prefetch_fields, received_prefetch, received_context)
        no_error_validation('Prefetch is not valid.')
      rescue Inferno::Exceptions::AssertionException => e
        error_messages << "Request #{index + 1}: #{e.message}"
      end

      error_messages.each do |msg|
        messages << { type: 'error', message: msg }
      end
      assert error_messages.empty?, 'Prefetch is not valid.'
    end
  end
end
