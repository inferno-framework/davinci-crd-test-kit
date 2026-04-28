require_relative '../../lib/davinci_crd_test_kit/cross_suite/cards_logical_model_validation'

RSpec.describe DaVinciCRDTestKit::CardsLogicalModelValidation do
  let(:module_instance) do
    Class.new do
      include DaVinciCRDTestKit::CardsLogicalModelValidation

      attr_reader :messages, :conforms_calls

      def initialize
        @messages = []
        @conforms_calls = []
      end

      def add_message(type, message)
        @messages << { type:, message: }
      end

      def conforms_to_logical_model?(object, url, message_prefix: '')
        @conforms_calls << { object:, url:, message_prefix: }
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
      expect(call[:message_prefix]).to include('Server response 1 card 1')
      expect(call[:message_prefix]).to include('external_reference')
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
