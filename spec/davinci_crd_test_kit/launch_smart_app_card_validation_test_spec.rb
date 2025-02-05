RSpec.describe DaVinciCRDTestKit::LaunchSmartAppCardValidationTest do
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_launch_smart_app_card_validation') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:suite_id) { 'crd_server' }
  let(:valid_cards) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'valid_cards.json'))
    JSON.parse(json)
  end
  let(:valid_cards_with_links) { valid_cards.filter { |card| card['links'].present? } }

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

  it 'passes if cards contain a valid Launch SMART App card' do
    result = run(runnable, valid_cards_with_links: valid_cards_with_links.to_json)
    expect(result.result).to eq('pass')
  end

  it 'skips if valid_cards_with_links not present' do
    result = run(runnable)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'valid_cards_with_links' is nil, skipping test/)
  end

  it 'fails if valid_cards_with_links is not json' do
    result = run(runnable, valid_cards_with_links: '[[')
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'skips if no Launch SMART App card present' do
    result = run(runnable, valid_cards_with_links: [].to_json)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/does not contain any Launch SMART App cards/)
  end
end
