{
  lib,
  buildPythonPackage,
  fetchPypi,
  llama-index-core,
  openai,
  poetry-core,
  pythonOlder,
}:

buildPythonPackage rec {
  pname = "llama-index-llms-openai";
  version = "0.2.16";
  pyproject = true;

  disabled = pythonOlder "3.8";

  src = fetchPypi {
    pname = "llama_index_llms_openai";
    inherit version;
    hash = "sha256-fGZt0nBWwnigef9F1T8fv8jtNjdkqnuu7i4D30f5Byo=";
  };

  pythonRemoveDeps = [
    # Circular dependency
    "llama-index-agent-openai"
  ];

  build-system = [ poetry-core ];

  dependencies = [
    llama-index-core
    openai
  ];

  # Tests are only available in the mono repo
  doCheck = false;

  pythonImportsCheck = [ "llama_index.llms.openai" ];

  meta = with lib; {
    description = "LlamaIndex LLMS Integration for OpenAI";
    homepage = "https://github.com/run-llama/llama_index/tree/main/llama-index-integrations/llms/llama-index-llms-openai";
    license = licenses.mit;
    maintainers = with maintainers; [ fab ];
  };
}