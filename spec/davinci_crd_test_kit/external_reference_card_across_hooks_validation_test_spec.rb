RSpec.describe DaVinciCRDTestKit::ExternalReferenceCardAcrossHooksValidationTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable_across) do
    id = 'crd_server-crd_server_hooks-crd_server_required_card_response_validation' \
         '-crd_external_reference_card_across_hooks_validation'
    Inferno::Repositories::Tests.new.find(id)
  end
  let(:runnable_within) do
    Inferno::Repositories::Tests.new
      .find('crd_server-crd_server_hooks-crd_server_order_dispatch-crd_external_reference_card_validation')
  end
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:valid_response_body) do
    File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
  end
  let(:cards) { JSON.parse(valid_response_body)['cards'] }
  let(:external_ref_card) { cards.find { |card| card['links'].present? } }
  let(:base_url) { 'http://example.com' }

  # TODO: replace with inferno core version, but need to get inputs
  # right in the test invocations below first.
  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name: name == :valid_cards_with_links ? :order_dispatch_valid_cards_with_links : name,
        value:,
        type: runnable.config.input_type(name)
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  it 'passes if a valid external reference card is present' do
    run(runnable_within, valid_cards_with_links: [external_ref_card].to_json, base_url:)
    result = run(runnable_across)
    expect(result.result).to eq('pass')
  end

  it 'skips if no external reference card present' do
    run(runnable_within, valid_cards_with_links: [].to_json, base_url:)
    result = run(runnable_across)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/None of the hooks invoked returned an External Reference card./)
  end
end
