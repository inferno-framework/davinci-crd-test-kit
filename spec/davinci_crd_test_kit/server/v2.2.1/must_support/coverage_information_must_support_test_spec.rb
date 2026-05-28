RSpec.describe DaVinciCRDTestKit::V221::CoverageInformationMustSupportTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:covered_action) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures',
                                   'coverage_info_system_action_covered.json')))
  end
  let(:authorization_action) do
    response = File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'crd_authorization_hook_response.json'))
    JSON.parse(response).fetch('systemActions').first
  end
  let(:complete_action) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures',
                                   'coverage_info_system_action_complete.json')))
  end

  def create_hook_request(actions, tags:)
    repo_create(
      :request,
      result:,
      tags:,
      request_body: { hookInstance: SecureRandom.uuid }.to_json,
      response_body: { cards: [], systemActions: actions }.to_json
    )
  end

  it 'fails when no coverage information actions are found across the hook responses' do
    result = run(runnable)

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Coverage Information system action support not demonstrated/)
  end

  it 'fails when some must support elements are missing across all hook responses' do
    create_hook_request([covered_action], tags: [DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG])

    result = run(runnable)

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Extension.extension:doc-needed/)
    expect(result.result_message).to match(/Extension.extension:doc-purpose/)
    expect(result.result_message).to match(/Extension.extension:info-needed/)
  end

  it 'passes when all must support elements are present across multiple hook responses' do
    create_hook_request([complete_action], tags: [DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG])
    create_hook_request([authorization_action], tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG])

    result = run(runnable)

    expect(result.result).to eq('pass')
  end
end
