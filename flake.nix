{
  description = "A Nix-flake-based C# development environment";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
  inputs.pre-commit-hooks = {
    url = "github:cachix/pre-commit-hooks.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    pre-commit-hooks,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f rec {
          pkgs = import nixpkgs {inherit system;};
          checks = pre-commit-hooks.lib.${system}.run {
            src = ./src;
            hooks = {
              dotnet-build = {
                enable = true;
                name = "dotnet build";
                entry = "${pkgs.dotnet-sdk_8}/bin/dotnet build ./src";
                always_run = true;
                pass_filenames = false;
                fail_fast = true;
              };
              dotnet-format-style = {
                enable = true;
                name = "dotnet-format";
                entry = "${pkgs.dotnet-sdk_8}/bin/dotnet format src style --include ";
                types_or = ["c#"];
              };
              dotnet-format-analyzers = {
                enable = true;
                name = "dotnet-format";
                entry = "${pkgs.dotnet-sdk_8}/bin/dotnet format src analyzers --include ";
                types_or = ["c#"];
              };
              csharpier = {
                enable = true;
                name = "csharpier";
                entry = "${pkgs.csharpier}/bin/dotnet-csharpier src";
              };
              ripsecrets = {
                enable = true;
                name = "ripsecrets";
                entry = "${pkgs.ripsecrets}/bin/ripsecrets --strict-ignore";
                require_serial = true;
                types = ["text"];
              };
              typos = {
                enable = true;
                settings.locale = "en-au";
              };
              dotnet-test = {
                enable = true;
                name = "dotnet test";
                entry = ''bash -c "${pkgs.dotnet-sdk_8}/bin/dotnet test **/*.sln" '';
                always_run = true;
                pass_filenames = false;
                stages = ["manual" "push"];
              };
            };
          };
        });
  in {
    devShells = forEachSupportedSystem ({
      pkgs,
      checks,
    }: {
      default = let
        dotnet-combined = with pkgs.dotnetCorePackages; combinePackages [sdk_6_0 sdk_8_0];
      in
        pkgs.mkShell {
          # inherit (checks) shellHook;
          DOTNET_CLI_TELEMETRY_OPTOUT = true;
          DOTNET_ROOT = "${dotnet-combined}";
          packages = with pkgs; [
            dotnet-combined
            # roslyn-ls
          ];
        };
    });
    # packages = forEachSupportedSystem ({pkgs, ...}: rec {
    #   default = pkgs.callPackage ./package.nix {};
    #   dockerImage = pkgs.dockerTools.buildLayeredImage {
    #     name = "moviehub";
    #     tag = "latest";
    #     contents = [default];
    #     config = {
    #       Entrypoint = ["${default}/bin/MovieHub.Api"];
    #       Env = [
    #         "ConnectionStrings__MovieHubDatabase=Data Source=/var/lib/moviehub/MovieHub.sqlite"
    #         "ConnectionStrings__Cache=/var/lib/moviehub/cache.sqlite"
    #       ];
    #       WorkingDir = "/var/lib/moviehub";
    #       Volumes = {
    #         "/var/lib/moviehub/MovieHub.sqlite" = {};
    #         "/var/lib/moviehub/cache.sqlite" = {};
    #       };
    #     };
    #   };
    # });
  };
}
