require_relative '../../lib/davinci_crd_test_kit/fhirpath_on_cds_request'

RSpec.describe DaVinciCRDTestKit::FhirpathOnCDSRequest do
  let(:module_instance) { Class.new { include DaVinciCRDTestKit::FhirpathOnCDSRequest }.new }
  let(:fhirpath_url) { 'https://example.com/fhirpath/evaluate' }

  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_sign_hook_request.json')))
  end
  let(:fancy_structure_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'fancy_structure_hook_request.json')))
  end

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

  it 'returns the value for a list field' do
    results = module_instance.execute_fhirpath_on_cds_request(fancy_structure_request, 'context.list')

    expect(results).to be_an_instance_of(Array)
    expect(results.length).to eq(2)
    expect(results[0]['id']).to eq('123')
    expect(results[1]['id']).to eq('456')
  end

  it 'returns the value for a nested list field' do
    results = module_instance.execute_fhirpath_on_cds_request(fancy_structure_request, 'context.list.nested_list')

    expect(results).to be_an_instance_of(Array)
    expect(results.length).to eq(6)
    expect(results[0]).to eq('one')
    expect(results[5]).to eq('six')
  end

  it 'handles where(field=value) function when it matches' do
    results = module_instance.execute_fhirpath_on_cds_request(order_sign_request,
                                                              'context.where(patientId=example).userId')

    expect(results).to be_an_instance_of(Array)
    expect(results.length).to eq(1)
    expect(results[0]).to eq('Practitioner/example')
  end

  it 'handles where(field=value) function when it does not match' do
    results = module_instance.execute_fhirpath_on_cds_request(order_sign_request,
                                                              'context.where(patientId=wrong).userId')

    expect(results).to be_an_instance_of(Array)
    expect(results.length).to eq(0)
  end
end
