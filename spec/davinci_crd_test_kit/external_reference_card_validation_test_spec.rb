RSpec.describe DaVinciCRDTestKit::ExternalReferenceCardValidationTest do
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_external_reference_card_validation') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:suite_id) { 'crd_server' }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite_id) }
  let(:valid_response_body) do
    File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
  end
  let(:cards) { JSON.parse(valid_response_body)['cards'] }
  let(:external_ref_card) { cards.find { |card| card['links'].present? } }

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

  it 'passes if cards contain a valid external reference card' do
    result = run(runnable, valid_cards_with_links: [external_ref_card].to_json)
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

  it 'fails if no external reference card present' do
    result = run(runnable, valid_cards_with_links: [].to_json)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/did not contain an External Reference card/)
  end
end
