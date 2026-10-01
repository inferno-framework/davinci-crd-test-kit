module DaVinciCRDTestKit
  module ShortCircuitInteraction
    DEFAULT_SHORT_CIRCUIT_MESSAGE = 'Tester chose not to make additional hook requests.'.freeze

    def clear_short_circuit_flag
      scratch.delete(:short_circuit)
    end

    def short_circuit_remaining_tests(action)
      scratch[:short_circuit] = action
    end

    def check_for_short_circuit(message: '')
      return if scratch[:short_circuit].blank?

      message = DEFAULT_SHORT_CIRCUIT_MESSAGE if message.blank?

      case scratch[:short_circuit]
      when :pass then pass message
      when :skip then skip message
      else
        raise Inferno::Exceptions::TestSuiteImplementationException.new(
          'ShortCircuitInteraction', "invalid short circuit action: #{scratch[:short_circuit]}"
        )
      end
    end
  end
end
