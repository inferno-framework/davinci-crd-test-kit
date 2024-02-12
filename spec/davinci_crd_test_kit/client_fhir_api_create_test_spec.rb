require_relative '../../lib/davinci_crd_test_kit/client_tests/client_fhir_api_create_test'

RSpec.describe DaVinciCRDTestKit::ClientFHIRApiCreateTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('crd_client') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }

  let(:server_endpoint) { 'http://example.com/fhir' }
  let(:client_smart_credentials) do
    {
      access_token: 'SAMPLE_TOKEN',
      refresh_token: 'REFRESH_TOKEN',
      expires_in: 3600,
      client_id: 'CLIENT_ID',
      token_retrieval_time: Time.now.iso8601,
      token_url: 'http://example.com/token'
    }.to_json
  end

  let(:task) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_task_example.json'
                ))
    )
  end

  let(:task_second) do
    task = JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_task_example.json'
                ))
    )
    task['id'] = 'questionnaire-example2'
    task
  end

  let(:task_id) { 'questionnaire-example' }
  let(:task_id_second) { 'questionnaire-example2' }

  let(:patient) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_patient_example.json'
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
          level: 'ERROR'
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

  describe 'Task FHIR Create Test' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::ClientFHIRApiCreateTest) do
        fhir_client do
          url :server_endpoint
          oauth_credentials :client_smart_credentials
        end

        fhir_resource_validator do
          url ENV.fetch('CRD_FHIR_RESOURCE_VALIDATOR_URL', 'http://hl7_validator_service:3500')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.us.davinci-crd', 'hl7.fhir.us.core')
        end

        config(
          options: { resource_type: 'Task' }
        )

        input :server_endpoint
        input :client_smart_credentials, type: :oauth_credentials
      end
    end

    it 'passes if valid Task resource is passed in' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)
      task_create_request = stub_request(:post, "#{server_endpoint}/Task")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 201, body: task.to_json)
      result = run(test, create_resources: [task].to_json, server_endpoint:, client_smart_credentials:)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made
      expect(task_create_request).to have_been_made
    end

    it 'passes if multiple valid Task resources are passed in' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)
      task_create_request = stub_request(:post, "#{server_endpoint}/Task")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 201, body: task.to_json).then
        .to_return(status: 201, body: task_second.to_json)

      result = run(test, create_resources: [task, task_second].to_json, server_endpoint:, client_smart_credentials:)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(2)
      expect(task_create_request).to have_been_made.times(2)
    end

    it 'fails if multiple valid Task resources are passed in and at least 1 returns a non 201' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)
      task_create_request = stub_request(:post, "#{server_endpoint}/Task")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 201, body: task.to_json).then
        .to_return(status: 400, body: task_second.to_json)

      result = run(test, create_resources: [task, task_second].to_json, server_endpoint:, client_smart_credentials:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 201, but received 400')
      expect(validation_request).to have_been_made.times(2)
      expect(task_create_request).to have_been_made.times(2)
    end

    it 'passes if multiple Task resources are passed in and at least 1 is valid' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json).then
        .to_return(status: 200, body: operation_outcome_failure.to_json).then
        .to_return(status: 200, body: operation_outcome_success.to_json).then
      task_create_request = stub_request(:post, "#{server_endpoint}/Task")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 201, body: task.to_json)

      result = run(test, create_resources: [task, task_second].to_json, server_endpoint:, client_smart_credentials:)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(2)
      expect(task_create_request).to have_been_made
    end

    it 'skips if create_resources input is empty' do
      result = run(test, create_resources: [], server_endpoint:, client_smart_credentials:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq(
        "Input 'create_resources' is nil, skipping test."
      )
    end

    it 'skips if empty resource json is inputted' do
      result = run(test, create_resources: [{}].to_json, server_endpoint:, client_smart_credentials:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq(
        'No valid Task resources were provided to send in Create requests, skipping test.'
      )
    end

    it 'skips if inputted resource is the wrong resource type' do
      result = run(test, create_resources: [patient].to_json, server_endpoint:, client_smart_credentials:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq(
        'No valid Task resources were provided to send in Create requests, skipping test.'
      )
    end

    it 'skips if passed in Task resource is invalid' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      result = run(test, create_resources: [task].to_json, server_endpoint:, client_smart_credentials:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq(
        'No valid Task resources were provided to send in Create requests, skipping test.'
      )
      expect(validation_request).to have_been_made
    end

    it 'fails if resource in invalid JSON format is inputted' do
      result = run(test, create_resources: '[[', server_endpoint:, client_smart_credentials:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Invalid JSON. ')
    end

    it 'fails if Task creation interaction returns non 201' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)
      task_create_request = stub_request(:post, "#{server_endpoint}/Task")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400)

      result = run(test, create_resources: [task].to_json, server_endpoint:, client_smart_credentials:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 201, but received 400')
      expect(validation_request).to have_been_made
      expect(task_create_request).to have_been_made
    end
  end
end
