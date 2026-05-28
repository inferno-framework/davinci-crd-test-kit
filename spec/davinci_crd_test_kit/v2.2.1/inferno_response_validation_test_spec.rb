RSpec.describe DaVinciCRDTestKit::V221::InfernoResponseValidationTest do
  let(:suite_id) { 'crd_client' }
  let(:order_sign_test) do
    Class.new(described_class) do
      config({ options: { hook_name: DaVinciCRDTestKit::ORDER_SIGN_TAG } })

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
    expect(first_error_message.message).to match(/`summary` is over the 140-character limit/)
  end
end
