require 'erb'

module DaVinciCRDTestKit
  RESUME_PASS_PATH = '/resume_pass'.freeze
  RESUME_FAIL_PATH = '/resume_fail'.freeze

  # base url, plus other shared ones such as resume urls
  # suite_id must be defined
  module BaseURLs
    def inferno_base_url
      @inferno_base_url ||= "#{Inferno::Application['base_url']}/custom/#{suite_id}"
    end

    def resume_pass_url
      @resume_pass_url ||= inferno_base_url + RESUME_PASS_PATH
    end

    def resume_fail_url
      @resume_fail_url ||= inferno_base_url + RESUME_FAIL_PATH
    end

    # tokens such as a JWT issuer may contain characters that are reserved in a query string
    def resume_pass_url_for(token)
      "#{resume_pass_url}?token=#{ERB::Util.url_encode(token)}"
    end

    def resume_fail_url_for(token, message: nil)
      url = "#{resume_fail_url}?token=#{ERB::Util.url_encode(token)}"
      message.present? ? "#{url}&message=#{ERB::Util.url_encode(message)}" : url
    end
  end
end
