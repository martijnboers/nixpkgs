{ stdenv
, lib
, fetchurl
, formats
, installShellFiles
, makeWrapper
, php
, phpIniFile ? null
}:

let
  version = "2.10.0";

  completion = fetchurl {
    url = "https://raw.githubusercontent.com/wp-cli/wp-cli/v${version}/utils/wp-completion.bash";
    hash = "sha256-RDygYQzK6NLWrOug7EqnkpuH7Wz1T2Zq/tGNZjoYo5U=";
  };

  ini =
    if phpIniFile == null
    then
      (formats.ini { }).generate "php.ini"
        {
          PHP.memory_limit = -1; # no limit as composer uses a lot of memory
          Phar."phar.readonly" = "Off";
        }
    else phpIniFile;

in
stdenv.mkDerivation (finalAttrs: {
  pname = "wp-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/wp-cli/wp-cli/releases/download/v${version}/wp-cli-${version}.phar";
    hash = "sha256-TGqTzsrn9JnKSB+nptbUKZyLkyFOXlMI4mdw2/02Md8=";
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ installShellFiles makeWrapper ];

  # Usually --set-default is used to set default environment variables.
  # But the value is wrapped in single-quotes so our variables would be used literally instead
  # of the expanded version. Thus we use --run instead.
  installPhase = ''
    runHook preInstall

    install -Dm444 ${finalAttrs.src} $out/share/wp-cli/wp-cli.phar
    install -Dm444 ${ini}            $out/etc/${ini.name}
    installShellCompletion --bash --name wp ${completion}

    makeWrapper ${lib.getExe php} $out/bin/${finalAttrs.meta.mainProgram} \
      --run 'export XDG_CACHE_HOME=''${XDG_CACHE_HOME-"$HOME/.cache"}' \
      --run 'export XDG_CONFIG_HOME=''${XDG_CONFIG_HOME-"$HOME/.config"}' \
      --run 'export XDG_DATA_HOME=''${XDG_DATA_HOME-"$HOME/.local/share"}' \
      --run 'export WP_CLI_CONFIG_PATH=''${WP_CLI_CONFIG_PATH-"$XDG_CONFIG_HOME/wp-cli"}' \
      --run 'export WP_CLI_PACKAGES_DIR=''${WP_CLI_PACKAGES_DIR-"$XDG_DATA_HOME/wp-cli"}' \
      --run 'export WP_CLI_CACHE_DIR=''${WP_CLI_CACHE_DIR-"$XDG_CACHE_HOME/wp-cli"}' \
      --add-flags "-c $out/etc/${ini.name}" \
      --add-flags "-f $out/share/wp-cli/wp-cli.phar" \
      --add-flags "--"

    runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    $out/bin/wp --info
  '';

  meta = with lib; {
    description = "Command line interface for WordPress";
    homepage = "https://wp-cli.org";
    changelog = "https://github.com/wp-cli/wp-cli/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ peterhoeg ];
    platforms = platforms.all;
    mainProgram = "wp";
  };
})