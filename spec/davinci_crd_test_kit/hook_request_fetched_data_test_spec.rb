require_relative '../../lib/davinci_crd_test_kit/client_tests/hook_request_fetched_data_test'
require_relative '../../lib/davinci_crd_test_kit/jwt_helper'
require_relative '../../lib/davinci_crd_test_kit/tags'

RSpec.describe DaVinciCRDTestKit::HookRequestFetchedDataTest do
  let(:suite_id) { 'crd_client' }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:runnable) { described_class }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }
  let(:client_fhir_server_output) { 'https://example/r4' }
  let(:client_access_token_output) { 'SAMPLE_TOKEN' }

  let(:appointment_book_hook_request) do
    File.read(File.join(
                __dir__, '..', 'fixtures', 'appointment_book_hook_request.json'
              ))
  end
  let(:appointment_book_hook_request_hash) { JSON.parse(appointment_book_hook_request) }

  def create_appointment_hook_request(hook_instance, url: appointment_book_url, body: nil, status: 200, headers: nil,
                                      auth_header: nil, workflow_tag: nil)
    headers ||= [
      {
        type: 'request',
        name: 'Authorization',
        value: auth_header
      }
    ]
    repo_create(
      :request,
      name: 'hook_request',
      direction: 'incoming',
      url:,
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:,
      tags: ['appointment-book', hook_instance_tag(hook_instance), workflow_tag].compact
    )
  end

  def create_data_fetch_request(url, hook_instance, body: nil, status: 200, headers: nil,
                                auth_header: nil)
    headers ||= [
      {
        type: 'request',
        name: 'Authorization',
        value: auth_header
      }
    ]
    repo_create(
      :request,
      direction: 'outgoing',
      url:,
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:,
      tags: [DaVinciCRDTestKit::DATA_FETCH_TAG, hook_instance_tag(hook_instance)]
    )
  end

  def hook_instance_tag(hook_instance)
    "#{DaVinciCRDTestKit::HOOK_INSTANCE_TAG_PREFIX}#{hook_instance}"
  end

  def entity_result_message(test, index: 0)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [test])
      .first
      .messages[index]
  end

  describe 'Without a specific workflow' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::HookRequestFetchedDataTest) do
        config(
          options: { hook_name: 'appointment-book' }
        )
      end
    end

    it 'passes when no data fetches made' do
      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      create_appointment_hook_request(appointment_book_hook_request_hash['hookInstance'],
                                      body: appointment_book_hook_request, auth_header: "Bearer #{token}")

      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'passes when all data fetches successful' do
      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      create_appointment_hook_request(appointment_book_hook_request_hash['hookInstance'],
                                      body: appointment_book_hook_request, auth_header: "Bearer #{token}")
      create_data_fetch_request("#{client_fhir_server_output}/Patient/example",
                                appointment_book_hook_request_hash['hookInstance'])
      create_data_fetch_request("#{client_fhir_server_output}/Coverage?patient=example&status=active",
                                appointment_book_hook_request_hash['hookInstance'])

      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'fails when some data fetches not successful' do
      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      hook_instance = appointment_book_hook_request_hash['hookInstance']
      create_appointment_hook_request(hook_instance, body: appointment_book_hook_request,
                                                     auth_header: "Bearer #{token}")
      create_data_fetch_request("#{client_fhir_server_output}/Patient/example", hook_instance)
      create_data_fetch_request("#{client_fhir_server_output}/Coverage?patient=example&status=active", hook_instance,
                                status: 401)
      create_data_fetch_request("#{client_fhir_server_output}/Encounter/example", hook_instance, status: 401)
      create_data_fetch_request("#{client_fhir_server_output}/Practitioner/example", hook_instance)

      result = run(test)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Inferno could not fetch some required data during the hook invocations./)
      expect(entity_result_message(test, index: 0).message)
        .to match(/Failed to perform Coverage search `Coverage\?patient=example&status=active` for hook instance `#{hook_instance}`./) # rubocop:disable Layout/LineLength
      expect(entity_result_message(test, index: 1).message)
        .to match(%r{Failed to read reference `Encounter/example` for hook instance `#{hook_instance}`.})
    end
  end

  describe 'With a specific workflow' do
    let(:alpha_workflow) { 'alpha' }
    let(:beta_workflow) { 'beta' }
    let(:test) do
      Class.new(DaVinciCRDTestKit::HookRequestFetchedDataTest) do
        config(
          options: { hook_name: 'appointment-book', crd_test_group: 'alpha' }
        )
      end
    end

    it 'fails when a failing request has the workflow tag' do
      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      hook_instance = appointment_book_hook_request_hash['hookInstance']
      create_appointment_hook_request(hook_instance,
                                      body: appointment_book_hook_request, auth_header: "Bearer #{token}",
                                      workflow_tag: alpha_workflow)

      create_data_fetch_request("#{client_fhir_server_output}/Encounter/example", hook_instance, status: 401)

      result = run(test)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Inferno could not fetch some required data during the hook invocations./)
      expect(entity_result_message(test, index: 0).message)
        .to match(%r{Failed to read reference `Encounter/example` for hook instance `#{hook_instance}`.})
    end

    it 'passes when all failing requests have a different workflow tag' do
      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      hook_instance = appointment_book_hook_request_hash['hookInstance']
      create_appointment_hook_request(hook_instance,
                                      body: appointment_book_hook_request, auth_header: "Bearer #{token}",
                                      workflow_tag: beta_workflow)

      create_data_fetch_request("#{client_fhir_server_output}/Encounter/example", hook_instance, status: 401)

      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'passes when all failing requests have no workflow tag' do
      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      hook_instance = appointment_book_hook_request_hash['hookInstance']
      create_appointment_hook_request(hook_instance, body: appointment_book_hook_request,
                                                     auth_header: "Bearer #{token}")

      create_data_fetch_request("#{client_fhir_server_output}/Encounter/example", hook_instance, status: 401)

      result = run(test)
      expect(result.result).to eq('pass')
    end
  end
end
