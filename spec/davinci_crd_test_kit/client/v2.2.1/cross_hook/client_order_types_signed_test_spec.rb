require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/client_cross_hook_must_support_group'

RSpec.describe DaVinciCRDTestKit::V221::ClientOrderTypesSignedTest, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite_id) }
  let(:receiving_result) { repo_create(:result, test_session_id: test_session.id) }
  let(:test) { Inferno::Repositories::Tests.new.find('crd_v221_client_order_types_signed') }

  def service_request(id = 'sr1')
    { resourceType: 'ServiceRequest', id:, status: 'draft', intent: 'order',
      subject: { reference: 'Patient/p1' } }
  end

  def device_request(id = 'dr1')
    { resourceType: 'DeviceRequest', id:, status: 'draft', intent: 'order',
      subject: { reference: 'Patient/p1' } }
  end

  def bundle(*resources)
    { resourceType: 'Bundle', entry: resources.map { |one| { resource: one } } }
  end

  # Only order-sign requests carry the hook tag; every hook request carries the cross hook tag.
  def create_request(body, hook_tag: nil)
    tags = [DaVinciCRDTestKit::CROSS_HOOK_ANALYSIS_TAG, hook_tag].compact
    repo_create(:request, test_session_id: test_session.id, request_body: body.to_json,
                          result: receiving_result, tags:)
  end

  def order_sign(*resources)
    create_request({ hook: 'order-sign', hookInstance: SecureRandom.uuid,
                     context: { draftOrders: bundle(*resources) } },
                   hook_tag: DaVinciCRDTestKit::ORDER_SIGN_TAG)
  end

  def order_select(*resources)
    create_request({ hook: 'order-select', hookInstance: SecureRandom.uuid,
                     context: { draftOrders: bundle(*resources) } },
                   hook_tag: DaVinciCRDTestKit::ORDER_SELECT_TAG)
  end

  it 'skips when no order resources were received' do
    create_request({ hook: 'encounter-start', hookInstance: SecureRandom.uuid,
                     prefetch: { patient: { resourceType: 'Patient', id: 'p1' } } })

    result = run(test)

    expect(result.result).to eq('skip')
    expect(result.result_message).to include('No order resources')
  end

  it 'passes when every observed order type was signed' do
    order_sign(service_request, device_request)

    result = run(test)

    expect(result.result).to eq('pass')
    expect(result.result_message).to include('ServiceRequest')
    expect(result.result_message).to include('DeviceRequest')
  end

  it 'fails when an order type was only ever selected, never signed' do
    order_sign(service_request)
    order_select(device_request)

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result.result_message).to include('DeviceRequest')
    expect(result.result_message).to_not include('ServiceRequest')
  end

  it 'accumulates signed types across several order-sign invocations' do
    order_sign(service_request)
    order_sign(device_request)

    expect(run(test).result).to eq('pass')
  end

  # An order carried outside draftOrders is not being signed, so it does not count.
  it 'ignores an order sent in the prefetch of an order-sign request' do
    order_sign(service_request)
    create_request({ hook: 'order-sign', hookInstance: SecureRandom.uuid,
                     prefetch: { order: device_request } },
                   hook_tag: DaVinciCRDTestKit::ORDER_SIGN_TAG)

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result.result_message).to include('DeviceRequest')
  end

  def messages_from(result_test)
    Inferno::Repositories::Results.new
      .current_results_for_test_session_and_runnables(test_session.id, [result_test]).first.messages.map(&:message)
  end

  it 'names the hook an unsigned order type was observed on' do
    order_select(service_request, device_request)
    order_sign(service_request)

    run(test)

    expect(messages_from(test))
      .to include(a_string_matching(/`DeviceRequest` that was observed on the `order-select` hook, but not on an/))
  end

  it 'names every hook an unsigned order type was observed on' do
    order_select(device_request)
    create_request({ hook: 'order-dispatch', hookInstance: SecureRandom.uuid,
                     context: { draftOrders: bundle(device_request) } },
                   hook_tag: DaVinciCRDTestKit::ORDER_DISPATCH_TAG)
    order_sign(service_request)

    run(test)

    expect(messages_from(test))
      .to include(a_string_matching(/`DeviceRequest`.*`order-dispatch` and `order-select` hooks/))
  end

  it 'does not name order-sign when the type was only there outside draftOrders' do
    order_sign(service_request)
    create_request({ hook: 'order-sign', hookInstance: SecureRandom.uuid,
                     prefetch: { order: device_request } },
                   hook_tag: DaVinciCRDTestKit::ORDER_SIGN_TAG)

    run(test)

    expect(messages_from(test))
      .to include(a_string_matching(/instance of `DeviceRequest` that was observed, but not as a draft order/))
  end
end
