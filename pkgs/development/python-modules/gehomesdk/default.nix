{
  lib,
  aiohttp,
  bidict,
  buildPythonPackage,
  fetchPypi,
  humanize,
  lxml,
  pythonOlder,
  requests,
  setuptools,
  slixmpp,
  websockets,
}:

buildPythonPackage rec {
  pname = "gehomesdk";
  version = "0.5.29";
  pyproject = true;

  disabled = pythonOlder "3.9";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-sV5V+D0K02qmP9Z0WqYSvNsKTeXkdrY9CsRtvYq1JcE=";
  };

  build-system = [ setuptools ];

  dependencies = [
    aiohttp
    bidict
    humanize
    lxml
    requests
    slixmpp
    websockets
  ];

  # Tests are not shipped and source is not tagged
  # https://github.com/simbaja/gehome/issues/32
  doCheck = false;

  pythonImportsCheck = [ "gehomesdk" ];

  meta = with lib; {
    description = "Python SDK for GE smart appliances";
    homepage = "https://github.com/simbaja/gehome";
    changelog = "https://github.com/simbaja/gehome/blob/master/CHANGELOG.md";
    license = licenses.mit;
    maintainers = with maintainers; [ fab ];
    mainProgram = "gehome-appliance-data";
  };
}