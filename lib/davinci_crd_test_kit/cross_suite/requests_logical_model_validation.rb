module DaVinciCRDTestKit
  module RequestsLogicalModelValidation
    CRD_CDS_HOOK_REQUEST_MODEL_URL = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksRequest'

    def validate_request_against_logical_model(request_body, request_index, ig_version)
      conforms_to_logical_model?(request_body, "#{CRD_CDS_HOOK_REQUEST_MODEL_URL}|#{ig_version}",
                                 message_prefix: "(Request #{request_index + 1}) ")
    end
  end
end
