{
  lib,
  aiohttp,
  buildPythonPackage,
  fetchFromGitHub,
  pytest-asyncio,
  pytestCheckHook,
  pythonOlder,
  setuptools,
}:

buildPythonPackage rec {
  pname = "py-synologydsm-api";
  version = "2.5.3";
  pyproject = true;

  disabled = pythonOlder "3.9";

  src = fetchFromGitHub {
    owner = "mib1185";
    repo = "py-synologydsm-api";
    rev = "refs/tags/v${version}";
    hash = "sha256-3DpgJqL8pSiAK/t/Qe2CxntQStTqDumkivhnPKHVlnE=";
  };

  build-system = [ setuptools ];

  dependencies = [ aiohttp ];

  nativeCheckInputs = [
    pytest-asyncio
    pytestCheckHook
  ];

  pythonImportsCheck = [ "synology_dsm" ];

  meta = with lib; {
    description = "Python API for Synology DSM";
    mainProgram = "synologydsm-api";
    homepage = "https://github.com/mib1185/py-synologydsm-api";
    changelog = "https://github.com/mib1185/py-synologydsm-api/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ uvnikita ];
  };
}