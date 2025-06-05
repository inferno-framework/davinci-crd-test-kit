require_relative '../../lib/davinci_crd_test_kit/client_tests/hook_request_valid_context_test'
require_relative '../../lib/davinci_crd_test_kit/jwt_helper'

RSpec.describe DaVinciCRDTestKit::HookRequestValidContextTest do
  let(:suite_id) { 'crd_client' }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:order_sign_url) { "#{base_url}/cds-services/order-sign-service" }
  let(:client_fhir_server) { 'https://example/r4' }
  let(:client_bearer_token) { 'SAMPLE_TOKEN' }
  let(:nutrition_order_profile) { 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-nutritionorder' }

  let(:order_sign_hook_request) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'order_sign_hook_request.json'
                ))
    )
  end

  let(:order_sign_context) do
    order_sign_hook_request['context']
  end

  let(:crd_patient) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_patient_example.json'
                ))
    )
  end

  let(:crd_practitioner) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_practitioner_example.json'
                ))
    )
  end

  let(:crd_encounter) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_encounter_example.json'
                ))
    )
  end

  let(:operation_outcome_success) do
    {
      outcomes: [{
        issues: []
      }],
      sessionId: 'b8cf5547-1dc7-4714-a797-dc2347b93fe2'
    }
  end

  let(:operation_outcome_failure) do
    {
      outcomes: [{
        issues: [{
          level: 'ERROR',
          message: 'Resource does not conform to profile'
        }]
      }],
      sessionId: 'b8cf5547-1dc7-4714-a797-dc2347b93fe2'
    }
  end

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  describe 'Order Sign Hook Valid Context' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::HookRequestValidContextTest) do
        fhir_resource_validator do
          url ENV.fetch('CRD_FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.us.davinci-crd', 'hl7.fhir.us.core')
        end
        config(
          options: { hook_name: 'order-sign' }
        )
      end
    end

    it 'passes if hook request `context` contains all required fields and fhir resources are valid' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)
      patient_resource_request = stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      practitioner_resource_request = stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token,
                   contexts: [order_sign_context].to_json)

      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(4)
      expect(patient_resource_request).to have_been_made
      expect(practitioner_resource_request).to have_been_made
    end

    it 'passes if multiple hook requests have `context` that contains all required fields and valid fhir resources' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)
      patient_resource_request = stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      practitioner_resource_request = stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)

      result = run(test, client_fhir_server:, client_access_token: client_bearer_token,
                         contexts:
                         [order_sign_context, order_sign_context].to_json)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(8)
      expect(patient_resource_request).to have_been_made.times(2)
      expect(practitioner_resource_request).to have_been_made.times(2)
    end

    it 'fails if one of multiple hook requests are invalid' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)
      patient_resource_request = stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      practitioner_resource_request = stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)

      invalid_hook_request = order_sign_context.except('patientId')

      result = run(test, client_fhir_server:, client_access_token: client_bearer_token,
                         contexts:
                         [order_sign_context, invalid_hook_request].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /Request 2: order-sign request context does not contain required field `patientId`/
      )
      expect(validation_request).to have_been_made.times(7)
      expect(patient_resource_request).to have_been_made
      expect(practitioner_resource_request).to have_been_made.times(2)
    end

    it 'skips if no client fhir server url is found' do
      result = run(test, contexts: [order_sign_context].to_json)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq(
        "Input 'client_fhir_server' is nil, skipping test."
      )
    end

    it 'fails if request body is does not contain the `context` field' do
      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token,
                   contexts: [nil].to_json)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No order-sign requests contained the `context` field.')
    end

    it 'fails if context does not contain all required fields' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)
      order_sign_context.delete('patientId')

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token,
                   contexts: [order_sign_context].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /order-sign request context does not contain required field `patientId`/
      )
    end

    it 'fails if resource type and id cannot be extracted from context `userId` field' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      order_sign_context['userId'] = '/'

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token,
                   contexts: [order_sign_context].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Invalid `userId` format./)
    end

    it 'fails if context `userId` field resource type is not valid' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      order_sign_context['userId'] = 'Observation/example'

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token,
                   contexts: [order_sign_context].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Unsupported resource type: `userId` type should be/)
    end

    it 'fails if client fhir server returns non 200 response' do
      practitioner_resource_request = stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 404)
      patient_resource_request = stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token,
                   contexts: [order_sign_context].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Unexpected response status: expected 200, but received 404/)
      expect(practitioner_resource_request).to have_been_made
      expect(patient_resource_request).to have_been_made
    end

    it 'fails if returned fhir resource fails validation' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_failure.to_json)
      practitioner_resource_request = stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)

      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token,
                   contexts: [order_sign_context].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match('Resource does not conform to profile')
      expect(validation_request).to have_been_made.times(4)
      expect(practitioner_resource_request).to have_been_made
    end

    it 'passes if context contains optional `encounterId` field' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)
      patient_resource_request = stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      practitioner_resource_request = stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)
      encounter_resource_request = stub_request(:get, "#{client_fhir_server}/Encounter/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter.to_json)

      order_sign_context['encounterId'] = 'example'

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token,
                   contexts: [order_sign_context].to_json)

      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(5)
      expect(patient_resource_request).to have_been_made
      expect(practitioner_resource_request).to have_been_made
      expect(encounter_resource_request).to have_been_made
    end

    it 'fails if context `draftOrders` is not a bundle' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)

      order_sign_context['draftOrders'] = crd_patient

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token,
                   contexts: [order_sign_context].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Wrong context resource type: Expected `Bundle`, got `Patient`/)
    end

    it 'fails if no resources in context `draftOrder` field are one of the supported resources' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)

      order_sign_context['draftOrders']['entry'].each do |entry|
        entry['resource'] = crd_patient
      end

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token,
                   contexts: [order_sign_context].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        '`draftOrders` bundle must contain at least one of the expected resource types:'
      )
    end

    it 'fails if all orders in context `draftOrders` field not in draft state' do
      oo =
        {
          outcomes: [{
            issues: [{
              message: 'NutritionOrder#pureeddiet-simple is invalid',
              level: 'ERROR'
            }]
          }],
          sessionId: 'b8cf5547-1dc7-4714-a797-dc2347b93fe2'
        }

      validation_request = stub_request(:post, "#{validator_url}/validate")
        .with { |request| request.body.exclude?(nutrition_order_profile) }
        .to_return(status: 200, body: operation_outcome_success.to_json)
      nutrition_order_validation_request = stub_request(:post, "#{validator_url}/validate")
        .with { |request| request.body.include?(nutrition_order_profile) }
        .to_return(status: 200, body: oo.to_json)
      patient_resource_request = stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      practitioner_resource_request = stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)

      order_sign_context['draftOrders']['entry'][0]['resource']['status'] = 'active'

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token,
                   contexts: [order_sign_context].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/NutritionOrder#pureeddiet-simple is invalid/)
      expect(validation_request).to have_been_made.times(3)
      expect(nutrition_order_validation_request).to have_been_made
      expect(patient_resource_request).to have_been_made
      expect(practitioner_resource_request).to have_been_made
    end
  end
end
