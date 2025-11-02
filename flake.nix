{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    mixos = {
      url = "github:jmbaur/mixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-linux"
        "x86_64-darwin"
      ];

      imports = [
        inputs.git-hooks-nix.flakeModule
        inputs.treefmt-nix.flakeModule
      ];

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config =
              { pkgs }:
              {
                allowlistedLicenses = [ pkgs.lib.licenses.bsl11 ];
              };
          };

          devShells.default = pkgs.mkShell {
            packages = [ (pkgs.terraform.withPlugins (ps: with ps; [ hashicorp_azurerm ])) ];
          };

          pre-commit.settings.hooks = {
            # Formatter checks
            treefmt = {
              enable = true;
              package = config.treefmt.build.wrapper;
            };

            # Nix checks
            deadnix.enable = true;
            nil.enable = true;
            statix.enable = true;
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              # Markdown
              mdformat.enable = true;

              # Nix
              nixfmt = {
                enable = true;
                package = pkgs.nixfmt-rfc-style;
              };

              # Shell
              shellcheck.enable = true;
              shfmt.enable = true;
            };
          };
        };

      flake.mixosConfigurations.remote-builder = inputs.mixos.lib.mixosSystem {
        modules = [
          {
            nixpkgs = {
              inherit (inputs) nixpkgs;
              buildPlatform = "x86_64-linux";
              hostPlatform = "x86_64-linux";
            };
          }
          ./mixos-remote-builder.nix
        ];
      };
    };
}
