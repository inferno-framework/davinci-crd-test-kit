require 'inferno/dsl/must_support_metadata_extractor'

module DaVinciCRDTestKit
  module Generator
    # Extends the extractor inferno_core provides with the handling CRD's profiles need.
    class CRDMustSupportMetadataExtractor < Inferno::DSL::MustSupportMetadataExtractor
      def extract_required_binding_values(pattern_element, _metadata)
        Inferno::DSL::ValueExtractor.new(ig_resources, resource, profile_elements)
          .codings_from_value_set_binding(pattern_element)
          .presence || []
      end
    end
  end
end
