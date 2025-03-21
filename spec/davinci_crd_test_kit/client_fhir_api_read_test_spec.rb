require_relative '../../lib/davinci_crd_test_kit/client_tests/client_fhir_api_read_test'

RSpec.describe DaVinciCRDTestKit::ClientFHIRApiReadTest do
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

  let(:patient_ids) { 'example' }

  let(:crd_patient_first) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_patient_example.json'
                ))
    )
  end

  let(:crd_patient_second) do
    patient = JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_patient_example.json'
                ))
    )
    patient['id'] = 'example2'
    patient
  end

  let(:crd_patient_no_id) do
    crd_patient_first.except('id')
  end

  let(:crd_practitioner) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_practitioner_example.json'
                ))
    )
  end

  describe 'Patient FHIR Read Test' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::ClientFHIRApiReadTest) do
        fhir_client do
          url :server_endpoint
          auth_info :smart_auth_info
        end

        config(
          options: { resource_type: 'Patient' }
        )

        input :server_endpoint, :resource_ids
        input :smart_auth_info, type: :auth_info
      end
    end

    it 'passes if valid list of readable Patient ids are passed in' do
      patient_resource_request_first = stub_request(:get, "#{server_endpoint}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient_first.to_json)

      result = run(test, resource_ids: patient_ids, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
      expect(patient_resource_request_first).to have_been_made
    end

    it 'passes if valid list of more than 1 readable Patient id is passed in' do
      patient_resource_request_first = stub_request(:get, "#{server_endpoint}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient_first.to_json)
      patient_resource_request_second = stub_request(:get, "#{server_endpoint}/Patient/example2")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient_second.to_json)

      patient_ids = 'example, example2'
      result = run(test, resource_ids: patient_ids, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
      expect(patient_resource_request_first).to have_been_made
      expect(patient_resource_request_second).to have_been_made
    end

    it 'skips if no Patient ids are inputted' do
      result = run(test, resource_ids: '', server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('skip')
    end

    it 'fails if Patient id read returns non 200' do
      patient_resource_request_first = stub_request(:get, "#{server_endpoint}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: crd_patient_first.to_json)

      result = run(test, resource_ids: patient_ids, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 200, but received 400')
      expect(patient_resource_request_first).to have_been_made
    end

    it 'fails if Patient id read returns Patient with wrong id' do
      patient_resource_request_first = stub_request(:get, "#{server_endpoint}/Patient/wrong-id")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient_first.to_json)

      patient_ids = 'wrong-id'
      result = run(test, resource_ids: patient_ids, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Expected resource to have id: `wrong-id`, but found `example`')
      expect(patient_resource_request_first).to have_been_made
    end

    it 'fails if Patient id read returns Patient with no id' do
      patient_resource_request_first = stub_request(:get, "#{server_endpoint}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient_no_id.to_json)

      result = run(test, resource_ids: patient_ids, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Expected resource to have id: `example`, but found ``')
      expect(patient_resource_request_first).to have_been_made
    end

    it 'fails if Patient id read returns wrong resource type' do
      patient_resource_request_first = stub_request(:get, "#{server_endpoint}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)

      result = run(test, resource_ids: patient_ids, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected resource type: expected Patient, but received Practitioner')
      expect(patient_resource_request_first).to have_been_made
    end
  end
end
