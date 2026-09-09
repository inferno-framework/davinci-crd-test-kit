RSpec.describe DaVinciCRDTestKit::V221::InstructionsCardReceivedTest do
  let(:suite_id) { 'crd_server' }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:valid_response_body) do
    File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'crd_authorization_hook_response.json'))
  end
  let(:cards) { JSON.parse(valid_response_body)['cards'] }

  before do
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('order-sign')
  end

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  it 'passes if cards contain a valid Instructions card' do
    repo_create(
      :request,
      direction: 'outgoing',
      test_session_id: test_session.id,
      result:,
      request_body: nil,
      response_body: valid_response_body,
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG],
      status: 200
    )

    allow_any_instance_of(runnable).to receive(:perform_response_logical_model_validation).and_return(nil)

    result = run(runnable, invoked_hook: 'order-sign')
    expect(result.result).to eq('pass'), result.result_message
  end

  it 'skips if no successful hook responses were received' do
    repo_create(
      :request,
      direction: 'outgoing',
      test_session_id: test_session.id,
      result:,
      request_body: nil,
      response_body: nil,
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG],
      status: 400
    )
    result = run(runnable, invoked_hook: 'order-sign')

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to include('No successful hook responses')
  end

  it 'skips if no Instructions card present' do
    repo_create(
      :request,
      direction: 'outgoing',
      test_session_id: test_session.id,
      result:,
      request_body: nil,
      response_body: { cards: [cards.last] }.to_json,
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG],
      status: 200
    )

    result = run(runnable, invoked_hook: 'order-sign')

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to include('do not contain any Instructions cards')
  end

  it 'fails if the Instructions card is not valid' do
    repo_create(
      :request,
      direction: 'outgoing',
      test_session_id: test_session.id,
      result:,
      request_body: nil,
      response_body: valid_response_body,
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG],
      status: 200
    )

    allow_any_instance_of(runnable).to receive(:conforms_to_logical_model?).and_return(nil)
    allow_any_instance_of(runnable).to(
      receive(:manually_check_card_specific_errors)
        .and_return(
          [
            OpenStruct.new(severity: 'error', message: 'ERROR MESSAGE')
          ]
        )
    )
    result = run(runnable, invoked_hook: 'order-sign')
    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to include('Not all Instructions')
    expect(entity_result_message.message).to include('ERROR MESSAGE')
  end
end
