{
  lib,
  aiohttp,
  aioresponses,
  buildPythonPackage,
  fetchFromGitHub,
  mashumaro,
  poetry-core,
  pytest-aiohttp,
  pytest-cov-stub,
  pytestCheckHook,
  pythonOlder,
}:

buildPythonPackage rec {
  pname = "aioopenexchangerates";
  version = "0.6.10";
  pyproject = true;

  disabled = pythonOlder "3.11";

  src = fetchFromGitHub {
    owner = "MartinHjelmare";
    repo = "aioopenexchangerates";
    rev = "refs/tags/v${version}";
    hash = "sha256-GDAeBk4h0YLFbLSGEjomvzR94y0JGsRzd15J4sv6i6o=";
  };

  pythonRelaxDeps = [ "pydantic" ];

  build-system = [ poetry-core ];


  dependencies = [
    aiohttp
    mashumaro
  ];

  nativeCheckInputs = [
    aioresponses
    pytest-aiohttp
    pytest-cov-stub
    pytestCheckHook
  ];

  pythonImportsCheck = [ "aioopenexchangerates" ];

  meta = with lib; {
    description = "Library for the Openexchangerates API";
    homepage = "https://github.com/MartinHjelmare/aioopenexchangerates";
    changelog = "https://github.com/MartinHjelmare/aioopenexchangerates/blob/v${version}/CHANGELOG.md";
    license = with licenses; [ asl20 ];
    maintainers = with maintainers; [ fab ];
  };
}