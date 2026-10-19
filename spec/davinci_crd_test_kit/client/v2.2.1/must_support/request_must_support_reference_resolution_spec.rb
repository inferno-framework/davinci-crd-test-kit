require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/client_cross_hook_group'
require_relative '../../../../../lib/davinci_crd_test_kit/generator/must_support_test_generator'

RSpec.describe DaVinciCRDTestKit::V221::RequestMustSupportReferenceResolution, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite_id) }
  let(:receiving_result) { repo_create(:result, test_session_id: test_session.id) }
  let(:fhir_server) { 'https://example/r4' }
  let(:vision_prescription_test) do
    Class.new(described_class) do
      config(options: { ig_version: 'v2.2.1',
                        profiles: [{ resource_type: 'VisionPrescription', profile_keys: ['vision_prescription'] }] })
    end
  end

  let(:patient) { { resourceType: 'Patient', id: 'p1' } }
  let(:encounter) { { resourceType: 'Encounter', id: 'e1' } }
  let(:practitioner) { { resourceType: 'Practitioner', id: 'pr1' } }
  let(:practitioner_role) { { resourceType: 'PractitionerRole', id: 'role1' } }

  def vision_prescription(prescriber: 'Practitioner/pr1', **elements)
    { resourceType: 'VisionPrescription', id: SecureRandom.hex(4), patient: { reference: 'Patient/p1' },
      encounter: { reference: "#{fhir_server}/Encounter/e1" }, prescriber: { reference: prescriber } }
      .merge(elements)
  end

  # A hook request carrying the given draft orders and a patient prefetch, along with a successful
  # read of each of the given resources made while it was processed. An order or extra prefetched
  # resource given as a [fullUrl, resource] pair is placed in its Bundle under that fullUrl. External
  # reads map the URL each was read from to the resource returned.
  def create_hook_request(orders, read: [], failed_reads: [], external_reads: {}, prefetched: [])
    hook_instance = SecureRandom.uuid
    body = { hook: 'order-sign', hookInstance: hook_instance, fhirServer: fhir_server,
             context: { draftOrders: bundle_of(orders) },
             prefetch: { patient:, others: bundle_of(prefetched) } }
    hook_request = repo_create(:request, test_session_id: test_session.id, request_body: body.to_json,
                                         result: receiving_result, tags: [DaVinciCRDTestKit::CROSS_HOOK_ANALYSIS_TAG])
    fetch_tags = [DaVinciCRDTestKit::DATA_FETCH_TAG,
                  DaVinciCRDTestKit::TagMethods.hook_instance_data_fetch_tag(hook_instance),
                  DaVinciCRDTestKit::MUST_SUPPORT_REFERENCE_FETCH_TAG]
    read.each { |resource| create_read(resource, 200, fetch_tags) }
    failed_reads.each { |resource| create_read(resource, 404, fetch_tags) }
    external_reads.each { |url, resource| create_read(resource, 200, fetch_tags, url:) }
    hook_request
  end

  def bundle_of(resources)
    entries = resources.map do |one|
      one.is_a?(Array) ? { fullUrl: one.first, resource: one.last } : { resource: one }
    end
    { resourceType: 'Bundle', type: 'collection', entry: entries }
  end

  def create_read(resource, status, tags, url: "#{fhir_server}/#{resource[:resourceType]}/#{resource[:id]}")
    repo_create(:request, test_session_id: test_session.id, verb: 'get', direction: 'outgoing', url:, status:,
                          response_body: resource.to_json, result: receiving_result, tags:)
  end

  # The result returned by `run` does not carry its requests, so they are read back from the database.
  def attached_request_ids(result)
    Inferno::Repositories::Results::Model.find(id: result.id).requests.map(&:id)
  end

  def attached_urls(result)
    Inferno::Repositories::Results::Model.find(id: result.id).requests.map(&:url)
  end

  def all_types_selected(inputs = {})
    generator = DaVinciCRDTestKit::Generator::MustSupportTestGenerator
    {
      order_types_supported: generator::ORDER_TYPE_OPTIONS.to_json,
      supporting_types_supported: generator::SUPPORTING_TYPE_OPTIONS.to_json
    }.merge(inputs)
  end

  def without_practitioner_role
    generator = DaVinciCRDTestKit::Generator::MustSupportTestGenerator
    all_types_selected(supporting_types_supported: (generator::SUPPORTING_TYPE_OPTIONS - ['PractitionerRole']).to_json)
  end

  before do
    allow_any_instance_of(vision_prescription_test).to receive(:resource_is_valid?).and_return(true)
  end

  it 'skips when no hook requests have been received' do
    result = run(vision_prescription_test, all_types_selected)

    expect(result.result).to eq('skip')
    expect(result.result_message).to include('No hook requests received')
  end

  it 'passes when no instances of the resource type were observed' do
    create_hook_request([])

    result = run(vision_prescription_test, all_types_selected)

    expect(result.result).to eq('pass')
    expect(result.result_message).to include('No instances of VisionPrescription observed')
  end

  it 'passes when references resolve to resources in the request or read while processing it' do
    create_hook_request([vision_prescription, vision_prescription(prescriber: 'PractitionerRole/role1')],
                        read: [encounter, practitioner, practitioner_role])

    result = run(vision_prescription_test, all_types_selected)

    expect(result.result).to eq('pass')
  end

  it 'requires every must support target profile to be demonstrated' do
    create_hook_request([vision_prescription], read: [encounter, practitioner])

    result = run(vision_prescription_test, all_types_selected)

    expect(result.result).to eq('skip')
    expect(result.result_message).to include('`prescriber` using profile [HRex PractitionerRole Profile](')
    expect(result.result_message).to_not include('[CRD Practitioner](')
  end

  it 'does not require target profiles for resource types the tester declared unsupported' do
    create_hook_request([vision_prescription], read: [encounter, practitioner])

    result = run(vision_prescription_test, without_practitioner_role)

    expect(result.result).to eq('pass')
  end

  it 'skips when a populated element never resolves' do
    create_hook_request([vision_prescription], read: [practitioner], failed_reads: [encounter])

    result = run(vision_prescription_test, without_practitioner_role)

    expect(result.result).to eq('skip')
    expect(result.result_message).to include('`encounter`')
  end

  it 'does not resolve a reference using a read made for a different hook request' do
    create_hook_request([vision_prescription], read: [practitioner])
    create_hook_request([], read: [encounter])

    result = run(vision_prescription_test, without_practitioner_role)

    expect(result.result).to eq('skip')
    expect(result.result_message).to include('`encounter`')
  end

  it 'resolves references to contained resources' do
    order = vision_prescription(encounter: { reference: '#enc' }, contained: [encounter.merge(id: 'enc')])
    create_hook_request([order], read: [practitioner])

    result = run(vision_prescription_test, without_practitioner_role)

    expect(result.result).to eq('pass')
  end

  it 'does not count a resolved resource that does not conform to the target profile' do
    allow_any_instance_of(vision_prescription_test).to receive(:resource_is_valid?) do |_test, resource:, **|
      resource.resourceType != 'Practitioner'
    end
    create_hook_request([vision_prescription], read: [encounter, practitioner])

    result = run(vision_prescription_test, without_practitioner_role)

    expect(result.result).to eq('skip')
    expect(result.result_message).to include('`prescriber` using profile [CRD Practitioner](')
  end

  describe 'when resources are identified by fullUrl' do
    let(:elsewhere) { 'https://elsewhere.example/r4' }

    it 'resolves an absolute reference to a resource carried under that fullUrl' do
      order = vision_prescription(prescriber: "#{elsewhere}/Practitioner/pr1")
      create_hook_request([order], read: [encounter],
                                   prefetched: [["#{elsewhere}/Practitioner/pr1", practitioner]])

      result = run(vision_prescription_test, without_practitioner_role)

      expect(result.result).to eq('pass')
    end

    it 'resolves a relative reference against the server of the resource holding it' do
      order = vision_prescription(encounter: { reference: 'Encounter/e1' })
      create_hook_request([["#{elsewhere}/VisionPrescription/vp1", order]],
                          prefetched: [["#{elsewhere}/Patient/p1", patient], ["#{elsewhere}/Encounter/e1", encounter],
                                       ["#{elsewhere}/Practitioner/pr1", practitioner]])

      result = run(vision_prescription_test, without_practitioner_role)

      expect(result.result).to eq('pass')
    end

    it 'does not resolve a relative reference to a resource with the same type and id on the FHIR server' do
      order = vision_prescription(encounter: { reference: 'Encounter/e1' })
      create_hook_request([["#{elsewhere}/VisionPrescription/vp1", order]], read: [encounter, practitioner])

      result = run(vision_prescription_test, without_practitioner_role)

      expect(result.result).to eq('skip')
      expect(result.result_message).to include('`encounter`')
    end
  end

  describe 'with a reference to a resource on another server' do
    let(:external_url) { 'https://elsewhere.example/r4/Practitioner/pr1' }
    let(:order) { vision_prescription(prescriber: external_url) }

    it 'resolves it to the resource read from that server' do
      create_hook_request([order], read: [encounter], external_reads: { external_url => practitioner })

      result = run(vision_prescription_test, without_practitioner_role)

      expect(result.result).to eq('pass')
    end

    it 'does not resolve it when the read from that server did not succeed' do
      create_hook_request([order], read: [encounter])

      result = run(vision_prescription_test, without_practitioner_role)

      expect(result.result).to eq('skip')
      expect(result.result_message).to include('`prescriber`')
    end

    it 'does not resolve it to a resource with the same type and id from the FHIR server' do
      create_hook_request([order], read: [encounter, practitioner])

      result = run(vision_prescription_test, without_practitioner_role)

      expect(result.result).to eq('skip')
    end

    it 'does not resolve it to a resource the read returned under a different id' do
      create_hook_request([order], read: [encounter], external_reads: { external_url => practitioner.merge(id: 'x') })

      result = run(vision_prescription_test, without_practitioner_role)

      expect(result.result).to eq('skip')
    end
  end

  it 'does not count a resolved resource of a type the target profile does not constrain' do
    create_hook_request([vision_prescription(prescriber: 'Patient/p1')], read: [encounter])

    result = run(vision_prescription_test, without_practitioner_role)

    expect(result.result).to eq('skip')
    expect(result.result_message).to include('`prescriber` using profile [CRD Practitioner](')
  end

  it 'does not count a must support element populated only with logical references' do
    order = vision_prescription(prescriber: nil).merge(prescriber: { display: 'Dr. Smith' })
    create_hook_request([order], read: [encounter])

    result = run(vision_prescription_test, without_practitioner_role)

    expect(result.result).to eq('skip')
    expect(result.result_message).to include('`prescriber` using profile [CRD Practitioner](')
  end

  it 'passes when a logical reference sits alongside a literal one that resolves' do
    logical = vision_prescription(prescriber: nil).merge(prescriber: { display: 'Dr. Smith' })
    create_hook_request([logical, vision_prescription], read: [encounter, practitioner])

    result = run(vision_prescription_test, without_practitioner_role)

    expect(result.result).to eq('pass')
  end

  describe 'request association' do
    it 'attaches only the hook requests carrying the resource type under test' do
      with_order = create_hook_request([vision_prescription], read: [encounter, practitioner, practitioner_role])
      without_order = create_hook_request([])

      vision_prescription_result = run(vision_prescription_test, all_types_selected)

      expect(attached_request_ids(vision_prescription_result)).to include(with_order.id)
      expect(attached_request_ids(vision_prescription_result)).to_not include(without_order.id)
    end

    it 'attaches every considered hook request when none carried the resource type' do
      requests = [create_hook_request([]), create_hook_request([])]

      vision_prescription_result = run(vision_prescription_test, all_types_selected)

      expect(attached_request_ids(vision_prescription_result)).to match_array(requests.map(&:id))
    end

    it 'attaches the reads that references from the resource type resolved to' do
      hook_request = create_hook_request([vision_prescription], read: [encounter, practitioner])

      result = run(vision_prescription_test, without_practitioner_role)

      expect(attached_urls(result)).to contain_exactly(
        hook_request.url, "#{fhir_server}/Encounter/e1", "#{fhir_server}/Practitioner/pr1"
      )
    end

    it 'attaches the failed read of a reference that did not resolve' do
      hook_request = create_hook_request([vision_prescription], read: [encounter], failed_reads: [practitioner])

      result = run(vision_prescription_test, without_practitioner_role)

      expect(result.result).to eq('skip')
      expect(attached_urls(result)).to contain_exactly(
        hook_request.url, "#{fhir_server}/Encounter/e1", "#{fhir_server}/Practitioner/pr1"
      )
    end

    it 'does not attach reads no reference from the resource type pointed to' do
      unrelated = { resourceType: 'Organization', id: 'o1' }
      hook_request = create_hook_request([vision_prescription], read: [encounter, practitioner, unrelated])

      result = run(vision_prescription_test, without_practitioner_role)

      expect(attached_urls(result)).to_not include("#{fhir_server}/Organization/o1")
      expect(attached_urls(result)).to include(hook_request.url)
    end
  end
end
