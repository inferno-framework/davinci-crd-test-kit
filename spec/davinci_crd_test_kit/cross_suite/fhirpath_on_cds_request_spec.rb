require_relative '../../../lib/davinci_crd_test_kit/cross_suite/fhirpath_on_cds_request'

RSpec.describe DaVinciCRDTestKit::FhirpathOnCDSRequest do
  let(:module_instance) { Class.new { include DaVinciCRDTestKit::FhirpathOnCDSRequest }.new }
  let(:fhirpath_url) { 'https://example.com/fhirpath/evaluate' }

  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'order_sign_hook_request.json')))
  end
  let(:order_dispatch_v221_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'order_dispatch_hook_v221_request.json')))
  end
  let(:crd_practitioner_example) do
    FHIR.from_contents(File.read(File.join(__dir__, '..', '..', 'fixtures', 'crd_practitioner_example.json')))
  end
  let(:crd_service_request_example) do
    FHIR.from_contents(File.read(File.join(__dir__, '..', '..', 'fixtures', 'crd_service_request_example.json')))
  end
  let(:nutrition_order) do
    FHIR.from_contents(File.read(File.join(__dir__, '..', '..', 'fixtures', 'NutritionOrder-pureeddiet-simple.json')))
  end
  let(:medication_request) do
    FHIR.from_contents(File.read(File.join(__dir__, '..', '..', 'fixtures',
                                           'MedicationRequest-smart-MedicationRequest-103.json')))
  end
  let(:task_schedule_json) do
    File.read(File.join(__dir__, '..', '..', 'fixtures', 'Task-example-schedule-task.json'))
  end
  let(:task_refill_json) do
    File.read(File.join(__dir__, '..', '..', 'fixtures', 'Task-example-refill-task.json'))
  end

  describe 'today() expressions' do
    let(:fixed_date) { Date.new(2026, 5, 28) }

    before { allow(Date).to receive(:today).and_return(fixed_date) }

    it 'returns today\'s date for today()' do
      result = module_instance.execute_fhirpath_on_cds_request({}, 'today()')
      expect(result).to eq(['2026-05-28'])
    end

    it 'returns a past date for today()-N days' do
      result = module_instance.execute_fhirpath_on_cds_request({}, 'today()-7 days')
      expect(result).to eq(['2026-05-21'])
    end

    it 'returns a future date for today()+N days' do
      result = module_instance.execute_fhirpath_on_cds_request({}, 'today()+3 days')
      expect(result).to eq(['2026-05-31'])
    end

    it 'allows whitespace around the operator' do
      result = module_instance.execute_fhirpath_on_cds_request({}, 'today() + 10 days')
      expect(result).to eq(['2026-06-07'])
    end

    it 'allows whitespace around the minus operator' do
      result = module_instance.execute_fhirpath_on_cds_request({}, 'today() - 10 days')
      expect(result).to eq(['2026-05-18'])
    end
  end

  describe 'for cds hook request fields' do
    it 'returns the value for a base string field' do
      results = module_instance.execute_fhirpath_on_cds_request(order_sign_request, 'hook')

      expect(results).to be_an_instance_of(Array)
      expect(results.length).to eq(1)
      expect(results[0]).to eq('order-sign')
    end

    it 'returns the value for a nested object field' do
      results = module_instance.execute_fhirpath_on_cds_request(order_sign_request, 'fhirAuthorization')

      expect(results).to be_an_instance_of(Array)
      expect(results.length).to eq(1)
      expect(results[0]).to be_an_instance_of(Hash)
      expect(results[0]['access_token']).to eq('SAMPLE_TOKEN')
    end

    it 'returns the value for a nested string field' do
      results = module_instance.execute_fhirpath_on_cds_request(order_sign_request, 'fhirAuthorization.access_token')

      expect(results).to be_an_instance_of(Array)
      expect(results.length).to eq(1)
      expect(results[0]).to eq('SAMPLE_TOKEN')
    end

    it 'returns the value for a list field' do
      results = module_instance.execute_fhirpath_on_cds_request(order_dispatch_v221_request, 'context.dispatchedOrders')

      expect(results).to be_an_instance_of(Array)
      expect(results.length).to eq(2)
      expect(results[0]).to eq('ServiceRequest/example')
      expect(results[1]).to eq('MedicationRequest/smart-MedicationRequest-103')
    end

    #   it 'resolves lists of references in the cds request' do
    #     results = module_instance.execute_fhirpath_on_cds_request(
    #       order_dispatch_v221_request,
    #       'context.dispatchedOrders.resolve()',
    #       fetched_resources:
    #         { 'ServiceRequest/example' => JSON.parse(crd_service_request_example.to_json),
    #           'MedicationRequest/smart-MedicationRequest-103' => JSON.parse(medication_request.to_json) }
    #     )

    #     expect(results).to be_an_instance_of(Array)
    #     expect(results.length).to eq(2)
    #     expect(results[0]).to be_a(Hash)
    #     expect(results[0]['resourceType']).to eq('ServiceRequest')
    #     expect(results[0]['id']).to eq('example')
    #     expect(results[1]).to be_a(Hash)
    #     expect(results[1]['resourceType']).to eq('MedicationRequest')
    #     expect(results[1]['id']).to eq('smart-MedicationRequest-103')
    #   end
  end

  describe 'for fhirpath on resources in the cds object' do
    it 'clears current_fhir_base_server after execution' do
      hook_request = {
        'context' => {
          'draftOrders' => {
            'resourceType' => 'Bundle',
            'entry' => [{ 'fullUrl' => 'http://example.com/fhir/NutritionOrder/1',
                          'resource' => { 'resourceType' => 'NutritionOrder', 'id' => '1' } }]
          }
        }
      }
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.id")
        .to_return(status: 200, body: [{ type: 'id', element: '1' }].to_json)

      module_instance.execute_fhirpath_on_cds_request(hook_request, 'context.draftOrders.entry.resource.id')

      expect(module_instance.instance_variable_get(:@current_base_fhir_server)).to be_nil
    end

    it 'returns an empty array without calling the fhirpath service when the target hash is nil' do
      stub_request(:post, /#{Regexp.escape(fhirpath_url)}/)
      results = module_instance.execute_fhirpath_on_cds_request(
        order_sign_request,
        'context.nonExistentField.someProperty'
      )
      expect(results).to eq([])
      expect(a_request(:post, /#{Regexp.escape(fhirpath_url)}/)).to_not have_been_made
    end

    it 'returns the value for a nested FHIR resource field' do
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.id")
        .to_return(status: 200, body: [{ type: 'id', element: 'pureeddiet-simple' },
                                       { type: 'id', element: 'smart-MedicationRequest-103' }].to_json)

      results =
        module_instance.execute_fhirpath_on_cds_request(order_sign_request, 'context.draftOrders.entry.resource.id')

      expect(results).to be_an_instance_of(Array)
      expect(results.length).to eq(2)
      expect(results[0]).to eq('pureeddiet-simple')
      expect(results[1]).to eq('smart-MedicationRequest-103')
    end

    it 'returns the value for a nested FHIR resource field filtered by type' do
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(MedicationRequest).id")
        .to_return(status: 200, body: [{ type: 'id', element: 'smart-MedicationRequest-103' }].to_json)

      results =
        module_instance
          .execute_fhirpath_on_cds_request(order_sign_request,
                                           'context.draftOrders.entry.resource.ofType(MedicationRequest).id')

      expect(results).to be_an_instance_of(Array)
      expect(results.length).to eq(1)
      expect(results[0]).to eq('smart-MedicationRequest-103')
    end

    it 'executes fhirpath on a list of FHIR resources in a cds request' do
      fhirpath_result_one = [{ type: 'Reference', element: { 'reference' => 'ServiceRequest/example' } }]
      stub_request(:post, "#{fhirpath_url}?path=focus")
        .with(body: /"id":"example-schedule-task"/)
        .to_return(status: 200, body: fhirpath_result_one.to_json)
      fhirpath_result_two = [{ type: 'Reference',
                               element: { 'reference' => 'MedicationRequest/smart-MedicationRequest-103' } }]
      stub_request(:post, "#{fhirpath_url}?path=focus")
        .with(body: /"id":"example-refill-task"/)
        .to_return(status: 200, body: fhirpath_result_two.to_json)

      results = module_instance.execute_fhirpath_on_cds_request(
        order_dispatch_v221_request,
        'context.fulfillmentTasks.focus'
      )

      expect(results).to be_an_instance_of(Array)
      expect(results.length).to eq(2)
      expect(results[0]['reference']).to eq('ServiceRequest/example')
      expect(results[1]['reference']).to eq('MedicationRequest/smart-MedicationRequest-103')
    end
  end

  describe 'current_base_fhir_server during execution' do
    let(:captured_base_servers) { [] }
    let(:capturing_instance) do
      servers = captured_base_servers
      Class.new do
        include DaVinciCRDTestKit::FhirpathOnCDSRequest

        private

        define_method(:resolve) do |_reference|
          servers << @current_base_fhir_server
          nil
        end
      end.new
    end

    it 'defaults @current_base_fhir_server from hook request fhirServer' do
      hook_request = {
        'fhirServer' => 'http://example.com/fhir',
        'context' => { 'patient' => 'Patient/123' }
      }
      capturing_instance.execute_fhirpath_on_cds_request(hook_request, 'context.patient.resolve()')
      expect(captured_base_servers).to eq(['http://example.com/fhir'])
    end

    it 'overrides @current_base_fhir_server from entry fullUrl during entry.resource processing' do
      hook_request = {
        'fhirServer' => 'http://example.com/fhir',
        'context' => {
          'draftOrders' => {
            'resourceType' => 'Bundle',
            'entry' => [{
              'fullUrl' => 'http://entry.example.com/fhir/NutritionOrder/1',
              'resource' => { 'resourceType' => 'NutritionOrder', 'id' => '1' }
            }]
          }
        }
      }
      stub_request(:post, "#{fhirpath_url}?path=subject")
        .to_return(status: 200, body: [{ type: 'string', element: 'Patient/123' }].to_json)

      capturing_instance.execute_fhirpath_on_cds_request(
        hook_request,
        'context.draftOrders.entry.resource.subject.resolve()'
      )
      expect(captured_base_servers).to eq(['http://entry.example.com/fhir'])
    end
  end

  describe 'entry.resource queries with resolve()' do
    let(:hook_request_with_entry) do
      {
        'fhirServer' => 'http://example.com/fhir',
        'context' => {
          'draftOrders' => {
            'resourceType' => 'Bundle',
            'entry' => [{
              'fullUrl' => 'http://example.com/fhir/NutritionOrder/1',
              'resource' => { 'resourceType' => 'NutritionOrder', 'id' => '1' }
            }]
          }
        }
      }
    end

    it 'raises FhirpathServiceError when an unsupported function appears after resolve()' do
      expect do
        module_instance.execute_fhirpath_on_cds_request(
          hook_request_with_entry,
          'context.draftOrders.entry.resource.subject.resolve().exists()'
        )
      end.to raise_error(DaVinciCRDTestKit::FhirpathServiceError, /exists/)
    end

    it 'raises before making any fhirpath service calls' do
      stub_request(:post, /#{Regexp.escape(fhirpath_url)}/)
      expect do
        module_instance.execute_fhirpath_on_cds_request(
          hook_request_with_entry,
          'context.draftOrders.entry.resource.subject.resolve().count()'
        )
      end.to raise_error(DaVinciCRDTestKit::FhirpathServiceError)
      expect(a_request(:post, /#{Regexp.escape(fhirpath_url)}/)).to_not have_been_made
    end

    it 'permits ofType() after resolve()' do
      stub_request(:post, "#{fhirpath_url}?path=subject")
        .to_return(status: 200, body: [{ type: 'string', element: 'Patient/123' }].to_json)
      expect do
        module_instance.execute_fhirpath_on_cds_request(
          hook_request_with_entry,
          'context.draftOrders.entry.resource.subject.resolve().ofType(Patient)'
        )
      end.to_not raise_error
    end

    it 'permits chained resolve() after resolve()' do
      stub_request(:post, "#{fhirpath_url}?path=subject")
        .to_return(status: 200, body: [{ type: 'string', element: 'Patient/123' }].to_json)
      expect do
        module_instance.execute_fhirpath_on_cds_request(
          hook_request_with_entry,
          'context.draftOrders.entry.resource.subject.resolve().resolve()'
        )
      end.to_not raise_error
    end
  end

  describe '#base_fhir_server_for_identity' do
    def base_fhir_server(url)
      module_instance.send(:base_fhir_server_for_identity, url)
    end

    it 'returns nil for nil input' do
      expect(base_fhir_server(nil)).to be_nil
    end

    it 'returns nil for an empty string' do
      expect(base_fhir_server('')).to be_nil
    end

    it 'returns the base server for an http URL' do
      expect(base_fhir_server('http://example.com/fhir/NutritionOrder/1')).to eq('http://example.com/fhir')
    end

    it 'returns the base server for an https URL' do
      expect(base_fhir_server('https://example.com/fhir/Patient/123')).to eq('https://example.com/fhir')
    end

    it 'returns nil for a relative URL' do
      expect(base_fhir_server('NutritionOrder/1')).to be_nil
    end

    it 'returns nil for a urn scheme' do
      expect(base_fhir_server('urn:uuid:some-uuid')).to be_nil
    end

    it 'returns nil for an invalid URI' do
      expect(base_fhir_server('http://example.com/foo bar')).to be_nil
    end
  end
end
