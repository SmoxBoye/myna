self:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  cfg = config.programs.myna;
in
{
  options.programs.myna = with lib; {
    enable = mkEnableOption "GIF picker and viewer for Hyprland";

    package = mkOption {
      type = types.package;
      default = self.packages.${system}.default;
      description = "The myna package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".config/myna/config.json".text = ''{"key": ""}'';
    home.file.".local/share/myna/favorites.json".text = ''{"favorites": []}'';
  };
}
