require_relative '../../lib/davinci_crd_test_kit/client_tests/client_fhir_api_update_test'

RSpec.describe DaVinciCRDTestKit::ClientFHIRApiUpdateTest do
  let(:suite_id) { 'crd_client' }
  let(:server_endpoint) { 'http://example.com/fhir' }
  let(:client_smart_credentials) do
    {
      access_token: 'SAMPLE_TOKEN',
      refresh_token: 'REFRESH_TOKEN',
      expires_in: 3600,
      client_id: 'CLIENT_ID',
      issue_time: Time.now.iso8601,
      token_url: 'http://example.com/token'
    }
  end
  let(:smart_auth_info) { Inferno::DSL::AuthInfo.new(client_smart_credentials) }

  let(:encounter) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_encounter_example.json'
                ))
    )
  end

  let(:encounter_second) do
    encounter = JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_encounter_example.json'
                ))
    )
    encounter['id'] = 'example2'
    encounter
  end

  let(:encounter_id) { 'example' }
  let(:encounter_id_second) { 'example2' }

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

  describe 'Encounter FHIR Update Test' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::ClientFHIRApiUpdateTest) do
        fhir_client do
          url :server_endpoint
          auth_info :smart_auth_info
        end

        fhir_resource_validator do
          url validation_url

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.us.davinci-crd', 'hl7.fhir.us.core')
        end

        config(
          options: { resource_type: 'Encounter' }
        )

        input :server_endpoint
        input :smart_auth_info, type: :auth_info
      end
    end

    it 'passes if valid Encounter resource is passed in' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      encounter_update_request = stub_request(:put, "#{server_endpoint}/Encounter/#{encounter_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: encounter.to_json)

      result = run(test, update_resources: [encounter].to_json, server_endpoint:,
                         smart_auth_info:)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made
      expect(encounter_update_request).to have_been_made
    end

    it 'passes if valid Encounter resource is passed in and create interaction returns 201' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      encounter_update_request = stub_request(:put, "#{server_endpoint}/Encounter/#{encounter_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 201, body: encounter.to_json)

      result = run(test, update_resources: [encounter].to_json, server_endpoint:,
                         smart_auth_info:)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made
      expect(encounter_update_request).to have_been_made
    end

    it 'passes if multiple valid Encounter resource are passed in' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      encounter_update_request = stub_request(:put, "#{server_endpoint}/Encounter/#{encounter_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: encounter.to_json)
      encounter_update_request_second = stub_request(:put, "#{server_endpoint}/Encounter/#{encounter_id_second}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: encounter_second.to_json)

      result = run(test, update_resources: [encounter, encounter_second].to_json, server_endpoint:,
                         smart_auth_info:)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(2)
      expect(encounter_update_request).to have_been_made
      expect(encounter_update_request_second).to have_been_made
    end

    it 'fails if multiple valid Encounter resource are passed in and at least 1 returns a non 200 or 201' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      encounter_update_request = stub_request(:put, "#{server_endpoint}/Encounter/#{encounter_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: encounter.to_json)
      encounter_update_request_second = stub_request(:put, "#{server_endpoint}/Encounter/#{encounter_id_second}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: encounter_second.to_json)

      result = run(test, update_resources: [encounter, encounter_second].to_json, server_endpoint:,
                         smart_auth_info:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 200, 201, but received 400')
      expect(validation_request).to have_been_made.times(2)
      expect(encounter_update_request).to have_been_made
      expect(encounter_update_request_second).to have_been_made
    end

    it 'passes if multiple Encounter resource are passed in and at least 1 is valid' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json).then
        .to_return(status: 200, body: operation_outcome_failure.to_json).then
        .to_return(status: 200, body: operation_outcome_success.to_json).then
      encounter_update_request = stub_request(:put, "#{server_endpoint}/Encounter/#{encounter_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: encounter.to_json)

      result = run(test, update_resources: [encounter, encounter_second].to_json, server_endpoint:,
                         smart_auth_info:)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(2)
      expect(encounter_update_request).to have_been_made
    end

    it 'skips if update_resources input is empty' do
      result = run(test, update_resources: [], server_endpoint:, smart_auth_info:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq(
        "Input 'update_resources' is nil, skipping test."
      )
    end

    it 'skips if empty resource json is inputted' do
      result = run(test, update_resources: [{}], server_endpoint:, smart_auth_info:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq(
        'No valid Encounter resources were provided to send in Update requests, skipping test.'
      )
    end

    it 'skips if inputted resource is the wrong resource type' do
      result = run(test, update_resources: [patient].to_json, server_endpoint:,
                         smart_auth_info:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq(
        'No valid Encounter resources were provided to send in Update requests, skipping test.'
      )
    end

    it 'skips if passed in Encounter resource is invalid' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      result = run(test, update_resources: [encounter].to_json, server_endpoint:,
                         smart_auth_info:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq(
        'No valid Encounter resources were provided to send in Update requests, skipping test.'
      )
      expect(validation_request).to have_been_made
    end

    it 'fails if resource in invalid JSON format is inputted' do
      result = run(test, update_resources: '[[', server_endpoint:, smart_auth_info:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Invalid JSON. ')
    end

    it 'fails if Encounter update interaction returns non 200 or 201' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      encounter_update_request = stub_request(:put, "#{server_endpoint}/Encounter/#{encounter_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400)

      result = run(test, update_resources: [encounter].to_json, server_endpoint:,
                         smart_auth_info:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 200, 201, but received 400')
      expect(validation_request).to have_been_made
      expect(encounter_update_request).to have_been_made
    end
  end
end
