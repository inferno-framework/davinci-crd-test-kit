require_relative '../../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::V221::ClientLocationAddressPropagationTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:hook_name) { 'order-sign' }
  let(:hook_instance) { 'd1577c69-dfbe-44ad-ba6d-3e05e953b2ea' }

  let(:test) do
    Class.new(described_class) do
      config(options: { hook_name: 'order-sign' })
    end
  end

  let(:location_with_address) do
    { 'resourceType' => 'Location', 'id' => 'loc-1',
      'address' => { 'line' => ['123 Main St'], 'city' => 'Anytown' } }
  end

  let(:location_without_address) do
    { 'resourceType' => 'Location', 'id' => 'loc-2' }
  end

  let(:parent_location_with_address) do
    { 'resourceType' => 'Location', 'id' => 'parent-1',
      'address' => { 'line' => ['456 Parent Ave'], 'city' => 'Anytown' } }
  end

  let(:parent_location_without_address) do
    { 'resourceType' => 'Location', 'id' => 'parent-1' }
  end

  def create_hook_request(body:, tags: [hook_name])
    repo_create(
      :request,
      direction: 'incoming',
      url: "https://example.com/cds-services/#{hook_name}-service",
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status: 200,
      headers: [],
      tags:
    )
  end

  def create_parent_location_fetch_request(location:, status: 200, instance: hook_instance)
    repo_create(
      :request,
      direction: 'outgoing',
      url: "https://example.com/fhir/Location/#{location['id']}",
      result:,
      test_session_id: test_session.id,
      response_body: location.is_a?(Hash) ? location.to_json : location,
      status:,
      headers: [],
      tags: [DaVinciCRDTestKit::PARENT_LOCATION_FETCH_TAG,
             DaVinciCRDTestKit::TagMethods.hook_instance_data_fetch_tag(instance),
             DaVinciCRDTestKit::DATA_FETCH_TAG]
    )
  end

  def result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
  end

  def location_bundle(*locations)
    { 'resourceType' => 'Bundle', 'entry' => locations.map { |r| { 'resource' => r } } }
  end

  describe 'when checking location address propagation' do
    it 'skips when there are no hook requests to analyze' do
      result = run(test)
      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No hook requests received/)
    end

    it 'passes when a prefetched location already has an address' do
      create_hook_request(body: {
                            'hookInstance' => hook_instance, 'hook' => hook_name,
                            'prefetch' => { 'locations' => location_bundle(location_with_address) }
                          })
      expect(run(test).result).to eq('pass')
    end

    it 'passes when a prefetched location has no address and no partOf' do
      create_hook_request(body: {
                            'hookInstance' => hook_instance, 'hook' => hook_name,
                            'prefetch' => { 'locations' => location_bundle(location_without_address) }
                          })
      expect(run(test).result).to eq('pass')
    end

    it 'passes when a prefetched location has no address and its parent also has no address' do
      child = location_without_address.merge('partOf' => { 'reference' => 'Location/parent-1' })
      create_hook_request(body: {
                            'hookInstance' => hook_instance, 'hook' => hook_name,
                            'prefetch' => { 'locations' => location_bundle(child, parent_location_without_address) }
                          })
      expect(run(test).result).to eq('pass')
    end

    it 'fails when a prefetched location has no address but its parent does' do
      child = location_without_address.merge('partOf' => { 'reference' => 'Location/parent-1' })
      create_hook_request(body: {
                            'hookInstance' => hook_instance, 'hook' => hook_name,
                            'prefetch' => { 'locations' => location_bundle(child, parent_location_with_address) }
                          })
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message).join).to match(%r{Address missing on prefetched 'Location/loc-2'})
      expect(result_messages.map(&:message).join).to match(%r{parent 'Location/parent-1' has an address})
    end

    it 'fails when the error is found by traversing to a grandparent with an address' do
      child = { 'resourceType' => 'Location', 'id' => 'child',
                'partOf' => { 'reference' => 'Location/middle' } }
      middle = { 'resourceType' => 'Location', 'id' => 'middle',
                 'partOf' => { 'reference' => 'Location/grandparent' } }
      grandparent = { 'resourceType' => 'Location', 'id' => 'grandparent',
                      'address' => { 'line' => ['1 Top St'], 'city' => 'Anytown' } }
      create_hook_request(body: {
                            'hookInstance' => hook_instance, 'hook' => hook_name,
                            'prefetch' => { 'locations' => location_bundle(child, middle, grandparent) }
                          })
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message).join).to match(%r{Address missing on prefetched 'Location/child'})
      expect(result_messages.map(&:message).join).to match(%r{parent 'Location/grandparent' has an address})
    end

    it 'fails when the partOf reference cannot be resolved' do
      child = location_without_address.merge('partOf' => { 'reference' => 'Location/missing-loc' })
      create_hook_request(body: {
                            'hookInstance' => hook_instance, 'hook' => hook_name,
                            'prefetch' => { 'locations' => location_bundle(child) }
                          })
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message).join).to match(/Unable to check address propagation/)
      expect(result_messages.map(&:message).join).to match(%r{Location/missing-loc.*could not be fetched})
    end

    it 'resolves parent locations from fetched location requests' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      child = location_without_address.merge('partOf' => { 'reference' => 'Location/parent-1' })
      create_hook_request(body: {
                            'hookInstance' => hook_instance, 'hook' => hook_name,
                            'prefetch' => { 'locations' => location_bundle(child) }
                          })
      create_parent_location_fetch_request(location: parent_location_with_address)
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message).join).to match(%r{Address missing on prefetched 'Location/loc-2'})
    end

    it 'passes when a fetched parent location has no address' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      child = location_without_address.merge('partOf' => { 'reference' => 'Location/parent-1' })
      create_hook_request(body: {
                            'hookInstance' => hook_instance, 'hook' => hook_name,
                            'prefetch' => { 'locations' => location_bundle(child) }
                          })
      create_parent_location_fetch_request(location: parent_location_without_address)
      expect(run(test).result).to eq('pass')
    end

    it 'handles a single prefetched Location (not a Bundle)' do
      create_hook_request(body: {
                            'hookInstance' => hook_instance, 'hook' => hook_name,
                            'prefetch' => { 'locations' => location_with_address }
                          })
      expect(run(test).result).to eq('pass')
    end

    it 'skips requests with invalid JSON without crashing' do
      create_hook_request(body: 'not valid json')
      expect(run(test).result).to eq('pass')
    end

    it 'does not check conformance for prefetched parent locations' do
      child = location_without_address.merge('partOf' => { 'reference' => 'Location/parent-pf' })
      prefetched_parent = { 'resourceType' => 'Location', 'id' => 'parent-pf' }
      create_hook_request(body: {
                            'hookInstance' => hook_instance, 'hook' => hook_name,
                            'prefetch' => { 'locations' => location_bundle(child, prefetched_parent) }
                          })
      expect_any_instance_of(test).to_not receive(:resource_is_valid?)
      run(test)
    end
  end

  describe 'when checking fetched parent location conformance' do
    let(:child_location) do
      location_without_address.merge('partOf' => { 'reference' => 'Location/parent-1' })
    end

    before do
      create_hook_request(body: {
                            'hookInstance' => hook_instance, 'hook' => hook_name,
                            'prefetch' => { 'locations' => location_bundle(child_location) }
                          })
      create_parent_location_fetch_request(location: parent_location_without_address)
    end

    it 'passes when the fetched parent conforms to the CRD Location profile' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      expect(run(test).result).to eq('pass')
    end

    it 'fails when the fetched parent does not conform to the CRD Location profile' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(false)
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message).join)
        .to match(%r{Parent of prefetched 'Location/loc-2' does not conform to the CRD Location profile})
    end

    it 'includes individual validation issues in messages when conformance fails' do
      issue = instance_double(Inferno::DSL::FHIRResourceValidation::ValidatorIssue,
                              severity: 'error', message: 'Missing required field')
      instance = test.new
      allow(instance).to receive(:prefetched_location_hash).and_return({})
      allow(instance).to receive(:resource_is_valid?) do |resource: nil, profile_url: nil, # rubocop:disable Lint/UnusedBlockArgument
                                                          add_messages_to_runnable: true, # rubocop:disable Lint/UnusedBlockArgument
                                                          validator_response_details: nil|
        validator_response_details << issue
        false
      end
      location = FHIR.from_contents(parent_location_without_address.to_json)
      instance.check_location_conformance(location, 'loc-2')
      expect(instance.messages).to include(a_hash_including(message: a_string_including('Missing required field')))
    end

    it 'does not re-check conformance for a location already validated' do
      second_child = { 'resourceType' => 'Location', 'id' => 'loc-3',
                       'partOf' => { 'reference' => 'Location/parent-1' } }
      create_hook_request(body: {
                            'hookInstance' => 'second-instance', 'hook' => hook_name,
                            'prefetch' => { 'locations' => location_bundle(second_child) }
                          })
      expect_any_instance_of(test).to receive(:resource_is_valid?).once.and_return(true)
      run(test)
    end
  end
end
