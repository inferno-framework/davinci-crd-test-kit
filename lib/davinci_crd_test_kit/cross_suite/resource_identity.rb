require 'uri'

module DaVinciCRDTestKit
  # Identifies the resources carried in a CDS Hooks request, and the references within them, by
  # absolute URL, so that a reference only resolves to the resource it actually names.
  #
  # A resource in a Bundle is identified by the entry's `fullUrl`. Any other resource, or an entry
  # without a `fullUrl`, is assumed to be a RESTful resource on the `fhirServer` of the request. A
  # relative reference is made absolute against the base of the resource that holds it, following
  # the FHIR rules for resolving references.
  module ResourceIdentity
    RELATIVE_REFERENCE_PATTERN = %r{\A[A-Z][A-Za-z]+/[A-Za-z0-9\-.]{1,64}\z}
    RESTFUL_URL_PATTERN = %r{\A(?i:https?)://\S+/([A-Z][A-Za-z]+)/([A-Za-z0-9\-.]{1,64})\z}
    # A URI scheme, as RFC 3986 defines it. Schemes are case-insensitive.
    SCHEME_PATTERN = /\A[a-z][a-z0-9+\-.]*:/i

    module_function

    # The request's FHIR server, without a trailing slash.
    def fhir_server_base(hook_request)
      hook_request['fhirServer'].to_s.chomp('/').presence if hook_request.is_a?(Hash)
    end

    # Yields the absolute URL identifying each resource in the request's context and prefetch,
    # along with the resource as given.
    def each_identified_resource(hook_request, &)
      each_identified_context_resource(hook_request, &)
      each_identified_prefetch_resource(hook_request, &)
    end

    def each_identified_context_resource(hook_request, &)
      each_identified_section_resource(hook_request, 'context', &)
    end

    def each_identified_prefetch_resource(hook_request, &)
      each_identified_section_resource(hook_request, 'prefetch', &)
    end

    # check in each key in this json object (as Hash) for FHIR resources
    def each_identified_section_resource(hook_request, section, &block)
      values = hook_request[section] if hook_request.is_a?(Hash)
      return unless values.is_a?(Hash)

      base = fhir_server_base(hook_request)
      values.each_value { |value| each_identified_within(value, base, nil, &block) }
    end

    def each_identified_within(value, base, full_url, &block)
      case value
      when Array then value.each { |element| each_identified_within(element, base, nil, &block) }
      when Hash then each_identified_within_hash(value, base, full_url, &block)
      end
    end

    def each_identified_within_hash(value, base, full_url, &block)
      return if value['resourceType'].blank?
      return each_identified_bundle_entry(value, base, &block) if value['resourceType'] == 'Bundle'

      identity = full_url.presence || restful_identity(value, base)
      block.call(identity, value) if identity.present?
    end

    def each_identified_bundle_entry(bundle, base, &block)
      Array(bundle['entry']).each do |entry|
        next unless entry.is_a?(Hash)

        each_identified_within(entry['resource'], base, entry['fullUrl'], &block)
      end
    end

    # The URL of a resource with the given type and id on the given server.
    def restful_identity(resource, base)
      type, id = type_and_id(resource)
      "#{base.chomp('/')}/#{type}/#{id}" if base.present? && type.present? && id.present?
    end

    def type_and_id(resource)
      if resource.is_a?(Hash)
        [resource['resourceType'], resource['id']]
      elsif resource.respond_to?(:resourceType)
        [resource.resourceType, resource.id]
      else
        []
      end
    end

    # The server a resource identified by the given URL is held on, or nil when the URL is not a
    # RESTful http(s) URL.
    def base_for(identity)
      return if identity.blank?

      parsed = URI.parse(identity)
      return unless ['http', 'https'].include?(parsed.scheme)

      identity.split('/')[0..-3].join('/')
    rescue URI::InvalidURIError
      nil
    end

    # The absolute form of a literal reference held by a resource on the given base server: an
    # absolute URL as given, a relative `Type/id` reference appended to the base. nil for a
    # contained reference, or one in neither form.
    def absolute_reference(reference, base)
      return if reference.blank? || reference.start_with?('#')
      return reference if absolute_url?(reference)

      "#{base.chomp('/')}/#{reference}" if base.present? && reference.match?(RELATIVE_REFERENCE_PATTERN)
    end

    # Whether the reference is an absolute URL rather than one relative to a base. Decided by the
    # scheme alone, so that a reference naming its own scheme is never taken to be on the request's
    # FHIR server, even when it is not otherwise a valid URL.
    def absolute_url?(reference)
      reference.to_s.match?(SCHEME_PATTERN)
    end

    # Whether the URL is a RESTful http(s) URL to a single resource, and so can be read.
    def readable?(url)
      url.to_s.match?(RESTFUL_URL_PATTERN)
    end

    # Whether a resource read from the given URL is the resource that URL names.
    def names?(url, resource)
      type, id = url.to_s.match(RESTFUL_URL_PATTERN)&.captures
      type.present? && type_and_id(resource) == [type, id]
    end

    def on_server?(url, base)
      relative_to(url, base).present?
    end

    # The part of an absolute URL that follows the given base, or nil when the URL is not on that
    # base. The scheme and host are compared ignoring case, and a default port matches an omitted
    # one, since RFC 3986 treats those forms as the same server. The path is case-sensitive.
    def relative_to(url, base)
      return if base.blank? || !absolute_url?(url)

      uri = URI.parse(url.to_s)
      base_uri = URI.parse(base.to_s)
      return unless same_server?(uri, base_uri)

      base_path = "#{base_uri.path.chomp('/')}/"
      return unless uri.path.start_with?(base_path)

      relative = uri.path.delete_prefix(base_path)
      uri.query.nil? ? relative : "#{relative}?#{uri.query}"
    rescue URI::InvalidURIError
      nil
    end

    def same_server?(uri, other_uri)
      uri.host.present? &&
        [uri.scheme, uri.host.downcase, uri.port] == [other_uri.scheme, other_uri.host&.downcase, other_uri.port]
    end
  end
end
