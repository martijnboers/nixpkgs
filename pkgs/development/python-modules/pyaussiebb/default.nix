{
  lib,
  aiohttp,
  buildPythonPackage,
  fetchFromGitHub,
  loguru,
  pydantic,
  poetry-core,
  pythonOlder,
  requests,
}:

buildPythonPackage rec {
  pname = "pyaussiebb";
  version = "0.1.4";
  pyproject = true;

  disabled = pythonOlder "3.9";

  src = fetchFromGitHub {
    owner = "yaleman";
    repo = "aussiebb";
    rev = "refs/tags/v${version}";
    hash = "sha256-IW2HraJbgvf0G1eRXNpnsPMWlLXi2P9DTyk+tG5Hc2U=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'requests = "^2.27.1"' 'requests = "*"'
  '';

  build-system = [ poetry-core ];

  dependencies = [
    aiohttp
    requests
    loguru
    pydantic
  ];

  # Tests require credentials and requests-testing
  doCheck = false;

  pythonImportsCheck = [ "aussiebb" ];

  meta = with lib; {
    description = "Module for interacting with the Aussie Broadband APIs";
    homepage = "https://github.com/yaleman/aussiebb";
    changelog = "https://github.com/yaleman/pyaussiebb/blob/v${version}/CHANGELOG.md";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ fab ];
  };
}