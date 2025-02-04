# require_relative '../../lib/davinci_crd_test_kit/client_tests/submitted_response_validation'

RSpec.describe DaVinciCRDTestKit::SubmittedResponseValidationTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:valid_response_body_json) do
    File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
  end
  let(:first_error_message) do
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  it 'omits if no custom response is provided' do
    result = run(runnable)

    expect(result.result).to eq('omit')
  end

  it 'passes if response body contains valid cards and system actions' do
    result = run(runnable, custom_response: valid_response_body_json)

    expect(result.result).to eq('pass')
  end

  it 'fails if a system action is invalid' do
    response = JSON.parse(valid_response_body_json)
    response['systemActions'] = [
      { 'type' => 'create', 'description' => 'ok', 'resource' => '123' }
    ]

    result = run(runnable, custom_response: response.to_json)

    expect(result.result).to eq('fail')
    expect(first_error_message.message).to match(/must be a FHIR resource/)
  end

  it 'fails if a card is invalid' do
    response = JSON.parse(valid_response_body_json)
    response['cards'].first.delete('summary')
    result = run(runnable, custom_response: response.to_json)

    expect(result.result).to eq('fail')
    expect(first_error_message.message).to match('summary')
  end
end
