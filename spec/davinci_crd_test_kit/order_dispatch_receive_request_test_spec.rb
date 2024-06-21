require_relative '../../lib/davinci_crd_test_kit/client_tests/order_dispatch_receive_request_test'
require_relative '../request_helper'

RSpec.describe DaVinciCRDTestKit::OrderDispatchReceiveRequestTest do
  include Rack::Test::Methods
  include RequestHelpers

  let(:suite) { Inferno::Repositories::TestSuites.new.find('crd_client') }
  let(:test) { Inferno::Repositories::Tests.new.find('crd_order_dispatch_request') }
  let(:test_group) { Inferno::Repositories::TestGroups.new.find('crd_client_hooks') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:resume_pass_url) do
    "#{Inferno::Application['base_url']}/custom/crd_client/resume_pass?token=order-dispatch%20#{example_client_url}"
  end
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:order_dispatch_url) { "#{base_url}/cds-services/order-dispatch-service" }
  let(:client_fhir_server) { 'https://example/r4' }
  let(:patient_id) { 'example' }
  let(:order_dispatch_selected_response_types) { ['instructions', 'coverage_information', 'external_reference'] }

  let(:server_endpoint) { '/custom/crd_client/cds-services/order-dispatch-service' }
  let(:body) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', 'fixtures', 'order_dispatch_hook_request.json'
                         )))
  end

  let(:crd_order) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', 'fixtures', 'crd_service_request_example.json'
                         )))
  end
  let(:crd_coverage) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', 'fixtures', 'crd_coverage_example.json'
                         )))
  end
  let(:crd_coverage_bundle) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: 'https://example.com/base/Coverage/coverage_example',
                          resource: FHIR.from_contents(crd_coverage.to_json)
                        ))
    bundle
  end

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

  it 'passes and responds 200 if request sent to the provided URL and jwt `iss` claim matches the given`iss`' do
    allow(test).to receive_messages(suite:, parent: test_group)

    token = jwt_helper.build(
      aud: order_dispatch_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    result = run(test, iss: example_client_url, order_dispatch_selected_response_types:)

    expect(result.result).to eq('wait')

    body['prefetch'] = { 'coverage' => crd_coverage, 'order' => crd_order }
    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body)
    expect(last_response).to be_ok
    get(resume_pass_url)

    result = results_repo.find(result.id)
    expect(result.result).to eq('pass')
  end

  it 'returns cards and systemActions and uses client information to build request' do
    allow(test).to receive(:suite).and_return(suite)

    token = jwt_helper.build(
      aud: order_dispatch_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    run(test, iss: example_client_url, order_dispatch_selected_response_types:)

    body['prefetch'] = { 'coverage' => crd_coverage, 'order' => crd_order }
    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body)

    expect(last_response).to be_ok

    card_response = JSON.parse(last_response.body)
    cards = card_response['cards']
    system_actions = card_response['systemActions']

    expect(cards.length).to eq(2)
    expect(system_actions.length).to eq(1)
    expect(system_actions.first['resource']['id']).to eq('example')

    order_extension = system_actions.first['resource']['extension']
    coverage_extension = order_extension.first['extension'].first

    expect(coverage_extension['url']).to eq('coverage')
    expect(coverage_extension['valueReference']['reference']).to eq("Coverage/#{crd_coverage['id']}")
  end

  it 'queries the client\'s FHIR server if coverage is not present in the prefetch' do
    coverage_search_request = stub_request(:get,
                                           "#{client_fhir_server}/Coverage?patient=#{patient_id}&status=active")
      .with(
        headers: { 'Authorization' => 'Bearer SAMPLE_TOKEN' }
      )
      .to_return(status: 200, body: crd_coverage_bundle.to_json)
    order_request = stub_request(:get,
                                 "#{client_fhir_server}/ServiceRequest/example")
      .with(
        headers: { 'Authorization' => 'Bearer SAMPLE_TOKEN' }
      )
      .to_return(status: 200, body: crd_order.to_json)

    allow(test).to receive(:suite).and_return(suite)

    token = jwt_helper.build(
      aud: order_dispatch_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    run(test, iss: example_client_url, order_dispatch_selected_response_types:)

    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body)
    expect(last_response).to be_ok

    card_response = JSON.parse(last_response.body)
    cards = card_response['cards']
    system_actions = card_response['systemActions']

    expect(cards.length).to eq(2)
    expect(system_actions.length).to eq(1)
    expect(system_actions.first['resource']['id']).to eq('example')

    order_extension = system_actions.first['resource']['extension']
    coverage_extension = order_extension.first['extension'].first

    expect(coverage_extension['url']).to eq('coverage')
    expect(coverage_extension['valueReference']['reference']).to eq("Coverage/#{crd_coverage['id']}")
    expect(coverage_search_request).to have_been_made
    expect(order_request).to have_been_made
  end

  it 'waits and responds with 500 if request sent to the provided URL and jwt `iss` claim mismatches the given `iss`' do
    allow(test).to receive(:suite).and_return(suite)

    token = jwt_helper.build(
      aud: order_dispatch_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    result = run(test, iss: 'example.com', order_dispatch_selected_response_types:)

    expect(result.result).to eq('wait')

    body['prefetch'] = { 'coverage' => crd_coverage, 'order' => crd_order }
    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body.to_json)

    expect(last_response).to be_server_error
    expect(last_response.body).to match(/find test run with identifier/)
    result = results_repo.find(result.id)
    expect(result.result).to eq('wait')
  end

  it 'waits and responds with 500 if request sent to the provided URL contains the wrong hook name' do
    allow(test).to receive(:suite).and_return(suite)

    token = jwt_helper.build(
      aud: order_dispatch_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    result = run(test, iss: 'example.com', order_dispatch_selected_response_types:)

    expect(result.result).to eq('wait')

    body['prefetch'] = { 'coverage' => crd_coverage }
    body['hook'] = 'incorrect-hook'
    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body.to_json)

    expect(last_response).to be_server_error
    expect(last_response.body).to match(/find test run with identifier/)
    result = results_repo.find(result.id)
    expect(result.result).to eq('wait')
  end

  it 'returns default cards when no order_dispatch_selected_response_types selected' do
    order_request = stub_request(:get,
                                 "#{client_fhir_server}/ServiceRequest/example")
      .with(
        headers: { 'Authorization' => 'Bearer SAMPLE_TOKEN' }
      )
      .to_return(status: 200, body: crd_order.to_json)

    allow(test).to receive(:suite).and_return(suite)

    token = jwt_helper.build(
      aud: order_dispatch_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    run(test, iss: example_client_url, order_dispatch_selected_response_types: [])

    body['prefetch'] = { 'coverage' => crd_coverage }
    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body)

    expect(last_response).to be_ok

    card_response = JSON.parse(last_response.body)
    cards = card_response['cards']
    system_actions = card_response['systemActions']

    expect(cards.length).to eq(0)
    expect(system_actions.length).to eq(1)
    expect(system_actions.first['resource']['id']).to eq('example')

    encounter_extension = system_actions.first['resource']['extension']
    coverage_extension = encounter_extension.first['extension'].first

    expect(coverage_extension['url']).to eq('coverage')
    expect(coverage_extension['valueReference']['reference']).to eq("Coverage/#{crd_coverage['id']}")
    expect(order_request).to have_been_made
  end

  it 'successfully returns all supported cards when all selected_response_type options are selected' do
    order_request = stub_request(:get,
                                 "#{client_fhir_server}/ServiceRequest/example")
      .with(
        headers: { 'Authorization' => 'Bearer SAMPLE_TOKEN' }
      )
      .to_return(status: 200, body: crd_order.to_json)

    allow(test).to receive(:suite).and_return(suite)

    token = jwt_helper.build(
      aud: order_dispatch_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    run(test, iss: example_client_url, order_dispatch_selected_response_types: order_dispatch_selected_response_types +
    ['request_form_completion', 'create_update_coverage_info', 'launch_smart_app',
     'propose_alternate_request', 'companions_prerequisites'])

    body['prefetch'] = { 'coverage' => crd_coverage }
    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body)

    expect(last_response).to be_ok

    card_response = JSON.parse(last_response.body)
    cards = card_response['cards']
    system_actions = card_response['systemActions']

    expect(cards.length).to eq(7)

    expect(cards.first['summary']).to eq('Order Dispatch Request Form Completion Card')
    expect(cards[1]['summary']).to eq('Order Dispatch Launch SMART Application Card')
    expect(cards[2]['summary']).to eq('Order Dispatch External Reference Card')
    expect(cards[3]['summary']).to eq('Order Dispatch Additional Orders As Companions/Prerequisites Card')
    expect(cards[4]['summary']).to eq('Order Dispatch Propose Alternate Request Card')
    expect(cards[5]['summary']).to eq('Order Dispatch Create/Update Coverage Information Card')
    expect(cards[6]['summary']).to eq('Order Dispatch Instructions Card')

    expect(system_actions.length).to eq(1)
    expect(system_actions.first['resource']['id']).to eq('example')

    order_extension = system_actions.first['resource']['extension']
    coverage_extension = order_extension.first['extension'].first

    expect(coverage_extension['url']).to eq('coverage')
    expect(coverage_extension['valueReference']['reference']).to eq("Coverage/#{crd_coverage['id']}")
    expect(order_request).to have_been_made.times(2)
  end
end
