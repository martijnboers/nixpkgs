{
  lib,
  stdenv,
  buildPythonPackage,
  fetchFromGitHub,

  # build-system
  setuptools,

  # dependencies
  portpicker,
  pyserial,
  pyyaml,
  timeout-decorator,
  typing-extensions,

  # tests
  procps,
  pytestCheckHook,
  pytz,
}:

buildPythonPackage rec {
  pname = "mobly";
  version = "1.12.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "google";
    repo = "mobly";
    rev = "refs/tags/${version}";
    hash = "sha256-77wZK5dqxXUkOgWE7NBpGJBbbtYYxRCJwPbtwLIX09I=";
  };

  build-system = [ setuptools ];

  dependencies = [
    portpicker
    pyserial
    pyyaml
    timeout-decorator
    typing-extensions
  ];

  nativeCheckInputs = [
    procps
    pytestCheckHook
    pytz
  ];

  disabledTests = lib.optionals stdenv.hostPlatform.isDarwin [
    # cannot access /usr/bin/pgrep from the sandbox
    "test_stop_standing_subproc"
    "test_stop_standing_subproc_and_descendants"
    "test_stop_standing_subproc_without_pipe"
  ];

  __darwinAllowLocalNetworking = true;

  meta = with lib; {
    changelog = "https://github.com/google/mobly/blob/${src.rev}/CHANGELOG.md";
    description = "Automation framework for special end-to-end test cases";
    homepage = "https://github.com/google/mobly";
    license = licenses.asl20;
    maintainers = with maintainers; [ hexa ];
  };
}