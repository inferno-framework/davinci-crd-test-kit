RSpec.describe DaVinciCRDTestKit::CoverageInformationSystemActionReceivedTest do
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_coverage_info_system_action_received') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:suite_id) { 'crd_server' }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite_id) }
  let(:coverage_info_system_action) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
    JSON.parse(json)['systemActions'].first
  end
  let(:other_system_action) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'other_system_action.json'))
    JSON.parse(json)
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

  before do
    allow_any_instance_of(runnable).to receive(:hook_name).and_return('appointment-book')
  end

  it 'passes if coverage information system action is provided' do
    result = run(runnable, valid_system_actions: [coverage_info_system_action].to_json)
    expect(result.result).to eq('pass')
  end

  it 'skips if valid_system_actions not present' do
    result = run(runnable)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'valid_system_actions' is nil, skipping test/)
  end

  it 'fails if valid_system_actions is not json' do
    result = run(runnable, valid_system_actions: '[[')
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'fails if coverage information system action is missing' do
    result = run(runnable, valid_system_actions: [other_system_action].to_json)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Coverage Information system action was not returned/)
  end

  it 'persists output' do
    result = run(runnable, valid_system_actions: [coverage_info_system_action].to_json)
    expect(result.result).to eq('pass')

    persisted_coverage_info = session_data_repo.load(test_session_id: test_session.id, name: :coverage_info)
    expect(persisted_coverage_info).to eq([coverage_info_system_action].to_json)
  end
end
