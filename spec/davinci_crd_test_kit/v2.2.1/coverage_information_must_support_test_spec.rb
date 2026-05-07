RSpec.describe DaVinciCRDTestKit::V221::CoverageInformationMustSupportTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }

  let(:covered_action) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'coverage_info_system_action_covered.json')))
  end
  let(:authorization_action) do
    response = File.read(File.join(__dir__, '..', '..', 'fixtures', 'crd_authorization_hook_response.json'))
    JSON.parse(response).fetch('systemActions').first
  end
  let(:complete_action) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'coverage_info_system_action_complete.json')))
  end

  def hook_request_with_actions(actions)
    Inferno::Entities::Request.new(
      request_body: '{}',
      response_body: { cards: [], systemActions: actions }.to_json
    )
  end

  def stub_tagged_requests(hook_request_map)
    allow_any_instance_of(described_class).to receive(:load_tagged_requests) do |_instance, *tags|
      hook_request_map[tags.first] || []
    end
  end

  it 'fails when no coverage information actions are found across the hook responses' do
    stub_tagged_requests({})

    result = run(runnable)

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Coverage Information system action support not demonstrated/)
  end

  it 'fails when some must support elements are missing across all hook responses' do
    stub_tagged_requests(
      DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG => [hook_request_with_actions([covered_action])]
    )

    result = run(runnable)

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Extension.extension:doc-needed/)
    expect(result.result_message).to match(/Extension.extension:doc-purpose/)
    expect(result.result_message).to match(/Extension.extension:info-needed/)
  end

  it 'passes when all must support elements are present across multiple hook responses' do
    stub_tagged_requests(
      DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG => [hook_request_with_actions([complete_action])],
      DaVinciCRDTestKit::ORDER_SIGN_TAG => [hook_request_with_actions([authorization_action])]
    )

    result = run(runnable)

    expect(result.result).to eq('pass')
  end
end
