RSpec.describe DaVinciCRDTestKit::InstructionsCardReceivedTest do
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_valid_instructions_card_received') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:suite_id) { 'crd_server' }
  let(:cards) do
    response_body = File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
    JSON.parse(response_body)['cards']
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

  it 'passes if cards contain an Instructions card' do
    result = run(runnable, valid_cards: cards.to_json)
    expect(result.result).to eq('pass')
  end

  it 'skips if valid_cards not present' do
    result = run(runnable)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'valid_cards' is nil, skipping test/)
  end

  it 'fails if valid_cards is not json' do
    result = run(runnable, valid_cards: '[[')
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'fails if no instructions card present' do
    dup_cards = cards.deep_dup
    dup_cards.delete(dup_cards.find { |card| card['links'].blank? })

    result = run(runnable, valid_cards: dup_cards.to_json)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/did not contain an Instructions card/)
  end
end
