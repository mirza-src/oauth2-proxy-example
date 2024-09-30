{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, devenv, flake-utils, ... } @ inputs: flake-utils.lib.eachDefaultSystem (system:
    let
      # Toggle between Nginx and Outh2-proxy for reverse proxy
      # If true, access application at http://localhost:${ports.nginx} e.g. http://localhost:8080
      # If false, access application at http://localhost:${ports.oauth2-proxy} e.g. http://localhost:4180
      enableNginx = false;
      ports = {
        frontend = 3000;
        backend = 4000;
        keycloak = 8000;
        oauth2-proxy = 4180;
        nginx = 8080;
      };

      pkgs = nixpkgs.legacyPackages.${system};
      nodejs = pkgs.nodejs-slim_20;
      keycloak = pkgs.keycloak;
    in
    {
      packages = {
        devenv-up = self.devShells.${system}.default.config.procfileScript;
      };
      devShells = {
        default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              # https://devenv.sh/basics/
              env = {
                KC_HOME_DIR = self.devShells.${system}.default.config.env.DEVENV_STATE + "/keycloak";
              };

              # https://devenv.sh/packages/
              packages = with pkgs; [
                git
                nest-cli
                hostctl
              ];

              # https://devenv.sh/languages/
              languages.javascript = {
                enable = true;
                package = nodejs;
                yarn = {
                  enable = true;
                  install.enable = true;
                };
              };

              # https://devenv.sh/processes/
              processes = {
                frontend = {
                  exec = "yarn --cwd frontend run dev";
                  process-compose = {
                    environment = [
                      "PORT=${toString ports.frontend}"
                      "NEXT_PUBLIC_LOGOUT_URL=http://localhost:${toString ports.oauth2-proxy}/oauth2/sign_out"
                    ];
                  };
                };
                backend = {
                  exec = "yarn --cwd backend run start:dev";
                  process-compose = {
                    environment = [
                      "PORT=${toString ports.backend}"
                      "API_PREFIX=/api"
                    ];
                  };
                };
                keycloak = {
                  exec = "${keycloak}/bin/kc.sh start --optimized";
                  process-compose = {
                    readiness_probe = {
                      http_get = {
                        scheme = "http";
                        host = "localhost:${toString ports.keycloak}";
                        path = "/auth/realms/master";
                      };
                      initial_delay_seconds = 5;
                      period_seconds = 3;
                      timeout_seconds = 3;
                      success_threshold = 1;
                      failure_threshold = 3;
                    };
                    environment = [
                      "KC_HTTP_PORT=${toString ports.keycloak}"
                      "KEYCLOAK_ADMIN=admin"
                      "KEYCLOAK_ADMIN_PASSWORD=admin"
                      "KC_HTTP_RELATIVE_PATH=/auth"
                      "KC_HOSTNAME=http://localhost:${toString ports.keycloak}/auth"
                      "KC_HTTP_ENABLED=true"
                      "KC_PROXY_HEADERS=xforwarded"
                      "KC_HEALTH_ENABLED=true"
                      "KC_HOSTNAME_DEBUG=true"
                    ];
                  };
                };
                oauth2-proxy = {
                  exec = "${pkgs.oauth2-proxy}/bin/oauth2-proxy --alpha-config ./oauth2-proxy.yaml";
                  process-compose = {
                    environment = [
                      "PORT=${toString ports.oauth2-proxy}"
                      "OIDC_ISSUER_URL=http://localhost:${toString ports.keycloak}/auth/realms/application"
                      "FRONTEND_URL=http://localhost:${toString ports.frontend}"
                      "BACKEND_URL=http://localhost:${toString ports.backend}"
                      "KEYCLOAK_URL=http://localhost:${toString ports.keycloak}"

                      "OAUTH2_PROXY_COOKIE_SECRET=OQINaROshtE9TcZkNAm-5Zs2Pv3xaWytBmc5W7sPX7w="
                      "OAUTH2_PROXY_EMAIL_DOMAINS=*"
                      "OAUTH2_PROXY_COOKIE_SECURE=false"
                      "OAUTH2_PROXY_COOKIE_EXPIRE=168h"
                      "OAUTH2_PROXY_COOKIE_REFRESH=1m" # https://github.com/oauth2-proxy/oauth2-proxy/issues/1285
                      "OAUTH2_PROXY_REDIRECT_URL=http://localhost:${toString (if enableNginx then ports.nginx else ports.oauth2-proxy) }/oauth2/callback"
                      "OAUTH2_PROXY_REVERSE_PROXY=true"
                      "OAUTH2_PROXY_SKIP_JWT_BEARER_TOKENS=true"
                      "OAUTH2_PROXY_SKIP_PROVIDER_BUTTON=true"
                      "OAUTH2_PROXY_API_ROUTES=/api"
                    ];
                    depends_on = {
                      keycloak = {
                        condition = "process_healthy";
                      };
                    };
                  };
                };
              };

              # https://devenv.sh/services/
              services.nginx = {
                enable = enableNginx;
                httpConfig = ''
                  # Only add authorization header if it is empty
                  map $http_authorization $authorization {
                      default $http_authorization;
                      "" $auth_response_header;
                  }

                  # Use local DNS resolver, not required with localhost
                  resolver 127.0.0.1;

                  # Adjust buffer settings to handle large cookies in headers
                  proxy_buffers 4 256k;
                  proxy_buffer_size 128k;
                  proxy_busy_buffers_size 256k;

                  # Nginx server that handles the oauth flow by sending auth_request to oauth2-proxy
                  server {
                      listen ${toString ports.nginx};

                      # By default, require authentication for all endpoints
                      auth_request /oauth2/auth;
                      # this gets called right after auth_request returns.
                      # it reads http "authorization" header from upstream (= auth_request)
                      # and sets it to the variable $auth_header
                      # https://stackoverflow.com/a/31485557/1759845
                      auth_request_set $auth_response_header $upstream_http_authorization;

                      # Common proxy settings, but doesn't seem to work correctly with auth_request
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Host $host:$server_port;
                      proxy_set_header X-Forwarded-Server $host;
                      proxy_set_header X-Forwarded-Port $server_port;
                      proxy_set_header X-Forwarded-Proto $scheme;
                      proxy_set_header X-Forwarded-Uri $request_uri;

                      # Create variables for dynamic DNS resolution, not required with localhost
                      set $oauth2 localhost:${toString ports.oauth2-proxy};
                      set $keycloak localhost:${toString ports.keycloak};
                      set $frontend localhost:${toString ports.frontend};
                      set $backend localhost:${toString ports.backend};

                      location /oauth2 {
                          # Disable authentication for this location
                          auth_request off;

                          proxy_pass http://localhost:${toString ports.oauth2-proxy};

                          # Common proxy settings
                          proxy_set_header Host $host;
                          proxy_set_header X-Real-IP $remote_addr;
                          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                          proxy_set_header X-Forwarded-Host $host:$server_port;
                          proxy_set_header X-Forwarded-Server $host;
                          proxy_set_header X-Forwarded-Port $server_port;
                          proxy_set_header X-Forwarded-Proto $scheme;
                          proxy_set_header X-Forwarded-Uri $request_uri;
                      }

                      location / {
                          proxy_pass http://localhost:${toString ports.frontend};

                          # Automatically add the Authorization header to the request
                          proxy_set_header Authorization $authorization;
                          # Start the oauth flow if the user is not authenticated
                          error_page 401 =403 http://localhost:${toString ports.oauth2-proxy}/oauth2/start?rd=$scheme://$host$request_uri;

                          # Common proxy settings
                          proxy_set_header Host $host;
                          proxy_set_header X-Real-IP $remote_addr;
                          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                          proxy_set_header X-Forwarded-Host $host:$server_port;
                          proxy_set_header X-Forwarded-Server $host;
                          proxy_set_header X-Forwarded-Port $server_port;
                          proxy_set_header X-Forwarded-Proto $scheme;
                          proxy_set_header X-Forwarded-Uri $request_uri;
                      }

                      # This provides access to the API without the need for bearer token in frontend
                      location /api {
                          proxy_pass http://localhost:${toString ports.backend};

                          # Automatically add the Authorization header to the request
                          proxy_set_header Authorization $authorization;

                          # Common proxy settings
                          proxy_set_header Host $host;
                          proxy_set_header X-Real-IP $remote_addr;
                          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                          proxy_set_header X-Forwarded-Host $host:$server_port;
                          proxy_set_header X-Forwarded-Server $host;
                          proxy_set_header X-Forwarded-Port $server_port;
                          proxy_set_header X-Forwarded-Proto $scheme;
                          proxy_set_header X-Forwarded-Uri $request_uri;
                      }

                      # This provides access to the keycloak without the need for bearer token in frontend
                      # Will only work for API calls, not for the UI (redirection)
                      location /iam/ {
                          # HACK: Nginx does not drop prefix if using dynamic DNS resolution i.e. $keycloak
                          proxy_pass http://localhost:${toString ports.keycloak}/auth/;

                          # Automatically add the Authorization header to the request
                          proxy_set_header Authorization $authorization;

                          # Common proxy settings
                          proxy_set_header Host $host;
                          proxy_set_header X-Real-IP $remote_addr;
                          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                          proxy_set_header X-Forwarded-Host $host:$server_port;
                          proxy_set_header X-Forwarded-Server $host;
                          proxy_set_header X-Forwarded-Port $server_port;
                          proxy_set_header X-Forwarded-Proto $scheme;
                          proxy_set_header X-Forwarded-Uri $request_uri;
                      }
                  }
                '';
              };

              hostsProfileName = "devenv-oauth2-proxy";
              # hosts = {
              #   "keycloak.localhost" = "127.0.0.1";
              # };

              # https://devenv.sh/scripts/
              scripts = {
                keycloak-import = {
                  description = "Import keycloak realm configurations";
                  exec = ''
                    ${keycloak}/bin/kc.sh import --optimized --dir ./keycloak
                  '';
                };
                keycloak-export = {
                  description = "Export keycloak realm configurations";
                  exec = ''
                    ${keycloak}/bin/kc.sh export --optimized --users realm_file --dir ./keycloak
                  '';
                };
              };

              # enterShell = ''
              #   echo "Entering shell"
              # '';

              # https://devenv.sh/tasks/
              # tasks = {
              #   "myproj:setup".exec = "mytool build";
              #   "devenv:enterShell".after = [ "myproj:setup" ];
              # };

              # https://devenv.sh/tests/
              # enterTest = ''
              #   echo "Running tests"
              # '';

              # https://devenv.sh/pre-commit-hooks/
              # pre-commit.hooks.shellcheck.enable = true;

              # See full reference at https://devenv.sh/reference/options/
            }
          ];
        };
      };
    }
  );
}
