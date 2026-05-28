require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/verify_request/hook_request_secured_transport_test' # rubocop:disable Layout/LineLength

RSpec.describe DaVinciCRDTestKit::V221::HookRequestSecuredTransportTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:test) do
    Class.new(described_class) do
      config(options: { hook_name: 'appointment-book' })
    end
  end

  def create_hook_request(url: 'https://example.com/cds-services/appointment-book-service',
                          fhir_server: 'https://fhir.example.com',
                          tags: ['appointment-book'])
    body = {
      'hookInstance' => 'd1577c69-dfbe-44ad-ba6d-3e05e953b2ea',
      'hook' => 'appointment-book',
      'fhirServer' => fhir_server
    }.compact
    repo_create(
      :request,
      direction: 'incoming',
      url:,
      result:,
      test_session_id: test_session.id,
      request_body: body.to_json,
      status: 200,
      tags:
    )
  end

  def result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [test])
      .first
      .messages
  end

  it 'skips when no hook requests have been received' do
    result = run(test)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No appointment-book hook requests received/)
  end

  it 'passes when the request URL and fhirServer both use https' do
    create_hook_request
    result = run(test)
    expect(result.result).to eq('pass')
  end

  it 'passes when fhirServer is absent' do
    create_hook_request(fhir_server: nil)
    result = run(test)
    expect(result.result).to eq('pass')
  end

  it 'fails when the request URL uses http' do
    create_hook_request(url: 'http://example.com/cds-services/appointment-book-service')
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message))
      .to include(match(/Inferno's simulated CRD server must use the https protocol/))
  end

  it 'fails when fhirServer uses http' do
    create_hook_request(fhir_server: 'http://fhir.example.com')
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message)).to include(match(/fhirServer.*must use the https protocol/))
  end

  it 'reports the request number when one of multiple requests fails' do
    create_hook_request
    create_hook_request(fhir_server: 'http://fhir.example.com')
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message)).to include(match(/\(Request 2\).*fhirServer/))
  end

  describe 'when a crd_test_group is configured' do
    let(:test) do
      Class.new(described_class) do
        config(options: { hook_name: 'appointment-book', crd_test_group: 'some-group' })
      end
    end

    it 'only loads requests tagged with both the hook name and group tag' do
      create_hook_request(url: 'http://example.com/insecure', tags: ['appointment-book'])
      create_hook_request(tags: ['appointment-book', 'some-group'])
      result = run(test)
      expect(result.result).to eq('pass')
    end
  end
end
