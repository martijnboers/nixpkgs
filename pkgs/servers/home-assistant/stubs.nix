{ lib
, buildPythonPackage
, fetchFromGitHub
, hatchling
, hatch-vcs
, home-assistant
, python
}:

buildPythonPackage rec {
  pname = "homeassistant-stubs";
  version = "2024.11.2";
  pyproject = true;

  disabled = python.version != home-assistant.python.version;

  src = fetchFromGitHub {
    owner = "KapJI";
    repo = "homeassistant-stubs";
    rev = "refs/tags/${version}";
    hash = "sha256-P9fhFl91IJyRCacJ5lDJu036hgzcNMCF7LO4Brv4P6c=";
  };

  build-system = [
    hatchling
    hatch-vcs
    home-assistant
  ];

  postPatch = ''
    # Relax constraint to year and month
    substituteInPlace pyproject.toml --replace-fail \
      'homeassistant==${version}' \
      'homeassistant~=${lib.versions.majorMinor home-assistant.version}'
  '';

  pythonImportsCheck = [
    "homeassistant-stubs"
  ];

  doCheck = false;

  meta = with lib; {
    description = "Typing stubs for Home Assistant Core";
    homepage = "https://github.com/KapJI/homeassistant-stubs";
    changelog = "https://github.com/KapJI/homeassistant-stubs/releases/tag/${version}";
    license = licenses.mit;
    maintainers = teams.home-assistant.members;
  };
}