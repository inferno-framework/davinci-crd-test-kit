require 'inferno'

module DaVinciCRDTestKit
  # Some CRD slices cannot be matched by the must support assessment as it stands, so they would
  # report as unobserved no matter what a client sent. Each override below covers one such case.
  module MustSupportSliceMatching
    def required_binding_value_match?(coding, values)
      whole_systems, enumerated = Array(values).partition do |value|
        value.is_a?(Hash) && value[:code].nil?
      end

      return true if whole_systems.any? { |value| value[:system] == coding.system }

      super(coding, enumerated)
    end

    def matching_slice?(slice, discriminator)
      return super unless discriminator[:type] == 'referenceTarget'

      reference_target?(slice, discriminator)
    end

    def find_slice(resource, path, discriminator)
      return super unless discriminator[:type] == 'referenceTarget'

      find_a_value_at(resource, path, recursive_segments: recursive_element_segments) do |element|
        reference_target?(element, discriminator)
      end
    end

    def reference_target?(element, discriminator)
      return false unless element.respond_to?(:actor)

      element.actor&.reference&.include?("#{discriminator[:resource_type]}/")
    end

    def matching_pattern_codeable_concept_slice?(slice, discriminator)
      return super if discriminator[:path].blank?

      codings = Array.wrap(slice.send(discriminator[:path])).flat_map { |value| Array.wrap(value.coding) }
      codings.any? { |coding| coding.code == discriminator[:code] && coding.system == discriminator[:system] }
    end
  end

  # The must support assessment runs inside this class rather than in the test, so the overrides
  # go on a CRD-only subclass instead of the inferno_core class, which other test kits share.
  class MustSupportLogic < Inferno::DSL::MustSupportAssessment::InternalMustSupportLogic
    include MustSupportSliceMatching
  end
end
