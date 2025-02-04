RSpec.describe DaVinciCRDTestKit::CoverageInformationSystemActionReceivedTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }
  let(:coverage_info_system_action) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
    JSON.parse(json)['systemActions'].first
  end
  let(:other_system_action) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'other_system_action.json'))
    JSON.parse(json)
  end

  before do
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('appointment-book')
  end

  it 'passes if coverage information system action is provided' do
    result = run(runnable,
                 { valid_system_actions: [coverage_info_system_action].to_json, invoked_hook: 'appointment-book' })
    expect(result.result).to eq('pass')
  end

  it 'skips if valid_system_actions not present' do
    result = run(runnable, invoked_hook: 'appointment-book')
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'valid_system_actions' is nil, skipping test/)
  end

  it 'fails if valid_system_actions is not json' do
    result = run(runnable, { valid_system_actions: '[[', invoked_hook: 'appointment-book' })
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'fails if coverage information system action is missing' do
    result = run(runnable, { valid_system_actions: [other_system_action].to_json, invoked_hook: 'appointment-book' })
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Coverage Information system action was not returned/)
  end

  it 'persists output' do
    result = run(runnable,
                 { valid_system_actions: [coverage_info_system_action].to_json, invoked_hook: 'appointment-book' })
    expect(result.result).to eq('pass')

    persisted_coverage_info = session_data_repo.load(test_session_id: test_session.id, name: :coverage_info)
    expect(persisted_coverage_info).to eq([coverage_info_system_action].to_json)
  end
end
