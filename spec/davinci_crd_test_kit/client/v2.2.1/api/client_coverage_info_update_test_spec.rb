RSpec.describe DaVinciCRDTestKit::V221::ClientCoverageInfoUpdateTest do
  let(:suite_id) { 'crd_client' }
  let(:server_endpoint) { 'http://example.com/fhir' }
  let(:client_smart_credentials) do
    {
      access_token: 'SAMPLE_TOKEN',
      refresh_token: 'REFRESH_TOKEN',
      expires_in: 3600,
      client_id: 'CLIENT_ID',
      issue_time: Time.now.iso8601,
      token_url: 'http://example.com/token'
    }
  end
  let(:smart_auth_info) { Inferno::DSL::AuthInfo.new(client_smart_credentials) }

  let(:test) do
    Class.new(DaVinciCRDTestKit::V221::ClientCoverageInfoUpdateTest) do
      fhir_client do
        url :server_endpoint
        auth_info :smart_auth_info
      end
      input :server_endpoint
      input :smart_auth_info, type: :auth_info
    end
  end

  let(:coverage_info_system_action) do
    JSON.parse(
      File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'coverage_info_system_action_covered.json'))
    )
  end

  let(:device_request_id) { coverage_info_system_action.dig('resource', 'id') }
  let(:device_request_resource_type) { coverage_info_system_action.dig('resource', 'resourceType') }

  let(:hook_request_with_coverage_info) do
    Inferno::Entities::Request.new(
      request_body: '{}',
      response_body: { cards: [], systemActions: [coverage_info_system_action] }.to_json
    )
  end

  let(:hook_request_without_coverage_info) do
    Inferno::Entities::Request.new(
      request_body: '{}',
      response_body: { cards: [], systemActions: [] }.to_json
    )
  end

  # The resource body returned by fhir_read when the extension is stored correctly
  let(:stored_resource_with_extension) { coverage_info_system_action['resource'].to_json }

  # The resource body returned by fhir_read when the client did not store the extension
  let(:stored_resource_without_extension) do
    resource = JSON.parse(coverage_info_system_action['resource'].to_json)
    resource.delete('extension')
    resource.to_json
  end

  # The resource body returned by fhir_read when the extension sub-elements are in a different order
  let(:stored_resource_with_reordered_extension) do
    resource = JSON.parse(coverage_info_system_action['resource'].to_json)
    resource.dig('extension', 0, 'extension').reverse!
    resource.to_json
  end

  # The resource body returned by fhir_read when the extension is present but with different content
  let(:stored_resource_with_different_extension) do
    resource = JSON.parse(coverage_info_system_action['resource'].to_json)
    resource.dig('extension', 0, 'extension').find { |e| e['url'] == 'covered' }['valueCode'] = 'not-covered'
    resource.to_json
  end

  # Bypass the uses_request :capability_statement prerequisite check — no stored request is needed
  # because we mock extract_supported_resource_types directly.
  before do
    allow_any_instance_of(described_class).to receive(:load_named_requests)
  end

  describe 'when no hook requests have been recorded' do
    it 'skips' do
      allow_any_instance_of(described_class)
        .to receive(:extract_supported_resource_types).and_return([device_request_resource_type])
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return([])

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No hook requests found/)
    end
  end

  describe 'when no coverage-info actions are found for supported resource types' do
    it 'skips when there are no coverage-info system actions at all' do
      allow_any_instance_of(described_class)
        .to receive(:extract_supported_resource_types).and_return([device_request_resource_type])
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return([hook_request_without_coverage_info])

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No coverage-info responses found/)
    end

    it 'skips when coverage-info actions exist but target resource type is not in the capability statement' do
      allow_any_instance_of(described_class)
        .to receive(:extract_supported_resource_types).and_return(['Patient']) # DeviceRequest not listed
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return([hook_request_with_coverage_info])

      result = run(test, server_endpoint:, smart_auth_info:)
      result_messages = Inferno::Repositories::Messages.new.messages_for_result(result.id)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No coverage-info responses found/)
      expect(result_messages.map(&:message))
        .to include(match(/#{device_request_resource_type}.*not supported/))
    end

    it 'skips when system actions are present but none are coverage-info type' do
      non_coverage_info_action = {
        'type' => 'update',
        'resource' => { 'resourceType' => 'DeviceRequest', 'id' => 'no-ext' }
      }
      allow_any_instance_of(described_class)
        .to receive(:extract_supported_resource_types).and_return([device_request_resource_type])
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return(
          [Inferno::Entities::Request.new(
            request_body: '{}',
            response_body: { cards: [], systemActions: [non_coverage_info_action] }.to_json
          )]
        )

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No coverage-info responses found/)
    end

    it 'skips when the response body has no systemActions key' do
      allow_any_instance_of(described_class)
        .to receive(:extract_supported_resource_types).and_return([device_request_resource_type])
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return(
          [Inferno::Entities::Request.new(
            request_body: '{}',
            response_body: { cards: [] }.to_json
          )]
        )

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No coverage-info responses found/)
    end
  end

  describe 'when multiple coverage-info updates target the same resource' do
    it 'skips verification for that resource and adds a warning message' do
      allow_any_instance_of(described_class)
        .to receive(:extract_supported_resource_types).and_return([device_request_resource_type])
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return([hook_request_with_coverage_info,
                                                      hook_request_with_coverage_info])

      result = run(test, server_endpoint:, smart_auth_info:)
      result_messages = Inferno::Repositories::Messages.new.messages_for_result(result.id)

      expect(result.result).to eq('skip')
      expect(result_messages.map(&:message))
        .to include(match(%r{#{device_request_resource_type}/#{device_request_id}}))
    end
  end

  describe 'when a coverage-info action targets a supported resource type' do
    before do
      allow_any_instance_of(described_class)
        .to receive(:extract_supported_resource_types).and_return([device_request_resource_type])
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return([hook_request_with_coverage_info])
    end

    it 'fails with an error message when the target resource cannot be read' do
      stub_request(:get, "#{server_endpoint}/#{device_request_resource_type}/#{device_request_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 404, body: '{}')

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Not all coverage-information extensions stored/)
    end

    it 'fails with an error message when the coverage-information extension is absent from the stored resource' do
      stub_request(:get, "#{server_endpoint}/#{device_request_resource_type}/#{device_request_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: stored_resource_without_extension)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Not all coverage-information extensions stored/)
    end

    it 'fails with an error message when the stored coverage-information extension differs from the hook response' do
      stub_request(:get, "#{server_endpoint}/#{device_request_resource_type}/#{device_request_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: stored_resource_with_different_extension)

      result = run(test, server_endpoint:, smart_auth_info:)

      result_messages = Inferno::Repositories::Messages.new.messages_for_result(result.id)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Not all coverage-information extensions stored/)
      expect(result_messages.map(&:message)).to include(match(/'covered'/))
    end

    it 'passes when the coverage-information extension sub-elements are stored in a different order' do
      stub_request(:get, "#{server_endpoint}/#{device_request_resource_type}/#{device_request_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: stored_resource_with_reordered_extension)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
    end

    it 'passes when the coverage-information extension matches the one sent in the hook response' do
      stub_request(:get, "#{server_endpoint}/#{device_request_resource_type}/#{device_request_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: stored_resource_with_extension)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
    end

    it 'fails when the FHIR read returns a 200 with the wrong resource type' do
      wrong_type_body = { 'resourceType' => 'Patient', 'id' => device_request_id }.to_json
      stub_request(:get, "#{server_endpoint}/#{device_request_resource_type}/#{device_request_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: wrong_type_body)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Not all coverage-information extensions stored/)
    end

    it 'fails when the stored resource has more coverage-information extensions than were sent' do
      coverage_info_url = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'
      resource = JSON.parse(coverage_info_system_action['resource'].to_json)
      resource['extension'] << {
        'url' => coverage_info_url,
        'extension' => [{ 'url' => 'covered', 'valueCode' => 'not-covered' }]
      }
      stub_request(:get, "#{server_endpoint}/#{device_request_resource_type}/#{device_request_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: resource.to_json)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Not all coverage-information extensions stored/)
    end

    it 'passes when the stored resource has additional non-coverage-info extensions' do
      resource = JSON.parse(coverage_info_system_action['resource'].to_json)
      resource['extension'] << { 'url' => 'http://example.org/other-ext', 'valueString' => 'extra' }
      stub_request(:get, "#{server_endpoint}/#{device_request_resource_type}/#{device_request_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: resource.to_json)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
    end
  end

  describe 'when multiple resources are found' do
    let(:second_resource_type) { 'MedicationRequest' }
    let(:second_resource_id) { 'med-req-001' }
    let(:second_coverage_info_action) do
      {
        'type' => 'update',
        'resource' => {
          'resourceType' => second_resource_type,
          'id' => second_resource_id,
          'extension' => coverage_info_system_action.dig('resource', 'extension')
        }
      }
    end

    before do
      allow_any_instance_of(described_class)
        .to receive(:extract_supported_resource_types)
        .and_return([device_request_resource_type, second_resource_type])
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return(
          [
            hook_request_with_coverage_info,
            Inferno::Entities::Request.new(
              request_body: '{}',
              response_body: { cards: [], systemActions: [second_coverage_info_action] }.to_json
            )
          ]
        )
    end

    it 'fails when any resource fails verification even if others pass' do
      stub_request(:get, "#{server_endpoint}/#{device_request_resource_type}/#{device_request_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: stored_resource_with_extension)
      stub_request(:get, "#{server_endpoint}/#{second_resource_type}/#{second_resource_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 404, body: '{}')

      result = run(test, server_endpoint:, smart_auth_info:)
      result_messages = Inferno::Repositories::Messages.new.messages_for_result(result.id)

      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message))
        .to include(match(%r{#{second_resource_type}/#{second_resource_id}}))
    end
  end

  describe 'when a single action contains multiple coverage-information extensions' do
    let(:action_with_two_coverage_info_extensions) do
      coverage_info_url = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'
      action = JSON.parse(coverage_info_system_action.to_json)
      action['resource']['extension'] << {
        'url' => coverage_info_url,
        'extension' => [{ 'url' => 'covered', 'valueCode' => 'not-covered' }]
      }
      action
    end

    it 'skips verification for that resource and adds an info message' do
      allow_any_instance_of(described_class)
        .to receive(:extract_supported_resource_types).and_return([device_request_resource_type])
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return(
          [Inferno::Entities::Request.new(
            request_body: '{}',
            response_body: { cards: [], systemActions: [action_with_two_coverage_info_extensions] }.to_json
          )]
        )

      result = run(test, server_endpoint:, smart_auth_info:)
      result_messages = Inferno::Repositories::Messages.new.messages_for_result(result.id)

      expect(result.result).to eq('skip')
      expect(result_messages.map(&:message))
        .to include(match(/Multiple coverage-information extensions/))
    end
  end

  describe 'when sub-extensions share a URL' do
    let(:action_with_duplicate_url) do
      action = JSON.parse(coverage_info_system_action.to_json)
      action.dig('resource', 'extension', 0, 'extension') << {
        'url' => 'coverage-assertion-id',
        'valueString' => 'second-assertion-id'
      }
      action
    end

    before do
      allow_any_instance_of(described_class)
        .to receive(:extract_supported_resource_types).and_return([device_request_resource_type])
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return(
          [Inferno::Entities::Request.new(
            request_body: '{}',
            response_body: { cards: [], systemActions: [action_with_duplicate_url] }.to_json
          )]
        )
    end

    it 'passes when duplicate-URL sub-extensions are stored in a different order' do
      resource = JSON.parse(action_with_duplicate_url['resource'].to_json)
      sub_exts = resource.dig('extension', 0, 'extension')
      first_idx = sub_exts.index { |e| e['url'] == 'coverage-assertion-id' }
      last_idx  = sub_exts.rindex { |e| e['url'] == 'coverage-assertion-id' }
      sub_exts[first_idx], sub_exts[last_idx] = sub_exts[last_idx], sub_exts[first_idx]

      stub_request(:get, "#{server_endpoint}/#{device_request_resource_type}/#{device_request_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: resource.to_json)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
    end

    it 'fails when one of the duplicate-URL sub-extensions is missing from the stored resource' do
      # Stored resource has only the original single coverage-assertion-id (not the duplicate)
      stub_request(:get, "#{server_endpoint}/#{device_request_resource_type}/#{device_request_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: coverage_info_system_action['resource'].to_json)

      result = run(test, server_endpoint:, smart_auth_info:)
      result_messages = Inferno::Repositories::Messages.new.messages_for_result(result.id)

      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message)).to include(match(/'coverage-assertion-id'/))
    end
  end

  describe 'normalization handles reordering at all nesting levels' do
    let(:complete_system_action) do
      JSON.parse(
        File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'coverage_info_system_action_complete.json'))
      )
    end

    let(:complete_resource_id) { complete_system_action.dig('resource', 'id') }
    let(:complete_resource_type) { complete_system_action.dig('resource', 'resourceType') }

    before do
      allow_any_instance_of(described_class)
        .to receive(:extract_supported_resource_types).and_return([complete_resource_type])
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return(
          [Inferno::Entities::Request.new(
            request_body: '{}',
            response_body: { cards: [], systemActions: [complete_system_action] }.to_json
          )]
        )
    end

    def stub_complete_resource(body)
      stub_request(:get, "#{server_endpoint}/#{complete_resource_type}/#{complete_resource_id}")
        .with(headers: { Authorization: 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body:)
    end

    it 'passes when the top-level sub-extensions are in a different order' do
      resource = JSON.parse(complete_system_action['resource'].to_json)
      resource.dig('extension', 0, 'extension').reverse!
      stub_complete_resource(resource.to_json)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
    end

    it 'passes when the detail sub-sub-extensions are in a different order' do
      resource = JSON.parse(complete_system_action['resource'].to_json)
      resource.dig('extension', 0, 'extension').find { |e| e['url'] == 'detail' }['extension'].reverse!
      stub_complete_resource(resource.to_json)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
    end

    it 'passes when the contact telecom entries are in a different order' do
      resource = JSON.parse(complete_system_action['resource'].to_json)
      resource.dig('extension', 0, 'extension')
        .find { |e| e['url'] == 'contact' }
        .dig('valueContactDetail', 'telecom').reverse!
      stub_complete_resource(resource.to_json)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
    end

    it 'passes when reorderings occur at multiple nesting levels simultaneously' do
      resource = JSON.parse(complete_system_action['resource'].to_json)
      sub_extensions = resource.dig('extension', 0, 'extension')
      sub_extensions.reverse!
      sub_extensions.find { |e| e['url'] == 'detail' }['extension'].reverse!
      sub_extensions.find { |e| e['url'] == 'contact' }.dig('valueContactDetail', 'telecom').reverse!
      stub_complete_resource(resource.to_json)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
    end
  end
end
