require_relative '../../../lib/davinci_crd_test_kit/cross_suite/hook_request_resource_extraction'

RSpec.describe DaVinciCRDTestKit::HookRequestResourceExtraction do
  let(:extraction) { described_class }

  def resource(type, id)
    { 'resourceType' => type, 'id' => id }
  end

  def bundle(*resources)
    { 'resourceType' => 'Bundle', 'type' => 'collection',
      'entry' => resources.map { |one| { 'resource' => one } } }
  end

  def collect(method, argument)
    [].tap { |found| extraction.send(method, argument) { |one| found << one } }
  end

  describe '.each_prefetch_resource' do
    it 'yields bare resources' do
      found = collect(:each_prefetch_resource, { 'patient' => resource('Patient', '1') })

      expect(found).to eq([resource('Patient', '1')])
    end

    it 'unwraps bundles' do
      prefetch = { 'coverage' => bundle(resource('Coverage', '1'), resource('Coverage', '2')) }

      expect(collect(:each_prefetch_resource, prefetch).map { |one| one['id'] }).to eq(%w[1 2])
    end

    it 'ignores the prefetch key names, so short and long keys behave identically' do
      long = { 'coverage' => bundle(resource('Coverage', '1')), 'locations' => bundle(resource('Location', '2')) }
      short = { 'cov' => bundle(resource('Coverage', '1')), 'locs' => bundle(resource('Location', '2')) }

      expect(collect(:each_prefetch_resource, short)).to eq(collect(:each_prefetch_resource, long))
    end

    it 'skips null values, which a client sends when a prefetch template matched nothing' do
      prefetch = { 'patient' => resource('Patient', '1'), 'encounter' => nil }

      expect(collect(:each_prefetch_resource, prefetch)).to eq([resource('Patient', '1')])
    end

    it 'skips values that are not FHIR resources' do
      prefetch = { 'patient' => resource('Patient', '1'), 'junk' => { 'no' => 'resourceType' }, 'text' => 'nope' }

      expect(collect(:each_prefetch_resource, prefetch)).to eq([resource('Patient', '1')])
    end

    it 'yields nothing when prefetch is absent or not a hash' do
      expect(collect(:each_prefetch_resource, nil)).to eq([])
      expect(collect(:each_prefetch_resource, 'not a hash')).to eq([])
    end

    it 'skips bundle entries without a resource' do
      prefetch = { 'coverage' => { 'resourceType' => 'Bundle', 'entry' => [{ 'fullUrl' => 'x' }, nil] } }

      expect(collect(:each_prefetch_resource, prefetch)).to eq([])
    end
  end

  describe '.each_context_resource' do
    it 'unwraps the draftOrders bundle' do
      context = { 'patientId' => '1288992', 'draftOrders' => bundle(resource('ServiceRequest', 'sr1')) }

      expect(collect(:each_context_resource, context)).to eq([resource('ServiceRequest', 'sr1')])
    end

    it 'unwraps the appointments bundle' do
      context = { 'appointments' => bundle(resource('Appointment', 'a1')) }

      expect(collect(:each_context_resource, context)).to eq([resource('Appointment', 'a1')])
    end

    it 'yields resources held in an array' do
      context = { 'fulfillmentTasks' => [resource('Task', 't1'), resource('Task', 't2')] }

      expect(collect(:each_context_resource, context).map { |one| one['id'] }).to eq(%w[t1 t2])
    end

    it 'yields a bare resource held directly in a context field' do
      context = { 'task' => resource('Task', 't1') }

      expect(collect(:each_context_resource, context)).to eq([resource('Task', 't1')])
    end

    it 'ignores scalar context fields' do
      context = { 'patientId' => '1288992', 'userId' => 'Practitioner/123',
                  'encounterId' => '89284', 'selections' => ['ServiceRequest/sr1'] }

      expect(collect(:each_context_resource, context)).to eq([])
    end
  end

  describe '.each_hook_request_resource' do
    it 'yields resources from both context and prefetch' do
      request_body = {
        'context' => { 'draftOrders' => bundle(resource('ServiceRequest', 'sr1')) },
        'prefetch' => { 'patient' => resource('Patient', 'p1') }
      }

      expect(collect(:each_hook_request_resource, request_body).map { |one| one['resourceType'] })
        .to contain_exactly('ServiceRequest', 'Patient')
    end
  end

  describe '.fhir_resources_by_type' do
    def request_double(body)
      instance_double(Inferno::Entities::Request, request_body: body)
    end

    it 'groups parsed FHIR models by resource type' do
      request = request_double({
        'context' => { 'draftOrders' => bundle(resource('ServiceRequest', 'sr1')) },
        'prefetch' => { 'patient' => resource('Patient', 'p1') }
      }.to_json)

      grouped = extraction.fhir_resources_by_type([request])

      expect(grouped.keys).to contain_exactly('ServiceRequest', 'Patient')
      expect(grouped['ServiceRequest'].first).to be_a(FHIR::ServiceRequest)
      expect(grouped['Patient'].first.id).to eq('p1')
    end

    it 'keeps every instance rather than de-duplicating across requests' do
      body = { 'prefetch' => { 'patient' => resource('Patient', 'p1') } }.to_json
      requests = [request_double(body), request_double(body)]

      expect(extraction.fhir_resources_by_type(requests)['Patient'].length).to eq(2)
    end

    it 'skips requests whose body is not valid JSON' do
      requests = [request_double('not json'),
                  request_double({ 'prefetch' => { 'patient' => resource('Patient', 'p1') } }.to_json)]

      expect(extraction.fhir_resources_by_type(requests)['Patient'].length).to eq(1)
    end

    it 'returns an empty hash when given no requests' do
      expect(extraction.fhir_resources_by_type([])).to eq({})
      expect(extraction.fhir_resources_by_type(nil)).to eq({})
    end
  end
end
