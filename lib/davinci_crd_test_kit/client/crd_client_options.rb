require_relative '../cross_suite/profiles_and_resource_types'

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

    ACCESS_TOKEN_SCOPES_WIKI_URL =
      'https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#access-token-scopes'.freeze

    # Request resource types that CRD clients send in hook requests and that Inferno may read
    # when they are the target of a Coverage Information response.
    CRD_REQUEST_RESOURCE_TYPES = (['Appointment'] + ProfilesAndResourceTypes::ORDER_RESOURCE_TYPES).freeze

    def self.us_core_resource_types(us_core_version)
      case us_core_version
      when US_CORE_3
        US_CORE_3_RESOURCE_TYPES
      when US_CORE_6, US_CORE_7
        US_CORE_6_7_RESOURCE_TYPES
      else
        []
      end
    end

    # Resource types that the CRD client may, but need not, grant access to in the hook request
    # access token: the CRD request types and, for US Core 3.1.1, Coverage.
    def self.optional_scope_resource_types(us_core_version)
      optional_types = CRD_REQUEST_RESOURCE_TYPES
      optional_types += ['Coverage'] if us_core_version == US_CORE_3
      optional_types - us_core_resource_types(us_core_version)
    end
  end
end
