require_relative '../../../cross_suite/hook_request_resource_extraction'
require_relative '../../../cross_suite/must_support_references'
require_relative '../../../cross_suite/profile_metadata'
require_relative '../../../cross_suite/resource_identity'
require_relative '../../../cross_suite/tags'
require_relative 'request_must_support_scope'

module DaVinciCRDTestKit
  module V221
    # Checks that the references held in the must support Reference elements of a CRD profile resolve
    # to resources conforming to the profiles the element targets. A CRD server can only read the
    # CRD client's FHIR server while a hook request is in progress, so the referenced resources are
    # read by the hook request endpoint as each request arrives, and this test works from what was
    # read then.
    class RequestMustSupportReferenceResolution < Inferno::Test
      include HookRequestResourceExtraction
      include RequestMustSupportScope

      id :crd_v221_request_must_support_reference_resolution

      # The type matters: Inferno parses a checkbox input's stored JSON into an array, and without
      # it the raw string arrives instead.
      input :order_types_supported, optional: true, type: 'checkbox'
      input :supporting_types_supported, optional: true, type: 'checkbox'

      class << self
        def build_description(options)
          sections = options[:profiles].map do |profile|
            metadata = metadata_for(options[:ig_version], profile)
            "### #{title_for(metadata, profile)}\n\n#{reference_list(metadata)}"
          end

          "#{description_intro}\n\n#{sections.join("\n\n")}"
        end

        def reference_list(metadata)
          MustSupportReferences.reference_elements(metadata).map do |element|
            targets = Array(element[:target_profiles]).map { |target_profile| "`#{target_profile}`" }
            "- `#{element[:path]}`#{": #{targets.join(', ')}" if targets.present?}"
          end.join("\n")
        end

        def description_intro
          <<~INTRO
            The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3)
            that when a client "maintains a mustSupport data element and surfaces it to users, then it
            SHALL be exposed in their FHIR interface when the data exists and privacy constraints permit."
            For a must support Reference element, this means that the referenced resource can be
            retrieved and conforms to the profiles the element targets.

            During this test, Inferno will check that for each must support Reference element listed
            below that was populated with a literal reference, at least one of those references
            resolved to a resource conforming to each target profile listed for the element. Target
            profiles for resource types the tester indicated the CRD client does not support are not
            checked.

            A CRD server can only retrieve data from the CRD client's FHIR server while it is processing
            a hook request, so Inferno reads the referenced resources as each hook request arrives.
            Using the `fhirServer` and `fhirAuthorization` provided in the request, Inferno reads each
            resource referenced from a must support Reference element of a resource in the `context`
            or `prefetch`, and the resources referenced in turn from those it reads. References to
            resources on other servers are read from those servers without the access token, which
            is only for the `fhirServer`.

            Resources and references are matched by absolute URL. A resource in a Bundle is
            identified by the entry's `fullUrl`, and any other resource is assumed to be on the
            `fhirServer`. A relative reference is resolved against the server of the resource holding
            it. A reference resolves when it points to a contained resource, to a resource carried in
            the same hook request, or to a resource Inferno read while processing it.

            The test will skip if a must support Reference element was populated but none of its
            references resolved. Inferno will consider the same hook requests as the must support
            element tests: those made during the latest run of each `Hooks` subgroup and the
            `Additional Hook Invocations for Cross Hook Support Demonstration` group.
          INTRO
        end

        def metadata_for(ig_version, profile)
          ProfileMetadata.merged(ig_version, profile[:profile_keys])
        end

        def title_for(metadata, profile)
          profile[:title] || metadata.profile_name
        end
      end

      def ig_version
        config.options[:ig_version]
      end

      # Each must support Reference element paired with each of its target profiles, so that every
      # target has to be demonstrated. An element without target profiles only has to resolve.
      def reference_targets(metadata)
        MustSupportReferences.reference_elements(metadata).flat_map do |element|
          (element[:target_profiles].presence || [nil]).map do |target_profile|
            { path: element[:path], target_profile:, target_type: target_type(target_profile) }
          end
        end
      end

      def target_type(target_profile)
        return if target_profile.blank?

        ProfileMetadata.for_profile_url(ig_version, target_profile)&.resource
      end

      # For each hook request, its resources and every resource available to resolve references
      # made within it, all identified by absolute URL (see ResourceIdentity).
      def hook_request_data
        @hook_request_data ||= must_support_requests.filter_map do |request|
          request_body = parse_request_body(request)
          next unless request_body.is_a?(Hash)

          fhir_server = ResourceIdentity.fhir_server_base(request_body)
          resources = request_fhir_resources(request_body)
          reads = reads_by_tag[TagMethods.hook_instance_data_fetch_tag(request_body['hookInstance'])]
          available = available_from_reads(reads, fhir_server)
          resources.each { |entry| available[entry[:identity]] = entry.merge(source: 'the hook request') }
          { fhir_server:, resources:, available: }
        end
      end

      def request_fhir_resources(request_body)
        resources = []
        ResourceIdentity.each_identified_resource(request_body) do |identity, raw_resource|
          resource = to_fhir_resource(raw_resource)
          resources << { identity:, resource: } if resource.present?
        end
        resources.uniq { |entry| entry[:identity] }
      end

      # The data fetches made while processing every hook request, keyed by the hook instance tag
      # that ties them to the request they were made for.
      def reads_by_tag
        @reads_by_tag ||=
          Inferno::Repositories::Requests.new.tagged_requests(test_session_id, [DATA_FETCH_TAG])
            .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |request, by_tag|
              request.tags.select { |tag| tag.start_with?(HOOK_INSTANCE_DATA_FETCH_TAG_PREFIX) }
                .each { |tag| by_tag[tag] << request }
            end
      end

      def available_from_reads(reads, fhir_server)
        reads.each_with_object({}) do |read, available|
          source = if ResourceIdentity.on_server?(read.url, fhir_server)
                     'a read made while processing the hook request'
                   else
                     'a read made from its server without the access token'
                   end
          identified_read_resources(read, fhir_server).each do |identity, resource|
            available[identity] ||= { identity:, resource:, source: }
          end
        end
      end

      # A read resource is identified by the URL it was read from, and only counts when it is the
      # resource that URL names. Search results are identified as entries in any other Bundle.
      def identified_read_resources(read, fhir_server)
        return [] unless read.status.to_s.start_with?('2')

        resource = FHIR.from_contents(read.response_body.to_s)
        return bundle_identified_resources(resource, fhir_server) if resource.is_a?(FHIR::Bundle)

        ResourceIdentity.names?(read.url, resource) ? [[read.url, resource]] : []
      rescue JSON::ParserError
        []
      end

      def bundle_identified_resources(bundle, fhir_server)
        identified = []
        ResourceIdentity.each_identified_within(JSON.parse(bundle.to_json), fhir_server, nil) do |identity, raw|
          identified << [identity, to_fhir_resource(raw)]
        end
        identified
      end

      # The resource a reference resolved to and where it came from, or why it did not resolve.
      def resolve(reference, entry, request_data)
        return resolve_contained(reference, entry[:resource]) if reference.reference.start_with?('#')

        base = ResourceIdentity.base_for(entry[:identity]) || request_data[:fhir_server]
        url = ResourceIdentity.absolute_reference(reference.reference, base)
        if url.blank?
          return { failure: 'it is neither a `Type/id` reference nor an absolute URL, so Inferno could not ' \
                            'resolve it' }
        end

        request_data[:available][url]&.merge(url:) || { url:, failure: unresolved_reason(url, request_data) }
      end

      def unresolved_reason(url, request_data)
        if ResourceIdentity.on_server?(url, request_data[:fhir_server])
          'it was neither carried in the hook request nor successfully read while processing it'
        else
          "it points to a server other than the hook request's `fhirServer` " \
            "(#{request_data[:fhir_server].presence || 'not provided'}), and was neither carried in the hook " \
            'request nor read from there without the access token while processing it'
        end
      end

      def resolve_contained(reference, resource)
        contained_id = reference.reference.delete_prefix('#')
        return { resource:, source: 'the referencing resource itself' } if contained_id.blank?

        contained = Array(resource.contained).find { |one| one.id == contained_id }
        return { resource: contained, source: 'a contained resource' } if contained.present?

        { failure: "no contained resource has the id `#{contained_id}`" }
      end

      # Each reference found at the path across every hook request, with what it resolved to.
      def reference_attempts(navigator, resource_type, path)
        hook_request_data.flat_map do |request_data|
          request_data[:resources].select { |entry| entry[:resource].resourceType == resource_type }
            .flat_map do |entry|
              navigator.literal_references(entry[:resource], path).map do |reference|
                resolve(reference, entry, request_data).merge(reference: reference.reference)
              end
            end
        end
      end

      def conforms?(resource, target)
        return false if target[:target_type].present? && resource.resourceType != target[:target_type]
        return true if target[:target_profile].blank?

        resource_is_valid?(resource:, profile_url: target[:target_profile], add_messages_to_runnable: false)
      end

      # The validator is the slow part, so each distinct resolved resource is checked once and the
      # search stops at the first that conforms.
      def target_resolved?(attempts, target)
        attempts.filter_map { |attempt| attempt[:resource] }.uniq(&:to_json)
          .any? { |resource| conforms?(resource, target) }
      end

      def unresolved_targets(profile)
        metadata = self.class.metadata_for(ig_version, profile)
        navigator = MustSupportReferences::Navigator.new(metadata)
        title = self.class.title_for(metadata, profile)

        reference_targets(metadata).filter_map do |target|
          next if target[:target_type].present? && declared_unsupported?(target[:target_type])

          attempts = reference_attempts(navigator, profile[:resource_type], target[:path])
          next if attempts.blank? || target_resolved?(attempts, target)

          target.merge(title:, attempts:)
        end
      end

      def observed_types
        hook_request_data.flat_map do |request_data|
          request_data[:resources].map { |entry| entry[:resource].resourceType }
        end.uniq
      end

      def target_description(target)
        "`#{target[:path]}`#{" (#{target[:target_profile]})" if target[:target_profile].present?}"
      end

      def log_unresolved(unresolved)
        unresolved.each do |target|
          outcomes = target[:attempts].map { |attempt| attempt_outcome(attempt, target) }.uniq
          add_message('info',
                      "No reference within #{target[:title]} element #{target_description(target)} resolved " \
                      "to a conforming resource:\n\n#{outcomes.map { |outcome| "- #{outcome}" }.join("\n")}")
        end
      end

      # Only called for a target none of whose resolved resources conformed, so a resolved resource
      # either has the wrong type or failed validation against the target profile.
      def attempt_outcome(attempt, target)
        reason =
          if attempt[:failure].present?
            "not resolved: #{attempt[:failure]}"
          elsif target[:target_type].present? && attempt[:resource].resourceType != target[:target_type]
            "resolved from #{attempt[:source]}, but is a #{attempt[:resource].resourceType} rather than a " \
              "#{target[:target_type]}"
          else
            "resolved from #{attempt[:source]}, but does not conform to #{target[:target_profile]}"
          end

        "#{attempt_reference(attempt)} #{reason}"
      end

      # A relative reference is shown with the absolute URL it was resolved as, so that it is clear
      # which server it was looked up on.
      def attempt_reference(attempt)
        return "`#{attempt[:reference]}`" if attempt[:url].blank? || attempt[:url] == attempt[:reference]

        "`#{attempt[:reference]}` (as `#{attempt[:url]}`)"
      end

      run do
        skip_if must_support_requests.blank?, 'No hook requests received.'

        resource_types = config.options[:profiles].map { |profile| profile[:resource_type] }
        unobserved_types = resource_types - observed_types
        pass_if unobserved_types == resource_types,
                "No instances of #{resource_types.uniq.to_sentence} observed, so there are no must support " \
                'references to check.'

        unresolved = config.options[:profiles].flat_map { |profile| unresolved_targets(profile) }
        log_unresolved(unresolved)

        skip_if unresolved.present?,
                'Could not resolve and validate any must support references for ' \
                "#{unresolved.map { |target| target_description(target) }.to_sentence}. See messages for details."

        pass 'At least one reference within each populated must support Reference element resolved to a ' \
             'conforming resource.'
      end
    end
  end
end
