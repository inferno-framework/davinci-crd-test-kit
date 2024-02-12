require_relative '../urls'

module DaVinciCRDTestKit
  class HookRequestValidPrefetchTest < Inferno::Test
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

    uses_request :hook_request

    def hook_name
      config.options[:hook_name]
    end

    def cds_services_json
      JSON.parse(File.read(File.join(
                             __dir__, '..', 'routes', 'cds-services.json'
                           )))['services']
    end

    def structure_definition_map
      {
        'Practitioner' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-practitioner',
        'PractitionerRole' => 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitionerrole',
        'Patient' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-patient',
        'Coverage' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-coverage',
        'RelatedPerson' => 'http://hl7.org/fhir/StructureDefinition/RelatedPerson',
        'Encounter' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-encounter',
        'DeviceRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-devicerequest',
        'MedicationRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-medicationrequest',
        'NutritionOrder' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-nutritionorder',
        'ServiceRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-servicerequest',
        'VisionPrescription' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-visionprescription'
      }
    end

    def validate_prefetch_coverage(received_resource, advertised_prefetch_key,
                                   received_context_patient_id, advertised_status)
      assert_resource_type('Bundle', resource: received_resource)
      assert(received_resource.entry.any?, 'Bundle of coverage resources received from prefetch is empty')
      coverage_resource = received_resource.entry.first.resource
      assert_resource_type('Coverage', resource: coverage_resource)
      assert_valid_resource(resource: coverage_resource,
                            profile_url: structure_definition_map['Coverage'])

      coverage_beneficiary_reference = coverage_resource.beneficiary
      coverage_beneficiary_patient_id = coverage_beneficiary_reference.reference_id
      assert(coverage_beneficiary_patient_id.present?,
             "Could not get beneficiary reference id from `#{advertised_prefetch_key}` field's Coverage resource")

      assert(coverage_beneficiary_patient_id == received_context_patient_id,
             %(Expected `#{advertised_prefetch_key}` field's Coverage resource to have a `beneficiary` reference id of
             '#{received_context_patient_id}', instead was '#{coverage_beneficiary_patient_id}'))

      coverage_status = coverage_resource.status
      assert(coverage_status == advertised_status,
             %(Expected `#{advertised_prefetch_key}` field's Coverage resource to have a `status` of
             '#{advertised_status}', instead was '#{coverage_status}'))
    end

    def validate_prefetch_resource(received_resource, advertised_prefetch_key, context_field_resource_type,
                                   context_field_id)
      assert_resource_type(context_field_resource_type, resource: received_resource)

      if hook_name == 'order-dispatch'
        assert_valid_resource(resource: received_resource)
      else
        assert_valid_resource(resource: received_resource,
                              profile_url: structure_definition_map[context_field_resource_type])
      end

      received_prefetch_resource_id = received_resource.id
      assert(received_prefetch_resource_id.present?,
             "`#{advertised_prefetch_key}` field's FHIR resource does not contain the `id` field")
      assert(received_prefetch_resource_id == context_field_id,
             %(Expected `#{advertised_prefetch_key}` field's FHIR resource to have an `id` of '#{context_field_id}',
             instead was '#{received_prefetch_resource_id}'))
    end

    run do
      assert_valid_json(request.request_body)
      request_body = JSON.parse(request.request_body)

      received_prefetch = request_body['prefetch']
      received_context = request_body['context']

      skip_if received_prefetch.blank?, 'Received hook request does not contain the `prefetch` field.'
      skip_if received_context.blank?,
              %(Received hook request does not contain the `context` field which is needed to validate the `prefetch`
              field)

      advertised_hook_service = cds_services_json.find { |service| service['hook'] == hook_name }

      advertised_prefetch_fields = advertised_hook_service['prefetch']

      advertised_prefetch_fields.each do |advertised_prefetch_key, advertised_prefetch_template|
        next unless received_prefetch[advertised_prefetch_key].present?

        assert(received_prefetch[advertised_prefetch_key].is_a?(Hash),
               "Prefetch field `#{advertised_prefetch_key}` is not of type `Hash`.")

        received_prefetch_resource = FHIR.from_contents(received_prefetch[advertised_prefetch_key].to_json)

        if advertised_prefetch_template.include?('?')
          advertised_prefetch_fhir_search = advertised_prefetch_template.gsub(/{|}/, '').split('?')
          advertised_prefetch_resource_type = advertised_prefetch_fhir_search.first

          if advertised_prefetch_resource_type == 'Coverage'
            advertised_coverage_query_params = Rack::Utils.parse_nested_query(advertised_prefetch_fhir_search.last)

            advertised_patient_token = advertised_coverage_query_params['patient']
            advertised_context_patient_id_key = advertised_patient_token.split('.').last
            received_context_patient_id = received_context[advertised_context_patient_id_key]

            advertised_status_param = advertised_coverage_query_params['status']

            validate_prefetch_coverage(received_prefetch_resource, advertised_prefetch_key, received_context_patient_id,
                                       advertised_status_param)
          end
        else
          advertised_prefetch_token = advertised_prefetch_template.gsub(/{|}/, '').split('/')
          advertised_context_id = advertised_prefetch_token.last.split('.').last

          if advertised_prefetch_token.length == 1
            received_context_reference = FHIR::Reference.new(reference: received_context[advertised_context_id])
            received_context_resource_type = received_context_reference.resource_type
            received_context_id = received_context_reference.reference_id
          else
            received_context_id = received_context[advertised_context_id]
            received_context_resource_type = advertised_prefetch_token.first
          end
          validate_prefetch_resource(received_prefetch_resource, advertised_prefetch_key,
                                     received_context_resource_type, received_context_id)
        end
      end
    end
  end
end
