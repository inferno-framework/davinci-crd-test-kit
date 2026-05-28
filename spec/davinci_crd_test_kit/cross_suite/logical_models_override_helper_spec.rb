require_relative '../../../lib/davinci_crd_test_kit/cross_suite/logical_models_override_helper'

IssueStub = Struct.new(:filtered, :location, :message, :severity, keyword_init: true) unless defined?(IssueStub)

RSpec.describe DaVinciCRDTestKit::LogicalModelsOverrideHelper do
  let(:module_instance) do
    Class.new do
      include DaVinciCRDTestKit::LogicalModelsOverrideHelper

      attr_reader :messages, :resource_is_valid_calls
      attr_accessor :mock_appointment_validation_details

      def initialize
        @messages = []
        @resource_is_valid_calls = []
        @mock_appointment_validation_details = []
      end

      def add_message(type, message)
        @messages << { type:, message: }
      end

      def resource_is_valid?(resource:, profile_url:, message_prefix: '', validator_response_details: nil, **_)
        @resource_is_valid_calls << { resource:, profile_url:, message_prefix: }
        validator_response_details&.concat(@mock_appointment_validation_details)
        true
      end

      def scratch
        @scratch ||= {}
      end
    end.new
  end

  let(:appointment_book_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'appointment_book_hook_request.json')))
  end

  describe '#reject_resource_issues' do
    it 'keeps issues that are not filtered and have no location' do
      issue = IssueStub.new(filtered: false, location: nil, message: 'something', severity: 'error')

      result = module_instance.send(:reject_resource_issues, [issue])

      expect(result).to eq([issue])
    end

    it 'rejects issues whose location contains a /*ResourceType/ path segment' do
      issue = IssueStub.new(filtered: false,
                            location: 'CRDHooksRequest.context/*Patient/name',
                            message: 'something',
                            severity: 'error')

      result = module_instance.send(:reject_resource_issues, [issue])

      expect(result).to be_empty
    end

    it 'keeps issues whose location does not contain a resource path segment' do
      issue = IssueStub.new(filtered: false,
                            location: 'CRDHooksRequest.context.userId',
                            message: 'something',
                            severity: 'error')

      result = module_instance.send(:reject_resource_issues, [issue])

      expect(result).to eq([issue])
    end
  end

  describe '#local_reference?' do
    it 'returns true and adds no errors for a valid reference with an allowed resource type' do
      result = module_instance.send(:local_reference?, 'Practitioner/example', 'prefix',
                                    allowed_resource_types: %w[Practitioner Patient])

      expect(result).to be true
      expect(module_instance.messages).to be_empty
    end

    it 'returns false and adds an error when the value is not in local reference format' do
      result = module_instance.send(:local_reference?, 'not-a-reference', 'prefix',
                                    allowed_resource_types: %w[Practitioner])

      expect(result).to be false
      expect(module_instance.messages.length).to eq(1)
      expect(module_instance.messages.first[:type]).to eq('error')
      expect(module_instance.messages.first[:message])
        .to eq("prefix expected a local reference, got 'not-a-reference'.")
    end

    it 'returns false and adds an error when the resource type is not in the allowed list' do
      result = module_instance.send(:local_reference?, 'Device/example', 'prefix',
                                    allowed_resource_types: %w[Practitioner Patient])

      expect(result).to be false
      expect(module_instance.messages.length).to eq(1)
      expect(module_instance.messages.first[:type]).to eq('error')
      expect(module_instance.messages.first[:message]).to include("'Device'")
      expect(module_instance.messages.first[:message]).to include('Practitioner, Patient')
    end

    it 'returns false and adds an error when the id contains invalid characters' do
      result = module_instance.send(:local_reference?, 'Practitioner/@@@', 'prefix',
                                    allowed_resource_types: %w[Practitioner])

      expect(result).to be false
      expect(module_instance.messages.length).to eq(1)
      expect(module_instance.messages.first[:type]).to eq('error')
      expect(module_instance.messages.first[:message]).to include("'@@@'")
      expect(module_instance.messages.first[:message]).to include('FHIR id data type')
    end

    it 'returns false and adds an error when the id contains a mix of valid and invalid characters' do
      result = module_instance.send(:local_reference?, 'Practitioner/abc@@@', 'prefix',
                                    allowed_resource_types: %w[Practitioner])

      expect(result).to be false
      expect(module_instance.messages.first[:message]).to include("'abc@@@'")
      expect(module_instance.messages.first[:message]).to include('FHIR id data type')
    end

    it 'returns true when no allowed list is given and the resource type is a valid FHIR type' do
      result = module_instance.send(:local_reference?, 'Patient/example', 'prefix')

      expect(result).to be true
      expect(module_instance.messages).to be_empty
    end

    it 'returns false and adds an error when no allowed list is given and the resource type is not a valid FHIR type' do
      result = module_instance.send(:local_reference?, 'NotAType/example', 'prefix')

      expect(result).to be false
      expect(module_instance.messages.length).to eq(1)
      expect(module_instance.messages.first[:type]).to eq('error')
      expect(module_instance.messages.first[:message]).to include("'NotAType'")
      expect(module_instance.messages.first[:message]).to include('a valid FHIR resource type')
    end
  end

  describe '#referenced_resource_present_in_bundle?' do
    let(:bundle) do
      {
        'resourceType' => 'Bundle',
        'entry' => [
          { 'resource' => { 'resourceType' => 'ServiceRequest', 'id' => 'sr-1' } },
          { 'resource' => { 'resourceType' => 'MedicationRequest', 'id' => 'mr-1' } }
        ]
      }
    end

    it 'returns true and adds no errors when the referenced resource is in the bundle' do
      result = module_instance.send(:referenced_resource_present_in_bundle?, bundle, 'ServiceRequest/sr-1',
                                    'prefix', 'draftOrders')

      expect(result).to be true
      expect(module_instance.messages).to be_empty
    end

    it 'returns false and adds an error when the referenced resource is not in the bundle' do
      result = module_instance.send(:referenced_resource_present_in_bundle?, bundle, 'ServiceRequest/missing',
                                    'prefix', 'draftOrders')

      expect(result).to be false
      expect(module_instance.messages.length).to eq(1)
      expect(module_instance.messages.first[:type]).to eq('error')
      expect(module_instance.messages.first[:message]).to eq(
        "prefix referenced resource 'ServiceRequest/missing' not found in the draftOrders Bundle."
      )
    end

    it 'returns false and adds an error when the bundle is nil' do
      result = module_instance.send(:referenced_resource_present_in_bundle?, nil, 'ServiceRequest/sr-1',
                                    'prefix', 'draftOrders')

      expect(result).to be false
      expect(module_instance.messages.length).to eq(1)
      expect(module_instance.messages.first[:type]).to eq('error')
      expect(module_instance.messages.first[:message]).to include("'ServiceRequest/sr-1'")
    end

    it 'returns false and adds an error when the bundle has no entries' do
      result = module_instance.send(:referenced_resource_present_in_bundle?,
                                    { 'resourceType' => 'Bundle' }, 'ServiceRequest/sr-1',
                                    'prefix', 'draftOrders')

      expect(result).to be false
      expect(module_instance.messages.length).to eq(1)
      expect(module_instance.messages.first[:type]).to eq('error')
      expect(module_instance.messages.first[:message]).to include("'ServiceRequest/sr-1'")
    end
  end

  describe '#check_appointment_conformance' do
    let(:appointment_with_based_on) do
      FHIR::Appointment.new(
        status: 'proposed',
        basedOn: [FHIR::Reference.new(reference: 'ServiceRequest/example')]
      )
    end

    let(:appointment_without_based_on) do
      FHIR::Appointment.new(status: 'proposed')
    end

    it 'validates against profile-appointment-with-order when basedOn is present' do
      module_instance.send(:check_appointment_conformance, appointment_with_based_on,
                           appointment_book_request, 'prefix - ', '2.2.1')

      call = module_instance.resource_is_valid_calls.first
      expect(call[:profile_url]).to include('profile-appointment-with-order')
      expect(call[:profile_url]).to include('2.2.1')
    end

    it 'validates against profile-appointment-no-order when basedOn is absent' do
      module_instance.send(:check_appointment_conformance, appointment_without_based_on,
                           appointment_book_request, 'prefix - ', '2.2.1')

      call = module_instance.resource_is_valid_calls.first
      expect(call[:profile_url]).to include('profile-appointment-no-order')
    end

    it 'adds messages for non-filtered validation issues' do
      module_instance.mock_appointment_validation_details = [
        IssueStub.new(filtered: false, location: nil, message: 'field missing', severity: 'error')
      ]

      module_instance.send(:check_appointment_conformance, appointment_without_based_on,
                           appointment_book_request, 'prefix - ', '2.2.1')

      expect(module_instance.messages.length).to eq(1)
      expect(module_instance.messages.first[:message]).to include('field missing')
      expect(module_instance.messages.first[:message]).to include('prefix - ')
    end

    it 'does not add messages for filtered validation issues' do
      module_instance.mock_appointment_validation_details = [
        IssueStub.new(filtered: true, location: nil, message: 'ignored', severity: 'error')
      ]

      module_instance.send(:check_appointment_conformance, appointment_without_based_on,
                           appointment_book_request, 'prefix - ', '2.2.1')

      expect(module_instance.messages).to be_empty
    end
  end

  describe '#manually_check_appointment_validation_errors' do
    let(:request_body) do
      { 'fhirServer' => 'https://example/r4', 'context' => { 'patientId' => 'pt-1' } }
    end

    let(:performer_participant) do
      FHIR::Appointment::Participant.new(
        actor: FHIR::Reference.new(reference: 'Practitioner/example'),
        type: [FHIR::CodeableConcept.new(
          coding: [FHIR::Coding.new(
            code: 'PPRF',
            system: 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType'
          )]
        )]
      )
    end

    let(:patient_participant) do
      FHIR::Appointment::Participant.new(
        actor: FHIR::Reference.new(reference: 'Patient/pt-1')
      )
    end

    let(:appointment_with_performer_and_patient) do
      FHIR::Appointment.new(participant: [performer_participant, patient_participant])
    end

    let(:appointment_without_slices) do
      FHIR::Appointment.new(participant: [])
    end

    let(:primary_performer_slice_error) do
      IssueStub.new(
        filtered: false, location: nil, severity: 'error',
        message: "Slice 'Appointment.participant:PrimaryPerformer': a matching slice is required, but not found"
      )
    end

    let(:patient_slice_error) do
      IssueStub.new(
        filtered: false, location: nil, severity: 'error',
        message: "Slice 'Appointment.participant:Patient': a matching slice is required, but not found"
      )
    end

    it 'keeps non-filtered issues' do
      issue = IssueStub.new(filtered: false, location: nil, message: 'something', severity: 'error')

      result = module_instance.send(:manually_check_appointment_validation_errors,
                                    [issue], appointment_without_slices, request_body)

      expect(result).to eq([issue])
    end

    it 'rejects filtered issues' do
      issue = IssueStub.new(filtered: true, location: nil, message: 'something', severity: 'error')

      result = module_instance.send(:manually_check_appointment_validation_errors,
                                    [issue], appointment_without_slices, request_body)

      expect(result).to be_empty
    end

    it 'rejects the PrimaryPerformer slice error when the appointment has a PPRF participant' do
      result = module_instance.send(:manually_check_appointment_validation_errors,
                                    [primary_performer_slice_error],
                                    appointment_with_performer_and_patient, request_body)

      expect(result).to be_empty
    end

    it 'keeps the PrimaryPerformer slice error when the appointment has no PPRF participant' do
      result = module_instance.send(:manually_check_appointment_validation_errors,
                                    [primary_performer_slice_error],
                                    appointment_without_slices, request_body)

      expect(result).to eq([primary_performer_slice_error])
    end

    it 'rejects the Patient slice error when the appointment has a patient participant' do
      result = module_instance.send(:manually_check_appointment_validation_errors,
                                    [patient_slice_error],
                                    appointment_with_performer_and_patient, request_body)

      expect(result).to be_empty
    end

    it 'keeps the Patient slice error when the appointment has no patient participant' do
      result = module_instance.send(:manually_check_appointment_validation_errors,
                                    [patient_slice_error],
                                    appointment_without_slices, request_body)

      expect(result).to eq([patient_slice_error])
    end

    context 'when a participant index is matched to a slice' do
      let(:matched_participant_slice_issue) do
        IssueStub.new(
          filtered: false, location: nil, severity: 'warning',
          message: 'Appointment.participant[0]: This element does not match any known slice defined in the profile'
        )
      end

      let(:unmatched_participant_slice_issue) do
        IssueStub.new(
          filtered: false, location: nil, severity: 'warning',
          message: 'Appointment.participant[1]: This element does not match any known slice defined in the profile'
        )
      end

      it 'rejects the "does not match any known slice" issue for the matched participant index' do
        # Issue order matches validator output: element-level errors before slice-level errors
        issues = [matched_participant_slice_issue, primary_performer_slice_error]

        result = module_instance.send(:manually_check_appointment_validation_errors,
                                      issues, appointment_with_performer_and_patient, request_body)

        expect(result).to be_empty
      end

      it 'keeps the "does not match any known slice" issue for non-matched participant indexes' do
        issues = [unmatched_participant_slice_issue, primary_performer_slice_error]

        result = module_instance.send(:manually_check_appointment_validation_errors,
                                      issues, appointment_with_performer_and_patient, request_body)

        expect(result).to eq([unmatched_participant_slice_issue])
      end

      it 'keeps the "does not match any known slice" issue when no slice is resolved' do
        result = module_instance.send(:manually_check_appointment_validation_errors,
                                      [matched_participant_slice_issue], appointment_without_slices, request_body)

        expect(result).to eq([matched_participant_slice_issue])
      end
    end
  end

  describe '#resolved_participant_primary_performer_slice_issue?' do
    before { module_instance.instance_variable_set(:@matched_participant_slice_indexes, []) }

    let(:primary_performer_issue) do
      IssueStub.new(
        filtered: false, location: nil, severity: 'error',
        message: "Slice 'Appointment.participant:PrimaryPerformer': a matching slice is required, but not found"
      )
    end

    let(:pprf_appointment) do
      FHIR::Appointment.new(
        participant: [
          FHIR::Appointment::Participant.new(
            actor: FHIR::Reference.new(reference: 'Practitioner/example'),
            type: [FHIR::CodeableConcept.new(
              coding: [FHIR::Coding.new(
                code: 'PPRF',
                system: 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType'
              )]
            )]
          )
        ]
      )
    end

    let(:no_pprf_appointment) { FHIR::Appointment.new(participant: []) }

    it 'returns false when the issue does not match the PrimaryPerformer slice error pattern' do
      other_issue = IssueStub.new(filtered: false, location: nil, severity: 'error', message: 'something else')

      result = module_instance.send(:resolved_participant_primary_performer_slice_issue?,
                                    other_issue, pprf_appointment)

      expect(result).to be false
    end

    it 'returns false when the issue matches but no participant is a primary performer' do
      result = module_instance.send(:resolved_participant_primary_performer_slice_issue?,
                                    primary_performer_issue, no_pprf_appointment)

      expect(result).to be false
    end

    it 'returns true when the issue matches and a participant is a primary performer' do
      result = module_instance.send(:resolved_participant_primary_performer_slice_issue?,
                                    primary_performer_issue, pprf_appointment)

      expect(result).to be true
    end

    it 'records the matching participant index when resolved' do
      module_instance.send(:resolved_participant_primary_performer_slice_issue?,
                           primary_performer_issue, pprf_appointment)

      expect(module_instance.instance_variable_get(:@matched_participant_slice_indexes)).to include(0)
    end

    it 'does not record any index when not resolved' do
      module_instance.send(:resolved_participant_primary_performer_slice_issue?,
                           primary_performer_issue, no_pprf_appointment)

      expect(module_instance.instance_variable_get(:@matched_participant_slice_indexes)).to be_empty
    end
  end

  describe '#resolved_participant_patient_slice_issue?' do
    let(:request_body) { { 'fhirServer' => 'https://example/r4', 'context' => { 'patientId' => 'pt-1' } } }

    let(:patient_issue) do
      IssueStub.new(
        filtered: false, location: nil, severity: 'error',
        message: "Slice 'Appointment.participant:Patient': a matching slice is required, but not found"
      )
    end

    before { module_instance.instance_variable_set(:@matched_participant_slice_indexes, []) }

    it 'returns false when the issue does not match the Patient slice error pattern' do
      other_issue = IssueStub.new(filtered: false, location: nil, severity: 'error', message: 'something else')
      appointment = FHIR::Appointment.new(participant: [FHIR::Appointment::Participant.new(
        actor: FHIR::Reference.new(reference: 'Patient/pt-1')
      )])

      expect(module_instance.send(:resolved_participant_patient_slice_issue?,
                                  other_issue, appointment, request_body)).to be false
    end

    it 'returns false when the issue matches but no participant matches the patient reference' do
      appointment = FHIR::Appointment.new(participant: [FHIR::Appointment::Participant.new(
        actor: FHIR::Reference.new(reference: 'Practitioner/example')
      )])

      expect(module_instance.send(:resolved_participant_patient_slice_issue?,
                                  patient_issue, appointment, request_body)).to be false
    end

    it 'returns true when a participant matches the local patient reference' do
      appointment = FHIR::Appointment.new(participant: [FHIR::Appointment::Participant.new(
        actor: FHIR::Reference.new(reference: 'Patient/pt-1')
      )])

      expect(module_instance.send(:resolved_participant_patient_slice_issue?,
                                  patient_issue, appointment, request_body)).to be true
    end

    it 'returns true when a participant matches the absolute patient reference' do
      appointment = FHIR::Appointment.new(participant: [FHIR::Appointment::Participant.new(
        actor: FHIR::Reference.new(reference: 'https://example/r4/Patient/pt-1')
      )])

      expect(module_instance.send(:resolved_participant_patient_slice_issue?,
                                  patient_issue, appointment, request_body)).to be true
    end

    it 'records the matching participant index when resolved' do
      appointment = FHIR::Appointment.new(participant: [FHIR::Appointment::Participant.new(
        actor: FHIR::Reference.new(reference: 'Patient/pt-1')
      )])

      module_instance.send(:resolved_participant_patient_slice_issue?, patient_issue, appointment, request_body)

      expect(module_instance.instance_variable_get(:@matched_participant_slice_indexes)).to include(0)
    end
  end
end
