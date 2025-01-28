RSpec.describe DaVinciCRDTestKit::ServiceRequestContextValidationTest do
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_service_request_context_validation') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:suite_id) { 'crd_server' }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite_id) }
  let(:context) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'appointment_book_hook_request.json'))
    JSON.parse(json)['context']
  end
  let(:encounter_start_context) do
    { 'userId' => 'PractitionerRole/A2340113', 'patientId' => '1288992', 'encounterId' => '456' }
  end
  let(:apppointment_book_context_required_fields) { ['userId', 'patientId', 'appointments'] }
  let(:encounter_start_context_required_fields) { ['userId', 'patientId', 'encounterId'] }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name:,
        value:,
        type: runnable.config.input_type(name)
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  context 'when appointment-book hook' do
    let(:context) do
      json = File.read(File.join(__dir__, '..', 'fixtures', 'appointment_book_hook_request.json'))
      JSON.parse(json)['context']
    end
    let(:apppointment_book_context_required_fields) { ['userId', 'patientId', 'appointments'] }

    before do
      allow_any_instance_of(runnable).to receive(:hook_name).and_return('appointment-book')
      allow_any_instance_of(runnable).to receive(:resource_is_valid?).and_return(true)
    end

    it 'fails if a required field is missing' do
      apppointment_book_context_required_fields.each do |field|
        context_dup = context.deep_dup
        context_dup.delete(field)

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/does not contain required field `#{field}`/)
      end
    end

    it 'fails if required field is a wrong type' do
      apppointment_book_context_required_fields.each do |field|
        context_dup = context.deep_dup
        context_dup[field] = 123

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/field `#{field}` is not of type/)
      end
    end

    it 'fails if userId is not correctly formatted `resource_type/resource_id`' do
      ['/', 'Appointment/', '/123'].each do |string|
        context_dup = context.deep_dup
        context_dup['userId'] = string

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/Invalid `userId` format/)
      end
    end

    it 'fails if user type is not Practitioner, PractitionerRole, Patient, or RelatedPerson' do
      context_dup = context.deep_dup
      context_dup['userId'] = 'Condition/123'

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Unsupported resource type/)
    end

    it 'fails if patientId is a reference instead of a plain ID' do
      context_dup = context.deep_dup
      context_dup['patientId'] = 'Patient/123'

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/should be a plain ID, not a reference/)
    end

    it 'fails if appointments field is not a FHIR resource' do
      context_dup = context.deep_dup
      context_dup['appointments'] = { a: 1 }

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/is not a FHIR resource/)
    end

    it 'fails if appointments field is not a FHIR Bundle' do
      context_dup = context.deep_dup
      context_dup['appointments'] = { resourceType: 'Patient', id: 'bundle-example' }

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Expected `Bundle`/)
    end

    it 'fails if bundle does not have at least one Appointment resource' do
      context_dup = context.deep_dup
      context_dup['appointments']['entry'].each do |entry|
        entry['resource']['resourceType'] = 'Patient'
      end

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/bundle must contain at least one of the expected resource types/)
    end

    it 'fails if any of the Appointment resources in the bundle does not have a status of proposed' do
      context_dup = context.deep_dup
      context_dup['appointments']['entry'].first['resource']['status'] = 'pending'

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/must have a `proposed` status/)
    end

    it 'passes if context contains optional `encounterId` field' do
      context_dup = context.deep_dup
      context_dup['encounterId'] = 'example'
      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('pass')
    end
  end

  context 'when encounter-start or encounter-discharge hook' do
    let(:encounter_context) do
      { 'userId' => 'PractitionerRole/A2340113', 'patientId' => '1288992', 'encounterId' => '456' }
    end

    let(:encounter_context_required_fields) { ['userId', 'patientId', 'encounterId'] }

    before do
      hook = ['encounter-start', 'encounter-discharge'].sample
      allow_any_instance_of(runnable).to receive(:hook_name).and_return(hook)
    end

    it 'passes if all encounter-start contexts provided are valid' do
      result = run(runnable, contexts: [encounter_context].to_json)
      expect(result.result).to eq('pass')
    end

    it 'fails if a required field is missing' do
      encounter_context_required_fields.each do |field|
        context_dup = encounter_context.deep_dup
        context_dup.delete(field)

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/does not contain required field `#{field}`/)
      end
    end

    it 'fails if required field is a wrong type' do
      encounter_context_required_fields.each do |field|
        context_dup = encounter_context.deep_dup
        context_dup[field] = 123

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/field `#{field}` is not of type/)
      end
    end

    it 'fails if userId is not correctly formatted `resource_type/resource_id`' do
      ['/', 'Practitioner/', '/123'].each do |string|
        context_dup = encounter_context.deep_dup
        context_dup['userId'] = string

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/Invalid `userId` format/)
      end
    end

    it 'fails if user type is not Practitioner or PractitionerRole' do
      context_dup = encounter_context.deep_dup
      context_dup['userId'] = 'Patient/123'

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Unsupported resource type/)
    end

    it 'fails if patientId or encounterId is a reference instead of a plain ID' do
      ['patientId', 'encounterId'].each do |field|
        context_dup = encounter_context.deep_dup
        context_dup[field].prepend('/')
        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/should be a plain ID, not a reference/)
      end
    end
  end

  context 'when order-select hook' do
    let(:order_select_context) do
      json = File.read(File.join(__dir__, '..', 'fixtures', 'order_select_context.json'))
      JSON.parse(json)
    end
    let(:order_select_context_required_fields) { ['userId', 'patientId', 'selections', 'draftOrders'] }

    before do
      allow_any_instance_of(runnable).to receive(:hook_name).and_return('order-select')
      allow_any_instance_of(runnable).to receive(:resource_is_valid?).and_return(true)
    end

    it 'passes if all encounter-start contexts provided are valid' do
      result = run(runnable, contexts: [order_select_context].to_json)
      expect(result.result).to eq('pass')
    end

    it 'fails if a required field is missing' do
      order_select_context_required_fields.each do |field|
        context_dup = order_select_context.deep_dup
        context_dup.delete(field)

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/does not contain required field `#{field}`/)
      end
    end

    it 'fails if required field is a wrong type' do
      order_select_context_required_fields.each do |field|
        context_dup = order_select_context.deep_dup
        context_dup[field] = 123

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/field `#{field}` is not of type/)
      end
    end

    it 'fails if userId is not correctly formatted `resource_type/resource_id`' do
      ['/', 'Practitioner/', '/123'].each do |string|
        context_dup = order_select_context.deep_dup
        context_dup['userId'] = string

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/Invalid `userId` format/)
      end
    end

    it 'fails if user type is not Practitioner or PractitionerRole' do
      context_dup = order_select_context.deep_dup
      context_dup['userId'] = 'Patient/123'

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Unsupported resource type/)
    end

    it 'fails if patientId is a reference instead of a plain ID' do
      context_dup = order_select_context.deep_dup
      context_dup['patientId'] = 'Patient/123'

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/should be a plain ID, not a reference/)
    end

    it 'fails if draftOrders field is not a FHIR resource' do
      context_dup = order_select_context.deep_dup
      context_dup['draftOrders'] = { a: 1 }

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/is not a FHIR resource/)
    end

    it 'fails if draftOrders field is not a FHIR Bundle' do
      context_dup = order_select_context.deep_dup
      context_dup['draftOrders'] = { resourceType: 'Patient', id: 'bundle-example' }

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Expected `Bundle`/)
    end

    it 'fails if the bundle does not contain at least one expected resource type' do
      context_dup = order_select_context.deep_dup
      context_dup['draftOrders']['entry'].each do |entry|
        entry['resource']['resourceType'] = 'Patient'
      end

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/bundle must contain at least one of the expected resource types/)
    end

    it 'fails if any item in selections field has an unsupported resource type' do
      context_dup = order_select_context.deep_dup
      context_dup['selections'] << 'Task/test'

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Unsupported resource type/)
    end

    it 'fails if any item in selections field is not refenced in the drafOrders bundle' do
      context_dup = order_select_context.deep_dup
      context_dup['selections'] << 'MedicationRequest/test'

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/must reference FHIR resources in `draftOrders`/)
    end
  end

  context 'when order-dispatch' do
    let(:order_dispatch_context) do
      { 'patientId' => '1288992', 'order' => 'ServiceRequest/proc002', 'performer' => 'Organization/some-performer' }
    end
    let(:order_dispatch_context_required_fields) { ['patientId', 'order', 'performer'] }

    before do
      allow_any_instance_of(runnable).to receive(:hook_name).and_return('order-dispatch')
    end

    it 'passes if all order-dispatch contexts provided are valid' do
      result = run(runnable, contexts: [order_dispatch_context].to_json)
      expect(result.result).to eq('pass')
    end

    it 'fails if a required field is missing' do
      order_dispatch_context_required_fields.each do |field|
        context_dup = order_dispatch_context.deep_dup
        context_dup.delete(field)

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/does not contain required field `#{field}`/)
      end
    end

    it 'fails if required field is a wrong type' do
      order_dispatch_context_required_fields.each do |field|
        context_dup = order_dispatch_context.deep_dup
        context_dup[field] = 123

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/field `#{field}` is not of type/)
      end
    end

    it 'fails if a required fied has a correct type but is empty' do
      context_dup = order_dispatch_context.deep_dup
      context_dup['patientId'] = ''

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/`patientId` should not be an empty String/)
    end

    it 'fails if performer is not correctly formatted `resource_type/resource_id`' do
      ['/', 'Practitioner/', '/123'].each do |string|
        context_dup = order_dispatch_context.deep_dup
        context_dup['performer'] = string

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/Invalid `performer` format/)
      end
    end

    it 'fails if order is not correctly formatted `resource_type/resource_id`' do
      ['/', 'ServiceRequest/', '/123'].each do |string|
        context_dup = order_dispatch_context.deep_dup
        context_dup['order'] = string

        result = run(runnable, contexts: [context_dup].to_json)
        expect(result.result).to eq('fail')
        expect(entity_result_message.message).to match(/Invalid `order` format/)
      end
    end

    it 'fails if order is not DeviceRequest, ServiceRequest, NutritionOrder, MedicatioonRequest or VisioPrescription' do
      context_dup = order_dispatch_context.deep_dup
      context_dup['order'] = 'Patient/123'
      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Unsupported resource type/)
    end

    it 'fails if patientId is a reference instead of a plain ID' do
      context_dup = order_dispatch_context.deep_dup
      context_dup['patientId'] = 'Patient/123'

      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/should be a plain ID, not a reference/)
    end

    it 'fails if context `task` is not a task resource' do
      context_dup = order_dispatch_context.deep_dup
      context_dup['task'] = { resourceType: 'Patient' }
      result = run(runnable, contexts: [context_dup].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Field `task` must be a `Task`/)
    end
  end

  it 'skips if contexts is not provided' do
    result = run(runnable)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'contexts' is nil, skipping test/)
  end
end
