require_relative '../../lib/davinci_crd_test_kit/client_tests/hook_request_valid_context_test'
require_relative '../../lib/davinci_crd_test_kit/jwt_helper'

RSpec.describe DaVinciCRDTestKit::HookRequestValidContextTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('crd_client') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }
  let(:klass) { Class.new(DaVinciCRDTestKit::JwtHelper) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:order_select_url) { "#{base_url}/cds-services/order-select-service" }
  let(:client_fhir_server) { 'https://example/r4' }
  let(:client_bearer_token) { 'SAMPLE_TOKEN' }
  let(:nutrition_order_profile) { 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-nutritionorder' }

  let(:order_select_hook_request) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'order_select_hook_request.json'
                ))
    )
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

  let(:crd_nutrition_order) do
    FHIR.from_contents(order_select_hook_request['context']['draftOrders']['entry'][0]['resource'].to_json)
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

  let(:validator_url) { ENV.fetch('CRD_FHIR_RESOURCE_VALIDATOR_URL') }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name:,
        value:,
        type: runnable.config.input_type(name)
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  def create_order_select_hook_request(url: order_select_url, body: nil, status: 200)
    auth_token = klass.build(
      aud: order_select_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    headers = [
      {
        type: 'request',
        name: 'Authorization',
        value: "Bearer #{auth_token}"
      }
    ]

    repo_create(
      :request,
      name: 'order_select',
      direction: 'incoming',
      url:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:
    )
  end

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  describe 'Order Select Hook Valid Context' do
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
          options: { hook_name: 'order-select' },
          requests: {
            hook_request: { name: :order_select }
          }
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

      create_order_select_hook_request(body: order_select_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(4)
      expect(patient_resource_request).to have_been_made
      expect(practitioner_resource_request).to have_been_made
    end

    it 'skips if no client fhir server url is found' do
      create_order_select_hook_request(body: order_select_hook_request)

      result = run(test)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq(
        "Input 'client_fhir_server' is nil, skipping test."
      )
    end

    it 'fails if request body is not a valid json' do
      create_order_select_hook_request(body: 'invalid_request')

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Invalid JSON. ')
    end

    it 'fails if request body is does not contain the `context` field' do
      invalid_hook_request = order_select_hook_request.except('context')
      create_order_select_hook_request(body: invalid_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Hook request does not contain required `context` field')
    end

    it 'fails if context does not contain all required fields' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)
      order_select_hook_request['context'].delete('patientId')
      create_order_select_hook_request(body: order_select_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /order-select request context does not contain required field `patientId`/
      )
    end

    it 'fails if resource type and id cannot be extracted from context `userId` field' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      order_select_hook_request['context']['userId'] = '/'
      create_order_select_hook_request(body: order_select_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

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
      order_select_hook_request['context']['userId'] = 'Observation/example'
      create_order_select_hook_request(body: order_select_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Unsupported resource type/)
    end

    it 'fails if client fhir server returns non 200 response' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
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

      create_order_select_hook_request(body: order_select_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Unexpected response status: expected 200, but received 404/)
      expect(practitioner_resource_request).to have_been_made
      expect(patient_resource_request).to have_been_made
    end

    it 'fails if retrieved fhir resource fails validation' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_failure.to_json)
      practitioner_resource_request = stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)
      patient_resource_request = stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      create_order_select_hook_request(body: order_select_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Resource does not conform to/)
      expect(validation_request).to have_been_made.times(4)
      expect(practitioner_resource_request).to have_been_made
      expect(patient_resource_request).to have_been_made
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

      order_select_hook_request['context']['encounterId'] = 'example'

      create_order_select_hook_request(body: order_select_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(5)
      expect(patient_resource_request).to have_been_made
      expect(practitioner_resource_request).to have_been_made
      expect(encounter_resource_request).to have_been_made
    end

    it 'fails if context `draftOrders` is not a bundle' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      order_select_hook_request['context']['draftOrders'] = crd_patient

      create_order_select_hook_request(body: order_select_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Wrong context resource type: Expected `Bundle`/)
    end

    it 'fails if no resources in context `draftOrder` field are one of the supported resources' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      order_select_hook_request['context']['draftOrders']['entry'].each do |entry|
        entry['resource'] = crd_patient
      end

      create_order_select_hook_request(body: order_select_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /`draftOrders` bundle must contain at least one of the expected resource types/
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

      order_select_hook_request['context']['draftOrders']['entry'][0]['resource']['status'] = 'active'

      create_order_select_hook_request(body: order_select_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/NutritionOrder#pureeddiet-simple is invalid/)
      expect(validation_request).to have_been_made.times(3)
      expect(nutrition_order_validation_request).to have_been_made
      expect(patient_resource_request).to have_been_made
      expect(practitioner_resource_request).to have_been_made
    end

    it 'fails if context `selections` field contains an reference not found in the `draftOrders` bundle' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      order_select_hook_request['context']['draftOrders']['entry'][0]['resource']['id'] = 'new_id'

      create_order_select_hook_request(body: order_select_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /`selections` field must reference FHIR resources in `draftOrders`./
      )
    end
  end
end
