{
  lib,
  buildPythonPackage,
  camel-converter,
  fetchFromGitHub,
  pythonOlder,
  setuptools,
  requests,
}:

buildPythonPackage rec {
  pname = "meilisearch";
  version = "0.31.6";
  pyproject = true;

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "meilisearch";
    repo = "meilisearch-python";
    rev = "refs/tags/v${version}";
    hash = "sha256-YMKspKryhcxecIDLg3PiKHJoRtQBsIi8N//ZtAMBvMg=";
  };

  build-system = [ setuptools ];

  dependencies = [
    camel-converter
    requests
  ] ++ camel-converter.optional-dependencies.pydantic;

  pythonImportsCheck = [ "meilisearch" ];

  # Tests spin up a local server and are not mocking the requests
  doCheck = false;

  meta = with lib; {
    description = "Client for the Meilisearch API";
    homepage = "https://github.com/meilisearch/meilisearch-python";
    changelog = "https://github.com/meilisearch/meilisearch-python/releases/tag/v${version}";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ fab ];
  };
}