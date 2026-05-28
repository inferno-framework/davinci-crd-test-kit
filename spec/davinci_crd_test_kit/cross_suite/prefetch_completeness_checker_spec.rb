require_relative '../../../lib/davinci_crd_test_kit/cross_suite/prefetch_completeness_checker'

RSpec.describe DaVinciCRDTestKit::PrefetchCompletenessChecker do
  let(:fhirpath_url) { 'https://example.com/fhirpath/evaluate' }
  let(:base_fhir_url) { 'https://example/r4' }

  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'order_sign_hook_request.json')))
  end
  let(:crd_patient_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'crd_patient_example.json')))
  end
  let(:crd_patient_example_bundle) do
    { 'resourceType' => 'Bundle', 'entry' => [{ 'fullUrl' => "#{base_fhir_url}/Patient/example",
                                                'resource' => crd_patient_example }] }
  end
  let(:crd_coverage_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'crd_coverage_example.json')))
  end
  let(:crd_coverage_example_bundle) do
    { 'resourceType' => 'Bundle', 'entry' => [{ 'fullUrl' => "#{base_fhir_url}/Coverage/coverage_example",
                                                'resource' => crd_coverage_example }] }
  end
  let(:crd_practitioner_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'crd_practitioner_example.json')))
  end
  let(:crd_practitioner_example_bundle) do
    { 'resourceType' => 'Bundle',
      'entry' => [{ 'fullUrl' => "#{base_fhir_url}/Practitioner/example", 'resource' => crd_practitioner_example }] }
  end
  let(:crd_practitioner_role_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'crd_practitioner_role_example.json')))
  end
  let(:crd_practitioner_role_example_bundle) do
    { 'resourceType' => 'Bundle',
      'entry' => [{ 'fullUrl' => "#{base_fhir_url}/PractitionerRole/example",
                    'resource' => crd_practitioner_role_example }] }
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

    it 'raises an error with template context when the FHIRPath service fails during token substitution' do
      templates = { 'orders' => 'ServiceRequest?_id={{context.draftOrders.entry.resource.id}}' }
      order_sign_request['prefetch'] = { 'orders' => { 'resourceType' => 'Bundle', 'entry' => [] } }
      stub_request(:post, /#{Regexp.escape(fhirpath_url)}/)
        .to_return(status: 422, body: 'Invalid FHIRPath expression')

      checker = make_checker(order_sign_request, templates)
      expect { checker.check_prefetched_data }
        .to raise_error(RuntimeError, /Prefetch Template orders.*FHIRPath service error/)
    end

    it 'deduplicates errors when the same error occurs multiple times across token evaluation' do
      order_sign_request['context']['draftOrders']['entry'].each do |entry|
        entry['resource']['patient'] = { 'reference' => 'Patient/example' }
      end
      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      stub_request(:post, "#{fhirpath_url}?path=patient")
        .to_return(status: 200,
                   body: [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }].to_json)

      templates = { 'patient' => 'Patient?_id={{context.draftOrders.entry.resource.patient.resolve().id}}' }
      errors = errors_for(order_sign_request, templates)
      expect(errors.count { |e| e.include?("resource '#{base_fhir_url}/Patient/example'") }).to eq(1)
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
        .to eq(['(Request 1) Prefetch Template patient - ' \
                "requested resource '#{base_fhir_url}/Patient/example' not provided."])
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
        '(Request 1) Prefetch Template patient - prefetched Bundle missing expected entries: ' \
        "#{base_fhir_url}/Patient/example.",
        '(Request 1) Prefetch Template patient - prefetched Bundle includes unrequested entries: ' \
        "#{base_fhir_url}/Patient/example."
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
        '(Request 1) Prefetch Template patient - prefetched Bundle missing expected entries: ' \
        "#{base_fhir_url}/Patient/example.",
        '(Request 1) Prefetch Template patient - prefetched Bundle includes unrequested entries: ' \
        "#{base_fhir_url}/Patient/example."
      )
    end

    it 'returns an error when no prefetch provided and ids are requested' do
      order_sign_request['prefetch'] = { 'patient' => nil }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template patient - requested resources not provided: ' \
                "#{base_fhir_url}/Patient/example."])
    end

    it 'returns an error when an empty Bundle is provided and ids are requested' do
      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      expect(errors_for(order_sign_request, templates))
        .to eq(['(Request 1) Prefetch Template patient - prefetched Bundle missing expected entries: ' \
                "#{base_fhir_url}/Patient/example."])
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

    it 'raises an exception for a non-_id search on a non-Coverage resource' do
      order_sign_request['prefetch'] = { 'unsupported' => crd_coverage_example_bundle }
      expect { errors_for(order_sign_request, templates) }
        .to raise_error(RuntimeError, /Unexpected search template.*implementation problem/)
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
      stub_request(:post, "#{fhirpath_url}?path=patient")
        .to_return(status: 200, body: [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }].to_json)
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"resourceType":"Patient"/)
        .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)

      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      expect(errors_for(order_sign_request, templates)).to be_empty
    end

    it 'returns an error when the referenced resource is not in the prefetch set' do
      stub_request(:post, "#{fhirpath_url}?path=patient")
        .to_return(status: 200, body: [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }].to_json)
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"resourceType":"Patient"/)
        .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)

      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      errors = errors_for(order_sign_request, templates)
      expect(errors)
        .to eq(["(Request 1) Prefetch Template patient - resource 'https://example/r4/Patient/example' needed to " \
                'instantiate the query was not provided in the prefetched values.'])
    end

    it 'resolves absolute references directly without base server lookup' do
      stub_request(:post, "#{fhirpath_url}?path=patient")
        .to_return(status: 200,
                   body: [{ type: 'Reference',
                            element: { 'reference' => "#{base_fhir_url}/Patient/example" } }].to_json)
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"resourceType":"Patient"/)
        .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)

      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      expect(errors_for(order_sign_request, templates)).to be_empty
    end

    it 'returns an error when resolving a relative reference without a known base FHIR server' do
      order_sign_request.delete('fhirServer')
      order_sign_request['context']['draftOrders']['entry'].each { |e| e.delete('fullUrl') }
      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      stub_request(:post, "#{fhirpath_url}?path=patient")
        .to_return(status: 200,
                   body: [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }].to_json)

      errors = errors_for(order_sign_request, templates)
      expect(errors).to include(match('is a relative reference, but the base FHIR Server is not known'))
    end

    it 'returns an error for a reference with too many path segments' do
      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      stub_request(:post, "#{fhirpath_url}?path=patient")
        .to_return(status: 200,
                   body: [{ type: 'Reference',
                            element: { 'reference' => 'Patient/example/extra' } }].to_json)

      errors = errors_for(order_sign_request, templates)
      expect(errors).to include(match('too many segments to be a relative reference'))
    end

    it 'returns an error for a malformed relative reference missing the resource id' do
      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      stub_request(:post, "#{fhirpath_url}?path=patient")
        .to_return(status: 200,
                   body: [{ type: 'Reference', element: { 'reference' => 'Patient' } }].to_json)

      errors = errors_for(order_sign_request, templates)
      expect(errors).to include(match('is not a valid relative reference of the form'))
    end

    it 'returns an error for a reference that is an invalid URI' do
      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      stub_request(:post, "#{fhirpath_url}?path=patient")
        .to_return(status: 200,
                   body: [{ type: 'Reference',
                            element: { 'reference' => 'http://example.com/bad path' } }].to_json)

      errors = errors_for(order_sign_request, templates)
      expect(errors).to include(match('is invalid'))
    end

    it 'does not update the base FHIR server when resolve() fails, ' \
       'so relative references after the failure resolve correctly' do
      order_sign_request['context']['draftOrders'] = {
        'resourceType' => 'Bundle',
        'entry' => [{
          'fullUrl' => "#{base_fhir_url}/NutritionOrder/example",
          'resource' => {
            'resourceType' => 'NutritionOrder',
            'id' => 'example',
            'basedOn' => [
              { 'reference' => 'https://other-server/r4/Patient/missing' },
              { 'reference' => 'Patient/example' }
            ]
          }
        }]
      }
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }

      stub_request(:post, "#{fhirpath_url}?path=basedOn")
        .to_return(status: 200,
                   body: [
                     { type: 'Reference', element: { 'reference' => 'https://other-server/r4/Patient/missing' } },
                     { type: 'Reference', element: { 'reference' => 'Patient/example' } }
                   ].to_json)
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"resourceType":"Patient"/)
        .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)

      errors = errors_for(order_sign_request,
                          { 'patient' => 'Patient?_id={{context.draftOrders.entry.resource.basedOn.resolve().id}}' })
      expect(errors).to eq(
        ["(Request 1) Prefetch Template patient - resource 'https://other-server/r4/Patient/missing' " \
         'needed to instantiate the query was not provided in the prefetched values.']
      )
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

  describe 'prefetch resource extraction' do
    let(:resolve_patient_template) do
      { 'patient' => 'Patient?_id={{context.draftOrders.entry.resource.patient.resolve().id}}' }
    end

    before do
      order_sign_request['context']['draftOrders']['entry'][0]['resource']['patient']['reference'] = 'Patient/example'
    end

    context 'when bundle entries have no fullUrl' do
      let(:bundle_without_fullurl) do
        { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => crd_patient_example }] }
      end

      it 'are registered using the fhirServer-based key and can be resolved' do
        order_sign_request['prefetch'] = { 'patient' => bundle_without_fullurl }
        stub_request(:post, "#{fhirpath_url}?path=patient")
          .to_return(status: 200,
                     body: [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }].to_json)
        stub_request(:post, "#{fhirpath_url}?path=id")
          .with(body: /"resourceType":"Patient"/)
          .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)

        expect(errors_for(order_sign_request, resolve_patient_template)).to be_empty
      end

      it 'are not registered when fhirServer is absent, causing resource not found during resolve' do
        order_sign_request.delete('fhirServer')
        order_sign_request['prefetch'] = { 'patient' => bundle_without_fullurl }
        stub_request(:post, "#{fhirpath_url}?path=patient")
          .to_return(status: 200,
                     body: [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }].to_json)

        errors = errors_for(order_sign_request, resolve_patient_template)
        expect(errors).to include(match("resource '#{base_fhir_url}/Patient/example' needed to instantiate"))
      end
    end

    context 'when the prefetch resource is direct (not in a bundle)' do
      # Direct prefetch is a single resource, so use a read template (not _id search)
      # to avoid a resourceType mismatch when check_id_search expects a Bundle.
      let(:resolve_patient_template) do
        { 'patient' => 'Patient/{{context.draftOrders.entry.resource.patient.resolve().id}}' }
      end

      it 'are registered using the fhirServer-based key and can be resolved' do
        order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
        stub_request(:post, "#{fhirpath_url}?path=patient")
          .with(body: /"resourceType":"NutritionOrder"/)
          .to_return(status: 200,
                     body: [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }].to_json)
        stub_request(:post, "#{fhirpath_url}?path=patient")
          .with(body: /"resourceType":"MedicationRequest"/)
          .to_return(status: 200, body: [].to_json)
        stub_request(:post, "#{fhirpath_url}?path=id")
          .with(body: /"resourceType":"Patient"/)
          .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)

        expect(errors_for(order_sign_request, resolve_patient_template)).to be_empty
      end

      it 'are not registered when fhirServer is absent, causing resource not found during resolve' do
        order_sign_request.delete('fhirServer')
        order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
        stub_request(:post, "#{fhirpath_url}?path=patient")
          .with(body: /"resourceType":"NutritionOrder"/)
          .to_return(status: 200,
                     body: [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }].to_json)
        stub_request(:post, "#{fhirpath_url}?path=patient")
          .with(body: /"resourceType":"MedicationRequest"/)
          .to_return(status: 200, body: [].to_json)

        errors = errors_for(order_sign_request, resolve_patient_template)
        expect(errors).to include(match("resource '#{base_fhir_url}/Patient/example' needed to instantiate"))
      end

      it 'are registered correctly when fhirServer has a trailing slash' do
        order_sign_request['fhirServer'] = "#{base_fhir_url}/"
        order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
        stub_request(:post, "#{fhirpath_url}?path=patient")
          .with(body: /"resourceType":"NutritionOrder"/)
          .to_return(status: 200,
                     body: [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }].to_json)
        stub_request(:post, "#{fhirpath_url}?path=patient")
          .with(body: /"resourceType":"MedicationRequest"/)
          .to_return(status: 200, body: [].to_json)
        stub_request(:post, "#{fhirpath_url}?path=id")
          .with(body: /"resourceType":"Patient"/)
          .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)

        expect(errors_for(order_sign_request, resolve_patient_template)).to be_empty
      end
    end
  end

  describe '#instantiated_prefetch_templates' do
    it 'is empty before any methods are called' do
      checker = make_checker(order_sign_request, {})
      expect(checker.instantiated_prefetch_templates).to be_empty
    end

    it 'is populated with instantiated templates after check_prefetched_data' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      checker = make_checker(order_sign_request, { 'patient' => 'Patient/{{context.patientId}}' })
      checker.check_prefetched_data
      expect(checker.instantiated_prefetch_templates).to eq({ 'patient' => 'Patient/example' })
    end

    it 'stores instantiated templates for all checked keys' do
      order_sign_request['prefetch'] = {
        'patient' => crd_patient_example,
        'coverage' => crd_coverage_example_bundle
      }
      checker = make_checker(order_sign_request, {
                               'patient' => 'Patient/{{context.patientId}}',
                               'coverage' => 'Coverage?patient={{context.patientId}}&status=active'
                             })
      checker.check_prefetched_data
      expect(checker.instantiated_prefetch_templates.keys).to contain_exactly('patient', 'coverage')
      expect(checker.instantiated_prefetch_templates['patient']).to eq('Patient/example')
    end
  end

  describe '#data_sets_different?' do
    def make_original_with_instantiated(instantiated_templates)
      checker = make_checker(order_sign_request, {})
      checker.instantiated_prefetch_templates.merge!(instantiated_templates)
      checker
    end

    it 'returns false when the alternate requests the same resources as the original' do
      original = make_original_with_instantiated({ 'orders' => 'ServiceRequest?_id=example' })
      alternate = make_checker(order_sign_request,
                               { 'orders' => 'ServiceRequest?_id={{context.patientId}}' })

      expect(alternate.data_sets_different?(original, {})).to be(false)
    end

    it 'returns true when the alternate requests different resources than the original' do
      original = make_original_with_instantiated({ 'orders' => 'ServiceRequest?_id=other-id' })
      alternate = make_checker(order_sign_request,
                               { 'orders' => 'ServiceRequest?_id={{context.patientId}}' })

      expect(alternate.data_sets_different?(original, {})).to be(true)
    end

    it 'skips patient, encounter, and coverage keys and their short forms' do
      original = make_original_with_instantiated({})
      alternate = make_checker(order_sign_request, {
                                 'patient' => 'Patient/{{context.patientId}}',
                                 'pat' => 'Patient/{{context.patientId}}',
                                 'encounter' => 'Encounter/unused',
                                 'enc' => 'Encounter/unused',
                                 'coverage' => 'Coverage?patient=unused&status=active',
                                 'cov' => 'Coverage?patient=unused&status=active'
                               })

      expect(alternate.data_sets_different?(original, {})).to be(false)
    end

    it 'uses the compare_key_map to find the matching key in the original' do
      original = make_original_with_instantiated({ 'original_orders' => 'ServiceRequest?_id=example' })
      alternate = make_checker(order_sign_request,
                               { 'orders' => 'ServiceRequest?_id={{context.patientId}}' })

      expect(alternate.data_sets_different?(original, { 'orders' => 'original_orders' })).to be(false)
    end

    it 'uses the alternate key directly when it is not in the compare_key_map' do
      original = make_original_with_instantiated({ 'orders' => 'ServiceRequest?_id=example' })
      alternate = make_checker(order_sign_request,
                               { 'orders' => 'ServiceRequest?_id={{context.patientId}}' })

      expect(alternate.data_sets_different?(original, { 'unrelated' => 'something' })).to be(false)
    end

    it 'returns true when any errors occurred indicating failed resource resolution' do
      original = make_original_with_instantiated({ 'orders' => 'ServiceRequest?_id=example' })
      alternate = make_checker(order_sign_request,
                               { 'orders' => 'ServiceRequest?_id={{context.patientId}}' })
      alternate.instance_variable_set(:@errors, ['error one'])

      expect(alternate.data_sets_different?(original, {})).to be(true)
    end

    context 'with %key. prefix remapping in alternate templates' do
      it 'remaps %key. prefixes in the template before evaluation, enabling ID comparison' do
        order_sign_request['prefetch'] = { 'newKey' => { 'resourceType' => 'ServiceRequest', 'id' => 'sr-1' } }
        stub_request(:post, "#{fhirpath_url}?path=id")
          .with(body: /"resourceType":"ServiceRequest"/)
          .to_return(status: 200, body: [{ type: 'id', element: 'sr-1' }].to_json)

        # Template uses %oldKey. but hook_request has data under 'newKey';
        # compare_key_map maps oldKey → newKey, so %oldKey. is replaced with %newKey. before evaluation
        original = make_original_with_instantiated({ 'orders' => 'ServiceRequest?_id=sr-2' })
        alternate = make_checker(order_sign_request, { 'orders' => 'ServiceRequest?_id={{%oldKey.id}}' })

        expect(alternate.data_sets_different?(original, { 'oldKey' => 'newKey' })).to be(true)
      end

      it 'returns false when the remapped template produces the same IDs as the original' do
        order_sign_request['prefetch'] = { 'newKey' => { 'resourceType' => 'ServiceRequest', 'id' => 'sr-1' } }
        stub_request(:post, "#{fhirpath_url}?path=id")
          .with(body: /"resourceType":"ServiceRequest"/)
          .to_return(status: 200, body: [{ type: 'id', element: 'sr-1' }].to_json)

        original = make_original_with_instantiated({ 'orders' => 'ServiceRequest?_id=sr-1' })
        alternate = make_checker(order_sign_request, { 'orders' => 'ServiceRequest?_id={{%oldKey.id}}' })

        expect(alternate.data_sets_different?(original, { 'oldKey' => 'newKey' })).to be(false)
      end

      it 'returns true via error when remapping enables resolve() of a resource absent from prefetch' do
        encounter = {
          'resourceType' => 'Encounter',
          'id' => 'encounter-1',
          'participant' => [{ 'individual' => { 'reference' => 'PractitionerRole/role-1' } }]
        }
        order_sign_request['prefetch'] = { 'enc' => encounter }

        stub_request(:post, "#{fhirpath_url}?path=participant.individual")
          .with(body: /"resourceType":"Encounter"/)
          .to_return(status: 200,
                     body: [{ type: 'Reference',
                              element: { 'reference' => 'PractitionerRole/role-1' } }].to_json)

        # Template uses %encounter. which remaps to %enc. via compare_key_map;
        # after remapping, the encounter is found and resolve() is attempted for PractitionerRole/role-1;
        # PractitionerRole is absent from prefetch, so resolve() adds an error → returns true
        original = make_original_with_instantiated({})
        alternate = make_checker(
          order_sign_request,
          { 'practitionerRoles' =>
              'PractitionerRole?_id={{%encounter.participant.individual.resolve().ofType(PractitionerRole).id}}' }
        )

        expect(alternate.data_sets_different?(original, { 'encounter' => 'enc' })).to be(true)
      end
    end
  end

  describe '#data_set_different_with_alternate_service?' do
    it 'creates a new checker for the alternate path and delegates to data_sets_different?' do
      original_checker = make_checker(order_sign_request, {})
      alternate_checker = instance_double(described_class)
      compare_key_map = { 'orders' => 'alt_orders' }
      allow(described_class).to receive(:new)
        .with(order_sign_request, 0, '/alternate/services.json')
        .and_return(alternate_checker)
      allow(alternate_checker).to receive(:data_sets_different?).and_return(true)

      result = original_checker.data_set_different_with_alternate_service?('/alternate/services.json',
                                                                           compare_key_map)

      expect(alternate_checker).to have_received(:data_sets_different?).with(original_checker, compare_key_map)
      expect(result).to be(true)
    end

    it 'returns false when the alternate service requests the same data' do
      original_checker = make_checker(order_sign_request, {})
      alternate_checker = instance_double(described_class)
      allow(described_class).to receive(:new)
        .with(order_sign_request, 0, '/alternate/services.json')
        .and_return(alternate_checker)
      allow(alternate_checker).to receive(:data_sets_different?).and_return(false)

      result = original_checker.data_set_different_with_alternate_service?('/alternate/services.json', {})

      expect(result).to be(false)
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
      stub_request(:post, "#{fhirpath_url}?path=orderer")
        .to_return(status: 200,
                   body: [{ type: 'Reference', element: { 'reference' => 'PractitionerRole/example' } }].to_json)
      stub_request(:post, "#{fhirpath_url}?path=ofType(PractitionerRole).id")
        .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)
      stub_request(:post, "#{fhirpath_url}?path=practitioner")
        .to_return(status: 200,
                   body: [{ type: 'Reference', element: { 'reference' => 'Practitioner/example' } }].to_json)
      stub_request(:post, "#{fhirpath_url}?path=id")
        .to_return(status: 200, body: [{ type: 'id', element: 'example' }].to_json)

      order_sign_request['prefetch'] = { 'practitionerRoles' => crd_practitioner_role_example_bundle,
                                         'practitioners' => crd_practitioner_example_bundle }
      errors = errors_for(order_sign_request, templates)
      expect(errors).to be_empty
    end
  end
end
