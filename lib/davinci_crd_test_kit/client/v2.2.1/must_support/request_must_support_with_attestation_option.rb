require_relative '../../../cross_suite/hook_request_resource_extraction'
require_relative '../../../cross_suite/profile_metadata'
require_relative '../../../cross_suite/must_support_slice_matching'
require_relative '../../../cross_suite/tags'
require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    # Checks that the CRD profiles within a given scope were observed in the hook requests the
    # client made, and that every must support element on them was populated on at least one
    # instance. Anything not observed falls back to a tester attestation.
    class RequestMustSupportWithAttestationOption < Inferno::Test
      include HookRequestResourceExtraction
      include ClientURLs

      id :crd_v221_request_must_support_with_attestation_option

      input :order_types_supported, optional: true
      input :supporting_types_supported, optional: true

      output :attest_true_url
      output :attest_false_url

      class << self
        def build_description(options)
          sections = options[:profiles].map do |profile|
            metadata = metadata_for(options[:ig_version], profile)
            elements = metadata.must_support_strings.map { |element| "- `#{element}`" }.join("\n")

            "### #{title_for(metadata, profile)}\n\n#{elements}"
          end

          "#{description_intro}\n\n#{sections.join("\n\n")}"
        end

        def description_intro
          <<~INTRO
            CRD clients populate the FHIR resources they send within a hook request from the data
            they maintain. During this test, Inferno checks the resources found in the `context` and
            `prefetch` of every hook request received so far, and verifies that each must support
            element below was populated on at least one instance.

            Elements that were not observed do not fail this test on their own. Inferno will instead
            ask the tester to attest that the client system does not capture that data or does not
            surface it to its users. The same applies to a resource type that was not seen at all,
            which the tester may attest the system does not support.

            To demonstrate elements that earlier hook requests did not cover, use the
            "Additional Hook Invocations for Cross Hook Support Demonstration" group to send more
            requests, then re-run this group.
          INTRO
        end

        def metadata_for(ig_version, profile)
          ProfileMetadata.merged(ig_version, profile[:profile_keys])
        end

        def title_for(metadata, profile)
          profile[:title] || metadata.profile_name
        end
      end

      # Reads the requests directly rather than going through `load_tagged_requests`, which would
      # also associate every cross hook request with this test's own result.
      def must_support_requests
        @must_support_requests ||=
          Inferno::Repositories::Requests.new.tagged_requests(test_session_id, [CROSS_HOOK_ANALYSIS_TAG])
      end

      # Every must support test in this group reads the same pooled requests, so the extraction is
      # kept in scratch, which persists across test instances. The request ids it was built from are
      # stored alongside it, since a tester can send more hook requests and re-run the group.
      def extraction
        request_ids = must_support_requests.map(&:id)
        cached = scratch[:must_support_extraction]
        return cached if cached && cached[:request_ids] == request_ids

        dropped = []
        scratch[:must_support_extraction] = {
          request_ids:,
          resources_by_type: fhir_resources_by_type(must_support_requests, dropped:),
          dropped:
        }
      end

      def dropped_resources
        extraction[:dropped]
      end

      def resources_by_type
        extraction[:resources_by_type]
      end

      def check_for_dropped_resources
        dropped_resources.each do |entry|
          add_message('error', dropped_resource_message(entry))
        end

        assert dropped_resources.blank?,
               "Inferno could not read #{dropped_resources.length} item(s) in the hook requests made " \
               'by the client system. See Messages for details.'
      end

      def dropped_resource_message(entry)
        if entry[:reason] == :unparsable_body
          'Could not parse the body of a hook request as JSON.'
        else
          "Could not read a #{entry[:resource_type].presence || 'resource'} found in a hook request."
        end
      end

      def ig_version
        config.options[:ig_version]
      end

      # A resource type the tester did not select, or that only a hook they never invoked would
      # carry, is not expected. Observing one anyway contradicts what the tester declared.
      def expected?(resource_type)
        return false if declared_unsupported?(resource_type)

        hooks = ClientCrossHookMustSupportGroup::REQUIRING_HOOKS[resource_type]
        hooks.nil? || hooks.any? { |hook_tag| hook_invoked?(hook_tag) }
      end

      # nil when the type is required of every client, so no input governs it. Inferno hands a
      # checkbox input over as an array, empty when the tester cleared it or never reached it, so
      # an empty selection leaves every type expected rather than none.
      def selected_types(resource_type)
        if ClientCrossHookMustSupportGroup::ORDER_TYPE_OPTIONS.any? { |one| one[:value] == resource_type }
          selected_or_all(order_types_supported, ClientCrossHookMustSupportGroup::ORDER_TYPE_OPTIONS)
        elsif ClientCrossHookMustSupportGroup::SUPPORTING_TYPE_OPTIONS.any? { |one| one[:value] == resource_type }
          selected_or_all(supporting_types_supported, ClientCrossHookMustSupportGroup::SUPPORTING_TYPE_OPTIONS)
        end
      end

      def selected_or_all(selected, options)
        selected.presence || options.map { |option| option[:value] }
      end

      def hook_invoked?(hook_tag)
        Inferno::Repositories::Requests.new.tagged_requests(test_session_id, [hook_tag]).present?
      end

      def declared_unsupported?(resource_type)
        selected = selected_types(resource_type)

        selected.present? && selected.exclude?(resource_type)
      end

      def unexpected_reason(resource_type)
        return 'the tester did not select it as supported' if declared_unsupported?(resource_type)

        hooks = ClientCrossHookMustSupportGroup::REQUIRING_HOOKS[resource_type]
        "no #{hooks.join(' or ')} hook was invoked"
      end

      def gather_unobserved
        config.options[:profiles].filter_map do |profile|
          metadata = self.class.metadata_for(ig_version, profile)
          title = self.class.title_for(metadata, profile)
          resource_type = profile[:resource_type]
          resources = resources_by_type[resource_type] || []

          # `missing_must_support_elements` returns nil rather than the full list when handed no
          # resources, so an absent resource type has to be caught before calling it.
          if resources.blank?
            next unless expected?(resource_type)

            next { kind: :unsupported_type, title:, resource_type:,
                   supporting_profile: profile[:supporting_profile] }
          end

          # Only a type the tester declared unsupported contradicts what they said. A hook gated
          # type can  turn up in another hook's request, so it is checked as normal.
          next { kind: :unexpected_type, title:, resource_type:, count: resources.length } if
            declared_unsupported?(resource_type)

          missing = missing_must_support_elements(resources, nil, metadata:)
          next if missing.blank?

          { kind: :unobserved_elements, title:, resource_type:, count: resources.length, missing: }
        end
      end

      def unexpected(unobserved)
        unobserved.select { |entry| entry[:kind] == :unexpected_type }
      end

      # The tester said the system does not send this type, but it did, so neither passing nor
      # asking them to attest to its absence would be right.
      def check_for_unexpected_types(unobserved)
        unexpected(unobserved).each do |entry|
          add_message('error',
                      "Observed #{entry[:count]} `#{entry[:resource_type]}` instance(s) in the hook requests " \
                      "made by the client system, but #{unexpected_reason(entry[:resource_type])}.")
        end

        assert unexpected(unobserved).blank?,
               'Inferno observed resource type(s) it was not expecting: ' \
               "#{unexpected(unobserved).map { |entry| entry[:resource_type] }.join(', ')}. See Messages."
      end

      # A type that was neither observed nor expected passes without the tester having to say
      # anything, so the message says why rather than claiming its elements were seen.
      def pass_message
        vacuous = config.options[:profiles].map { |profile| profile[:resource_type] }
          .reject { |resource_type| resources_by_type[resource_type].present? }
        return 'All must support elements were observed.' if vacuous.blank?

        "No instances of #{vacuous.join(', ')} observed, and none required: " \
          "#{vacuous.map { |resource_type| unexpected_reason(resource_type) }.uniq.join('; ')}."
      end

      def log_info_messages(unobserved)
        unobserved.each do |entry|
          if entry[:kind] == :unsupported_type
            add_message('info', "No #{entry[:resource_type]} instances observed for #{entry[:title]}.")
            next
          end

          add_message('info',
                      "Observed #{entry[:count]} #{entry[:resource_type]} instance(s) across " \
                      "#{must_support_requests.length} hook request(s) for #{entry[:title]}.")
          entry[:missing].each do |element|
            add_message('info', "Unobserved must support element for #{entry[:title]}: #{element}")
          end
        end
      end

      def attestation_message(unobserved, attest_true_url, attest_false_url)
        <<~MESSAGE
          **Must Support Attestation**

          #{unobserved.map { |entry| attestation_section(entry) }.join("\n\n")}

          [Click here](#{attest_true_url}) if the above statement is **true**. The test will **pass**.

          [Click here](#{attest_false_url}) if the above statement is **false**. The test will **fail**.
        MESSAGE
      end

      def attestation_section(entry)
        return unsupported_type_section(entry) if entry[:kind] == :unsupported_type

        <<~SECTION.chomp
          Inferno observed #{entry[:count]} `#{entry[:resource_type]}` instance(s) in the hook requests
          made by the client system, but the following #{entry[:title]} must support elements were not
          observed on any of them:

          #{entry[:missing].map { |element| "- `#{element}`" }.join("\n")}

          Attest that, for each element listed above, the client system either does not capture the
          data or does not surface it to its users, and therefore cannot populate it in CRD requests.
        SECTION
      end

      def unsupported_type_section(entry)
        return supporting_profile_section(entry) if entry[:supporting_profile]

        <<~SECTION.chomp
          Inferno did not observe any `#{entry[:resource_type]}` resources in the hook requests made by
          the client system, in either the hook `context` or the `prefetch`.

          Attest that the client system does **not** support the #{entry[:title]} request type -- it
          does not allow users to create or act on requests of this type, and therefore never includes
          them in CRD hook requests.
        SECTION
      end

      def supporting_profile_section(entry)
        <<~SECTION.chomp
          Inferno did not observe any `#{entry[:resource_type]}` resources in the hook requests made by
          the client system, in either the hook `context` or the `prefetch`.

          `#{entry[:resource_type]}` is referenced from within CRD requests rather than being a request
          type itself, so this is unexpected. Confirm that the hook requests sent so far were expected
          to include #{entry[:title]} data.

          Attest that the client system does not populate `#{entry[:resource_type]}` data in its CRD
          hook requests. If it should have, cancel this attestation, send further requests that include
          it, and re-run this group.
        SECTION
      end

      run do
        skip_if must_support_requests.blank?, 'No hook requests received.'

        unobserved = gather_unobserved
        check_for_unexpected_types(unobserved)
        log_info_messages(unobserved)
        check_for_dropped_resources
        pass pass_message if unobserved.blank?

        identifier = SecureRandom.hex(32)
        attest_true_url = "#{resume_pass_url}?token=#{identifier}"
        attest_false_url = "#{resume_fail_url}?token=#{identifier}"
        output(attest_true_url:)
        output(attest_false_url:)

        wait(identifier:, message: attestation_message(unobserved, attest_true_url, attest_false_url))
      end
    end
  end
end
