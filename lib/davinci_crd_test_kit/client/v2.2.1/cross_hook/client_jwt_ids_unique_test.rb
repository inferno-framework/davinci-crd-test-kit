require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class ClientJwtIdsUniqueTest < Inferno::Test
      include TaggedRequestLoadHelper

      title 'CRD client does not reuse JWT `jti` values'
      id :crd_v221_client_jwt_ids_unique
      description <<~DESCRIPTION
        The CDS Hooks specification requires that the `jti` claim of the authentication JWT sent
        with each hook request be a nonce that uniquely identifies that JWT, so that CDS Services can
        use it to protect against replay attacks. A CDS Service does so by rejecting a `jti` it has
        already received, so each hook request must carry a new JWT with its own `jti`.

        During this test, Inferno will check that across all hook invocations performed during these
        tests, no `jti` value was sent on more than one request.
      DESCRIPTION

      verifies_requirements 'cds-hooks_3.0.0-ballot@192'

      def bearer_token(request)
        request.request_header('Authorization')&.value&.delete_prefix('Bearer ')
      end

      def jwt_id(token)
        payload, = JWT.decode(token, nil, false)
        payload['jti'] if payload.is_a?(Hash)
      rescue JWT::DecodeError
        nil
      end

      # request numbers carrying each token, grouped by the `jti` of that token
      def request_numbers_by_jti_and_token(requests)
        requests.each_with_index.with_object({}) do |(request, index), by_jti|
          token = bearer_token(request)
          next if token.blank?

          jti = jwt_id(token)
          next if jti.blank?

          ((by_jti[jti] ||= {})[token] ||= []) << (index + 1)
        end
      end

      def request_list(request_numbers)
        "#{'request'.pluralize(request_numbers.length)} #{request_numbers.sort.to_sentence}"
      end

      # Says whether the JWT itself was resent or the `jti` was reused in new JWTs, since the two point
      # to different fixes in the CRD client.
      def report_repeated_jti(jti, request_numbers_by_token)
        request_numbers = request_list(request_numbers_by_token.values.flatten)
        repetition =
          if request_numbers_by_token.length == 1
            "The same JWT (`jti` #{jti.to_json}) was sent on #{request_numbers}."
          else
            "`jti` #{jti.to_json} was used by #{request_numbers_by_token.length} different JWTs, sent on " \
              "#{request_numbers}."
          end
        add_message('error', "#{repetition} Each hook request must carry a new JWT with its own `jti`.")
      end

      run do
        hook_requests = load_requests_for_cross_hook_analysis
        skip_if hook_requests.blank?, 'No hook requests received.'

        request_numbers_by_jti_and_token(hook_requests).each do |jti, request_numbers_by_token|
          next if request_numbers_by_token.values.flatten.one?

          report_repeated_jti(jti, request_numbers_by_token)
        end

        assert_no_error_messages('Inferno received the same `jti` value on more than one hook request. ' \
                                 'See Messages for details.')
      end
    end
  end
end
