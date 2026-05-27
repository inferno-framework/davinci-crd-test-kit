require_relative '../../lib/davinci_crd_test_kit/cross_suite/cards_logical_model_validation'

MockValidationIssue = Struct.new(:message, :severity, :filtered, keyword_init: true)

RSpec.describe DaVinciCRDTestKit::CardsLogicalModelValidation do
  let(:module_instance) do
    Class.new do
      include DaVinciCRDTestKit::CardsLogicalModelValidation

      attr_reader :messages, :conforms_calls, :resource_is_valid_calls
      attr_writer :injected_validation_issues

      def initialize
        @messages = []
        @conforms_calls = []
        @resource_is_valid_calls = []
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

  let(:mocked_card_responses_dir) do
    File.join(__dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'client', 'endpoints', 'mocked_card_responses')
  end

  def load_mock(name)
    JSON.parse(File.read(File.join(mocked_card_responses_dir, name)))
  end

  describe '#validate_card_against_logical_model' do
    it 'wraps an external reference card in a CDS Hooks response and validates it against the logical model' do
      module_instance.validate_card_against_logical_model(external_reference_card, 0, 0)

      expect(module_instance.conforms_calls.length).to eq(1)
      call = module_instance.conforms_calls.first
      expect(call[:object]).to eq('cards' => [external_reference_card])
      expect(call[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-externalReference')
    end

    it 'uses the additional orders logical model for additional-orders cards' do
      module_instance.validate_card_against_logical_model(additional_orders_card, 0, 0)

      expect(module_instance.conforms_calls.last[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-additionalOrders')
    end

    it 'uses the instructions logical model for instructions cards' do
      module_instance.validate_card_against_logical_model(instructions_card, 0, 0)

      expect(module_instance.conforms_calls.last[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-instructions')
    end

    it 'uses the launchSMART logical model for launch SMART app cards' do
      module_instance.validate_card_against_logical_model(launch_smart_app_card, 0, 0)

      expect(module_instance.conforms_calls.last[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-launchSMART')
    end

    it 'uses the formCompletion logical model for form completion cards' do
      module_instance.validate_card_against_logical_model(form_completion_card, 0, 0)

      expect(module_instance.conforms_calls.last[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-formCompletion')
    end

    it 'records an error and skips validation when a card is not a JSON object' do
      module_instance.validate_card_against_logical_model('not a card', 0, 0)

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

      module_instance.validate_card_against_logical_model(unknown_card, 0, 0)

      expect(module_instance.conforms_calls.length).to eq(1)
      expect(module_instance.conforms_calls.first[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponseBase')
      expect(module_instance.messages).to include(
        hash_including(type: 'warning', message: a_string_including('could not be categorized'))
      )
    end

    context 'when validation returns a Questionnaire type error for a form completion card' do
      let(:questionnaire_error_message) do
        "CDSHooksResponse.cards[0].suggestions[0].actions[0].resource: The type 'Questionnaire' is not valid - must be Task"
      end
      let(:other_error_message) { 'Some other validation error' }

      before do
        module_instance.injected_validation_issues = [
          MockValidationIssue.new(message: questionnaire_error_message, severity: 'error', filtered: false),
          MockValidationIssue.new(message: other_error_message, severity: 'warning', filtered: false)
        ]
      end

      it 'filters out the matched Questionnaire type error and does not add it as a message' do
        module_instance.validate_card_against_logical_model(form_completion_card, 0, 0)

        expect(module_instance.messages).to_not include(
          hash_including(message: a_string_including("The type 'Questionnaire' is not valid"))
        )
      end

      it 'calls resource_is_valid? on the Questionnaire resource at the referenced path' do
        module_instance.validate_card_against_logical_model(form_completion_card, 0, 0)

        expect(module_instance.resource_is_valid_calls.length).to eq(1)
        call = module_instance.resource_is_valid_calls.first
        expect(call[:resource].resourceType).to eq('Questionnaire')
        expect(call[:message_prefix]).to include('suggestions[0].actions[0].resource')
      end

      it 'does not filter out other validation errors' do
        module_instance.validate_card_against_logical_model(form_completion_card, 0, 0)

        expect(module_instance.messages).to include(
          hash_including(message: a_string_including(other_error_message))
        )
      end
    end
  end

  describe '#validate_system_action_against_logical_model' do
    it 'wraps the action in a CDS Hooks response and uses the coverageInformation logical model' do
      module_instance.validate_system_action_against_logical_model(coverage_information_action, 2, 1)

      expect(module_instance.conforms_calls.length).to eq(1)
      call = module_instance.conforms_calls.first
      expect(call[:object]).to eq('systemActions' => [coverage_information_action])
      expect(call[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponse-coverageInformation')
      expect(call[:message_prefix]).to include('Server response 3 systemAction 2')
      expect(call[:message_prefix]).to include('coverage_information')
    end

    it 'records an error and skips validation when a system action is not a JSON object' do
      module_instance.validate_system_action_against_logical_model('not an action', 0, 0)

      expect(module_instance.conforms_calls).to be_empty
      expect(module_instance.messages).to include(
        hash_including(type: 'error', message: a_string_including('is not a JSON object'))
      )
    end

    it 'records a warning and validates uncategorized actions against the base logical model' do
      unknown_action = { 'type' => 'update', 'description' => 'x',
                         'resource' => { 'resourceType' => 'Patient', 'id' => 'p' } }

      module_instance.validate_system_action_against_logical_model(unknown_action, 0, 0)

      expect(module_instance.conforms_calls.length).to eq(1)
      expect(module_instance.conforms_calls.first[:url])
        .to eq('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksResponseBase')
      expect(module_instance.messages).to include(
        hash_including(type: 'warning', message: a_string_including('could not be categorized'))
      )
    end
  end

  describe '#perform_cards_logical_model_validation' do
    it 'validates each card and each system action independently' do
      module_instance.perform_cards_logical_model_validation(
        [external_reference_card, instructions_card],
        [coverage_information_action],
        0
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
      expect { module_instance.perform_cards_logical_model_validation(nil, nil, 0) }.to_not raise_error
      expect(module_instance.conforms_calls).to be_empty
    end
  end
end
