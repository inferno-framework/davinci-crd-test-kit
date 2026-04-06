require_relative '../../lib/davinci_crd_test_kit/cross_suite/fhirpath_on_cds_request'

RSpec.describe DaVinciCRDTestKit::ReplaceTokens do
  let(:module_instance) do
    Class.new do
      include DaVinciCRDTestKit::ReplaceTokens
      include DaVinciCRDTestKit::FhirpathOnCDSRequest
    end.new
  end
  let(:fhirpath_url) { 'https://example.com/fhirpath/evaluate' }

  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_sign_hook_request.json')))
  end

  let(:order_dispatch_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_dispatch_hook_v220_request.json')))
  end

  describe 'when replacing in a string' do
    it 'handles no replacements' do
      target = 'Patient/123'
      module_instance.replace_tokens(target, order_sign_request)

      expect(target).to eq('Patient/123')
    end

    it 'replaces single tokens' do
      target = 'Patient/{{context.patientId}}'
      module_instance.replace_tokens(target, order_sign_request)

      expect(target).to eq('Patient/example')
    end

    it 'replaces multiple tokens' do
      target = 'This is a silly example: {{context.patientId}}, {{fhirServer}}, {{fhirAuthorization.access_token}}'
      module_instance.replace_tokens(target, order_sign_request)

      expect(target).to eq('This is a silly example: example, https://example/r4, SAMPLE_TOKEN')
    end

    it 'replaces with the empty string if nothing found' do
      target = 'Patient/{{context.patientxId}}'
      module_instance.replace_tokens(target, order_sign_request)

      expect(target).to eq('Patient/')
    end

    it 'treats an object as if nothing found' do
      target = 'Here is a token replaced with an object: {{context}} (nothing)'
      module_instance.replace_tokens(target, order_sign_request)

      expect(target).to eq('Here is a token replaced with an object:  (nothing)')
    end

    it 'returns a comma-delimited list if multiple things found' do
      fhirpath_result_one = [{ type: 'id', element: 'example-schedule-task' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"id":"example-schedule-task"/)
        .to_return(status: 200, body: fhirpath_result_one.to_json)
      fhirpath_result_two = [{ type: 'id', element: 'example-refill-task' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"id":"example-refill-task"/)
        .to_return(status: 200, body: fhirpath_result_two.to_json)

      target = 'Task?_id={{context.fulfillmentTasks.id}}'
      module_instance.replace_tokens(target, order_dispatch_request)

      expect(target).to eq('Task?_id=example-schedule-task,example-refill-task')
    end

    it 'handles missing values via compacting' do
      fhirpath_result_one = [{ type: 'id', element: 'example-schedule-task' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"id":"example-schedule-task"/)
        .to_return(status: 200, body: fhirpath_result_one.to_json)
      fhirpath_result_two = [{ type: 'id', element: 'example-refill-task' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"id":"example-refill-task"/)
        .to_return(status: 200, body: fhirpath_result_two.to_json)

      target = 'Task?_id={{context.fulfillmentTasks.id|context.notThere}}'
      module_instance.replace_tokens(target, order_dispatch_request)

      expect(target).to eq('Task?_id=example-schedule-task,example-refill-task')
    end
  end

  describe 'when replacing in a Hash' do
    it 'performs replacements on each value' do
      fhirpath_result_one = [{ type: 'id', element: 'example-schedule-task' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"id":"example-schedule-task"/)
        .to_return(status: 200, body: fhirpath_result_one.to_json)
      fhirpath_result_two = [{ type: 'id', element: 'example-refill-task' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"id":"example-refill-task"/)
        .to_return(status: 200, body: fhirpath_result_two.to_json)

      hash = {
        '{{tricky}}': 'Task?_id={{context.fulfillmentTasks.id}}',
        patient: 'Patient/{{context.patientId}}'
      }
      module_instance.replace_tokens(hash, order_dispatch_request)

      expect(hash[:'{{tricky}}']).to eq('Task?_id=example-schedule-task,example-refill-task')
      expect(hash[:patient]).to eq('Patient/example')
    end
  end

  describe 'when replacing in an Array' do
    it 'performs replacements on each value' do
      fhirpath_result_one = [{ type: 'id', element: 'example-schedule-task' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"id":"example-schedule-task"/)
        .to_return(status: 200, body: fhirpath_result_one.to_json)
      fhirpath_result_two = [{ type: 'id', element: 'example-refill-task' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"id":"example-refill-task"/)
        .to_return(status: 200, body: fhirpath_result_two.to_json)

      array = [
        'Task?_id={{context.fulfillmentTasks.id}}',
        'Patient/{{context.patientId}}'
      ]

      module_instance.replace_tokens(array, order_dispatch_request)

      expect(array.length).to eq(2)
      expect(array[0]).to eq('Task?_id=example-schedule-task,example-refill-task')
      expect(array[1]).to eq('Patient/example')
    end
  end
end
