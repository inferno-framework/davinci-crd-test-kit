require_relative 'hook_request_field_validation'

module DaVinciCRDTestKit
  module ClientHookRequestValidation
    include DaVinciCRDTestKit::HookRequestFieldValidation

    def client_test?
      true
    end

    def server_test?
      false
    end
  end
end
