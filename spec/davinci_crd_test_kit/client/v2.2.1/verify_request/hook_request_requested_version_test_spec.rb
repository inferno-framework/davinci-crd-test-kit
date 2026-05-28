require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/verify_request/hook_request_requested_version_test' # rubocop:disable Layout/LineLength

RSpec.describe DaVinciCRDTestKit::V221::HookRequestRequestedVersionTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:test) do
    Class.new(described_class) do
      config(
        options: { hook_name: 'appointment-book' }
      )
    end
  end

  let(:base_request_body) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'appointment_book_hook_request.json')))
  end

  let(:valid_request_body) do
    base_request_body.merge('extension' => { 'davinci-crd.requestedVersion' => '2.2' })
  end

  def create_hook_request(body:, tags: ['appointment-book'])
    repo_create(
      :request,
      direction: 'incoming',
      url: 'https://example.com/cds-services/appointment-book-service',
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status: 200,
      headers: [],
      tags:
    )
  end

  def entity_result_message(index = 0)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages[index]
  end

  it 'passes when the extension has the correct version' do
    allow(test).to receive(:suite).and_return(suite)
    create_hook_request(body: valid_request_body)
    result = run(test)
    expect(result.result).to eq('pass')
  end

  it 'passes with multiple valid requests' do
    allow(test).to receive(:suite).and_return(suite)
    create_hook_request(body: valid_request_body)
    create_hook_request(body: valid_request_body)
    result = run(test)
    expect(result.result).to eq('pass')
  end

  it 'skips when no requests are found' do
    allow(test).to receive(:suite).and_return(suite)
    result = run(test)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No appointment-book hook requests received/)
  end

  it 'fails when the extension is missing' do
    allow(test).to receive(:suite).and_return(suite)
    create_hook_request(body: base_request_body)
    result = run(test)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/Required extension 'davinci-crd.requestedVersion' is not present/)
  end

  it 'fails when the extension value is not a String' do
    allow(test).to receive(:suite).and_return(suite)
    body = base_request_body.merge('extension' => { 'davinci-crd.requestedVersion' => 2.2 })
    create_hook_request(body:)
    result = run(test)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/expected a String, got Float/)
  end

  it 'fails when the extension value is the wrong version string' do
    allow(test).to receive(:suite).and_return(suite)
    body = base_request_body.merge('extension' => { 'davinci-crd.requestedVersion' => '2.0' })
    create_hook_request(body:)
    result = run(test)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/expected '2.2', got '2.0'/)
  end

  it 'fails when one of multiple requests is invalid, reporting the correct request number' do
    allow(test).to receive(:suite).and_return(suite)
    create_hook_request(body: valid_request_body)
    create_hook_request(body: base_request_body)
    result = run(test)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/\(Request 2\)/)
  end

  it 'fails when a request body is not valid JSON' do
    allow(test).to receive(:suite).and_return(suite)
    create_hook_request(body: 'not valid json')
    result = run(test)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/Request body contains invalid JSON./)
  end

  describe 'when a crd_test_group is configured' do
    let(:test) do
      Class.new(described_class) do
        config(
          options: { hook_name: 'appointment-book', crd_test_group: 'some-group' }
        )
      end
    end

    it 'only loads requests that have both the hook tag and the group tag' do
      allow(test).to receive(:suite).and_return(suite)
      create_hook_request(body: base_request_body, tags: ['appointment-book'])
      create_hook_request(body: valid_request_body, tags: ['appointment-book', 'some-group'])
      result = run(test)
      expect(result.result).to eq('pass')
    end
  end
end
