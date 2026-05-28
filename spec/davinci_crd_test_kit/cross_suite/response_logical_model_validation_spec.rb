require_relative '../../../lib/davinci_crd_test_kit/cross_suite/response_logical_model_validation'

MockValidationIssue = Struct.new(:message, :severity, :filtered, :location, keyword_init: true)

RSpec.describe DaVinciCRDTestKit::ResponseLogicalModelValidation do
  let(:module_instance) do
    Class.new do
      include DaVinciCRDTestKit::ResponseLogicalModelValidation

      attr_reader :messages, :conforms_calls, :resource_is_valid_calls, :resource_conformance_calls,
                  :coverage_profile_calls, :questionnaire_task_profile_calls
      attr_writer :injected_validation_issues

      def initialize
        @messages = []
        @conforms_calls = []
        @resource_is_valid_calls = []
        @resource_conformance_calls = []
        @coverage_profile_calls = []
        @questionnaire_task_profile_calls = []
        @injected_validation_issues = []
      end

      def add_message(type, message)
        @messages << { type:, message: }
      end

      def conforms_to_logical_model?(object, url, validator_response_details: nil, **kwargs)
        @conforms_calls << { object:, url:, **kwargs }
        validator_response_details&.concat(@injected_validation_issues)
        true
      end

      def resource_is_valid?(resource:, message_prefix: '')
        @resource_is_valid_calls << { resource:, message_prefix: }
        true
      end

      def check_resource_conformance_to_order_profile(resource_hash, request_body, error_prefix, ig_semver)
        @resource_conformance_calls << { resource_hash:, request_body:, error_prefix:, ig_semver: }
      end

      def check_resource_conformance_to_order_or_encounter_profile(resource_hash, request_body, error_prefix,
                                                                   ig_semver)
        @resource_conformance_calls << { resource_hash:, request_body:, error_prefix:, ig_semver: }
      end

      def check_resource_conformance_to_coverage_profile(resource_hash, error_prefix, ig_semver)
        @coverage_profile_calls << { resource_hash:, error_prefix:, ig_semver: }
      end

      def check_resource_conformance_to_questionnaire_task_profile(resource_hash, error_prefix, ig_semver)
        @questionnaire_task_profile_calls << { resource_hash:, error_prefix:, ig_semver: }
      end

      def scratch
        @scratch ||= {}
      end
    end.new
  end
  let(:additional_orders_card) { load_mock('companions_prerequisites.json') }
  let(:external_reference_card) { load_mock('external_reference.json') }
  let(:instructions_card) { load_mock('instructions.json') }
  let(:launch_smart_app_card) { load_mock('launch_smart_app.json') }
  let(:form_completion_card) { load_mock('request_form_completion.json') }
  let(:propose_alternate_request_card) do
    {
      'summary' => 'Propose Alternate Request Card',
      'indicator' => 'info',
      'source' => { 'label' => 'Inferno' },
      'selectionBehavior' => 'any',
      'suggestions' => [
        {
          'label' => 'Replace order with alternate',
          'actions' => [
            {
              'type' => 'update',
              'description' => 'Replace existing order',
              'resource' => { 'resourceType' => 'ServiceRequest', 'id' => 'existing-order' }
            }
          ]
        }
      ]
    }
  end
  let(:request_body) { { 'context' => { 'patientId' => 'p1' }, 'fhirServer' => 'http://example.com/fhir' } }
  let(:ig_semver) { '2.2.1' }
  let(:coverage_information_action) do
    JSON.parse(<<~JSON)
      {
        "type": "update",
        "description": "add coverage-information extension",
        "resource": {
          "resourceType": "ServiceRequest",
          "id": "existingSR",
          "extension": [{
            "url": "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information",
            "valueString": "sub-extensions elided"
          }],
          "status": "details elided"
        }
      }
    JSON
  end

  let(:coverage_update_action) do
    {
      'type' => 'update',
      'description' => 'Update coverage',
      'resource' => { 'resourceType' => 'Coverage', 'id' => 'cov1' }
    }
  end

  let(:form_completion_task_action) do
    {
      'type' => 'create',
      'description' => 'Create task',
      'resource' => {
        'resourceType' => 'Task',
        'id' => 'task1',
        'code' => { 'coding' => [{ 'code' => 'complete-questionnaire' }] },
        'input' => [{ 'type' => { 'text' => 'questionnaire' }, 'valueCanonical' => 'http://example.org/q' }]
      }
    }
  end

  let(:mocked_card_responses_dir) do
    File.join(__dir__, '..', '..', '..', 'lib', 'davinci_crd_test_kit', 'client', 'endpoints', 'mocked_card_responses')
  end

  def load_mock(name)
    JSON.parse(File.read(File.join(mocked_card_responses_dir, name)))
  end

  describe '#validate_card_against_logical_model' do
    it 'wraps an external reference card in a CDS Hooks response and validates it against the logical model' do
      module_instance.validate_card_against_logical_model(external_reference_card, 0, request_body, 0, ig_semver)

      expect(module_instance.conforms_calls.length).to eq(1)
      call = module_instance.conforms_calls.first
      expect(call[:object]).to eq('cards' => [external_reference_card])
      expect(call[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-externalReference')
    end

    it 'uses the additional orders logical model for additional-orders cards' do
      module_instance.validate_card_against_logical_model(additional_orders_card, 0, request_body, 0, ig_semver)

      expect(module_instance.conforms_calls.last[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-additionalOrders')
    end

    it 'uses the instructions logical model for instructions cards' do
      module_instance.validate_card_against_logical_model(instructions_card, 0, request_body, 0, ig_semver)

      expect(module_instance.conforms_calls.last[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-instructions')
    end

    it 'uses the launchSMART logical model for launch SMART app cards' do
      module_instance.validate_card_against_logical_model(launch_smart_app_card, 0, request_body, 0, ig_semver)

      expect(module_instance.conforms_calls.last[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-launchSMART')
    end

    it 'uses the formCompletion logical model for form completion cards' do
      module_instance.validate_card_against_logical_model(form_completion_card, 0, request_body, 0, ig_semver)

      expect(module_instance.conforms_calls.last[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-formCompletion')
    end

    it 'records an error and skips validation when a card is not a JSON object' do
      module_instance.validate_card_against_logical_model('not a card', 0, request_body, 0, ig_semver)

      expect(module_instance.conforms_calls).to be_empty
      expect(module_instance.messages).to include(
        hash_including(type: 'error', message: a_string_including('is not a JSON object'))
      )
    end

    it 'records a warning and validates uncategorized cards against the base logical model' do
      unknown_card = {
        'summary' => 'unknown', 'indicator' => 'info', 'source' => { 'label' => 'x' },
        'links' => [{ 'type' => 'smart' }, { 'type' => 'absolute' }]
      }

      module_instance.validate_card_against_logical_model(unknown_card, 0, request_body, 0, ig_semver)

      expect(module_instance.conforms_calls.length).to eq(1)
      expect(module_instance.conforms_calls.first[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponseBase')
      expect(module_instance.messages).to include(
        hash_including(type: 'warning', message: a_string_including('could not be categorized'))
      )
    end

    it 'filters out extension unrecognized property issues regardless of card type' do
      extension_issue = MockValidationIssue.new(
        message: 'CDSHooksResponse.cards[0].extension: Unrecognized property',
        severity: 'error',
        filtered: false
      )
      module_instance.injected_validation_issues = [extension_issue]
      module_instance.validate_card_against_logical_model(external_reference_card, 0, request_body, 0, ig_semver)

      expect(module_instance.messages).to_not include(
        hash_including(message: a_string_including('Unrecognized property'))
      )
    end

    context 'when validation returns a Questionnaire type error for a form completion card' do
      let(:questionnaire_error_message) do
        "CDSHooksResponse.cards[0].suggestions[0].actions[0].resource: The type 'Questionnaire' " \
          'is not valid - must be Task'
      end
      let(:other_error_message) { 'Some other validation error' }

      before do
        module_instance.injected_validation_issues = [
          MockValidationIssue.new(message: questionnaire_error_message, severity: 'error', filtered: false),
          MockValidationIssue.new(message: other_error_message, severity: 'warning', filtered: false)
        ]
      end

      it 'filters out the matched Questionnaire type error and does not add it as a message' do
        module_instance.validate_card_against_logical_model(form_completion_card, 0, request_body, 0, ig_semver)

        expect(module_instance.messages).to_not include(
          hash_including(message: a_string_including("The type 'Questionnaire' is not valid"))
        )
      end

      it 'calls resource_is_valid? on the Questionnaire resource at the referenced path' do
        module_instance.validate_card_against_logical_model(form_completion_card, 0, request_body, 0, ig_semver)

        expect(module_instance.resource_is_valid_calls.length).to eq(1)
        call = module_instance.resource_is_valid_calls.first
        expect(call[:resource].resourceType).to eq('Questionnaire')
        expect(call[:message_prefix]).to include('suggestion 1, action 1')
      end

      it 'does not filter out other validation errors' do
        module_instance.validate_card_against_logical_model(form_completion_card, 0, request_body, 0, ig_semver)

        expect(module_instance.messages).to include(
          hash_including(message: a_string_including(other_error_message))
        )
      end
    end

    context 'when a Questionnaire type error has an unexpected message format' do
      it 'raises with an implementation problem message when indexes cannot be extracted' do
        bad_format_issue = MockValidationIssue.new(
          message: "The type 'Questionnaire' is not valid - must be Task",
          severity: 'error',
          filtered: false
        )
        module_instance.injected_validation_issues = [bad_format_issue]

        expect do
          module_instance.validate_card_against_logical_model(form_completion_card, 0, request_body, 0, ig_semver)
        end.to raise_error(RuntimeError, /implementation problem in the test kit/)
      end
    end

    context 'when validating additional orders cards' do
      let(:other_error) { MockValidationIssue.new(message: 'Some other error', severity: 'warning', filtered: false) }

      it 'does not filter out validation errors' do
        module_instance.injected_validation_issues = [other_error]
        module_instance.validate_card_against_logical_model(additional_orders_card, 0, request_body, 0, ig_semver)

        expect(module_instance.messages).to include(
          hash_including(message: a_string_including('Some other error'))
        )
      end

      it 'checks conformance of action resources against order profiles' do
        module_instance.validate_card_against_logical_model(additional_orders_card, 0, request_body, 0, ig_semver)

        expect(module_instance.resource_conformance_calls).to_not be_empty
        call = module_instance.resource_conformance_calls.first
        expect(call[:resource_hash]['resourceType']).to eq('ServiceRequest')
        expect(call[:ig_semver]).to eq(ig_semver)
      end
    end

    context 'when validating propose alternative cards' do
      let(:create_fixed_error) do
        MockValidationIssue.new(
          message: "This element has a value of 'update' but is fixed to 'create' in the profile",
          severity: 'error',
          filtered: false
        )
      end
      let(:other_error) { MockValidationIssue.new(message: 'Some other error', severity: 'warning', filtered: false) }

      it 'filters out the fixed-to-create validator error' do
        module_instance.injected_validation_issues = [create_fixed_error]
        module_instance.validate_card_against_logical_model(propose_alternate_request_card, 0, request_body, 0,
                                                            ig_semver)

        expect(module_instance.messages).to_not include(
          hash_including(message: a_string_including("fixed to 'create'"))
        )
      end

      it 'does not filter out other validation errors' do
        module_instance.injected_validation_issues = [create_fixed_error, other_error]
        module_instance.validate_card_against_logical_model(propose_alternate_request_card, 0, request_body, 0,
                                                            ig_semver)

        expect(module_instance.messages).to include(
          hash_including(message: a_string_including('Some other error'))
        )
      end
    end
  end

  describe '#validate_system_action_against_logical_model' do
    it 'wraps the action in a CDS Hooks response and uses the coverageInformation logical model' do
      module_instance.validate_system_action_against_logical_model(coverage_information_action, 2, request_body, 1,
                                                                   ig_semver)

      expect(module_instance.conforms_calls.length).to eq(1)
      call = module_instance.conforms_calls.first
      expect(call[:object]).to eq('systemActions' => [coverage_information_action])
      expect(call[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-coverageInformation')
    end

    it 'records an error and skips validation when a system action is not a JSON object' do
      module_instance.validate_system_action_against_logical_model('not an action', 0, request_body, 0, ig_semver)

      expect(module_instance.conforms_calls).to be_empty
      expect(module_instance.messages).to include(
        hash_including(type: 'error', message: a_string_including('is not a JSON object'))
      )
    end

    it 'records a warning and validates uncategorized actions against the base logical model' do
      unknown_action = { 'type' => 'update', 'description' => 'x',
                         'resource' => { 'resourceType' => 'Patient', 'id' => 'p' } }

      module_instance.validate_system_action_against_logical_model(unknown_action, 0, request_body, 0, ig_semver)

      expect(module_instance.conforms_calls.length).to eq(1)
      expect(module_instance.conforms_calls.first[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponseBase')
      expect(module_instance.messages).to include(
        hash_including(type: 'warning', message: a_string_including('could not be categorized'))
      )
    end

    it 'filters out extension unrecognized property issues regardless of action type' do
      unknown_action = { 'type' => 'update', 'description' => 'x',
                         'resource' => { 'resourceType' => 'Patient', 'id' => 'p' } }
      extension_issue = MockValidationIssue.new(
        message: 'CDSHooksResponse.systemActions[0].extension: Unrecognized property',
        severity: 'error',
        filtered: false
      )
      module_instance.injected_validation_issues = [extension_issue]
      module_instance.validate_system_action_against_logical_model(unknown_action, 0, request_body, 0, ig_semver)

      expect(module_instance.messages).to_not include(
        hash_including(message: a_string_including('Unrecognized property'))
      )
    end

    context 'when validating coverage information actions' do
      let(:resource_path_error) do
        MockValidationIssue.new(
          message: 'CDSHooksResponse.systemActions[0].resource: ' \
                   'Unable to find a match for the specified profile among choices',
          severity: 'error',
          filtered: false,
          location: nil
        )
      end
      let(:non_resource_error) do
        MockValidationIssue.new(
          message: 'Some top-level validation error',
          severity: 'warning',
          filtered: false,
          location: nil
        )
      end

      it 'calls check_resource_conformance_to_order_or_encounter_profile when the action has a resource' do
        module_instance.validate_system_action_against_logical_model(coverage_information_action, 0, request_body, 0,
                                                                     ig_semver)

        expect(module_instance.resource_conformance_calls).to_not be_empty
        call = module_instance.resource_conformance_calls.first
        expect(call[:resource_hash]['resourceType']).to eq('ServiceRequest')
        expect(call[:ig_semver]).to eq(ig_semver)
      end

      it 'suppresses logical model resource path issues (resource is checked manually)' do
        module_instance.injected_validation_issues = [resource_path_error]
        module_instance.validate_system_action_against_logical_model(coverage_information_action, 0, request_body, 0,
                                                                     ig_semver)

        expect(module_instance.messages).to_not include(
          hash_including(message: a_string_including('Unable to find a match'))
        )
      end

      it 'reports non-resource validation issues from the logical model' do
        module_instance.injected_validation_issues = [non_resource_error]
        module_instance.validate_system_action_against_logical_model(coverage_information_action, 0, request_body, 0,
                                                                     ig_semver)

        expect(module_instance.messages).to include(
          hash_including(message: a_string_including('Some top-level validation error'))
        )
      end
    end

    context 'when validating create/update coverage system actions' do
      let(:wrong_type_coverage_action) do
        {
          'type' => 'create',
          'description' => 'Create coverage',
          'resource' => { 'resourceType' => 'Coverage', 'id' => 'cov1' }
        }
      end
      let(:resource_path_error) do
        MockValidationIssue.new(
          message: 'CDSHooksResponse.systemActions[0].resource: ' \
                   'Unable to find a match for the specified profile among choices',
          severity: 'error',
          filtered: false,
          location: nil
        )
      end
      let(:non_resource_error) do
        MockValidationIssue.new(
          message: 'Some top-level validation error',
          severity: 'warning',
          filtered: false,
          location: nil
        )
      end

      it 'uses the base logical model URL, not the adjust-coverage model' do
        module_instance.validate_system_action_against_logical_model(coverage_update_action, 0, request_body, 0,
                                                                     ig_semver)

        expect(module_instance.conforms_calls.first[:url])
          .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponseBase')
      end

      it 'reports an error when action type is not update' do
        module_instance.validate_system_action_against_logical_model(wrong_type_coverage_action, 0, request_body, 0,
                                                                     ig_semver)

        expect(module_instance.messages).to include(
          hash_including(type: 'error', message: a_string_including("action type must be 'update'"))
        )
      end

      it 'calls check_resource_conformance_to_coverage_profile when the action has a resource' do
        module_instance.validate_system_action_against_logical_model(coverage_update_action, 0, request_body, 0,
                                                                     ig_semver)

        expect(module_instance.coverage_profile_calls).to_not be_empty
        call = module_instance.coverage_profile_calls.first
        expect(call[:resource_hash]['resourceType']).to eq('Coverage')
        expect(call[:ig_semver]).to eq(ig_semver)
      end

      it 'suppresses logical model resource path issues (resource is checked manually)' do
        module_instance.injected_validation_issues = [resource_path_error]
        module_instance.validate_system_action_against_logical_model(coverage_update_action, 0, request_body, 0,
                                                                     ig_semver)

        expect(module_instance.messages).to_not include(
          hash_including(message: a_string_including('Unable to find a match'))
        )
      end

      it 'reports non-resource validation issues from the logical model' do
        module_instance.injected_validation_issues = [non_resource_error]
        module_instance.validate_system_action_against_logical_model(coverage_update_action, 0, request_body, 0,
                                                                     ig_semver)

        expect(module_instance.messages).to include(
          hash_including(message: a_string_including('Some top-level validation error'))
        )
      end
    end

    context 'when validating form completion system actions' do
      let(:resource_path_error) do
        MockValidationIssue.new(
          message: 'CDSHooksResponse.systemActions[0].resource: ' \
                   'Unable to find a match for the specified profile among choices',
          severity: 'error',
          filtered: false,
          location: nil
        )
      end
      let(:non_resource_error) do
        MockValidationIssue.new(
          message: 'Some top-level validation error',
          severity: 'warning',
          filtered: false,
          location: nil
        )
      end

      it 'uses the base logical model URL, not the form-completion model' do
        module_instance.validate_system_action_against_logical_model(form_completion_task_action, 0, request_body, 0,
                                                                     ig_semver)

        expect(module_instance.conforms_calls.first[:url])
          .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponseBase')
      end

      it 'calls check_resource_conformance_to_questionnaire_task_profile when the action has a resource' do
        module_instance.validate_system_action_against_logical_model(form_completion_task_action, 0, request_body, 0,
                                                                     ig_semver)

        expect(module_instance.questionnaire_task_profile_calls).to_not be_empty
        call = module_instance.questionnaire_task_profile_calls.first
        expect(call[:resource_hash]['resourceType']).to eq('Task')
        expect(call[:ig_semver]).to eq(ig_semver)
      end

      it 'suppresses logical model resource path issues (resource is checked manually)' do
        module_instance.injected_validation_issues = [resource_path_error]
        module_instance.validate_system_action_against_logical_model(form_completion_task_action, 0, request_body, 0,
                                                                     ig_semver)

        expect(module_instance.messages).to_not include(
          hash_including(message: a_string_including('Unable to find a match'))
        )
      end

      it 'reports non-resource validation issues from the logical model' do
        module_instance.injected_validation_issues = [non_resource_error]
        module_instance.validate_system_action_against_logical_model(form_completion_task_action, 0, request_body, 0,
                                                                     ig_semver)

        expect(module_instance.messages).to include(
          hash_including(message: a_string_including('Some top-level validation error'))
        )
      end
    end
  end

  describe '#perform_response_logical_model_validation' do
    it 'validates each card and each system action independently' do
      module_instance.perform_response_logical_model_validation(
        [external_reference_card, instructions_card],
        [coverage_information_action],
        request_body,
        0,
        ig_semver
      )

      expect(module_instance.conforms_calls.length).to eq(3)
      urls = module_instance.conforms_calls.map { |c| c[:url] }
      expect(urls).to include(
        'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-externalReference',
        'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-instructions',
        'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-coverageInformation'
      )
    end

    it 'handles missing cards and systemActions gracefully' do
      expect do
        module_instance.perform_response_logical_model_validation(nil, nil, request_body, 0, ig_semver)
      end.to_not raise_error
      expect(module_instance.conforms_calls).to be_empty
    end
  end
end
