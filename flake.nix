{
  description = "Locate and track Apple Airtags with ease, regardless of the platform you are using.";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
      ];
      imports = [
        inputs.pre-commit-hooks.flakeModule
      ];

      perSystem =
        {
          config,
          pkgs,
          lib,
          system,
          ...
        }:

        let
          fenix = inputs.fenix.packages.${system};

          /*
            # https://github.com/nix-community/fenix/issues/123
            toolchain = fromToolchainFile {
              file = ./rust-toolchain.toml;
              sha256 = "sha256-X/4ZBHO3iW0fOenQ3foEvscgAPJYl2abspaBThDOukI=";
            };
          */

          toolchain =
            let
              toml = with builtins; (fromTOML (readFile ./rust-toolchain.toml)).toolchain;
              channel = toml.channel or "stable";
              profile = toml.profile or "default";
              targets = toml.targets or [ "x86_64-unknown-linux-gnu" ];
              components = toml.components or [ ];
            in
            with pkgs;
            pkgs.buildEnv {
              name = "toolchain";
              paths = [
                cargo-nextest
                cargo-ndk
                cargo-audit
                (fenix.combine (
                  [
                    fenix."${channel}"."${profile}Toolchain"
                    (fenix."${channel}".withComponents components)
                  ]
                  ++ map (target: fenix.targets.${target}.${channel}.rust-std) targets
                ))
              ];
            };

          android-studio = pkgs.android-studio.overrideAttrs (_: {
            propagatedBuildInputs = [ toolchain ];
            meta.license = with lib.licenses; [
              asl20 # any free license
            ];
          });

        in
        /*
          naersk' = naersk.lib.${system}.override {
            cargo = toolchain;
            rustc = toolchain;
          };
        */
        {
          devShells.default = pkgs.mkShell {
            packages = [
              toolchain
              android-studio
            ];

            shellHook = ''
              ${config.pre-commit.installationScript}
            '';
          };

          pre-commit = {
            check.enable = true;
            settings = {
              excludes = [
                "\.age$"
              ];

              hooks =
                let
                  cargo = "${toolchain}/bin/cargo";
                  mkCargoHook =
                    name: entry: additional:
                    {
                      inherit name;
                      enable = true;
                      entry = "${cargo} ${entry}";
                      types = [ "rust" ];
                    }
                    // additional;
                in
                {
                  cargo-clippy =
                    mkCargoHook "cargo-clippy"
                      "clippy --all-targets --all-features --fix --allow-staged -- -W clippy::all -W clippy::pedantic -W clippy::nursery -W clippy::cargo"
                      {
                        pass_filenames = false;
                      };
                  cargo-check = mkCargoHook "cargo-check" "check" {
                    pass_filenames = false;
                  };
                  cargo-audit = mkCargoHook "cargo-audit" "audit" {
                    pass_filenames = false;
                  };
                  cargo-fmt = mkCargoHook "cargo-fmt" "fmt -- --check" { };
                  cargo-nextest = mkCargoHook "cargo-nextest" "nextest run --all" { };

                  nixfmt-rfc-style.enable = true;
                  deadnix.enable = true;
                  statix.enable = true;

                  markdownlint = {
                    enable = true;
                    args = [ "-f" ];
                  };
                  commitizen.enable = true;
                  editorconfig-checker.enable = true;
                  typos.enable = true;
                };
            };
          };
          formatter = pkgs.nixfmt-rfc-style;
        };
    };
}
