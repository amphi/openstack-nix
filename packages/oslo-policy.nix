{
  fetchPypi,
  oslo-config,
  oslo-context,
  oslo-i18n,
  oslo-serialization,
  oslo-utils,
  oslotest,
  python3Packages,
  version ? "4.4.0",
  hash ? "sha256-LV9QyLq8vLgOHuQLKv+3y0ZGUP37HZZUoU3fWxk2mcU=",
}:
let
  inherit (python3Packages)
    coverage
    pyyaml
    requests
    requests-mock
    sphinx
    stestr
    stevedore
    ;
in
python3Packages.buildPythonPackage rec {
  pname = "oslo.policy";
  inherit version;

  pyproject = true;
  build-system = [
    python3Packages.pbr
    python3Packages.setuptools
  ];

  propagatedBuildInputs = [
    oslo-config
    oslo-context
    oslo-i18n
    oslo-serialization
    oslo-utils
    pyyaml
    requests
    stevedore
  ];

  nativeCheckInputs = [
    stestr
  ];

  checkInputs = [
    coverage
    oslotest
    requests-mock
    sphinx
  ];

  checkPhase = ''
    stestr run
  '';

  src = fetchPypi {
    inherit pname version;
    sha256 = hash;
  };
}
