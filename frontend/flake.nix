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
      pkgs = nixpkgs.legacyPackages.${system};
      nodejs = pkgs.nodejs-slim_20;
      packageJson = builtins.fromJSON (builtins.readFile ./package.json);
    in
    {
      packages = rec {
        node-modules = pkgs.mkYarnModules {
          pname = packageJson.name;
          version = packageJson.version;
          packageJSON = ./package.json;
          yarnLock = if builtins.pathExists ./yarn.lock then ./yarn.lock else ../yarn.lock;
          nodejs = nodejs;
        };

        build = pkgs.stdenv.mkDerivation {
          name = packageJson.name;
          src = ./.;
          buildInputs = [ pkgs.yarn ];

          NODE_OPTIONS = "--max-old-space-size=4096";

          buildPhase = ''
            cp -r ${node-modules}/node_modules node_modules
            yarn build
          '';

          installPhase = ''
            mkdir -p $out/.next

            mv .next/standalone/* $out
            mv .next/standalone/.* $out
            mv .next/static $out/.next/
          '';
        };

        dockerImage = pkgs.dockerTools.streamLayeredImage {
          name = packageJson.name;
          tag = packageJson.version;
          config =
            let
              port = "80";
            in
            {
              Cmd = [ "${nodejs}/bin/node" "${build}/server.js" ];
              ExposedPorts = { "${port}/tcp" = { }; };
              Env = [
                "PORT=${port}"
                "HOSTNAME=0.0.0.0"
              ];
            };
        };

        default = build;

        devenv-up = self.devShells.${system}.default.config.procfileScript;
      };

      devShells = {
        default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              packages = with pkgs; [
                git
              ];

              languages.javascript = {
                enable = true;
                package = nodejs;
                yarn = {
                  enable = true;
                  install.enable = false;
                };
              };
            }
          ];
        };
      };
    }
  );
}
