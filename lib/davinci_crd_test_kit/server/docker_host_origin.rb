# frozen_string_literal: true

module DaVinciCRDTestKit
  # Docker dials the host as host.docker.internal. Capbluecross registers its
  # OAuth client at localhost on the same port, and uses these headers for that
  # lookup instead of the request URL.
  module DockerHostOrigin
    DOCKER_HOST = 'host.docker.internal'

    def docker_host_origin_headers(url)
      uri = URI.parse(url)
      return {} unless uri.host == DOCKER_HOST

      {
        'X-Forwarded-Host' => 'localhost',
        'X-Forwarded-Proto' => uri.scheme,
        'X-Forwarded-Port' => uri.port.to_s
      }
    end
  end
end
