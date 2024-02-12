require_relative '../jwks'

module DaVinciCRDTestKit
  module Routes
    class JWKSetEndpointHandler
      def self.call(...)
        new.call(...)
      end

      def call(_env)
        [200, { 'Content-Type' => 'application/json' }, [JWKS.jwks_json]]
      end
    end
  end
end
