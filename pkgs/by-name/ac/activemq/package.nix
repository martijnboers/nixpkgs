{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "6.1.3";
in
stdenvNoCC.mkDerivation {
  pname = "activemq";
  inherit version;

  src = fetchurl {
    url = "https://archive.apache.org/dist/activemq/${version}/apache-activemq-${version}-bin.tar.gz";
    hash = "sha256-ytFOgW6ZDxMScJ6/wij0KJXYxUxlLTzVbwtRRWNdx5Q=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    mv * $out/
    for j in $(find $out/lib -name "*.jar"); do
      cp="''${cp:+"$cp:"}$j";
    done
    echo "CLASSPATH=$cp" > $out/lib/classpath.env

    runHook postInstall
  '';

  meta = {
    homepage = "https://activemq.apache.org/";
    description = "Messaging and Integration Patterns server written in Java";
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    license = lib.licenses.asl20;
    mainProgram = "activemq";
    maintainers = [ lib.maintainers.anthonyroussel ];
    platforms = lib.platforms.unix;
  };
}