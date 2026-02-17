{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    quickshell.url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
    quickshell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      quickshell,
    }:
    let
      system = "x86_64-linux"; # or "aarch64-darwin", etc.
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          quickshell.packages.${system}.default
        ];
        shellHook = ''
          echo "------------------------------------------------"
          echo "🚀 Quickshell Development Environment Active"
          echo "Source: ${quickshell}"
          echo "        To exit run \"exit\" or Ctrl-D"
          echo "------------------------------------------------"

          # Example: Exporting an environment variable
          export QS_DEBUG=1

          # Example: Setting a custom alias for this project
          alias qsr="quickshell -p ."
        '';

      };
    };
}
