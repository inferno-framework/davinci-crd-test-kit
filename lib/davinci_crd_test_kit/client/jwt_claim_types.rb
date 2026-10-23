module DaVinciCRDTestKit
  # Checks the JSON types of the claims CDS Hooks requires in the authentication JWT payload. JWT.decode
  # does not check them: it coerces `exp` with `to_i`, accepts any `jti` that is not blank, and does not
  # check `iat` at all when its verification is turned off. Claims that are absent are not checked here,
  # since they are reported as missing separately.
  module JwtClaimTypes
    CLAIM_TYPES = {
      'iss' => ['a string', ->(value) { value.is_a?(String) }],
      'aud' => ['a string or an array of strings',
                ->(value) { value.is_a?(String) || (value.is_a?(Array) && value.all?(String)) }],
      'exp' => ['a number', ->(value) { value.is_a?(Numeric) }],
      'iat' => ['a number', ->(value) { value.is_a?(Numeric) }],
      'jti' => ['a string', ->(value) { value.is_a?(String) }]
    }.freeze

    # One message for each claim present in the payload that does not have the type CDS Hooks requires.
    def jwt_claim_type_errors(payload)
      return [] unless payload.is_a?(Hash)

      CLAIM_TYPES.filter_map do |claim, (expected, valid)|
        next unless payload.key?(claim)
        next if valid.call(payload[claim])

        "JWT payload claim `#{claim}` must be #{expected}, got #{payload[claim].to_json}."
      end
    end
  end
end
