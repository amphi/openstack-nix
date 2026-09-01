{
  alembic,
  castellan,
  fetchPypi,
  keystonemiddleware,
  microversion-parse,
  oslo-config,
  oslo-context,
  oslo-db,
  oslo-i18n,
  oslo-log,
  oslo-messaging,
  oslo-middleware,
  oslo-policy,
  oslo-serialization,
  oslo-service,
  oslo-upgradecheck,
  oslo-utils,
  oslo-versionedobjects,
  oslotest,
  pycadf,
  python-keystoneclient,
  python3Packages,
  sqlalchemy,
}:
let
  inherit (python3Packages)
    cffi
    cryptography
    eventlet
    hacking
    jsonschema
    ldap3
    paste
    pastedeploy
    pbr
    pecan
    pycodestyle
    pymysql
    python-memcached
    stestr
    stevedore
    webob
    webtest
    ;

in
python3Packages.buildPythonPackage rec {
  pname = "barbican";
  version = "20.0.0";
  pyproject = true;
  doCheck = false;

  build-system = [
    python3Packages.pbr
    python3Packages.setuptools
  ];

  nativeBuildInputs = [
    pbr
  ];

  propagatedBuildInputs = [
    alembic
    castellan
    cffi
    cryptography
    eventlet
    jsonschema
    keystonemiddleware
    ldap3
    microversion-parse
    oslo-config
    oslo-context
    oslo-db
    oslo-i18n
    oslo-log
    oslo-messaging
    oslo-middleware
    oslo-policy
    oslo-serialization
    oslo-service
    oslo-upgradecheck
    oslo-utils
    oslo-versionedobjects
    paste
    pastedeploy
    pecan
    pycadf
    pymysql
    python-keystoneclient
    python-memcached
    sqlalchemy
    stevedore
    webob
  ];

  nativeCheckInputs = [
    hacking
    oslotest
    pycodestyle
    stestr
    webtest
  ];

  checkPhase = ''
    stestr run
  '';

  pythonImportsCheck = [
    "barbican.api.app"
    "barbican.cmd.worker"
  ];

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-pqUtjOMZ1Q5cNko+124d7Vob1vz2xf0wOV8Mudtjmqs=";
  };
}
