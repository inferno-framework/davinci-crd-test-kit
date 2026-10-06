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

      # The type matters: Inferno parses a checkbox input's stored JSON into an array, and without
      # it the raw string arrives instead.
      input :order_types_supported, optional: true, type: 'checkbox'
      input :supporting_types_supported, optional: true, type: 'checkbox'

      output :attest_true_url
      output :attest_false_url

      class << self
        def build_description(options)
          sections = options[:profiles].map do |profile|
            parts = profile[:profile_keys].map { |key| ProfileMetadata.for(options[:ig_version], key) }
            heading = parts.map { |one| "[#{one.profile_name}](#{profile_page_url(one)})" }.to_sentence(
              two_words_connector: ' or ', last_word_connector: ', or '
            )
            metadata = metadata_for(options[:ig_version], profile)

            "### #{heading}\n\n#{multiple_profiles_note if parts.length > 1}" \
              "#{element_list(metadata)}#{choice_section(metadata)}"
          end

          "#{description_intro}\n\n#{sections.join("\n\n")}"
        end

        def element_list(metadata)
          (metadata.must_support_strings - choice_paths(metadata))
            .map { |element| "- `#{element}`" }.join("\n")
        end

        def choice_paths(metadata)
          Array(metadata.must_supports[:choices]).flat_map { |choice| Array(choice[:paths]) }
        end

        def choice_section(metadata)
          choices = Array(metadata.must_supports[:choices])
          return '' if choices.blank?

          "\n\n#{choice_note}#{choices.map { |choice| choice_entry(choice) }.join("\n\n")}"
        end

        def choice_entry(choice)
          locations = Array(choice[:paths]).map { |path| "  - `#{path}`" }.join("\n")

          "- `#{choice[:element]}`, on any one of:\n#{locations}"
        end

        def choice_note
          <<~NOTE
            #### Timing

            The CRD Timing elements below appear in more than one place on this profile. Each only
            needs to be demonstrated in one of the locations listed under it.

          NOTE
        end

        def multiple_profiles_note
          <<~NOTE
            The elements below are drawn from both appointment profiles, and each may be demonstrated on
            an instance of either of them. A client that supports only one of these profiles can still
            demonstrate every element.

          NOTE
        end

        def profile_page_url(metadata)
          ig_base, structure_definition = metadata.profile_url.split('/StructureDefinition/')

          "#{ig_base}/#{metadata.profile_version}/en/StructureDefinition-#{structure_definition}.html"
        end

        def description_intro
          <<~INTRO
            The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3)
            that when a client "maintains a mustSupport data element and surfaces it to users, then it
            SHALL be exposed in their FHIR interface when the data exists and privacy constraints permit."

            During this test, Inferno will check whether all must support elements defined in the
            profile(s) listed below are demonstrated within hook requests made during this session.
            This check may vacuously pass if the tester has attested that this resource type is not
            supported by the client system or if the relevant hooks are not invoked.

            If any must support elements are not demonstrated, the tester will have the option to attest
            that these elements are not supported by the client system or surfaced to its users. Testers
            must setup scenarios in which the "data exists and privacy constraints permit" Inferno to view
            the must support information.

            Inferno will consider resources present within the `context` and `prefetch` elements of all hook
            requests made during the latest run of each `Hooks` subgroup and the `Additional Hook
            Invocations for Cross Hook Support Demonstration` group, but not any made within the `Scenarios`
            subgroups. If any of the considered groups are re-run, then requests made during prior runs will
            no longer be considered and must support elements demonstrated only during that prior run must
            be re-demonstrated on the new run or a subsequent one.
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

        scratch[:must_support_extraction] = {
          request_ids:,
          resources_by_type: fhir_resources_by_type(must_support_requests)
        }
      end

      def resources_by_type
        extraction[:resources_by_type]
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

      # nil when the type is required of every client, so no input governs it. A client need not
      # support any order type, so clearing every box means none are expected rather than all.
      def selected_types(resource_type)
        if ClientCrossHookMustSupportGroup::ORDER_TYPE_OPTIONS.any? { |one| one[:value] == resource_type }
          Array(order_types_supported)
        elsif ClientCrossHookMustSupportGroup::SUPPORTING_TYPE_OPTIONS.any? { |one| one[:value] == resource_type }
          Array(supporting_types_supported)
        end
      end

      def hook_invoked?(hook_tag)
        Inferno::Repositories::Requests.new
          .tagged_requests(test_session_id, [hook_tag, CROSS_HOOK_ANALYSIS_TAG]).present?
      end

      def declared_unsupported?(resource_type)
        selected_types(resource_type)&.exclude?(resource_type) || false
      end

      def unexpected_reason(resource_type)
        if declared_unsupported?(resource_type)
          return 'the tester indicated that the client system does not support this resource type'
        end

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

            next { kind: :missing_type, title:, resource_type: }
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

      def missing(unobserved)
        unobserved.select { |entry| entry[:kind] == :missing_type }
      end

      # What the tester declared and what the client sent have to agree: a type they said is
      # supported must turn up, and one they said is not must not.
      def check_declared_types(unobserved)
        mismatched = unexpected(unobserved) + missing(unobserved)

        assert mismatched.blank?, mismatched.map { |entry| declared_type_message(entry) }.join(' ')
      end

      def declared_type_message(entry)
        if entry[:kind] == :unexpected_type
          "Observed #{entry[:count]} `#{entry[:resource_type]}` instance(s) in the hook requests made by the " \
            "client system, but #{unexpected_reason(entry[:resource_type])}."
        else
          "The tester indicated the client system supports the `#{entry[:resource_type]}` " \
            'resource type, but no instances were observed in the hook requests made.'
        end
      end

      # A type that was neither observed nor expected passes without the tester having to say
      # anything, so the message says why rather than claiming its elements were seen.
      def pass_message
        vacuous = config.options[:profiles].map { |profile| profile[:resource_type] }
          .reject { |resource_type| resources_by_type[resource_type].present? }
        return 'All must support elements were observed.' if vacuous.blank?

        "No instances of #{vacuous.to_sentence} observed, and none expected: " \
          "#{vacuous.map { |resource_type| unexpected_reason(resource_type) }.uniq.join('; ')}."
      end

      def log_info_messages(unobserved)
        unobserved.each do |entry|
          next unless entry[:kind] == :unobserved_elements

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

          [Click here](#{attest_true_url}) if the above statement is **true**.

          [Click here](#{attest_false_url}) if the above statement is **false**.
        MESSAGE
      end

      def attestation_section(entry)
        <<~SECTION.chomp
          Inferno observed #{entry[:count]} `#{entry[:resource_type]}` instance(s) in the hook requests
          made by the client system, but the following #{entry[:title]} must support elements were not
          observed on any of them:

          #{entry[:missing].map { |element| "- `#{element}`" }.join("\n")}

          I attest that the client system either does not capture or does not surface it to its users the data represented by the elements in the list above.
        SECTION
      end

      run do
        skip_if must_support_requests.blank?, 'No hook requests received.'

        unobserved = gather_unobserved
        check_declared_types(unobserved)
        log_info_messages(unobserved)
        pass pass_message if unobserved.blank?

        identifier = SecureRandom.hex(32)
        attest_true_url = "#{resume_pass_url}?token=#{identifier}"
        decline_message = CGI.escape('Not all must support elements demonstrated. See messages for details.')
        attest_false_url = "#{resume_fail_url}?token=#{identifier}&message=#{decline_message}"
        output(attest_true_url:)
        output(attest_false_url:)

        wait(identifier:, message: attestation_message(unobserved, attest_true_url, attest_false_url))
      end
    end
  end
end
