{ lib, stdenv, fetchurl, autoreconfHook }:

stdenv.mkDerivation rec {
  pname = "chrpath";
  version = "0.17";

  src = fetchurl {
    url = "https://codeberg.org/pere/chrpath/archive/release-${version}.tar.gz";
    hash = "sha256-Sh2syR9OrxyMP3Z/2IHrH+OlCaINBii/l2DZCsEkvQw=";
  };

  nativeBuildInputs = [
    autoreconfHook
  ];

  meta = with lib; {
    description = "Command line tool to adjust the RPATH or RUNPATH of ELF binaries";
    mainProgram = "chrpath";
    longDescription = ''
      chrpath changes, lists or removes the rpath or runpath setting in a
      binary. The rpath, or runpath if it is present, is where the runtime
      linker should look for the libraries needed for a program.
    '';
    homepage = "https://codeberg.org/pere/chrpath";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = [ maintainers.bjornfor ];
  };
}