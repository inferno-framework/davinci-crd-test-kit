# Resources populating every must support element of their CRD profile, used to check that a fully
# demonstrated client passes without an attestation. Each was built against the generated metadata,
# so a profile gaining a must support element fails the coverage spec until its resource is updated.
module DaVinciCRDTestKit
  module CompleteResources
    ADDRESS = { type: 'physical', line: ['1 Main St'], city: 'Boston', state: 'MA',
                postalCode: '02101', country: 'US' }.freeze
    NPI = { type: { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/v2-0203', code: 'NPI' }] },
            system: 'http://hl7.org/fhir/sid/us-npi', value: '1234567893' }.freeze
    TIN = { type: { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/v2-0203', code: 'TAX' }] },
            system: 'urn:oid:2.16.840.1.113883.4.4', value: '12-3456789' }.freeze
    CONTAINED_CONDITION = { resourceType: 'Condition', id: 'cond1',
                            subject: { reference: 'Patient/p1' } }.freeze
    X12_SERVICE_TYPE_SYSTEM = 'https://codesystem.x12.org/005010/1365'.freeze
    # Every must support element of the CRD Timing profile.
    FULL_TIMING = {
      event: ['2026-01-01T00:00:00Z'],
      repeat: { boundsPeriod: { start: '2026-01-01', end: '2026-02-01' }, count: 3, duration: 30,
                durationUnit: 'min', frequency: 2, period: 1, periodUnit: 'd' }
    }.freeze
    CATEGORY_CODINGS = [
      { coding: [{ system: X12_SERVICE_TYPE_SYSTEM, code: '1' }] },
      { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode', code: 'AMB' }] },
      { coding: [{ system: 'http://snomed.info/sct', code: '108252007' }] }
    ].freeze

    COVERAGE_INFORMATION =
      { url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information',
        extension: [{ url: 'coverage', valueReference: { reference: 'Coverage/c1' } }] }.freeze
    BILLING_OPTIONS =
      { url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-billing-options',
        valueCodeableConcept: { coding: [{ code: 'x' }] } }.freeze
    # Both the EncounterCategory and ServiceCategory slices carry this url.
    REQUEST_CATEGORY =
      { url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-request-category',
        valueCodeableConcept: { coding: [{ code: 'rc' }] } }.freeze

    SERVICE_REQUEST = {
      resourceType: 'ServiceRequest', id: 'sr1', status: 'draft', intent: 'order',
      subject: { reference: 'Patient/p1' },
      identifier: [{ system: 'http://example.org', value: 'sr-1' }],
      doNotPerform: false,
      # Inherited from US Core, which the snapshot scope brings into the must support set.
      authoredOn: '2026-01-01T00:00:00Z',
      encounter: { reference: 'Encounter/e1' },
      requester: { reference: 'Practitioner/pr1' },
      occurrencePeriod: { start: '2026-01-01T00:00:00Z' },
      occurrenceTiming: FULL_TIMING,
      category: CATEGORY_CODINGS,
      basedOn: [{ reference: 'ServiceRequest/sr0' }],
      contained: [{ resourceType: 'Practitioner', id: 'pr1' }],
      quantityQuantity: { value: 1 },
      reasonReference: [{ reference: 'Condition/c1' }],
      locationReference: [{ reference: 'Location/l1' }],
      performer: [{ reference: 'Practitioner/pr1' }],
      extension: [COVERAGE_INFORMATION],
      code: { coding: [{ system: 'http://snomed.info/sct', code: '1234' }],
              extension: [BILLING_OPTIONS] },
      performerType: { coding: [{ system: 'http://nucc.org/provider-taxonomy', code: '207Q00000X' }],
                       extension: [{ url: 'http://hl7.org/fhir/StructureDefinition/codeOptions',
                                     valueCodeableConcept: { coding: [{ code: 'y' }] } }] },
      locationCode: [
        { coding: [{ system: 'https://www.cms.gov/Medicare/Coding/place-of-service-codes/' \
                             'Place_of_Service_Code_Set',
                     code: '11' }] },
        { coding: [{ system: 'https://www.nubc.org/CodeSystem/TypeOfBill', code: '0111' }] },
        # A non-individual NUCC taxonomy code; the slice matches on system alone.
        { coding: [{ system: 'http://nucc.org/provider-taxonomy', code: '282N00000X' }] }
      ],
      reasonCode: [{ coding: [{ system: 'http://hl7.org/fhir/sid/icd-10-cm', code: 'A00' }] }]
    }.freeze

    # Covers both Appointment profiles, which are checked as one merged set. The two participants
    # are each required by a slice: one carrying the PPRF code, one referencing a Patient.
    APPOINTMENT = {
      resourceType: 'Appointment', id: 'a1', status: 'booked',
      identifier: [{ system: 'http://example.org/appt', value: 'a-1' }],
      serviceCategory: CATEGORY_CODINGS,
      serviceType: [{ coding: [{ code: 'st' }], extension: [BILLING_OPTIONS] }],
      specialty: [{ coding: [{ system: 'http://nucc.org/provider-taxonomy', code: '207Q00000X' }] }],
      appointmentType: { coding: [{ code: 'ROUTINE' }] },
      reasonReference: [{ reference: 'Condition/cond1' }],
      start: '2026-01-01T09:00:00Z', end: '2026-01-01T09:30:00Z',
      requestedPeriod: [{ start: '2026-01-01T09:00:00Z' }],
      basedOn: [{ reference: 'ServiceRequest/sr1',
                  extension: [{ url: 'http://hl7.org/fhir/StructureDefinition/alternate-reference',
                                valueReference: { reference: 'ServiceRequest/sr2' } }] }],
      participant: [
        { type: [{ coding: [{ system: 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType',
                              code: 'PPRF' }] }],
          actor: { reference: 'Practitioner/pr1' }, status: 'accepted' },
        { actor: { reference: 'Patient/p1' }, status: 'accepted' }
      ],
      extension: [COVERAGE_INFORMATION],
      contained: [CONTAINED_CONDITION]
    }.freeze

    LOCATION = {
      resourceType: 'Location', id: 'l1', status: 'active', name: 'Main Clinic',
      type: [{ coding: [{ system: 'http://terminology.hl7.org/CodeSystem/v3-RoleCode', code: 'HOSP' }] }],
      identifier: [{ system: 'http://example.org/loc', value: 'l-1' }],
      telecom: [{ system: 'phone', value: '555-0100' }],
      managingOrganization: { reference: 'Organization/o1' },
      address: ADDRESS
    }.freeze

    ORGANIZATION = {
      resourceType: 'Organization', id: 'o1', active: true, name: 'Acme Health',
      identifier: [NPI, TIN], address: [ADDRESS],
      telecom: [{ system: 'phone', value: '555-0100' }],
      partOf: { reference: 'Organization/o0' }
    }.freeze

    PATIENT = {
      resourceType: 'Patient', id: 'p1', gender: 'female', birthDate: '1980-01-01',
      identifier: [{ system: 'http://example.org/mrn', value: 'm-1' }],
      name: [{ family: 'Doe', given: ['Jane'] }],
      telecom: [{ system: 'phone', value: '555-0100', use: 'home' }],
      address: [ADDRESS],
      communication: [{ language: { coding: [{ system: 'urn:ietf:bcp:47', code: 'en' }] } }]
    }.freeze

    PRACTITIONER = {
      resourceType: 'Practitioner', id: 'pr1', identifier: [NPI, TIN],
      name: [{ family: 'Smith', given: ['John'] }],
      telecom: [{ system: 'phone', value: '555-0100' }],
      address: [ADDRESS]
    }.freeze

    PRACTITIONER_ROLE = {
      resourceType: 'PractitionerRole', id: 'prr1',
      practitioner: { reference: 'Practitioner/pr1' },
      organization: { reference: 'Organization/o1' },
      code: [{ coding: [{ system: 'http://nucc.org/provider-taxonomy', code: '207Q00000X' }] }],
      specialty: [{ coding: [{ system: 'http://nucc.org/provider-taxonomy', code: '207Q00000X' }] }],
      location: [{ reference: 'Location/l1' }],
      endpoint: [{ reference: 'Endpoint/e1' }],
      telecom: [{ system: 'phone', value: '555-0100' }]
    }.freeze

    COVERAGE = {
      resourceType: 'Coverage', id: 'c1', status: 'active',
      identifier: [{ type: { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/v2-0203',
                                        code: 'MB' }] },
                     system: 'http://example.org/member', value: 'mem-1' }],
      type: { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode', code: 'EHCPOL' }] },
      policyHolder: { reference: 'Patient/p1' }, subscriber: { reference: 'Patient/p1' },
      subscriberId: 'sub-1', beneficiary: { reference: 'Patient/p1' }, dependent: '01',
      relationship: { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/subscriber-relationship',
                                 code: 'self' }] },
      period: { start: '2026-01-01' }, payor: [{ reference: 'Organization/o1' }],
      class: [
        { type: { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/coverage-class',
                             code: 'group' }] },
          value: 'grp-1', name: 'Group Plan' },
        { type: { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/coverage-class',
                             code: 'plan' }] },
          value: 'pln-1', name: 'Gold Plan' }
      ],
      order: 1, network: 'net-1'
    }.freeze

    ENCOUNTER = {
      resourceType: 'Encounter', id: 'e1', status: 'finished',
      meta: { lastUpdated: '2026-01-01T00:00:00Z' },
      identifier: [{ system: 'http://example.org/enc', value: 'e-1' }],
      class: { system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode', code: 'AMB' },
      type: [{ coding: [{ system: 'http://snomed.info/sct', code: '162673000' }] }],
      serviceType: { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/service-type', code: '57' }],
                     extension: [BILLING_OPTIONS] },
      subject: { reference: 'Patient/p1' },
      participant: [{ type: [{ coding: [{ code: 'ATND' }] }], period: { start: '2026-01-01T00:00:00Z' },
                      individual: { reference: 'Practitioner/pr1' } }],
      appointment: [{ reference: 'Appointment/a1' }],
      period: { start: '2026-01-01T00:00:00Z' }, length: { value: 30, unit: 'min' },
      reasonCode: [{ coding: [{ code: 'rc' }] }],
      reasonReference: [{ reference: 'Condition/cond1' }],
      diagnosis: [{ condition: { reference: 'Condition/cond1' } }],
      hospitalization: { dischargeDisposition: { coding: [{ code: 'home' }] } },
      location: [{ location: { reference: 'Location/l1' }, status: 'active',
                   period: { start: '2026-01-01T00:00:00Z' } }],
      serviceProvider: { reference: 'Organization/o1' },
      extension: [COVERAGE_INFORMATION],
      contained: [CONTAINED_CONDITION]
    }.freeze

    VISION_PRESCRIPTION = {
      resourceType: 'VisionPrescription', id: 'vp1', status: 'active',
      created: '2026-01-01T00:00:00Z', dateWritten: '2026-01-01T00:00:00Z',
      identifier: [{ system: 'http://example.org/vp', value: 'vp-1' }],
      patient: { reference: 'Patient/p1' }, encounter: { reference: 'Encounter/e1' },
      prescriber: { reference: 'Practitioner/pr1' },
      extension: [COVERAGE_INFORMATION, REQUEST_CATEGORY],
      contained: [{ resourceType: 'Practitioner', id: 'pr1' }],
      lensSpecification: [{
        product: { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/ex-visionprescriptionproduct',
                              code: 'lens' }] },
        eye: 'right', sphere: -2.0, cylinder: -0.5, axis: 180, add: 1.5, power: 1.0,
        backCurve: 8.6, diameter: 14.0, duration: { value: 1, unit: 'month' },
        prism: [{ amount: 0.5, base: 'up' }],
        extension: [BILLING_OPTIONS]
      }]
    }.freeze

    NUTRITION_ORDER = {
      resourceType: 'NutritionOrder', id: 'no1', status: 'draft', intent: 'order',
      identifier: [{ system: 'http://example.org/no', value: 'no-1' }],
      patient: { reference: 'Patient/p1' }, encounter: { reference: 'Encounter/e1' },
      dateTime: '2026-01-01', orderer: { reference: 'Practitioner/pr1' },
      allergyIntolerance: [{ reference: 'AllergyIntolerance/ai1' }],
      foodPreferenceModifier: [{ coding: [{ code: 'dairy-free' }] }],
      excludeFoodModifier: [{ coding: [{ code: 'nuts' }] }],
      oralDiet: {
        type: [{ coding: [{ code: 'diabetic' }] }],
        schedule: [FULL_TIMING],
        nutrient: [{ modifier: { coding: [{ code: 'carb' }] }, amount: { value: 50, unit: 'g' } }],
        texture: [{ modifier: { coding: [{ code: 'pureed' }] }, foodType: { coding: [{ code: 'meat' }] } }]
      },
      supplement: [{ type: { coding: [{ code: 'protein' }] }, quantity: { value: 1, unit: 'can' },
                     schedule: [{ repeat: { frequency: 1, period: 1, periodUnit: 'd' } }] }],
      enteralFormula: {
        baseFormulaType: { coding: [{ code: 'formula' }] },
        additiveType: { coding: [{ code: 'additive' }] },
        caloricDensity: { value: 1, unit: 'cal/mL' },
        routeofAdministration: { coding: [{ code: 'NG' }] },
        administration: [{ schedule: { repeat: { frequency: 1, period: 1, periodUnit: 'd' } },
                           quantity: { value: 100, unit: 'mL' },
                           rateRatio: { numerator: { value: 100, unit: 'mL' },
                                        denominator: { value: 1, unit: 'h' } } }]
      },
      extension: [COVERAGE_INFORMATION, REQUEST_CATEGORY],
      contained: [{ resourceType: 'Practitioner', id: 'pr1' }]
    }.freeze

    COMMUNICATION_REQUEST = {
      resourceType: 'CommunicationRequest', id: 'cr1', status: 'draft',
      identifier: [{ system: 'http://example.org/cr', value: 'cr-1' }],
      subject: { reference: 'Patient/p1' }, requester: { reference: 'Practitioner/pr1' },
      sender: { reference: 'Practitioner/pr1' }, recipient: [{ reference: 'Practitioner/pr1' }],
      authoredOn: '2026-01-01T00:00:00Z', occurrenceDateTime: '2026-01-02T00:00:00Z',
      basedOn: [{ reference: 'ServiceRequest/sr0' }],
      reasonCode: [{ coding: [{ code: 'rc' }] }],
      reasonReference: [{ reference: 'Condition/cond1' }],
      payload: [{
        extension: [{ url: 'http://hl7.org/fhir/5.0/StructureDefinition/' \
                           'extension-CommunicationRequest.payload.content',
                      valueCodeableConcept: { coding: [{ code: 'pc' }],
                                              extension: [BILLING_OPTIONS] } }],
        contentString: 'note'
      }],
      extension: [COVERAGE_INFORMATION],
      contained: [CONTAINED_CONDITION]
    }.freeze

    # DeviceRequest and MedicationRequest each carry a choice element whose two arms are separately
    # must support, so they take two instances to demonstrate fully.
    DEVICE_REQUEST_BASE = {
      resourceType: 'DeviceRequest', id: 'dr1', status: 'draft', intent: 'order',
      identifier: [{ system: 'http://example.org/dr', value: 'dr-1' }],
      subject: { reference: 'Patient/p1' }, requester: { reference: 'Practitioner/pr1' },
      performer: { reference: 'Practitioner/pr1' },
      authoredOn: '2026-01-01T00:00:00Z', occurrenceDateTime: '2026-01-02T00:00:00Z',
      basedOn: [{ reference: 'DeviceRequest/dr0' }],
      reasonCode: [{ coding: [{ code: 'rc' }] }],
      reasonReference: [{ reference: 'Condition/cond1' }],
      parameter: [{ code: { coding: [{ code: 'p' }] } }],
      extension: [COVERAGE_INFORMATION, REQUEST_CATEGORY],
      contained: [CONTAINED_CONDITION]
    }.freeze

    DEVICE_REQUESTS = [
      DEVICE_REQUEST_BASE.merge(
        codeCodeableConcept: { coding: [{ system: 'http://snomed.info/sct', code: '1234' }],
                               extension: [BILLING_OPTIONS] }
      ),
      DEVICE_REQUEST_BASE.merge(id: 'dr2', codeReference: { reference: 'Device/d1' })
    ].freeze

    MEDICATION_REQUEST_BASE = {
      resourceType: 'MedicationRequest', id: 'mr1', status: 'draft', intent: 'order',
      identifier: [{ system: 'http://example.org/mr', value: 'mr-1' }],
      subject: { reference: 'Patient/p1' }, encounter: { reference: 'Encounter/e1' },
      requester: { reference: 'Practitioner/pr1' }, performer: { reference: 'Practitioner/pr1' },
      authoredOn: '2026-01-01T00:00:00Z', reportedBoolean: false,
      category: [
        { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/medicationrequest-category',
                     code: 'community' }] },
        { coding: [{ system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode', code: 'AMB' }] },
        { coding: [{ system: X12_SERVICE_TYPE_SYSTEM, code: '1' }] }
      ],
      reasonCode: [{ coding: [{ code: 'rc' }] }],
      reasonReference: [{ reference: 'Condition/cond1' }],
      priorPrescription: { reference: 'MedicationRequest/mr0' },
      substitution: { allowedBoolean: true },
      dosageInstruction: [{ text: 'take one',
                            timing: FULL_TIMING,
                            doseAndRate: [{ doseQuantity: { value: 1, unit: 'tab' } }] }],
      dispenseRequest: { numberOfRepeatsAllowed: 2, quantity: { value: 30, unit: 'tab' },
                         performer: { reference: 'Organization/o1' } },
      extension: [COVERAGE_INFORMATION],
      contained: [CONTAINED_CONDITION]
    }.freeze

    MEDICATION_REQUESTS = [
      MEDICATION_REQUEST_BASE.merge(
        medicationCodeableConcept: { coding: [{ system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
                                                code: '1234' }],
                                     extension: [BILLING_OPTIONS] }
      ),
      MEDICATION_REQUEST_BASE.merge(id: 'mr2', medicationReference: { reference: 'Medication/m1' },
                                    reportedReference: { reference: 'Practitioner/pr1' })
    ].freeze
  end
end
