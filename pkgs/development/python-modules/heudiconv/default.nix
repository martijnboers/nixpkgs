{
  lib,
  buildPythonPackage,
  datalad,
  dcm2niix,
  dcmstack,
  etelemetry,
  fetchPypi,
  filelock,
  git,
  nibabel,
  nipype,
  pydicom,
  pytestCheckHook,
  pythonOlder,
  setuptools,
  versioningit,
}:

buildPythonPackage rec {
  pname = "heudiconv";
  version = "1.2.0";
  pyproject = true;

  disabled = pythonOlder "3.8";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-qrDYl6hB8BPJz3VKl7jklDaAafsCf1M+3VgFbnGxCTU=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail "versioningit ~=" "versioningit >="
  '';

  build-system = [
    setuptools
    versioningit
  ];

  dependencies = [
    dcmstack
    etelemetry
    filelock
    nibabel
    nipype
    pydicom
  ];

  nativeCheckInputs = [
    datalad
    dcm2niix
    pytestCheckHook
    git
  ];

  preCheck = ''
    export HOME=$(mktemp -d)
  '';

  pythonImportsCheck = [ "heudiconv" ];

  disabledTests = [
    # No such file or directory
    "test_bvals_are_zero"
  ];

  meta = with lib; {
    description = "Flexible DICOM converter for organizing imaging data";
    homepage = "https://heudiconv.readthedocs.io";
    changelog = "https://github.com/nipy/heudiconv/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = with maintainers; [ bcdarwin ];
  };
}