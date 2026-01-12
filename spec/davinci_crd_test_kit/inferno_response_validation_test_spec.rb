require_relative '../../lib/davinci_crd_test_kit/tags'

RSpec.describe DaVinciCRDTestKit::InfernoResponseValidationTest do
  let(:suite_id) { 'crd_client' }
  let(:order_sign_test) do
    Class.new(DaVinciCRDTestKit::InfernoResponseValidationTest) do
      config({ options: { hook_name: DaVinciCRDTestKit::ORDER_SIGN_TAG } })
    end
  end
  let(:coverage_tag) { 'coverage' }
  let(:order_sign_coverage_test) do
    Class.new(DaVinciCRDTestKit::InfernoResponseValidationTest) do
      config({ options: { hook_name: DaVinciCRDTestKit::ORDER_SIGN_TAG, crd_test_group: 'coverage' } })
    end
  end
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:valid_response_body_json) do
    File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
  end
  let(:first_error_message) do
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [order_sign_test])
      .first
      .messages.select { |message| message.type == 'error' }
      .first
  end
  let(:mocked_response_creator) do
    Class.new do
      include DaVinciCRDTestKit::MockServiceResponse

      def selected_response_types
        @selected_response_types ||= [
          'coverage_information',
          'create_update_coverage_info',
          'instructions',
          'propose_alternate_request',
          'companions_prerequisites',
          'request_form_completion',
          'launch_smart_app',
          'external_reference'
        ]
      end

      def request_body
        @request_body ||=
          JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_sign_hook_request.json')))
            .merge({
                     'prefetch' => {
                       'coverage' =>
                        JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_coverage_example.json')))
                     }
                   })
      end

      def hook_name
        DaVinciCRDTestKit::ORDER_SIGN_TAG
      end
    end
  end

  def store_request(response_body, tags, status: 200)
    repo_create(
      :request,
      direction: 'incoming',
      test_session_id: test_session.id,
      result:,
      response_body:,
      tags:,
      status:
    )
  end

  describe 'When no requests made' do
    it 'skips and uses "custom built" response labels for errors when a custom response provided' do
      result = run(order_sign_test, custom_response_template: valid_response_body_json)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No custom built responses to verify.')
    end

    it 'skips and uses "mocked" response lables for errors when no custom response provided' do
      result = run(order_sign_test)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No mocked responses to verify.')
    end
  end

  describe 'when requests made' do
    it 'skips if only error responses are returned' do
      store_request('Invalid template provided for custom Inferno CRD response: invalid JSON',
                    [DaVinciCRDTestKit::ORDER_SIGN_TAG], status: 500)
      result = run(order_sign_test)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No .* cards or system actions to verify returned by Inferno./)
    end

    it 'fails if a system action is invalid' do
      store_request({ cards: [], systemActions: [{ type: 'notreal' }] }.to_json,
                    [DaVinciCRDTestKit::ORDER_SIGN_TAG])
      result = run(order_sign_test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Invalid Inferno .*\(s\). Check messages for issues found./)
      expect(first_error_message.message).to match(/Action does not contain required field/)
    end

    it 'fails if a card is invalid' do
      store_request({ cards: [{ summary: 'not real' }] }.to_json,
                    [DaVinciCRDTestKit::ORDER_SIGN_TAG])
      result = run(order_sign_test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Invalid Inferno .*\(s\). Check messages for issues found./)
      expect(first_error_message.message).to match(/Card does not contain required field/)
    end

    it 'passes on Inferno mocked cards and actions' do
      store_request(mocked_response_creator.new.build_mock_hook_response.to_json,
                    [DaVinciCRDTestKit::ORDER_SIGN_TAG])
      result = run(order_sign_test)

      expect(result.result).to eq('pass')
    end

    describe 'when a subgroup is defined' do
      it 'only considers requests tagged with that group' do
        store_request({ cards: [{ summary: 'not real' }] }.to_json,
                      [DaVinciCRDTestKit::ORDER_SIGN_TAG])
        store_request(mocked_response_creator.new.build_mock_hook_response.to_json,
                      [DaVinciCRDTestKit::ORDER_SIGN_TAG, coverage_tag])
        result = run(order_sign_coverage_test)

        expect(result.result).to eq('pass')
      end
    end
  end
end
