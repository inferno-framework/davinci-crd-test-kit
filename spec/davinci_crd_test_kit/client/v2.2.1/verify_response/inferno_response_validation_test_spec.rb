require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/crd_client_suite'

RSpec.describe DaVinciCRDTestKit::V221::InfernoResponseValidationTest do
  let(:suite_id) { 'crd_client' }
  let(:order_sign_test) do
    Class.new(described_class) do
      config({ options: { hook_name: DaVinciCRDTestKit::ORDER_SIGN_TAG,
                          crd_interaction_group: DaVinciCRDTestKit::ORDER_SIGN_TAG } })

      def conforms_to_logical_model?(*_args, **_kwargs)
        true
      end
    end
  end
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  def store_request(response_body, tags, status: 200, request_body: '{}')
    repo_create(
      :request,
      direction: 'incoming',
      test_session_id: test_session.id,
      result:,
      request_body:,
      response_body:,
      tags:,
      status:
    )
  end

  def first_error_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [order_sign_test])
      .first
      .messages.select { |message| message.type == 'error' }
      .first
  end

  it 'fails if a card summary is more than 140 characters' do
    cards = [{ summary: SecureRandom.alphanumeric(150), indicator: 'info', source: { label: 'Inferno' } }]
    store_request({ cards: }.to_json, [DaVinciCRDTestKit::ORDER_SIGN_TAG])

    result = run(order_sign_test)

    expect(result.result).to eq('fail')
    expect(first_error_message.message).to include('`summary` is over the 140-character limit')
  end

  describe 'response label' do
    it 'describes responses as mocked when the mocked approach was used' do
      result = run(order_sign_test, response_approach: 'mocked')

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No mocked responses to verify.')
    end

    it 'describes responses as custom built when the custom approach was used' do
      result = run(order_sign_test, response_approach: 'custom')

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No custom built responses to verify.')
    end

    it 'describes responses as mocked when no approach is provided' do
      result = run(order_sign_test)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No mocked responses to verify.')
    end
  end

  describe 'response approach input mapping' do
    {
      DaVinciCRDTestKit::V221::ClientAppointmentBookGroup => :appointment_book_response_approach,
      DaVinciCRDTestKit::V221::ClientEncounterStartGroup => :encounter_start_response_approach,
      DaVinciCRDTestKit::V221::ClientEncounterDischargeGroup => :encounter_discharge_response_approach,
      DaVinciCRDTestKit::V221::ClientOrderSelectGroup => :order_select_response_approach,
      DaVinciCRDTestKit::V221::ClientOrderSignGroup => :order_sign_response_approach,
      DaVinciCRDTestKit::V221::ClientOrderDispatchGroup => :order_dispatch_response_approach,
      DaVinciCRDTestKit::V221::ClientCrossHookInteractionGroup => :cross_hooks_response_approach
    }.each do |group, expected_input|
      it "maps response_approach to #{expected_input} in #{group.title}" do
        validation_test = ([group] + group.groups).flat_map(&:tests)
          .find { |test| test.id.to_s.end_with?('crd_v221_inferno_response_validation') }

        expect(validation_test.config.input_name(:response_approach)).to eq(expected_input.to_s)
      end
    end
  end
end
