{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "gcov2lcov";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "jandelgado";
    repo = "gcov2lcov";
    rev = "v${version}";
    hash = "sha256-E8TPxaKJTd+5OP9e5S1FD5aZP42nJvjiqqNs4xP9gm4=";
  };

  vendorHash = "sha256-/2OIBWXbNch6lmw0C1jkyJfNefJXOVG9/jNW8CYHTsc=";

  ldflags = [ "-s" "-w" ];

  # Some checks depend on looking up vcs root
  checkPhase = false;

  meta = with lib; {
    description = "Convert go coverage files to lcov format";
    mainProgram = "gcov2lcov";
    homepage = "https://github.com/jandelgado/gcov2lcov";
    changelog = "https://github.com/jandelgado/gcov2lcov/blob/${src.rev}/CHANGELOG.md";
    license = licenses.mit;
    maintainers = with maintainers; [ meain ];
  };
}