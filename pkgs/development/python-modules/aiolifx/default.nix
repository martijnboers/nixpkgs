{
  lib,
  async-timeout,
  bitstring,
  buildPythonPackage,
  click,
  fetchPypi,
  ifaddr,
  inquirerpy,
  pythonOlder,
  setuptools,
}:

buildPythonPackage rec {
  pname = "aiolifx";
  version = "1.1.1";
  pyproject = true;

  disabled = pythonOlder "3.7";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-oZpq2qUAtqDaRhgW9SbbQY9z81VqrqXhRLmpaPto9+A=";
  };

  build-system = [ setuptools ];

  dependencies = [
    async-timeout
    bitstring
    click
    ifaddr
    inquirerpy
  ];

  # Module has no tests
  doCheck = false;

  pythonImportsCheck = [ "aiolifx" ];

  meta = with lib; {
    description = "Module for local communication with LIFX devices over a LAN";
    homepage = "https://github.com/aiolifx/aiolifx";
    changelog = "https://github.com/aiolifx/aiolifx/releases/tag/${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ netixx ];
    mainProgram = "aiolifx";
  };
}