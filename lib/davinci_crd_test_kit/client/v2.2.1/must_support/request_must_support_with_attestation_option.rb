require_relative '../../../cross_suite/hook_request_resource_extraction'
require_relative '../../../cross_suite/profile_metadata'
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

      def resources_by_type
        @resources_by_type ||= fhir_resources_by_type(must_support_requests)
      end

      def ig_version
        config.options[:ig_version]
      end

      def gather_unobserved
        config.options[:profiles].filter_map do |profile|
          metadata = self.class.metadata_for(ig_version, profile)
          title = self.class.title_for(metadata, profile)
          resources = resources_by_type[profile[:resource_type]] || []

          # `missing_must_support_elements` returns nil rather than the full list when handed no
          # resources, so an absent resource type has to be caught before calling it.
          next { kind: :unsupported_type, title:, resource_type: profile[:resource_type] } if resources.blank?

          missing = missing_must_support_elements(resources, nil, metadata:)
          missing = remove_must_support_false_positives(missing, resources, profile[:resource_type])
          next if missing.blank?

          { kind: :unobserved_elements, title:, resource_type: profile[:resource_type],
            count: resources.length, missing: }
        end
      end

      def remove_must_support_false_positives(missing, _resources, _resource_type)
        missing
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
        <<~SECTION.chomp
          Inferno did not observe any `#{entry[:resource_type]}` resources in the hook requests made by
          the client system, in either the hook `context` or the `prefetch`.

          Attest that the client system does **not** support the #{entry[:title]} request type -- it
          does not allow users to create or act on requests of this type, and therefore never includes
          them in CRD hook requests.
        SECTION
      end

      run do
        skip_if must_support_requests.blank?, 'No hook requests received.'

        unobserved = gather_unobserved
        log_info_messages(unobserved)
        pass 'All must support elements were observed.' if unobserved.blank?

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
