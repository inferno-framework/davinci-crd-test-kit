require_relative '../../lib/davinci_crd_test_kit/cross_suite/prefetch_completeness_checker'

RSpec.describe DaVinciCRDTestKit::PrefetchCompletenessChecker do
  let(:fhirpath_url) { 'https://example.com/fhirpath/evaluate' }

  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_sign_hook_request.json')))
  end
  let(:crd_patient_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_patient_example.json')))
  end
  let(:crd_patient_example_bundle) do
    { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => crd_patient_example }] }
  end
  let(:crd_coverage_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_coverage_example.json')))
  end
  let(:crd_coverage_example_bundle) do
    { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => crd_coverage_example }] }
  end
  let(:crd_practitioner_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_practitioner_example.json')))
  end
  let(:crd_practitioner_example_bundle) do
    { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => crd_practitioner_example }] }
  end
  let(:crd_practitioner_role_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_practitioner_role_example.json')))
  end
  let(:crd_practitioner_role_example_bundle) do
    { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => crd_practitioner_role_example }] }
  end

  def make_checker(hook_request, templates, request_index: 0)
    instance = described_class.new(hook_request, request_index, '/unused/path.json')
    allow(instance).to receive(:hook_prefetch_templates).and_return(templates)
    instance
  end

  def errors_for(hook_request, templates, request_index: 0)
    make_checker(hook_request, templates, request_index:).check_prefetched_data
  end

  describe '#check_prefetched_data' do
    it 'returns an error when the prefetch key is absent' do
      expect(errors_for(order_sign_request, { 'patient' => 'Patient/{{context.patientId}}' }))
        .to eq(['(Request 1) No prefetch data provided.'])
    end

    it 'includes the correct request index in errors' do
      expect(errors_for(order_sign_request, { 'patient' => 'Patient/{{context.patientId}}' }, request_index: 2))
        .to eq(['(Request 3) No prefetch data provided.'])
    end

    it 'returns no errors when all templates are satisfied' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      expect(errors_for(order_sign_request, { 'patient' => 'Patient/{{context.patientId}}' })).to be_empty
    end

    it 'returns an error for an extra prefetch key not in the templates' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example, 'extra' => crd_patient_example }
      errors = errors_for(order_sign_request, { 'patient' => 'Patient/{{context.patientId}}' })
      expect(errors).to eq(["(Request 1) Extra prefetch data provided in unrequested template 'extra'."])
    end
  end

  describe 'read template' do
    let(:templates) { { 'patient' => 'Patient/{{context.patientId}}' } }

    it 'passes when the indicated resource is provided' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      expect(errors_for(order_sign_request, templates)).to be_empty
    end

    it 'passes when no resource is requested and none is provided' do
      order_sign_request['prefetch'] = { 'patient' => nil }
      order_sign_request['context'].delete('patientId')
      expect(errors_for(order_sign_request, templates)).to be_empty
    end

    it 'returns an error when the template key is absent from prefetch' do
      order_sign_request['prefetch'] = {}
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template patient - No prefetch data provided.'])
    end

    it 'returns an error when a requested resource is not provided' do
      order_sign_request['prefetch'] = { 'patient' => nil }
      expect(errors_for(order_sign_request, templates))
        .to eq(["(Request 1) Prefetch Template patient - requested resource 'Patient/example' not provided."])
    end

    it 'returns an error when the prefetched value has no resourceType' do
      crd_patient_example.delete('resourceType')
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template patient - prefetched value is not a FHIR resource (no resourceType).'])
    end

    it 'returns an error when the prefetched value has the wrong resourceType' do
      crd_patient_example['resourceType'] = 'NotPatient'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template patient - prefetched value has unexpected resourceType: ' \
                'expected Patient, got NotPatient.'])
    end

    it 'returns an error when the prefetched resource has no id' do
      crd_patient_example.delete('id')
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template patient - prefetched Patient is missing an id.'])
    end

    it 'returns an error when the prefetched resource has the wrong id' do
      crd_patient_example['id'] = 'wrong'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template patient - prefetched Patient has unexpected id: ' \
                'expected example, got wrong.'])
    end

    it 'returns multiple errors when both resourceType and id are wrong' do
      crd_patient_example['resourceType'] = 'NotPatient'
      crd_patient_example['id'] = 'wrong'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      expect(errors_for(order_sign_request, templates)).to contain_exactly(
        '(Request 1) Prefetch Template patient - prefetched value has unexpected resourceType: ' \
        'expected Patient, got NotPatient.',
        '(Request 1) Prefetch Template patient - prefetched Patient has unexpected id: expected example, got wrong.'
      )
    end
  end

  describe '_id search template' do
    let(:templates) { { 'patient' => 'Patient?_id={{context.patientId}}' } }

    it 'passes when a Bundle with the expected resource is provided' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      expect(errors_for(order_sign_request, templates)).to be_empty
    end

    it 'passes when no ids requested and none provided' do
      order_sign_request['prefetch'] = { 'patient' => nil }
      order_sign_request['context'].delete('patientId')
      expect(errors_for(order_sign_request, templates)).to be_empty
    end

    it 'passes when an empty Bundle is provided and no ids are requested' do
      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      order_sign_request['context'].delete('patientId')
      expect(errors_for(order_sign_request, templates)).to be_empty
    end

    it 'returns an error when the prefetched value has no resourceType' do
      crd_patient_example_bundle.delete('resourceType')
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template patient - prefetched value is not a FHIR resource (no resourceType).'])
    end

    it 'returns an error when the prefetched value is not a Bundle' do
      crd_patient_example_bundle['resourceType'] = 'NotBundle'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template patient - prefetched value has unexpected resourceType: ' \
                'expected Bundle, got NotBundle.'])
    end

    it 'returns an error when a Bundle entry has the wrong resourceType' do
      crd_patient_example_bundle['entry'][0]['resource']['resourceType'] = 'NotPatient'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      expect(errors_for(order_sign_request, templates)).to contain_exactly(
        '(Request 1) Prefetch Template patient - prefetched Bundle entry 1 has an unexpected resourceType: ' \
        'expected Patient, got NotPatient.',
        '(Request 1) Prefetch Template patient - prefetched Bundle missing expected entries: Patient/example.',
        '(Request 1) Prefetch Template patient - prefetched Bundle includes unrequested entries: NotPatient/example.'
      )
    end

    it 'returns an error when there are duplicate entries' do
      crd_patient_example_bundle['entry'] << { 'resource' => crd_patient_example }
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template patient - prefetched Bundle has multiple entries ' \
                'with the same resource id.'])
    end

    it 'returns errors for missing and extra ids when wrong id is present' do
      crd_patient_example_bundle['entry'][0]['resource']['id'] = 'wrong'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      expect(errors_for(order_sign_request, templates)).to contain_exactly(
        '(Request 1) Prefetch Template patient - prefetched Bundle missing expected entries: Patient/example.',
        '(Request 1) Prefetch Template patient - prefetched Bundle includes unrequested entries: Patient/wrong.'
      )
    end

    it 'returns an error when no prefetch provided and ids are requested' do
      order_sign_request['prefetch'] = { 'patient' => nil }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template patient - requested resources not provided: Patient/example.'])
    end

    it 'returns an error when an empty Bundle is provided and ids are requested' do
      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template patient - prefetched Bundle missing expected entries: Patient/example.'])
    end
  end

  describe 'coverage search template' do
    let(:templates) { { 'coverage' => 'Coverage?patient={{context.patientId}}&status=active' } }

    it 'passes when a Bundle with a valid Coverage is provided' do
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      expect(errors_for(order_sign_request, templates)).to be_empty
    end

    it 'returns an error when no coverage is provided' do
      order_sign_request['prefetch'] = { 'coverage' => nil }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template coverage - requested Coverage not provided.'])
    end

    it 'returns an error when the prefetched value has no resourceType' do
      crd_coverage_example_bundle.delete('resourceType')
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template coverage - prefetched value is not a FHIR resource (no resourceType).'])
    end

    it 'returns an error when the prefetched value is not a Bundle' do
      crd_coverage_example_bundle['resourceType'] = 'NotBundle'
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template coverage - prefetched value has unexpected resourceType: ' \
                'expected Bundle, got NotBundle.'])
    end

    it 'returns an error when the Bundle has more than one entry' do
      crd_coverage_example_bundle['entry'] << { 'resource' => crd_coverage_example }
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template coverage - exactly one Coverage must be provided.'])
    end

    it 'returns an error when the Coverage entry has the wrong resourceType' do
      crd_coverage_example_bundle['entry'][0]['resource']['resourceType'] = 'NotCoverage'
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template coverage - entry in prefetched Coverage Bundle ' \
                'has an unexpected type: expected Coverage, got NotCoverage.'])
    end

    it 'returns an error when the Coverage has the wrong status' do
      crd_coverage_example_bundle['entry'][0]['resource']['status'] = 'inactive'
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template coverage - prefetched Coverage has an unexpected status: ' \
                'expected active, got inactive.'])
    end

    it 'returns an error when the Coverage references the wrong patient' do
      crd_coverage_example_bundle['entry'][0]['resource']['beneficiary']['reference'] = 'Patient/wrong'
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template coverage - prefetched Coverage has an unexpected ' \
                'beneficiary reference: expected Patient/example, got Patient/wrong.'])
    end
  end

  describe 'unsupported search template' do
    let(:templates) { { 'unsupported' => 'Patient?birthdate=20200101' } }

    it 'returns an error for a non-_id search on a non-Coverage resource' do
      order_sign_request['prefetch'] = { 'unsupported' => crd_coverage_example_bundle }
      expect(errors_for(order_sign_request, templates).first).to match('unexpected search template')
    end
  end

  describe 'resolve() in prefetch tokens' do
    let(:templates) do
      { 'patient' => 'Patient?_id={{context.draftOrders.entry.resource.patient.resolve().id}}' }
    end

    before do
      order_sign_request['context']['draftOrders']['entry'][0]['resource']['patient']['reference'] = 'Patient/example'
    end

    it 'passes when the referenced resource is in the prefetch set' do
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.patient")
        .to_return(status: 200, body: [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }].to_json)
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"resourceType":"Patient"/)
        .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)

      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      expect(errors_for(order_sign_request, templates)).to be_empty
    end

    it 'returns an error when the referenced resource is not in the prefetch set' do
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.patient")
        .to_return(status: 200, body: [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }].to_json)
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"resourceType":"Patient"/)
        .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)

      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      expect(errors_for(order_sign_request, templates))
        .to eq(["(Request 1) Prefetch Template patient - resource 'Patient/example' needed to instantiate " \
                'the query was not provided in the prefetched values.'])
    end
  end

  describe '#observed_fhirpath_collection_as_comma_delimited_string' do
    it 'is false by default before check_prefetched_data is called' do
      checker = make_checker(order_sign_request, {})
      expect(checker.observed_fhirpath_collection_as_comma_delimited_string).to be(false)
    end

    it 'remains false when no _id search template is present' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      checker = make_checker(order_sign_request, { 'patient' => 'Patient/{{context.patientId}}' })
      checker.check_prefetched_data
      expect(checker.observed_fhirpath_collection_as_comma_delimited_string).to be(false)
    end

    it 'remains false when the _id template token has no pipe' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      checker = make_checker(order_sign_request, { 'patient' => 'Patient?_id={{context.patientId}}' })
      checker.check_prefetched_data
      expect(checker.observed_fhirpath_collection_as_comma_delimited_string).to be(false)
    end

    it 'remains false when the token has a pipe but only one id is resolved' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      checker = make_checker(order_sign_request,
                             { 'patient' => 'Patient?_id={{context.patientId|context.nonExistentField}}' })
      checker.check_prefetched_data
      expect(checker.observed_fhirpath_collection_as_comma_delimited_string).to be(false)
    end

    it 'remains false when the token has a pipe and multiple ids resolve but are all the same' do
      order_sign_request['context']['duplicatePatientId'] = 'example'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      checker = make_checker(order_sign_request,
                             { 'patient' => 'Patient?_id={{context.patientId|context.duplicatePatientId}}' })
      checker.check_prefetched_data
      expect(checker.observed_fhirpath_collection_as_comma_delimited_string).to be(false)
    end

    it 'becomes true when the token has a pipe and multiple ids are resolved' do
      order_sign_request['context']['secondPatientId'] = 'other'
      order_sign_request['prefetch'] = { 'patient' => {
        'resourceType' => 'Bundle',
        'entry' => [
          { 'resource' => crd_patient_example },
          { 'resource' => crd_patient_example.merge('id' => 'other') }
        ]
      } }
      checker = make_checker(order_sign_request,
                             { 'patient' => 'Patient?_id={{context.patientId|context.secondPatientId}}' })
      checker.check_prefetched_data
      expect(checker.observed_fhirpath_collection_as_comma_delimited_string).to be(true)
    end

    it 'becomes true when any one of multiple templates demonstrates multi-id collection' do
      order_sign_request['context']['secondPatientId'] = 'other'
      order_sign_request['prefetch'] = {
        'patient' => crd_patient_example,
        'patients' => {
          'resourceType' => 'Bundle',
          'entry' => [
            { 'resource' => crd_patient_example },
            { 'resource' => crd_patient_example.merge('id' => 'other') }
          ]
        }
      }
      checker = make_checker(order_sign_request, {
                               'patient' => 'Patient/{{context.patientId}}',
                               'patients' => 'Patient?_id={{context.patientId|context.secondPatientId}}'
                             })
      checker.check_prefetched_data
      expect(checker.observed_fhirpath_collection_as_comma_delimited_string).to be(true)
    end
  end

  describe 'chained prefetch tokens' do
    let(:templates) do
      {
        'practitionerRoles' =>
          'PractitionerRole?_id={{context.draftOrders.entry.resource.orderer.resolve().ofType(PractitionerRole).id}}',
        'practitioners' => 'Practitioner?_id={{%practitionerRoles.entry.resource.practitioner.resolve().id}}'
      }
    end

    before do
      order_sign_request['context']['draftOrders']['entry'][0]['resource']['orderer']['reference'] =
        'PractitionerRole/example'
    end

    it 'passes when all chained resources are present' do
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.orderer")
        .to_return(status: 200,
                   body: [{ type: 'Reference', element: { 'reference' => 'PractitionerRole/example' } }].to_json)
      stub_request(:post, "#{fhirpath_url}?path=ofType(PractitionerRole).id")
        .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.practitioner")
        .to_return(status: 200,
                   body: [{ type: 'Reference', element: { 'reference' => 'Practitioner/example' } }].to_json)
      stub_request(:post, "#{fhirpath_url}?path=id")
        .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)

      order_sign_request['prefetch'] = { 'practitionerRoles' => crd_practitioner_role_example_bundle,
                                         'practitioners' => crd_practitioner_example_bundle }
      expect(errors_for(order_sign_request, templates)).to be_empty
    end
  end
end
