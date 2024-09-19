# require_relative '../../lib/davinci_crd_test_kit/client_tests/submitted_response_validation'

RSpec.describe DaVinciCRDTestKit::SubmittedResponseValidationTest do
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_submitted_response_validation') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_server') }
  let(:valid_response_body_json) do
    File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
  end
  let(:first_error_message) do
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

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
