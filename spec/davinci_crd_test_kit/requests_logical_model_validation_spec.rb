require_relative '../../lib/davinci_crd_test_kit/cross_suite/requests_logical_model_validation'

RSpec.describe DaVinciCRDTestKit::RequestsLogicalModelValidation do
  let(:module_instance) do
    Class.new do
      include DaVinciCRDTestKit::RequestsLogicalModelValidation

      attr_reader :messages, :conforms_calls

      def initialize
        @messages = []
        @conforms_calls = []
      end

      def add_message(type, message)
        @messages << { type:, message: }
      end

      def conforms_to_logical_model?(object, url, message_prefix: '')
        @conforms_calls << { object:, url:, message_prefix: }
        true
      end

      def scratch
        @scratch ||= {}
      end
    end.new
  end

  let(:order_dispatch_request_v211) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_dispatch_hook_v221_request.json')))
  end

  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'order_sign_hook_request.json')))
  end

  describe '#validate_request_against_logical_model' do
    describe 'when performing additional v2.2.1 verification' do
      it 'adds an error message when a fullfillmentTask does not have an id' do
        order_dispatch_request_v211.dig('context', 'fulfillmentTasks', 0).delete('id')

        module_instance.validate_request_against_logical_model(order_dispatch_request_v211, 0, '2.2.1')

        expect(module_instance.messages.length).to eq(1)
        message = module_instance.messages.first
        expect(message[:type]).to eq('error')
        expect(message[:message]).to eq('(Request 1) FHIR resources provided in the hook context must have an id, none ' \
                                        'found for `context.fulfillmentTasks` entry 1.')
      end

      it 'adds an error message when a draftOrder entry does not have an id' do
        order_sign_request.dig('context', 'draftOrders', 'entry', 0, 'resource').delete('id')

        module_instance.validate_request_against_logical_model(order_sign_request, 0, '2.2.1')

        expect(module_instance.messages.length).to eq(1)
        message = module_instance.messages.first
        expect(message[:type]).to eq('error')
        expect(message[:message]).to eq('(Request 1) FHIR resources provided in the hook context must have an id, none ' \
                                        'found for `context.draftOrders` entry 1.')
      end
    end
  end
end
