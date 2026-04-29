require_relative '../server_base_urls'

module DaVinciCRDTestKit
  module V221
    module ServerURLs
      include ServerBaseURLs

      def suite_id
        DaVinciCRDTestKit::V221::CRDServerSuite.id
      end
    end
  end
end
