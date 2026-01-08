require_relative '../../lib/davinci_crd_test_kit/gather_response_generation_data'

RSpec.describe DaVinciCRDTestKit::GatherResponseGenerationData do
  let(:module_instance) do
    Class.new do
      include DaVinciCRDTestKit::GatherResponseGenerationData

      def request_body
        nil
      end
    end.new
  end

  let(:fhir_server) { 'https://example/r4' }
  let(:patient_example_reference_relative) { 'Patient/example' }
  let(:patient_example_reference_absolute) { "#{fhir_server}/#{patient_example_reference_relative}" }
  let(:patient_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_patient_example.json')))
  end
  let(:organization_example_reference_relative) { 'Organization/example' }
  let(:organization_example_reference_absolute) { "#{fhir_server}/#{organization_example_reference_relative}" }
  let(:organization_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_organization_example.json')))
  end
  let(:practitioner_example_reference_relative) { 'Practitioner/example' }
  let(:practitioner_example_reference_absolute) { "#{fhir_server}/#{practitioner_example_reference_relative}" }
  let(:practitioner_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_practitioner_example.json')))
  end
  let(:practitioner_role_example_reference_relative) { 'PractitionerRole/example' }
  let(:practitioner_role_example_reference_absolute) do
    "#{fhir_server}/#{practitioner_role_example_reference_relative}"
  end
  let(:practitioner_role_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_practitioner_role_example.json')))
  end
  let(:location_example_reference_relative) { 'Location/example' }
  let(:location_example_reference_absolute) do
    "#{fhir_server}/#{location_example_reference_relative}"
  end
  let(:location_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_location_example.json')))
  end
  let(:location2_example_reference_relative) { 'Location/example2' }
  let(:location2_example_reference_absolute) do
    "#{fhir_server}/#{location2_example_reference_relative}"
  end
  let(:location2_example) do
    loc = JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_location_example.json')))
    loc['id'] = 'example2'
    loc
  end
  let(:encounter_example_reference_relative) { 'Encounter/example' }
  let(:encounter_example_reference_absolute) do
    "#{fhir_server}/#{encounter_example_reference_relative}"
  end
  let(:encounter_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_encounter_example.json')))
  end
  let(:service_request_example_reference_relative) { 'ServiceRequest/example' }
  let(:service_request_example_reference_absolute) do
    "#{fhir_server}/#{service_request_example_reference_relative}"
  end
  let(:service_request_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_service_request_example.json')))
  end
  let(:appointment_book_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'appointment_book_hook_request.json')))
  end
  let(:encounter_start_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'encounter_start_hook_request.json')))
  end
  let(:encounter_discharge_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'encounter_discharge_hook_request.json')))
  end
  let(:order_select_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_select_hook_request.json')))
  end
  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_sign_hook_request.json')))
  end
  let(:order_dispatch_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_dispatch_hook_request.json')))
  end

  before do
    allow(module_instance).to(receive(:persist_query_request))
  end

  describe 'when deciding what data to fetch' do
    it 'does not fetch data that has been prefetched (relative reference)' do
      order_sign_request['prefetch'] = { patient: patient_example }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      module_instance.gather_data_for_request([patient_example_reference_relative], [])
      expect(module_instance.prefetched_resources[patient_example_reference_relative]).to eq(patient_example)
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to eq(patient_example)
      # no http requests made
    end

    it 'does not fetch data that has been prefetched (local absolute reference)' do
      order_sign_request['prefetch'] = { patient: patient_example }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      module_instance.gather_data_for_request([patient_example_reference_absolute], [])
      expect(module_instance.prefetched_resources[patient_example_reference_relative]).to eq(patient_example)
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to eq(patient_example)
      # no http requests made
    end

    it 'does not fetch data that has already been fetched (relative reference)' do
      allow(module_instance).to receive_messages(request_body: order_sign_request,
                                                 analyzed_resources:
                                                  { patient_example_reference_relative => patient_example })

      module_instance.gather_data_for_request([patient_example_reference_relative], [])
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to eq(patient_example)
      # no http requests made
    end

    it 'does not fetch data that has already been fetched (local absolute reference)' do
      allow(module_instance).to receive_messages(request_body: order_sign_request,
                                                 analyzed_resources:
                                                  { patient_example_reference_relative => patient_example })

      module_instance.gather_data_for_request(["#{fhir_server}/#{patient_example_reference_relative}"], [])
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to eq(patient_example)
      # no http requests made
    end

    it 'does not fetch data that has already been fetched (external absolute reference)' do
      external_reference = "https://another.server/r4/#{patient_example_reference_relative}"
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      allow(module_instance).to receive_messages(request_body: order_sign_request,
                                                 analyzed_resources: { external_reference => patient_example })

      module_instance.gather_data_for_request([external_reference], [])
      expect(module_instance.analyzed_resources[external_reference]).to eq(patient_example)
      # no http requests made
    end

    it 'requests references (relative reference)' do
      allow(module_instance).to receive_messages(request_body: order_sign_request)

      local_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)

      module_instance.gather_data_for_request([patient_example_reference_relative], [])
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to eq(patient_example)
      expect(local_request).to have_been_made.once
    end

    it 'requests references (local absolute reference)' do
      allow(module_instance).to receive_messages(request_body: order_sign_request)

      local_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)

      module_instance.gather_data_for_request([patient_example_reference_absolute], [])
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to eq(patient_example)
      expect(local_request).to have_been_made.once
    end

    it 'requests references (external absolute refrence)' do
      external_reference = "https://another.server/r4/#{patient_example_reference_relative}"
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      external_request = stub_request(:get, external_reference)
        .to_return(status: 200, body: patient_example.to_json)

      module_instance.gather_data_for_request([external_reference], [])
      expect(module_instance.analyzed_resources[external_reference]).to eq(patient_example)
      expect(external_request).to have_been_made.once
    end
  end

  describe 'when analyzing resources' do
    it 'finds references in top-level, single entry elements' do
      order_sign_request['prefetch'] = { practitioner: practitioner_example }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      module_instance.gather_data_for_request([], [practitioner_role_example])
      expect(module_instance.analyzed_resources.size).to eq(2)
      expect(module_instance.analyzed_resources[practitioner_role_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
    end

    it 'finds references in top-level, multiple entry elements' do
      order_sign_request['prefetch'] = { loc1: location_example, loc2: location2_example }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      practitioner_role_example.delete('practitioner')
      practitioner_role_example['location'] = [
        { 'reference' => location_example_reference_relative },
        { 'reference' => location2_example_reference_relative }
      ]

      module_instance.gather_data_for_request([], [practitioner_role_example])
      expect(module_instance.analyzed_resources.size).to eq(3)
      expect(module_instance.analyzed_resources[practitioner_role_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location2_example_reference_relative]).to be_present
    end

    it 'finds references in single entry elements nested under multi-entry elements' do
      order_sign_request['prefetch'] =
        { practitioner: practitioner_example, loc1: location_example, loc2: location2_example }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      encounter_example.delete('serviceProvider')

      module_instance.gather_data_for_request([], [encounter_example])
      expect(module_instance.analyzed_resources.size).to eq(4)
      expect(module_instance.analyzed_resources[encounter_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location2_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
    end

    it 'ignores references that are not literal' do
      practitioner_role_example['practitioner'] = {
        'identifier' => {
          'system' => 'http://hl7.org/fhir/sid/us-npi',
          'value' => '9941339108'
        }
      }

      module_instance.gather_data_for_request([], [practitioner_role_example])
      expect(module_instance.analyzed_resources.size).to eq(1)
      expect(module_instance.analyzed_resources[practitioner_role_example_reference_relative]).to be_present
    end
  end

  describe 'when fetching data' do
    it 'handles resource fetch failures' do
      order_sign_request['prefetch'] = { patient: patient_example }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      failed_request = stub_request(:get, practitioner_role_example_reference_absolute)
        .to_return(status: 401)

      module_instance.gather_data_for_request([practitioner_role_example_reference_relative,
                                               patient_example_reference_relative], [])

      expect(module_instance.analyzed_resources.size).to eq(2)
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources.key?(practitioner_role_example_reference_relative)).to be(true)
      expect(module_instance.analyzed_resources[practitioner_role_example_reference_relative]).to be_nil
      expect(failed_request).to have_been_made.once
    end

    it 'analyzes fetched resources and fetches found references' do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      pr_request = stub_request(:get, practitioner_role_example_reference_absolute)
        .to_return(status: 200, body: practitioner_role_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)

      module_instance.gather_data_for_request([practitioner_role_example_reference_relative], [])

      expect(module_instance.analyzed_resources.size).to eq(2)
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[practitioner_role_example_reference_relative]).to be_present
      expect(pr_request).to have_been_made.once
      expect(p_request).to have_been_made.once
    end
  end

  describe 'when identifying prefetched resources' do
    it 'handles requests with no prefetch' do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      expect(module_instance.prefetched_resources.is_a?(Hash)).to be(true)
      expect(module_instance.prefetched_resources.size).to be(0)
    end

    it 'ignores bad entries' do
      order_sign_request['prefetch'] = {
        good_resource: { 'resourceType' => 'Patient', 'id' => '123' },
        bad_empty: nil,
        bad_not_hash: 'test',
        bad_resource_no_type: { 'id' => '123' },
        bad_resource_no_id: { 'resourceType' => 'Patient' },
        bundle: {
          'resourceType' => 'Bundle',
          'entry' => [
            nil,
            'not_a_hash',
            {
              'not_resource' => 'wrong'
            },
            {
              'resource' => 'not a hash'
            },
            {
              'resource' => { 'resourceType' => 'no id' }
            },
            {
              'resource' => { 'id' => 'no resourceType' }
            },
            {
              'resource' => { 'resourceType' => 'Coverage', 'id' => '456' }
            }
          ]
        }
      }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
      expect(module_instance.prefetched_resources.is_a?(Hash)).to be(true)
      expect(module_instance.prefetched_resources.size).to be(2)
      expect(module_instance.prefetched_resources['Patient/123']).to be_present
      expect(module_instance.prefetched_resources['Coverage/456']).to be_present
    end
  end

  describe 'when fetching data for specific hooks' do
    it 'fetches expected resources for appointment-book example' do
      allow(module_instance).to receive(:request_body).and_return(appointment_book_request)

      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)

      module_instance.gather_appointment_book_data
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources['Appointment/apt1']).to be_present
      expect(module_instance.analyzed_resources['Appointment/apt2']).to be_present
      expect(module_instance.analyzed_resources.size).to eq(4)
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
    end

    it 'fetches expected resources for encounter-start example' do
      allow(module_instance).to receive(:request_body).and_return(encounter_start_request)

      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)
      e_request = stub_request(:get, encounter_example_reference_absolute)
        .to_return(status: 200, body: encounter_example.to_json)
      l_request = stub_request(:get, location_example_reference_absolute)
        .to_return(status: 200, body: location_example.to_json)
      l2_request = stub_request(:get, location2_example_reference_absolute)
        .to_return(status: 200, body: location2_example.to_json)
      o_request = stub_request(:get, organization_example_reference_absolute)
        .to_return(status: 200, body: organization_example.to_json)

      module_instance.gather_encounter_start_data
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[encounter_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location2_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[organization_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources.size).to eq(6)
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
      expect(e_request).to have_been_made.once
      expect(l_request).to have_been_made.once
      expect(l2_request).to have_been_made.once
      expect(o_request).to have_been_made.once
    end

    it 'fetches expected resources for encounter-discharge example' do
      allow(module_instance).to receive(:request_body).and_return(encounter_discharge_request)

      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)
      e_request = stub_request(:get, encounter_example_reference_absolute)
        .to_return(status: 200, body: encounter_example.to_json)
      l_request = stub_request(:get, location_example_reference_absolute)
        .to_return(status: 200, body: location_example.to_json)
      l2_request = stub_request(:get, location2_example_reference_absolute)
        .to_return(status: 200, body: location2_example.to_json)
      o_request = stub_request(:get, organization_example_reference_absolute)
        .to_return(status: 200, body: organization_example.to_json)

      module_instance.gather_encounter_discharge_data
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[encounter_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[location2_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[organization_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources.size).to eq(6)
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
      expect(e_request).to have_been_made.once
      expect(l_request).to have_been_made.once
      expect(l2_request).to have_been_made.once
      expect(o_request).to have_been_made.once
    end

    it 'fetches expected resources for order-select example' do
      allow(module_instance).to receive(:request_body).and_return(order_select_request)

      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)

      module_instance.gather_order_select_data
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources['MedicationRequest/smart-MedicationRequest-103']).to be_present
      expect(module_instance.analyzed_resources['NutritionOrder/pureeddiet-simple']).to be_present
      expect(module_instance.analyzed_resources.size).to eq(4)
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
    end

    it 'fetches expected resources for order-sign example' do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)

      module_instance.gather_order_sign_data
      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources['MedicationRequest/smart-MedicationRequest-103']).to be_present
      expect(module_instance.analyzed_resources['NutritionOrder/pureeddiet-simple']).to be_present
      expect(module_instance.analyzed_resources.size).to eq(4)
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
    end

    it 'fetches expected resources for order-dispatch example' do
      allow(module_instance).to receive(:request_body).and_return(order_dispatch_request)

      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)
      sr_request = stub_request(:get, service_request_example_reference_absolute)
        .to_return(status: 200, body: location_example.to_json)

      module_instance.gather_order_dispatch_data

      expect(module_instance.analyzed_resources[practitioner_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[patient_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources[service_request_example_reference_relative]).to be_present
      expect(module_instance.analyzed_resources['Task/example3']).to be_present
      expect(module_instance.analyzed_resources.size).to eq(4)
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
      expect(sr_request).to have_been_made.once
    end
  end
end
