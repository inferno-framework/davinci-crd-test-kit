module DaVinciCRDTestKit
  module CRDClientOptions
    SMART_1 = 'smart_app_launch_1'.freeze
    SMART_2 = 'smart_app_launch_2'.freeze

    SMART_1_REQUIREMENT = { smart_app_launch_version: SMART_1 }.freeze
    SMART_2_REQUIREMENT = { smart_app_launch_version: SMART_2 }.freeze

    US_CORE_3 = 'us_core_3'.freeze
    US_CORE_6 = 'us_core_6'.freeze
    US_CORE_7 = 'us_core_7'.freeze

    US_CORE_3_REQUIREMENT = { us_core_version: US_CORE_3 }.freeze
    US_CORE_6_REQUIREMENT = { us_core_version: US_CORE_6 }.freeze
    US_CORE_7_REQUIREMENT = { us_core_version: US_CORE_7 }.freeze

    US_CORE_3_RESOURCE_TYPES = %w[
      AllergyIntolerance CarePlan CareTeam Condition Device DiagnosticReport DocumentReference Encounter Goal
      Immunization Location Medication MedicationRequest Observation Organization Patient Practitioner
      PractitionerRole Procedure Provenance
    ].freeze

    US_CORE_6_7_RESOURCE_TYPES = %w[
      AllergyIntolerance CarePlan CareTeam Condition Coverage Device DiagnosticReport DocumentReference Encounter
      Goal Immunization Location Medication MedicationDispense MedicationRequest Observation Organization Patient
      Practitioner PractitionerRole Procedure Provenance QuestionnaireResponse RelatedPerson ServiceRequest
      Specimen
    ].freeze
  end
end
