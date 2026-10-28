require_relative '../../tagged_request_load_helper'
require_relative '../../../cross_suite/tags'

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

        During this test, Inferno will check that no `jti` value was sent on more than one of the hook
        requests it processed during these tests, including those made during the scenarios.
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

      def tagged_requests_exist?(tag)
        Inferno::Repositories::Requests.new.tagged_requests(test_session_id, [tag]).present?
      end

      # The `jti` values the hook endpoint found on an earlier request when it received a later one. The
      # duplicate requests are not loaded into the result, since each is loaded with the others sharing
      # its `jti`.
      def repeated_jwt_ids
        Inferno::Repositories::Requests.new.tagged_requests(test_session_id, [DUPLICATED_JWT_ID_TAG])
          .filter_map { |request| jwt_id(bearer_token(request)) }
          .uniq
      end

      # identifies a request by its hook and `hookInstance`, since the requests can come from any group
      def request_label(request)
        body = begin
          JSON.parse(request.request_body.to_s)
        rescue JSON::ParserError
          nil
        end
        body = {} unless body.is_a?(Hash)
        "`#{body['hook'] || 'unknown hook'}` (hookInstance `#{body['hookInstance'] || 'none'}`)"
      end

      def request_list(hook_requests)
        labels = hook_requests.sort_by(&:index).map { |request| request_label(request) }
        "#{labels.length} hook requests: #{labels.to_sentence}"
      end

      # Says whether the JWT itself was resent or the `jti` was reused in new JWTs, since the two point
      # to different fixes in the CRD client.
      def report_repeated_jti(jti, requests_by_token)
        sent_on = request_list(requests_by_token.values.flatten)
        repetition =
          if requests_by_token.length == 1
            "The same JWT (`jti` #{jti.to_json}) was sent on #{sent_on}."
          else
            "`jti` #{jti.to_json} was used by #{requests_by_token.length} different JWTs, sent on #{sent_on}."
          end
        add_message('error', "#{repetition} Each hook request must carry a new JWT with its own `jti`.")
      end

      run do
        skip_if !tagged_requests_exist?(CROSS_HOOK_ANALYSIS_TAG), 'No hook requests received.'

        repeated_jwt_ids.each do |jti|
          requests_sharing_jti = load_tagged_requests(TagMethods.jwt_id_tag(jti))
          report_repeated_jti(jti, requests_sharing_jti.group_by { |request| bearer_token(request) })
        end

        assert_no_error_messages('Inferno received the same `jti` value on more than one hook request. ' \
                                 'See Messages for details.')
      end
    end
  end
end
