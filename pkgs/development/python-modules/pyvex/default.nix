{
  lib,
  stdenv,
  bitstring,
  buildPythonPackage,
  cffi,
  fetchPypi,
  pycparser,
  pythonOlder,
  setuptools,
}:

buildPythonPackage rec {
  pname = "pyvex";
  version = "9.2.128";
  pyproject = true;

  disabled = pythonOlder "3.11";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-ASo1hqxLsX4UkdhXLOArKBQdxws/maUjGb/HotAoxzw=";
  };

  build-system = [ setuptools ];

  dependencies = [
    bitstring
    cffi
    pycparser
  ];

  postPatch = lib.optionalString stdenv.hostPlatform.isDarwin ''
    substituteInPlace vex/Makefile-gcc \
      --replace-fail '/usr/bin/ar' 'ar'
  '';

  setupPyBuildFlags = lib.optionals stdenv.hostPlatform.isLinux [
    "--plat-name"
    "linux"
  ];

  preBuild = ''
    export CC=${stdenv.cc.targetPrefix}cc
    substituteInPlace pyvex_c/Makefile \
      --replace-fail 'AR=ar' 'AR=${stdenv.cc.targetPrefix}ar'
  '';

  # No tests are available on PyPI, GitHub release has tests
  # Switch to GitHub release after all angr parts are present
  doCheck = false;

  pythonImportsCheck = [ "pyvex" ];

  meta = with lib; {
    description = "Python interface to libVEX and VEX IR";
    homepage = "https://github.com/angr/pyvex";
    license = with licenses; [
      bsd2
      gpl3Plus
      lgpl3Plus
    ];
    maintainers = with maintainers; [ fab ];
  };
}