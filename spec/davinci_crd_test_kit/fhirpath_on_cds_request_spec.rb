require_relative '../../lib/davinci_crd_test_kit/cross_suite/fhirpath_on_cds_request'

RSpec.describe DaVinciCRDTestKit::FhirpathOnCDSRequest do
  let(:module_instance) { Class.new { include DaVinciCRDTestKit::FhirpathOnCDSRequest }.new }
  let(:fhirpath_url) { 'https://example.com/fhirpath/evaluate' }

  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_sign_hook_request.json')))
  end
  let(:order_dispatch_v220_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_dispatch_hook_v220_request.json')))
  end
  let(:crd_practitioner_example) do
    FHIR.from_contents(File.read(File.join(__dir__, '..', 'fixtures', 'crd_practitioner_example.json')))
  end
  let(:crd_service_request_example) do
    FHIR.from_contents(File.read(File.join(__dir__, '..', 'fixtures', 'crd_service_request_example.json')))
  end
  let(:nutrition_order) do
    FHIR.from_contents(File.read(File.join(__dir__, '..', 'fixtures', 'NutritionOrder-pureeddiet-simple.json')))
  end
  let(:medication_request) do
    FHIR.from_contents(File.read(File.join(__dir__, '..', 'fixtures',
                                           'MedicationRequest-smart-MedicationRequest-103.json')))
  end
  let(:task_schedule_json) do
    File.read(File.join(__dir__, '..', 'fixtures', 'Task-example-schedule-task.json'))
  end
  let(:task_refill_json) do
    File.read(File.join(__dir__, '..', 'fixtures', 'Task-example-refill-task.json'))
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
      results = module_instance.execute_fhirpath_on_cds_request(order_dispatch_v220_request, 'context.dispatchedOrders')

      expect(results).to be_an_instance_of(Array)
      expect(results.length).to eq(2)
      expect(results[0]).to eq('ServiceRequest/example')
      expect(results[1]).to eq('MedicationRequest/smart-MedicationRequest-103')
    end

    #   it 'resolves lists of references in the cds request' do
    #     results = module_instance.execute_fhirpath_on_cds_request(
    #       order_dispatch_v220_request,
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
    it 'returns the value for a nested FHIR resource field' do
      fhirpath_result = [{ type: 'id', element: 'pureeddiet-simple' },
                         { type: 'id', element: 'smart-MedicationRequest-103' }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.id")
        .to_return(status: 200, body: fhirpath_result.to_json)

      results =
        module_instance.execute_fhirpath_on_cds_request(order_sign_request, 'context.draftOrders.entry.resource.id')

      expect(results).to be_an_instance_of(Array)
      expect(results.length).to eq(2)
      expect(results[0]).to eq('pureeddiet-simple')
      expect(results[1]).to eq('smart-MedicationRequest-103')
    end

    it 'returns the value for a nested FHIR resource field filtered by type' do
      fhirpath_result = [{ type: 'id', element: 'smart-MedicationRequest-103' }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.ofType(MedicationRequest).id")
        .to_return(status: 200, body: fhirpath_result.to_json)

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
        order_dispatch_v220_request,
        'context.fulfillmentTasks.focus'
      )

      expect(results).to be_an_instance_of(Array)
      expect(results.length).to eq(2)
      expect(results[0]['reference']).to eq('ServiceRequest/example')
      expect(results[1]['reference']).to eq('MedicationRequest/smart-MedicationRequest-103')
    end

    # it 'supports chained resolves' do
    #   fhirpath_result_one = [{ type: 'Reference', element: { 'reference' => 'Practitioner/example' } }]
    #   stub_request(:post, "#{fhirpath_url}?path=orderer")
    #     .with(body: /"resourceType":"ServiceRequest"/)
    #     .to_return(status: 200, body: fhirpath_result_one.to_json)
    #   stub_request(:post, "#{fhirpath_url}?path=orderer")
    #     .with(body: /"resourceType":"MedicationRequest"/)
    #     .to_return(status: 200, body: [].to_json)
    #   fhirpath_result_three = [{ type: 'id', element: 'example' }]
    #   stub_request(:post, "#{fhirpath_url}?path=id")
    #     .to_return(status: 200, body: fhirpath_result_three.to_json)

    #   results = module_instance.execute_fhirpath_on_cds_request(
    #     order_dispatch_v220_request,
    #     'context.dispatchedOrders.resolve().orderer.resolve().id',
    #     fetched_resources:
    #       { 'ServiceRequest/example' => JSON.parse(crd_service_request_example.to_json),
    #         'MedicationRequest/smart-MedicationRequest-103' => JSON.parse(medication_request.to_json),
    #         'Practitioner/example' => JSON.parse(crd_practitioner_example.to_json) }
    #   )

    #   expect(results).to be_an_instance_of(Array)
    #   expect(results.length).to eq(1)
    #   expect(results[0]).to eq('example')
    # end

    # it 'resolves references found in FHIR resources' do
    #   fhirpath_result = [{ type: 'Reference', element: nutrition_order.orderer }]
    #   stub_request(:post, "#{fhirpath_url}?path=entry.resource.orderer")
    #     .to_return(status: 200, body: fhirpath_result.to_json)

    #   results =
    #     module_instance.execute_fhirpath_on_cds_request(
    #       order_sign_request,
    #       'context.draftOrders.entry.resource.orderer.resolve()',
    #       fetched_resources: { 'Practitioner/example' => JSON.parse(crd_practitioner_example.to_json) }
    #     )

    #   expect(results).to be_an_instance_of(Array)
    #   expect(results.length).to eq(1)
    #   expect(results[0]).to be_a(Hash)
    #   expect(results[0]['resourceType']).to eq('Practitioner')
    #   expect(results[0]['id']).to eq('example')
    # end

    # it 'executes more fhirpath after resolving references found in FHIR resources' do
    #   fhirpath_result_one = [{ type: 'Reference', element: nutrition_order.orderer }]
    #   stub_request(:post, "#{fhirpath_url}?path=entry.resource.orderer")
    #     .to_return(status: 200, body: fhirpath_result_one.to_json)
    #   fhirpath_result_two = [{ type: 'id', element: 'example' }]
    #   stub_request(:post, "#{fhirpath_url}?path=id")
    #     .to_return(status: 200, body: fhirpath_result_two.to_json)

    #   results =
    #     module_instance.execute_fhirpath_on_cds_request(
    #       order_sign_request,
    #       'context.draftOrders.entry.resource.orderer.resolve().id',
    #       fetched_resources: { 'Practitioner/example' => JSON.parse(crd_practitioner_example.to_json) }
    #     )

    #   expect(results).to be_an_instance_of(Array)
    #   expect(results.length).to eq(1)
    #   expect(results[0]).to be_a(String)
    #   expect(results[0]).to eq('example')
    # end
  end
end
