RSpec.describe DaVinciCRDTestKit::CoverageInformationSystemActionAcrossHooksValidationTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable_across) do
    id = 'crd_server-crd_server_hooks-crd_server_required_card_response_validation' \
         '-crd_coverage_info_system_action_across_hooks_validation'
    Inferno::Repositories::Tests.new.find(id)
  end
  let(:runnable_within) do
    Inferno::Repositories::Tests.new
      .find('crd_server-crd_server_hooks-crd_server_appointment_book-crd_coverage_info_system_action_validation')
  end
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:valid_response_body) do
    File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
  end
  let(:valid_coverage_info_system_action) { JSON.parse(valid_response_body)['systemActions'].first }
  let(:base_url) { 'http://example.com/' }

  # TODO: replace with inferno core version, but need to get inputs
  # right in the test invocations below first.
  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name: name == :coverage_info ? :appointment_book_coverage_info : name,
        value:,
        type: runnable.config.input_type(name)
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  before do
    allow_any_instance_of(runnable_within).to receive(:assert_valid_resource).and_return(true)
  end

  it 'passes if a valid coverage info system action is present' do
    run(runnable_within, coverage_info: [valid_coverage_info_system_action].to_json, base_url:)
    result = run(runnable_across)
    expect(result.result).to eq('pass')
  end

  it 'skips if no valid coverage info system action present' do
    run(runnable_within, coverage_info: [], base_url:)
    result = run(runnable_across)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/None of the hooks invoked returned valid Coverage Info system actions/)
  end
end
