RSpec.describe DaVinciCRDTestKit::CardsIdentification do
  let(:module_instance) do
    Class.new do
      include DaVinciCRDTestKit::CardsIdentification
    end.new
  end

  let(:additional_orders_template) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses',
                           'companions_prerequisites.json'
                         )))
  end
  let(:create_coverage_card_template) do
    template = JSON.parse(File.read(File.join(
                                      __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses',
                                      'create_update_coverage_information.json'
                                    )))
    template['suggestions'].first['actions'] = JSON.parse('[{
      "type": "create",
      "description": "create new coverage",
      "resource": { "resourceType": "Coverage", "id": "newCov", "status": "details elided" }
    }]')

    template
  end
  let(:create_coverage_action_template) { create_coverage_card_template['suggestions'][0]['actions'][0] }
  let(:update_coverage_card_template) do
    template = JSON.parse(File.read(File.join(
                                      __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses',
                                      'create_update_coverage_information.json'
                                    )))
    template['suggestions'].first['actions'] = JSON.parse('[{
      "type": "update",
      "description": "update existing coverage",
      "resource": { "resourceType": "Coverage", "id": "existingCov", "status": "details elided" }
    }]')

    template
  end
  let(:update_coverage_action_template) { update_coverage_card_template['suggestions'][0]['actions'][0] }
  let(:coverage_information_action_template) do
    JSON.parse('{
      "type": "update",
      "description": "add coverage-information extension",
      "resource": { "resourceType": "ServiceReqeuest", "id": "existingSR", "extension": [{ "url": "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information", "valueString": "sub-extensions elided" }], "status": "details elided" }
    }')
  end
  let(:external_reference_template) do
    JSON.parse(File.read(
                 File.join(
                   __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses', 'external_reference.json'
                 )
               ))
  end
  let(:form_completion_card_template) do
    JSON.parse(File.read(
                 File.join(
                   __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses', 'request_form_completion.json'
                 )
               ))
  end
  let(:form_completion_action_template) { form_completion_card_template['suggestions'][0]['actions'][1] }
  let(:instructions_card_template) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses', 'instructions.json'
                         )))
  end
  let(:launch_smart_app_template) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses', 'launch_smart_app.json'
                         )))
  end
  let(:propose_alternate_delete_create_card_template) do
    template = JSON.parse(
      File.read(File.join(
                  __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses', 'propose_alternate_request.json'
                ))
    )
    template['suggestions'].first['actions'] << JSON.parse('{
      "type": "delete",
      "description": "remove the propsed order",
      "resourceId": "ServiceRequest/oldSR"
    }')
    template['suggestions'].first['actions'] << JSON.parse('{
      "type": "create",
      "description": "create a new order",
      "resource": { "resourceType": "ServiceRequest", "id": "newSR", "status": "details elided" }
    }')

    template
  end
  let(:propose_alternate_update_card_template) do
    template = JSON.parse(
      File.read(File.join(
                  __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses', 'propose_alternate_request.json'
                ))
    )
    template['suggestions'].first['actions'] << JSON.parse('{
      "type": "delete",
      "description": "remove the propsed order",
      "resourceId": "ServiceRequest/oldSR"
    }')
    template['suggestions'].first['actions'] << JSON.parse('{
      "type": "update",
      "description": "update an existing order",
      "resource": { "resourceType": "ServiceRequest", "id": "existingSR", "status": "updated details elided" }
    }')

    template
  end

  describe 'when identifying additional orders cards' do
    it 'correctly identifies the type' do
      expect(module_instance.identify_card_type(additional_orders_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::ADDITIONAL_ORDERS_RESPONSE_TYPE)
    end

    it 'returns true for a matching card' do
      expect(module_instance.additional_orders_response_type?(additional_orders_template)).to be(true)
    end

    it 'returns false for a non-matching cards' do
      expect(module_instance).to_not be_additional_orders_response_type(create_coverage_card_template)
      expect(module_instance).to_not be_additional_orders_response_type(update_coverage_card_template)
      expect(module_instance).to_not be_additional_orders_response_type(external_reference_template)
      expect(module_instance).to_not be_additional_orders_response_type(form_completion_card_template)
      expect(module_instance).to_not be_additional_orders_response_type(instructions_card_template)
      expect(module_instance).to_not be_additional_orders_response_type(launch_smart_app_template)
      expect(module_instance).to_not be_additional_orders_response_type(propose_alternate_delete_create_card_template)
      expect(module_instance).to_not be_additional_orders_response_type(propose_alternate_update_card_template)
    end
  end

  describe 'when identifying create or update coverage cards' do
    it 'correctly identifies the type' do
      expect(module_instance.identify_card_type(create_coverage_card_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE)
      expect(module_instance.identify_card_type(update_coverage_card_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE)
    end

    it 'returns true for a matching card' do
      expect(module_instance.create_or_update_coverage_card_response_type?(create_coverage_card_template)).to be(true)
      expect(module_instance.create_or_update_coverage_card_response_type?(update_coverage_card_template)).to be(true)
    end

    it 'returns false for a non-matching cards' do
      expect(module_instance).to_not be_create_or_update_coverage_card_response_type(additional_orders_template)
      expect(module_instance).to_not be_create_or_update_coverage_card_response_type(external_reference_template)
      expect(module_instance).to_not be_create_or_update_coverage_card_response_type(form_completion_card_template)
      expect(module_instance).to_not be_create_or_update_coverage_card_response_type(instructions_card_template)
      expect(module_instance).to_not be_create_or_update_coverage_card_response_type(launch_smart_app_template)
      expect(module_instance).to_not be_create_or_update_coverage_card_response_type(
        propose_alternate_delete_create_card_template
      )
      expect(module_instance).to_not be_create_or_update_coverage_card_response_type(
        propose_alternate_update_card_template
      )
    end
  end

  describe 'when identifying external reference cards' do
    it 'correctly identifies the type' do
      expect(module_instance.identify_card_type(external_reference_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::EXTERNAL_REFERENCE_RESPONSE_TYPE)
    end

    it 'returns true for a matching card' do
      expect(module_instance.external_reference_response_type?(external_reference_template)).to be(true)
    end

    it 'returns false for a non-matching cards' do
      expect(module_instance).to_not be_external_reference_response_type(additional_orders_template)
      expect(module_instance).to_not be_external_reference_response_type(create_coverage_card_template)
      expect(module_instance).to_not be_external_reference_response_type(update_coverage_card_template)
      expect(module_instance).to_not be_external_reference_response_type(form_completion_card_template)
      expect(module_instance).to_not be_external_reference_response_type(instructions_card_template)
      expect(module_instance).to_not be_external_reference_response_type(launch_smart_app_template)
      expect(module_instance).to_not be_external_reference_response_type(propose_alternate_delete_create_card_template)
      expect(module_instance).to_not be_external_reference_response_type(propose_alternate_update_card_template)
    end
  end

  describe 'when identifying form completion cards' do
    it 'correctly identifies the type' do
      expect(module_instance.identify_card_type(form_completion_card_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::FORM_COMPLETION_RESPONSE_TYPE)
    end

    it 'returns true for a matching card' do
      expect(module_instance.form_completion_card_response_type?(form_completion_card_template)).to be(true)
    end

    it 'returns false for a non-matching cards' do
      expect(module_instance).to_not be_form_completion_card_response_type(additional_orders_template)
      expect(module_instance).to_not be_form_completion_card_response_type(create_coverage_card_template)
      expect(module_instance).to_not be_form_completion_card_response_type(update_coverage_card_template)
      expect(module_instance).to_not be_form_completion_card_response_type(external_reference_template)
      expect(module_instance).to_not be_form_completion_card_response_type(instructions_card_template)
      expect(module_instance).to_not be_form_completion_card_response_type(launch_smart_app_template)
      expect(module_instance).to_not be_form_completion_card_response_type(
        propose_alternate_delete_create_card_template
      )
      expect(module_instance).to_not be_form_completion_card_response_type(propose_alternate_update_card_template)
    end
  end

  describe 'when identifying instructions cards' do
    it 'correctly identifies the type' do
      expect(module_instance.identify_card_type(instructions_card_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::INSTRUCTIONS_RESPONSE_TYPE)
    end

    it 'returns true for a matching card' do
      expect(module_instance.instructions_response_type?(instructions_card_template)).to be(true)
    end

    it 'returns false for a non-matching cards' do
      expect(module_instance).to_not be_instructions_response_type(additional_orders_template)
      expect(module_instance).to_not be_instructions_response_type(create_coverage_card_template)
      expect(module_instance).to_not be_instructions_response_type(update_coverage_card_template)
      expect(module_instance).to_not be_instructions_response_type(external_reference_template)
      expect(module_instance).to_not be_instructions_response_type(form_completion_card_template)
      expect(module_instance).to_not be_instructions_response_type(launch_smart_app_template)
      expect(module_instance).to_not be_instructions_response_type(propose_alternate_delete_create_card_template)
      expect(module_instance).to_not be_instructions_response_type(propose_alternate_update_card_template)
    end
  end

  describe 'when identifying launch smart app cards' do
    it 'correctly identifies the type' do
      expect(module_instance.identify_card_type(launch_smart_app_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::LAUNCH_SMART_APP_RESPONSE_TYPE)
    end

    it 'returns true for a matching card' do
      expect(module_instance.launch_smart_app_response_type?(launch_smart_app_template)).to be(true)
    end

    it 'returns false for a non-matching cards' do
      expect(module_instance).to_not be_launch_smart_app_response_type(additional_orders_template)
      expect(module_instance).to_not be_launch_smart_app_response_type(create_coverage_card_template)
      expect(module_instance).to_not be_launch_smart_app_response_type(update_coverage_card_template)
      expect(module_instance).to_not be_launch_smart_app_response_type(external_reference_template)
      expect(module_instance).to_not be_launch_smart_app_response_type(form_completion_card_template)
      expect(module_instance).to_not be_launch_smart_app_response_type(instructions_card_template)
      expect(module_instance).to_not be_launch_smart_app_response_type(propose_alternate_delete_create_card_template)
      expect(module_instance).to_not be_launch_smart_app_response_type(propose_alternate_update_card_template)
    end
  end

  describe 'when identifying propose alternate request cards' do
    it 'correctly identifies the type' do
      expect(module_instance.identify_card_type(propose_alternate_delete_create_card_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::PROPOSE_ALTERNATIVE_REQUEST_RESPONSE_TYPE)
      expect(module_instance.identify_card_type(propose_alternate_update_card_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::PROPOSE_ALTERNATIVE_REQUEST_RESPONSE_TYPE)
    end

    it 'returns true for a matching card' do
      expect(module_instance.propose_alternative_request_response_type?(propose_alternate_delete_create_card_template))
        .to be(true)
      expect(module_instance.propose_alternative_request_response_type?(propose_alternate_update_card_template))
        .to be(true)
    end

    it 'returns false for a non-matching cards' do
      expect(module_instance).to_not be_propose_alternative_request_response_type(additional_orders_template)
      expect(module_instance).to_not be_propose_alternative_request_response_type(create_coverage_card_template)
      expect(module_instance).to_not be_propose_alternative_request_response_type(update_coverage_card_template)
      expect(module_instance).to_not be_propose_alternative_request_response_type(external_reference_template)
      expect(module_instance).to_not be_propose_alternative_request_response_type(form_completion_card_template)
      expect(module_instance).to_not be_propose_alternative_request_response_type(instructions_card_template)
      expect(module_instance).to_not be_propose_alternative_request_response_type(launch_smart_app_template)
    end
  end

  describe 'when identifying coverage information actions' do
    it 'correctly identifies the type' do
      expect(module_instance.identify_action_type(coverage_information_action_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::COVERAGE_INFORMATION_RESPONSE_TYPE)
    end

    it 'returns true for a matching card' do
      expect(module_instance.coverage_information_response_type?(coverage_information_action_template)).to be(true)
    end

    it 'returns false for a non-matching cards' do
      expect(module_instance).to_not be_coverage_information_response_type(create_coverage_action_template)
      expect(module_instance).to_not be_coverage_information_response_type(update_coverage_action_template)
      expect(module_instance).to_not be_coverage_information_response_type(form_completion_action_template)
    end
  end

  describe 'when identifying create or update coverage actions' do
    it 'correctly identifies the type' do
      expect(module_instance.identify_action_type(create_coverage_action_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE)
      expect(module_instance.identify_action_type(update_coverage_action_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE)
    end

    it 'returns true for a matching card' do
      expect(module_instance.create_or_update_coverage_action_response_type?(create_coverage_action_template))
        .to be(true)
      expect(module_instance.create_or_update_coverage_action_response_type?(update_coverage_action_template))
        .to be(true)
    end

    it 'returns false for a non-matching cards' do
      expect(module_instance).to_not be_create_or_update_coverage_action_response_type(form_completion_action_template)
    end
  end

  describe 'when identifying form completion actions' do
    it 'correctly identifies the type' do
      expect(module_instance.identify_action_type(form_completion_action_template))
        .to eq(DaVinciCRDTestKit::CardsIdentification::FORM_COMPLETION_RESPONSE_TYPE)
    end

    it 'returns true for a matching card' do
      expect(module_instance.form_completion_action_response_type?(form_completion_action_template)).to be(true)
    end

    it 'returns false for a non-matching cards' do
      expect(module_instance).to_not be_form_completion_action_response_type(create_coverage_action_template)
      expect(module_instance).to_not be_form_completion_action_response_type(update_coverage_action_template)
    end
  end
end
