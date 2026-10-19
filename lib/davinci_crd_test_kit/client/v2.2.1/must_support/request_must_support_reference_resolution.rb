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

      # Where the pages of each IG version that target profiles come from are published, keyed by
      # the IG's canonical base and the profile version. The published paths do not follow a single
      # pattern (US Core 7.0.0 lives under STU7), so they are listed explicitly.
      PROFILE_PAGE_BASES = {
        ['http://hl7.org/fhir/us/davinci-crd', '2.2.1'] => 'https://hl7.org/fhir/us/davinci-crd/2.2.1/en',
        ['http://hl7.org/fhir/us/davinci-hrex', '1.2.0'] => 'https://hl7.org/fhir/us/davinci-hrex/1.2.0',
        ['http://hl7.org/fhir/us/core', '7.0.0'] => 'https://hl7.org/fhir/us/core/STU7'
      }.freeze

      # The type matters: Inferno parses a checkbox input's stored JSON into an array, and without
      # it the raw string arrives instead.
      input :order_types_supported, optional: true, type: 'checkbox'
      input :supporting_types_supported, optional: true, type: 'checkbox'

      class << self
        def build_description(options)
          sections = options[:profiles].map do |profile|
            metadata = metadata_for(options[:ig_version], profile)
            "### #{title_for(metadata, profile)}\n\n#{reference_list(options[:ig_version], metadata)}"
          end

          "#{description_intro}\n\n#{sections.join("\n\n")}"
        end

        # Each element, with the target profiles it must be demonstrated for as a sublist beneath it.
        def reference_list(ig_version, metadata)
          MustSupportReferences.reference_elements(metadata).map do |element|
            targets = Array(element[:target_profiles]).map do |target_profile|
              "  - #{target_profile_link(ig_version, target_profile)}"
            end
            ["- `#{element[:path]}`", *targets].join("\n")
          end.join("\n")
        end

        # The target profile's name, linked to its page in the published IG. A profile whose IG
        # version has no known page location is linked by its canonical URL instead.
        def target_profile_link(ig_version, target_profile)
          target_metadata = ProfileMetadata.for_profile_url(ig_version, target_profile)
          url = target_profile.split('|').first
          return "[#{url}](#{url})" if target_metadata.blank?

          base, id = url.split('/StructureDefinition/')
          page_base = PROFILE_PAGE_BASES[[base, target_metadata.profile_version]]
          page = page_base.present? ? "#{page_base}/StructureDefinition-#{id}.html" : url
          "[#{target_metadata.profile_name}](#{page})"
        end

        def description_intro
          <<~INTRO
            The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3)
            that when a client "maintains a mustSupport data element and surfaces it to users, then it
            SHALL be exposed in their FHIR interface when the data exists and privacy constraints permit."
            For a must support Reference element, this means that the referenced resource can be retrieved.
            Additionally, when some of the element's target profiles are themselves marked must support
            or the element has only one target profile, references to resources conforming to each of
            those profiles must be observed.

            During this test, Inferno will check that for each must support Reference element listed
            below that was populated, at least one of its references resolved to a resource
            conforming to each target profile listed for the element. Target profiles for resource types
            the tester indicated the CRD client does not support are not checked.

            Inferno obtains the resources needed to perform these checks during the hook request by
            performing a FHIR read of any references in must support elements that aren't already
            present in the `context` or `prefetch` fields of the hook request. See the wiki's
            documentation on [simulated CRD server behavior](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#prefetch-and-additional-data-retrieval)
            for details on how Inferno gets these resources.

            Inferno will consider the same hook requests as the must support
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
          resources.each { |entry| available[entry[:identity]] = entry }
          { request:, fhir_server:, resources:, available:, reads: }
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
          identified_read_resources(read, fhir_server).each do |identity, resource|
            available[identity] ||= { identity:, resource:, read: }
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

      # The resource a reference resolved to, if any, along with the read made for it, which is
      # attached as evidence for the result. Logical references cannot be resolved.
      def resolve(reference, entry, request_data)
        return {} if reference.reference.blank?
        return resolve_contained(reference, entry[:resource]) if reference.reference.start_with?('#')

        base = ResourceIdentity.base_for(entry[:identity]) || request_data[:fhir_server]
        url = ResourceIdentity.absolute_reference(reference.reference, base)
        return {} if url.blank?

        request_data[:available][url] || { read: request_data[:reads].find { |read| read.url == url } }
      end

      def resolve_contained(reference, resource)
        contained_id = reference.reference.delete_prefix('#')
        return { resource: } if contained_id.blank?

        { resource: Array(resource.contained).find { |one| one.id == contained_id } }.compact
      end

      # Each reference found at the path across every hook request, with what it resolved to.
      def reference_attempts(navigator, resource_type, path)
        hook_request_data.flat_map do |request_data|
          request_data[:resources].select { |entry| entry[:resource].resourceType == resource_type }
            .flat_map do |entry|
              navigator.references(entry[:resource], path).map do |reference|
                resolve(reference, entry, request_data)
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

        reference_targets(metadata).filter_map do |target|
          next if target[:target_type].present? && declared_unsupported?(target[:target_type])

          attempts = reference_attempts(navigator, profile[:resource_type], target[:path])
          consulted_reads.concat(attempts.filter_map { |attempt| attempt[:read] })
          next if attempts.blank? || target_resolved?(attempts, target)

          target
        end
      end

      def relevant_requests
        hook_request_data.filter_map do |request_data|
          carried = request_data[:resources].any? do |entry|
            profile_resource_types.include?(entry[:resource].resourceType)
          end
          request_data[:request] if carried
        end
      end

      # The reads that references from the resource type under test resolved to or failed on, which
      # are attached alongside the hook requests as the evidence for the result.
      def consulted_reads
        @consulted_reads ||= []
      end

      def observed_types
        hook_request_data.flat_map do |request_data|
          request_data[:resources].map { |entry| entry[:resource].resourceType }
        end.uniq
      end

      def target_description(target)
        return "`#{target[:path]}`" if target[:target_profile].blank?

        "`#{target[:path]}` using profile #{target_profile_link(target[:target_profile])}"
      end

      def target_profile_link(target_profile)
        self.class.target_profile_link(ig_version, target_profile)
      end

      run do
        skip_if must_support_requests.blank?, 'No hook requests received.'
        associate_requests(relevant_requests)

        resource_types = profile_resource_types
        unobserved_types = resource_types - observed_types
        pass_if unobserved_types == resource_types,
                "No instances of #{resource_types.uniq.to_sentence} observed, so there are no must support " \
                'references to check.'

        unresolved = config.options[:profiles].flat_map { |profile| unresolved_targets(profile) }
        requests.concat(consulted_reads.uniq(&:id))

        skip_if unresolved.present?,
                'Could not resolve and validate any must support references for ' \
                "#{unresolved.map { |target| target_description(target) }.to_sentence}."

        pass 'At least one reference within each populated must support Reference element resolved to a ' \
             'conforming resource.'
      end
    end
  end
end
