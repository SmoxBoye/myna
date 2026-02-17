{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  bash,
}:

stdenvNoCC.mkDerivation {
  pname = "myna";
  version = "0.1.0";
  src = ./..;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/quickshell/plugins/myna $out/bin

    cp shell.qml $out/share/quickshell/plugins/myna/

    makeWrapper ${quickshell}/bin/qs $out/bin/myna \
      --add-flags "-p $out/share/quickshell/plugins/myna" \

    runHook postInstall
  '';

  meta = {
    description = "GIF picker and viewer for Hyprland";
    license = lib.licenses.mit;
    mainProgram = "myna";
  };
}
