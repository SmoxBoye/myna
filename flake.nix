{
  description = "GIF picker and viewer for Hyprland";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      forAllSystems =
        fn: nixpkgs.lib.genAttrs nixpkgs.lib.platforms.linux (system: fn nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        myna = pkgs.callPackage ./nix {
          quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };
        default = myna;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = [
            inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
          ];

          shellHook = ''
            echo "------------------------------------------------"
            echo ":rocket: Quickshell Development Environment Active"
            echo "Source: ${inputs.quickshell.outPath}"
            echo "        To exit run \"exit\" or Ctrl-D"
            echo "------------------------------------------------"

            export QS_DEBUG=1
            alias qsr="quickshell -p ."
          '';
        };
      });

      homeManagerModules.default = import ./nix/home-manager.nix self;
    };
}
