require_relative 'hook_request_field_validation'

module DaVinciCRDTestKit
  module ServerHookRequestValidation
    include DaVinciCRDTestKit::HookRequestFieldValidation

    def client_test?
      false
    end

    def server_test?
      true
    end
  end
end
