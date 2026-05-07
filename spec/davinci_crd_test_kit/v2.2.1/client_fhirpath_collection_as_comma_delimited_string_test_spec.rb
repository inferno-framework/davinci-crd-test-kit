RSpec.describe DaVinciCRDTestKit::V221::ClientFHIRPathCollectionAsCommaDelimitedStringTest do
  let(:suite_id) { 'crd_client_v221' }

  let(:runnable) do
    Inferno::Repositories::Tests.new.find(
      'crd_client_v221-crd_v221_client_hook_invocation-crd_v221_client_cross_hook' \
      '-crd_v221_client_fhir_path_collection_as_comma_delimited_string'
    )
  end

  let(:prefetch_complete_test) do
    Inferno::Repositories::Tests.new.find(
      'crd_client_v221-crd_v221_client_hook_invocation-crd_v221_client_hooks' \
      '-crd_v221_client_order_sign-Group03-crd_v221_hook_request_prefetch_complete'
    )
  end

  def create_prefetch_complete_result(output_json: '[]', result: 'pass')
    repo_create(
      :result,
      test_session_id: test_session.id,
      runnable: prefetch_complete_test.reference_hash,
      output_json:,
      result:
    )
  end

  it 'skips when no prefetch completeness test results exist' do
    expect(run(runnable).result).to eq('skip')
  end

  it 'skips when completeness results have no collection behavior output' do
    create_prefetch_complete_result(output_json: '[]')
    expect(run(runnable).result).to eq('skip')
  end

  it 'skips when the collection output is present but false' do
    create_prefetch_complete_result(
      output_json: [{ name: 'demonstrates_fhirpath_collection_as_comma_delimited_string',
                      value: 'false' }].to_json
    )
    expect(run(runnable).result).to eq('skip')
  end

  it 'passes when a completeness result demonstrates collection behavior' do
    create_prefetch_complete_result(
      output_json: [{ name: 'demonstrates_fhirpath_collection_as_comma_delimited_string',
                      value: 'true' }].to_json
    )
    expect(run(runnable).result).to eq('pass')
  end

  it 'passes when any one of multiple completeness results demonstrates collection behavior' do
    create_prefetch_complete_result(output_json: '[]')
    create_prefetch_complete_result(
      output_json: [{ name: 'demonstrates_fhirpath_collection_as_comma_delimited_string',
                      value: 'true' }].to_json
    )
    expect(run(runnable).result).to eq('pass')
  end
end
