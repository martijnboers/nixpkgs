{ lib, stdenv
, fetchFromGitHub
, autoreconfHook
, zlib
}:

stdenv.mkDerivation rec {
  pname = "advancecomp";
  version = "2.6";

  src = fetchFromGitHub {
    owner = "amadvance";
    repo = "advancecomp";
    rev = "v${version}";
    hash = "sha256-MwXdXT/ZEvTcYV4DjhCUFflrPKBFu0fk5PmaWt4MMOU=";
  };

  nativeBuildInputs = [ autoreconfHook ];
  buildInputs = [ zlib ];

  # autover.sh relies on 'git describe', which obviously doesn't work as we're not cloning
  # the full git repo. so we have to put the version number in `.version`, otherwise
  # the binaries get built reporting "none" as their version number.
  postPatch = ''
    echo "${version}" >.version
  '';

  meta = with lib; {
    description = "Set of tools to optimize deflate-compressed files";
    license = licenses.gpl3 ;
    maintainers = [ maintainers.raskin ];
    platforms = platforms.linux ++ platforms.darwin;
    homepage = "https://github.com/amadvance/advancecomp";
    changelog = "https://github.com/amadvance/advancecomp/blob/v${version}/HISTORY";
  };
}