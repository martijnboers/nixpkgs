{
  lib,
  stdenv,
  aiohttp,
  async-timeout,
  buildPythonPackage,
  click,
  construct,
  dacite,
  fetchFromGitHub,
  paho-mqtt,
  poetry-core,
  pycryptodome,
  pycryptodomex,
  pytest-asyncio,
  pytestCheckHook,
  pythonOlder,
}:

buildPythonPackage rec {
  pname = "python-roborock";
  version = "2.7.2";
  pyproject = true;

  disabled = pythonOlder "3.10";

  src = fetchFromGitHub {
    owner = "humbertogontijo";
    repo = "python-roborock";
    rev = "refs/tags/v${version}";
    hash = "sha256-sPG3AqVrv+BiB+copgaghWDT/Rb/WU0R+Y8Z2J6l+7E=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail "poetry-core==1.8.0" "poetry-core"
  '';

  pythonRelaxDeps = [ "pycryptodome" ];

  build-system = [ poetry-core ];


  propagatedBuildInputs = [
    aiohttp
    async-timeout
    click
    construct
    dacite
    paho-mqtt
    pycryptodome
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [ pycryptodomex ];

  nativeCheckInputs = [
    pytest-asyncio
    pytestCheckHook
  ];

  pythonImportsCheck = [ "roborock" ];

  meta = with lib; {
    description = "Python library & console tool for controlling Roborock vacuum";
    homepage = "https://github.com/humbertogontijo/python-roborock";
    changelog = "https://github.com/humbertogontijo/python-roborock/blob/v${version}/CHANGELOG.md";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ fab ];
    mainProgram = "roborock";
  };
}