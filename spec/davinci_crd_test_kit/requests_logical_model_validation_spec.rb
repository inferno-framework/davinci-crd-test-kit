require_relative '../../lib/davinci_crd_test_kit/cross_suite/requests_logical_model_validation'

IssueStub = Struct.new(:filtered, :location, :message, :severity, keyword_init: true)

RSpec.describe DaVinciCRDTestKit::RequestsLogicalModelValidation do
  let(:module_instance) do
    Class.new do
      include DaVinciCRDTestKit::RequestsLogicalModelValidation

      attr_reader :messages, :conforms_calls, :resource_is_valid_calls
      attr_accessor :mock_validation_details, :mock_appointment_validation_details

      def initialize
        @messages = []
        @conforms_calls = []
        @resource_is_valid_calls = []
        @mock_validation_details = []
        @mock_appointment_validation_details = []
      end

      def add_message(type, message)
        @messages << { type:, message: }
      end

      def conforms_to_logical_model?(object, url, message_prefix: '', validator_response_details: nil, **_)
        @conforms_calls << { object:, url:, message_prefix: }
        validator_response_details&.concat(@mock_validation_details)
        true
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

  let(:order_dispatch_request_v211) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_dispatch_hook_v221_request.json')))
  end

  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_sign_hook_request.json')))
  end

  let(:order_select_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_select_hook_request.json')))
  end

  let(:appointment_book_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'appointment_book_hook_request.json')))
  end

  describe '#check_relative_references' do
    context 'when the hook is order-dispatch' do
      it 'adds no errors when performer and dispatchedOrders are valid local references' do
        module_instance.send(:check_relative_references, order_dispatch_request_v211, 0)

        expect(module_instance.messages).to be_empty
      end

      it 'adds an error when performer is not a local reference format' do
        order_dispatch_request_v211['context']['performer'] = 'not-a-reference'

        module_instance.send(:check_relative_references, order_dispatch_request_v211, 0)

        expect(module_instance.messages.length).to eq(1)
        expect(module_instance.messages.first[:type]).to eq('error')
        expect(module_instance.messages.first[:message]).to include('context.performer')
        expect(module_instance.messages.first[:message]).to include('expected a local reference')
      end

      it 'adds an error when performer has a disallowed resource type' do
        order_dispatch_request_v211['context']['performer'] = 'Patient/example'

        module_instance.send(:check_relative_references, order_dispatch_request_v211, 0)

        expect(module_instance.messages.length).to eq(1)
        expect(module_instance.messages.first[:type]).to eq('error')
        expect(module_instance.messages.first[:message]).to include('context.performer')
        expect(module_instance.messages.first[:message]).to include("'Patient'")
        expect(module_instance.messages.first[:message]).to include('Practitioner, PractitionerRole')
      end

      it 'adds an error when a dispatchedOrders entry has a disallowed resource type' do
        order_dispatch_request_v211['context']['dispatchedOrders'][0] = 'Patient/example'

        module_instance.send(:check_relative_references, order_dispatch_request_v211, 0)

        expect(module_instance.messages.length).to eq(1)
        expect(module_instance.messages.first[:type]).to eq('error')
        expect(module_instance.messages.first[:message]).to include('context.dispatchedOrders entry 1')
        expect(module_instance.messages.first[:message]).to include("'Patient'")
      end

      it 'includes the request index in error messages' do
        order_dispatch_request_v211['context']['performer'] = 'not-a-reference'

        module_instance.send(:check_relative_references, order_dispatch_request_v211, 2)

        expect(module_instance.messages.first[:message]).to include('(Request 3)')
      end
    end

    context 'when the hook is not order-dispatch' do
      it 'adds no errors when userId is a valid local reference' do
        module_instance.send(:check_relative_references, order_sign_request, 0)

        expect(module_instance.messages).to be_empty
      end

      it 'adds an error when userId is not a local reference format' do
        order_sign_request['context']['userId'] = 'not-a-reference'

        module_instance.send(:check_relative_references, order_sign_request, 0)

        expect(module_instance.messages.length).to eq(1)
        expect(module_instance.messages.first[:type]).to eq('error')
        expect(module_instance.messages.first[:message]).to include('context.userId')
        expect(module_instance.messages.first[:message]).to include('expected a local reference')
      end

      it 'adds an error when userId has a disallowed resource type' do
        order_sign_request['context']['userId'] = 'Device/example'

        module_instance.send(:check_relative_references, order_sign_request, 0)

        expect(module_instance.messages.length).to eq(1)
        expect(module_instance.messages.first[:type]).to eq('error')
        expect(module_instance.messages.first[:message]).to include('context.userId')
        expect(module_instance.messages.first[:message]).to include("'Device'")
        expect(module_instance.messages.first[:message])
          .to include('Practitioner, PractitionerRole, Patient, RelatedPerson')
      end
    end

    context 'when the hook is order-select' do
      it 'adds no errors when userId and selections are valid and present in draftOrders' do
        module_instance.send(:check_relative_references, order_select_request, 0)

        expect(module_instance.messages).to be_empty
      end

      it 'adds an error when a selection is not a local reference format' do
        order_select_request['context']['selections'][0] = 'not-a-reference'

        module_instance.send(:check_relative_references, order_select_request, 0)

        expect(module_instance.messages.length).to eq(1)
        expect(module_instance.messages.first[:type]).to eq('error')
        expect(module_instance.messages.first[:message]).to include('context.selections entry 1')
        expect(module_instance.messages.first[:message]).to include('expected a local reference')
      end

      it 'adds an error when a selection is not found in draftOrders' do
        order_select_request['context']['selections'][0] = 'ServiceRequest/missing-resource'

        module_instance.send(:check_relative_references, order_select_request, 0)

        expect(module_instance.messages.length).to eq(1)
        expect(module_instance.messages.first[:type]).to eq('error')
        expect(module_instance.messages.first[:message]).to include('context.selections entry 1')
        expect(module_instance.messages.first[:message]).to include("'ServiceRequest/missing-resource'")
        expect(module_instance.messages.first[:message]).to include('draftOrders')
      end

      it 'skips the bundle check when a selection has an invalid format' do
        order_select_request['context']['selections'][0] = 'not-a-reference'

        module_instance.send(:check_relative_references, order_select_request, 0)

        expect(module_instance.messages.none? { |m| m[:message].include?('not found') }).to be true
      end
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

  describe '#reject_resource_issues' do
    it 'keeps issues that are not filtered and have no location' do
      issue = IssueStub.new(filtered: false, location: nil, message: 'something', severity: 'error')

      result = module_instance.send(:reject_resource_issues, [issue])

      expect(result).to eq([issue])
    end

    it 'rejects issues where filtered is true' do
      issue = IssueStub.new(filtered: true, location: nil, message: 'something', severity: 'error')

      result = module_instance.send(:reject_resource_issues, [issue])

      expect(result).to be_empty
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

  describe '#reject_entry_resource_issues' do
    it 'keeps issues that are not filtered and have no location' do
      issue = IssueStub.new(filtered: false, location: nil, message: 'something', severity: 'error')

      result = module_instance.send(:reject_entry_resource_issues, [issue])

      expect(result).to eq([issue])
    end

    it 'rejects issues where filtered is true' do
      issue = IssueStub.new(filtered: true, location: nil, message: 'something', severity: 'error')

      result = module_instance.send(:reject_entry_resource_issues, [issue])

      expect(result).to be_empty
    end

    it 'rejects issues whose location starts with Bundle.entry[N].resource' do
      issue = IssueStub.new(filtered: false,
                            location: 'Bundle.entry[0].resource.status',
                            message: 'something',
                            severity: 'error')

      result = module_instance.send(:reject_entry_resource_issues, [issue])

      expect(result).to be_empty
    end

    it 'keeps issues whose location does not match the Bundle entry resource pattern' do
      issue = IssueStub.new(filtered: false,
                            location: 'Bundle.type',
                            message: 'something',
                            severity: 'error')

      result = module_instance.send(:reject_entry_resource_issues, [issue])

      expect(result).to eq([issue])
    end
  end

  describe '#check_bundle_non_entry_resource_conformance' do
    let(:bundle) { FHIR::Bundle.new(type: 'collection') }

    it 'validates the bundle against the profile-bundle-base profile' do
      module_instance.send(:check_bundle_non_entry_resource_conformance, bundle, 'prefix - ', '2.2.1')

      call = module_instance.resource_is_valid_calls.first
      expect(call[:profile_url]).to include('profile-bundle-base')
      expect(call[:profile_url]).to include('2.2.1')
    end

    it 'adds messages for non-filtered, non-entry-resource issues' do
      module_instance.mock_appointment_validation_details = [
        IssueStub.new(filtered: false, location: 'Bundle.type', message: 'bad type', severity: 'error')
      ]

      module_instance.send(:check_bundle_non_entry_resource_conformance, bundle, 'prefix - ', '2.2.1')

      expect(module_instance.messages.length).to eq(1)
      expect(module_instance.messages.first[:type]).to eq('error')
      expect(module_instance.messages.first[:message]).to include('bad type')
      expect(module_instance.messages.first[:message]).to include('prefix - ')
    end

    it 'does not add messages for filtered issues' do
      module_instance.mock_appointment_validation_details = [
        IssueStub.new(filtered: true, location: nil, message: 'ignored', severity: 'error')
      ]

      module_instance.send(:check_bundle_non_entry_resource_conformance, bundle, 'prefix - ', '2.2.1')

      expect(module_instance.messages).to be_empty
    end

    it 'does not add messages for entry resource issues' do
      module_instance.mock_appointment_validation_details = [
        IssueStub.new(filtered: false,
                      location: 'Bundle.entry[0].resource.status',
                      message: 'entry issue',
                      severity: 'error')
      ]

      module_instance.send(:check_bundle_non_entry_resource_conformance, bundle, 'prefix - ', '2.2.1')

      expect(module_instance.messages).to be_empty
    end
  end

  describe '#check_logical_model_conformance_no_resource_checks' do
    it 'calls conforms_to_logical_model? with add_messages_to_runnable: false' do
      module_instance.send(:check_logical_model_conformance_no_resource_checks, order_sign_request, 0, '2.2.1')

      call = module_instance.conforms_calls.first
      expect(call[:url]).to include('2.2.1')
    end

    it 'adds messages for non-filtered, non-resource issues returned by validation' do
      module_instance.mock_validation_details = [
        IssueStub.new(filtered: false, location: 'context.hook', message: 'bad value', severity: 'error')
      ]

      module_instance.send(:check_logical_model_conformance_no_resource_checks, order_sign_request, 0, '2.2.1')

      expect(module_instance.messages.length).to eq(1)
      expect(module_instance.messages.first[:type]).to eq('error')
      expect(module_instance.messages.first[:message]).to include('bad value')
      expect(module_instance.messages.first[:message]).to include('(Request 1)')
    end

    it 'does not add messages for filtered issues' do
      module_instance.mock_validation_details = [
        IssueStub.new(filtered: true, location: nil, message: 'ignored', severity: 'error')
      ]

      module_instance.send(:check_logical_model_conformance_no_resource_checks, order_sign_request, 0, '2.2.1')

      expect(module_instance.messages).to be_empty
    end

    it 'does not add messages for issues with a resource path in the location' do
      module_instance.mock_validation_details = [
        IssueStub.new(filtered: false,
                      location: 'context/*Patient/name',
                      message: 'resource issue',
                      severity: 'error')
      ]

      module_instance.send(:check_logical_model_conformance_no_resource_checks, order_sign_request, 0, '2.2.1')

      expect(module_instance.messages).to be_empty
    end
  end

  describe '#check_context_resource_profiles' do
    context 'when the hook is order-sign' do
      it 'validates draftOrders against the bundle-request profile' do
        module_instance.send(:check_context_resource_profiles, order_sign_request, 0, '2.2.1')

        call = module_instance.resource_is_valid_calls.first
        expect(call[:profile_url]).to include('profile-bundle-request')
        expect(call[:profile_url]).to include('2.2.1')
        expect(call[:message_prefix]).to include('context.draftOrders')
      end
    end

    context 'when the hook is order-select' do
      it 'validates draftOrders against the bundle-request profile' do
        module_instance.send(:check_context_resource_profiles, order_select_request, 0, '2.2.1')

        call = module_instance.resource_is_valid_calls.first
        expect(call[:profile_url]).to include('profile-bundle-request')
      end
    end

    context 'when the hook is order-dispatch' do
      it 'validates each fulfillmentTask against the task-dispatch profile' do
        module_instance.send(:check_context_resource_profiles, order_dispatch_request_v211, 0, '2.2.1')

        task_calls = module_instance.resource_is_valid_calls.select do |c|
          c[:profile_url].include?('profile-task-dispatch')
        end
        task_count = order_dispatch_request_v211.dig('context', 'fulfillmentTasks').length
        expect(task_calls.length).to eq(task_count)
      end

      it 'includes the entry index in the message prefix for each task' do
        module_instance.send(:check_context_resource_profiles, order_dispatch_request_v211, 0, '2.2.1')

        task_calls = module_instance.resource_is_valid_calls.select do |c|
          c[:profile_url].include?('profile-task-dispatch')
        end
        expect(task_calls.first[:message_prefix]).to include('entry 1')
        expect(task_calls.last[:message_prefix]).to include('entry 2')
      end
    end

    context 'when the hook is appointment-book' do
      it 'validates the appointments bundle against the bundle-base profile' do
        module_instance.send(:check_context_resource_profiles, appointment_book_request, 0, '2.2.1')

        bundle_call = module_instance.resource_is_valid_calls.find do |c|
          c[:profile_url].include?('profile-bundle-base')
        end
        expect(bundle_call).to_not be_nil
        expect(bundle_call[:profile_url]).to include('2.2.1')
      end
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

  describe '#filter_and_manually_check_appointment_validation_errors' do
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

      result = module_instance.send(:filter_and_manually_check_appointment_validation_errors,
                                    [issue], appointment_without_slices, request_body)

      expect(result).to eq([issue])
    end

    it 'rejects filtered issues' do
      issue = IssueStub.new(filtered: true, location: nil, message: 'something', severity: 'error')

      result = module_instance.send(:filter_and_manually_check_appointment_validation_errors,
                                    [issue], appointment_without_slices, request_body)

      expect(result).to be_empty
    end

    it 'rejects the PrimaryPerformer slice error when the appointment has a PPRF participant' do
      result = module_instance.send(:filter_and_manually_check_appointment_validation_errors,
                                    [primary_performer_slice_error],
                                    appointment_with_performer_and_patient, request_body)

      expect(result).to be_empty
    end

    it 'keeps the PrimaryPerformer slice error when the appointment has no PPRF participant' do
      result = module_instance.send(:filter_and_manually_check_appointment_validation_errors,
                                    [primary_performer_slice_error],
                                    appointment_without_slices, request_body)

      expect(result).to eq([primary_performer_slice_error])
    end

    it 'rejects the Patient slice error when the appointment has a patient participant' do
      result = module_instance.send(:filter_and_manually_check_appointment_validation_errors,
                                    [patient_slice_error],
                                    appointment_with_performer_and_patient, request_body)

      expect(result).to be_empty
    end

    it 'keeps the Patient slice error when the appointment has no patient participant' do
      result = module_instance.send(:filter_and_manually_check_appointment_validation_errors,
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

        result = module_instance.send(:filter_and_manually_check_appointment_validation_errors,
                                      issues, appointment_with_performer_and_patient, request_body)

        expect(result).to be_empty
      end

      it 'keeps the "does not match any known slice" issue for non-matched participant indexes' do
        issues = [unmatched_participant_slice_issue, primary_performer_slice_error]

        result = module_instance.send(:filter_and_manually_check_appointment_validation_errors,
                                      issues, appointment_with_performer_and_patient, request_body)

        expect(result).to eq([unmatched_participant_slice_issue])
      end

      it 'keeps the "does not match any known slice" issue when no slice is resolved' do
        result = module_instance.send(:filter_and_manually_check_appointment_validation_errors,
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

  describe '#validate_request_against_logical_model' do
    describe 'when performing additional v2.2.1 verification' do
      it 'adds an error message when a resource in a context list does not have an id' do
        order_dispatch_request_v211.dig('context', 'fulfillmentTasks', 0).delete('id')

        module_instance.validate_request_against_logical_model(order_dispatch_request_v211, 0, '2.2.1')

        expect(module_instance.messages.length).to eq(1)
        message = module_instance.messages.first
        expect(message[:type]).to eq('error')
        expect(message[:message]).to eq('(Request 1) FHIR resources provided in the hook context must have an id, ' \
                                        'none found for `context.fulfillmentTasks` entry 1.')
      end

      it 'adds an error message when a context Bundle entry does not have an id' do
        order_sign_request.dig('context', 'draftOrders', 'entry', 0, 'resource').delete('id')

        module_instance.validate_request_against_logical_model(order_sign_request, 0, '2.2.1')

        expect(module_instance.messages.length).to eq(1)
        message = module_instance.messages.first
        expect(message[:type]).to eq('error')
        expect(message[:message]).to eq('(Request 1) FHIR resources provided in the hook context must have an id, ' \
                                        'none found for `context.draftOrders` entry 1.')
      end
    end
  end
end
