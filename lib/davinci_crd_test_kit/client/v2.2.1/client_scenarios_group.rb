require_relative 'client_long_running_hook_group'
require_relative 'client_unknown_content_hook_group'
require_relative 'client_self_pay_hook_group'
require_relative 'client_multiple_payers_hook_group'
require_relative 'client_user_access_level_group'

module DaVinciCRDTestKit
  module V221
    class ClientScenariosGroup < Inferno::TestGroup
      title 'Scenarios'
      id :crd_v221_client_scenarios
      description <<~DESCRIPTION
        This group checks CRD requirements that pertain to specific scenarios
        that CRD clients need to handle.

        These scenario tests do not check requirements beyond those required for
        Inferno to recognize CRD client requests and confirm the exchange represents
        the target scenario. However, testers are expected to follow
        the same workflows as used during other tests and should adhere to the
        same CRD requirements when performing these scenarios.
      DESCRIPTION

      input_order :long_running_pause_time, :access_level_target_reference

      group from: :crd_v221_client_long_running_hook
      group from: :crd_v221_client_unknown_content_hook
      group from: :crd_v221_client_self_pay_hook
      group from: :crd_v221_client_multiple_payers_hook
      group from: :crd_v221_client_user_access_level
    end
  end
end
