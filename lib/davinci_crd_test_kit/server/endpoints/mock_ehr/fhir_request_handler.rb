require 'securerandom'

module DaVinciCRDTestKit
  module MockEHR
    module FHIRRequestHandler
      # ---------------------------------------------------------------------------
      # Session Matching
      # ---------------------------------------------------------------------------

      def test_run_identifier
        token_to_session_id(request.headers['authorization']&.delete_prefix('Bearer '))
      end

      def token_to_session_id(token_to_decode)
        JSON.parse(Base64.urlsafe_decode64(token_to_decode))&.dig('session_id')
      rescue JSON::ParserError, ArgumentError
        nil
      end

      def self.session_id_to_token(session_id, exp_min = 5)
        token_structure = {
          session_id:,
          expiration: exp_min.minutes.from_now.to_i,
          nonce: SecureRandom.hex(8)
        }.to_json

        Base64.urlsafe_encode64(token_structure, padding: false)
      end

      # ---------------------------------------------------------------------------
      # Response Generation
      # ---------------------------------------------------------------------------

      def prepare_response
        response.format = 'application/fhir+json'
        response.headers['Access-Control-Allow-Origin'] = '*'
      end

      def error_body(severity, code, text)
        FHIR::OperationOutcome.new(
          issue: FHIR::OperationOutcome::Issue.new(severity:, code:,
                                                   details: FHIR::CodeableConcept.new(
                                                     text:
                                                   ))
        ).to_json
      end

      def return_unhandled_error(error)
        logger.error("FHIR #{interaction_type} error: #{error.full_message}")
        response.status = 500
        response.body = error_body('error', 'processing', error.message)
      end

      def interaction_type
        case request.env['REQUEST_METHOD']
        when 'GET'
          if resource_id.present?
            'Read'
          else
            'Search'
          end
        when 'POST'
          if request.env['PATH_INFO'].ends_with?('_search')
            'Search'
          else
            'Create'
          end
        when 'PUT'
          'Update'
        when 'DELETE'
          'Delete'
        end
      end

      # ---------------------------------------------------------------------------
      # Request Resource Type
      # ---------------------------------------------------------------------------

      def resource_type
        request.params[:resource_type]
      end

      def resource_type_present?
        return true if resource_type.present?

        response.status = 400
        response.body = error_body('error', 'required', 'No recognized resource type in URL')
        false
      end

      # ---------------------------------------------------------------------------
      # Request Resource Id
      # ---------------------------------------------------------------------------

      def resource_id
        request.params[:resource_id]
      end

      def resource_id_present?
        return true if resource_id.present?

        response.status = 400
        response.body = error_body('error', 'required', 'No recognized resource id in URL')
        false
      end

      # ---------------------------------------------------------------------------
      # Request Provided Resource (body)
      # ---------------------------------------------------------------------------

      def provided_resource
        @provided_resource ||= begin
          FHIR.from_contents(request.body.read)
        rescue StandardError
          nil
        end
      end

      def provided_resource_valid?
        if provided_resource.blank?
          response.status = 400
          response.body = error_body('error', 'structure', 'Invalid resource')
          return false
        end
        if provided_resource.resourceType != resource_type
          response.status = 400
          response.body =
            error_body('error', 'structure',
                       "Incorrect resource type: url indicates `#{resource_type}`, " \
                       "body contains `#{provided_resource.resourceType}`")
          return false
        end

        true
      end

      def return_provided_resource(status: 201)
        response.status = status if status.present?
        response.body = provided_resource.to_json
      end

      # ---------------------------------------------------------------------------
      # Reading
      # ---------------------------------------------------------------------------

      def target_resource_entry_index
        @target_resource_entry_index ||= mock_ehr_bundle.entry.find_index do |entry|
          entry.resource&.resourceType == resource_type && entry.resource&.id == resource_id
        end
      end

      def target_resource_entry
        @target_resource_entry ||=
          target_resource_entry_index.present? ? mock_ehr_bundle.entry[target_resource_entry_index] : nil
      end

      def target_resource
        @target_resource ||= target_resource_entry&.resource
      end

      def target_resource_present?
        if target_resource.blank?
          response.status = 404
          response.body = error_body('error', 'not-found',
                                     "No resource found with id #{resource_type}/#{resource_id}")
          return false
        end

        true
      end

      def return_target_resource(status: 200)
        response.status = status if status.present?
        response.body = target_resource.to_json
      end

      # ---------------------------------------------------------------------------
      # Create, Update
      # ---------------------------------------------------------------------------

      def assign_id_to_provided_resource(target_id: SecureRandom.uuid)
        provided_resource.id = target_id
      end

      def add_provided_resource_to_mock_ehr_bundle
        mock_ehr_bundle.entry << FHIR::Bundle::Entry.new({ resource: provided_resource })
        save_mock_ehr_bundle_to_input
      end

      def update_target_resource_in_mock_ehr_bundle
        if target_resource_entry.present?
          target_resource_entry.resource = provided_resource
          save_mock_ehr_bundle_to_input
          response.status = 200
        else
          add_provided_resource_to_mock_ehr_bundle
          response.status = 201
        end
      end

      # ---------------------------------------------------------------------------
      # Delete
      # ---------------------------------------------------------------------------

      def remove_target_resource_from_bundle
        return if target_resource_entry_index.nil?

        mock_ehr_bundle.entry.delete_at(target_resource_entry_index)
        save_mock_ehr_bundle_to_input
      end

      # ---------------------------------------------------------------------------
      # Mock Bundle Management
      # ---------------------------------------------------------------------------

      def mock_ehr_bundle
        @mock_ehr_bundle ||= begin
          bundle_json = Inferno::Repositories::SessionData.new.load(
            test_session_id: test_run.test_session_id,
            name: mock_ehr_bundle_input_name
          )
          FHIR.from_contents(bundle_json)
        rescue StandardError
          nil
        end
      end

      def mock_ehr_bundle_input_name
        return 'mock_ehr_bundle' unless test.config.options[:mock_ehr_bundle_input_name].present?

        test.config.options[:mock_ehr_bundle_input_name].to_s
      end

      def mock_ehr_bundle_present?
        if mock_ehr_bundle.blank?
          response.status = 400
          response.body = error_body('warning', 'required', "No Bundle provided in input #{mock_ehr_bundle_input_name}")
          return false
        end

        unless mock_ehr_bundle.is_a?(FHIR::Bundle)
          response.status = 400
          response.body = error_body('warning', 'required',
                                     "Input #{mock_ehr_bundle_input_name} does not contain a FHIR Bundle.")
          return false
        end

        true
      end

      def save_mock_ehr_bundle_to_input
        Inferno::Repositories::SessionData.new.save(
          test_session_id: test_run.test_session_id,
          name: mock_ehr_bundle_input_name,
          value: mock_ehr_bundle.to_json,
          type: test.available_inputs[mock_ehr_bundle_input_name.to_sym]&.type
        )
      end
    end
  end
end
