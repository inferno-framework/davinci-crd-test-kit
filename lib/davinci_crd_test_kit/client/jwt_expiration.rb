module DaVinciCRDTestKit
  # Checks the authentication JWT's `exp` claim against when Inferno received the request rather than
  # against when the test runs, which can be minutes later in a slow run. JWT.decode can only compare
  # `exp` with the current time, so tests turn its check off (`verify_expiration: false`) and use this one.
  module JwtExpiration
    CLOCK_SKEW_LEEWAY = 60

    # A message when the token had already expired when the request was received, otherwise nil. A missing
    # or non-numeric `exp` is not reported here, since it is reported as a missing claim or a wrong type.
    # Without a request, `exp` is compared with the current time.
    def jwt_expiration_error(payload, request)
      exp = payload['exp'] if payload.is_a?(Hash)
      return unless exp.is_a?(Numeric)

      received_at = (request&.created_at || Time.now).to_i
      return if exp > received_at - CLOCK_SKEW_LEEWAY

      "Token had expired when the request was received: `exp` is #{Time.at(exp).utc.iso8601}, " \
        "the request was received at #{Time.at(received_at).utc.iso8601}."
    end
  end
end
