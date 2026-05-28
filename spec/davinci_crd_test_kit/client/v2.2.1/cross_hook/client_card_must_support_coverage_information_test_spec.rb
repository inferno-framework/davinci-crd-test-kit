RSpec.describe DaVinciCRDTestKit::V221::ClientCardMustSupportCoverageInformationTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:runnable) { described_class }

  let(:order_sign_hook_request) do
    File.read(File.join(
                __dir__, '..', '..', '..', '..', 'fixtures', 'order_sign_hook_request.json'
              ))
  end
  let(:order_sign_hook_response_complete) do
    {
      cards: [],
      systemActions: [JSON.parse(File.read(File.join(
                                             __dir__, '..', '..', '..', '..', 'fixtures',
                                             'coverage_info_system_action_complete.json'
                                           )))]
    }.to_json
  end
  let(:dependency_system_action) do
    {
      type: 'update',
      resource: {
        resourceType: 'MedicationRequest',
        id: 'dependency-example',
        extension: [{
          url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information',
          extension: [
            { url: 'coverage', valueReference: { reference: 'Coverage/example' } },
            { url: 'covered', valueCode: 'covered' },
            { url: 'dependency', valueId: 'dep-assertion-id-123' }
          ]
        }]
      }
    }
  end

  describe 'When checking coverage information actions' do
    it 'skips when no hook requests have been received' do
      result = run(runnable)
      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No hook requests received/)
    end

    it 'fails when no coverage information actions are found' do
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return(
          [Inferno::Entities::Request.new(
            request_body: order_sign_hook_request,
            response_body: { cards: [], systemActions: [] }.to_json
          )]
        )

      result = run(runnable)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Support for the Coverage Information response type not demonstrated/)
    end

    it 'fails when some must support elements are missing' do
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return(
          [Inferno::Entities::Request.new(
            request_body: order_sign_hook_request,
            response_body: order_sign_hook_response_complete
          )]
        )

      result = run(runnable)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Extension.extension:dependency/)
    end

    it 'passes when all must support elements are present' do
      allow_any_instance_of(described_class)
        .to receive(:requests_to_analyze).and_return(
          [Inferno::Entities::Request.new(
            request_body: order_sign_hook_request,
            response_body: order_sign_hook_response_complete
          ), Inferno::Entities::Request.new(
            request_body: order_sign_hook_request,
            response_body: { cards: [], systemActions: [dependency_system_action] }.to_json
          )]
        )

      result = run(runnable)
      expect(result.result).to eq('pass')
    end
  end
end
