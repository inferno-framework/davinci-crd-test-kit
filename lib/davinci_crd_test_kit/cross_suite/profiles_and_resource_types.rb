module DaVinciCRDTestKit
  module ProfilesAndResourceTypes
    ORDER_RESOURCE_CLASSES = [
      FHIR::CommunicationRequest, FHIR::DeviceRequest, FHIR::MedicationRequest,
      FHIR::NutritionOrder, FHIR::ServiceRequest, FHIR::VisionPrescription
    ].freeze
    ORDER_OR_ENCOUNTER_RESOURCE_CLASSES = (ORDER_RESOURCE_CLASSES + [FHIR::Encounter]).freeze
    ORDER_RESOURCE_TYPES = ORDER_RESOURCE_CLASSES.map { |c| c.name.split('::').last }.freeze

    def structure_definition_map(ig_version)
      case ig_version
      when 'v221', '2.2.1'
        structure_definition_map_v221
      when 'v201', '2.0.1'
        structure_definition_map_v201
      end
    end

    def structure_definition_map_v201
      {
        'Practitioner' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-practitioner|2.0.1',
        'PractitionerRole' => 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-practitionerrole|3.1.1',
        'Patient' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-patient|2.0.1',
        'Encounter' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-encounter|2.0.1',
        'Appointment' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-appointment|2.0.1',
        'DeviceRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-devicerequest|2.0.1',
        'MedicationRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-medicationrequest|2.0.1',
        'NutritionOrder' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-nutritionorder|2.0.1',
        'ServiceRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-servicerequest|2.0.1',
        'VisionPrescription' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-visionprescription|2.0.1',
        'Medication' => 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medication|3.1.1',
        'Device' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-device|2.0.1',
        'CommunicationRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-communicationrequest|2.0.1',
        'Task' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-taskquestionnaire|2.0.1',
        'Coverage' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-coverage|2.0.1',
        'Location' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-location|2.0.1',
        'Organization' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-organization|2.0.1'
      }.freeze
    end

    def structure_definition_map_v221
      {
        'Practitioner' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-practitioner|2.2.1',
        'PractitionerRole' => 'http://hl7.org/fhir/us/davinci-hrex/StructureDefinition/hrex-practitionerrole|1.2.0',
        'Patient' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-patient|2.2.1',
        'Encounter' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-encounter|2.2.1',
        'Appointment' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-appointment-no-order|2.2.1',
        'DeviceRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-devicerequest|2.2.1',
        'MedicationRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-medicationrequest|2.2.1',
        'NutritionOrder' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-nutritionorder|2.2.1',
        'ServiceRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-servicerequest|2.2.1',
        'VisionPrescription' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-visionprescription|2.2.1',
        'Medication' => 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-medication|3.1.1',
        'Device' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-device|2.2.1',
        'CommunicationRequest' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-communicationrequest|2.2.1',
        'Task' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-taskquestionnaire|2.2.1',
        'Coverage' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-coverage|2.2.1',
        'Location' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-location|2.2.1',
        'Organization' => 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-organization|2.2.1'
      }.freeze
    end
  end
end
