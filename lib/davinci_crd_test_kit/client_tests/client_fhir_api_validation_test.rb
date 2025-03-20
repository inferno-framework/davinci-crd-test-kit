module DaVinciCRDTestKit
  class ClientFHIRApiValidationTest < Inferno::Test
    id :crd_client_fhir_api_validation_test
    title 'FHIR Resource Validation'
    description %(
        Verify that the given resources returned from the previous client API interactions are valid resources. Each
        resource is validated against its corresponding [CRD resource profile](https://hl7.org/fhir/us/davinci-crd/STU2/artifacts.html).
      )

    def resource_type
      config.options[:resource_type]
    end

    def structure_definition_map
      {
        'Practitioner' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-practitioner',
        'PractitionerRole' => 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitionerrole',
        'Patient' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-patient',
        'Encounter' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-encounter',
        'Coverage' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-coverage',
        'Device' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-device',
        'Location' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-location',
        'Organization' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-organization'
      }.freeze
    end

    def profile_url
      structure_definition_map[resource_type]
    end

    run do
      load_tagged_requests(resource_type)
      skip_if requests.empty?, 'No FHIR api requests were made'

      requests.keep_if { |req| req.status == 200 }
      skip_if(requests.blank?,
              'There were no successful FHIR API requests made in previous tests to use in validation.')

      validated_resources =
        requests
          .map(&:resource)
          .compact
          .flat_map { |resource| resource.is_a?(FHIR::Bundle) ? resource.entry.map(&:resource) : resource }
          .select { |resource| resource.resourceType == resource_type }
          .uniq { |resource| resource.to_reference.reference }
          .each { |resource| resource_is_valid?(resource:, profile_url:) }

      skip_if(validated_resources.blank?,
              %(No #{resource_type} resources were returned from any of the FHIR API requests made in previous tests
              that could be validated.))

      validation_error_count = messages.count { |msg| msg[:type] == 'error' }
      assert(validation_error_count.zero?,
             %(#{validation_error_count}/#{validated_resources.length} #{resource_type} resources returned from previous
             test's FHIR API requests failed validation.))

      skip_if validated_resources.blank?, 'No FHIR resources were made in previous tests that could be validated.'
    end
  end
end
