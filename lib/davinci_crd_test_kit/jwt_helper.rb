require_relative 'jwks'

module DaVinciCRDTestKit
  class JwtHelper
    def self.build(...)
      new(...).signed_jwt
    end

    def self.decode_jwt(token, jwks_hash, kid = nil)
      jwks = JWT::JWK::Set.new(jwks_hash)
      jwks.filter! { |key| key[:use] == 'sig' }
      algorithms = jwks.map { |key| key[:alg] }.compact.uniq
      begin
        JWT.decode(token, kid, true, algorithms:, jwks:)
      rescue StandardError => e
        raise Inferno::Exceptions::AssertionException, e.message
      end
    end

    attr_reader :aud, :encryption_method, :exp, :iat, :iss, :jku, :jti, :kid

    def initialize(
      aud:,
      encryption_method:,
      iss:,
      jku:,
      iat: Time.now.to_i,
      exp: 5.minutes.from_now.to_i,
      jti: SecureRandom.hex(32),
      kid: nil
    )
      @aud = aud
      @encryption_method = encryption_method
      @iss = iss
      @jku = jku
      @iat = iat
      @exp = exp
      @jti = jti
      @kid = kid
    end

    def private_key
      @private_key ||= JWKS.jwks
        .select { |key| key[:key_ops]&.include?('sign') }
        .select { |key| key[:alg] == encryption_method }
        .find { |key| !kid || key[:kid] == kid }
    end

    def signing_key
      if private_key.nil?
        raise Inferno::Exceptions::AssertionException,
              "No signing key found for inputs: encryption method = '#{encryption_method}' and kid = '#{kid}'"
      end

      @private_key.signing_key
    end

    def jwt_header
      { alg: encryption_method, typ: 'JWT', kid: key_id, jku: }
    end

    def jwt_payload
      { iss:, aud:, exp:, iat:, jti: }
    end

    def key_id
      @private_key['kid']
    end

    def signed_jwt
      @signed_jwt ||= JWT.encode jwt_payload, signing_key, encryption_method, jwt_header
    end
  end
end
