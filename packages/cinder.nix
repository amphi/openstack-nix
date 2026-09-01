{
  castellan,
  cursive,
  keystoneauth1,
  keystonemiddleware,
  lib,
  os-brick,
  oslo-concurrency,
  oslo-config,
  oslo-context,
  oslo-db,
  oslo-log,
  oslo-messaging,
  oslo-middleware,
  oslo-policy,
  oslo-privsep,
  oslo-reports,
  oslo-rootwrap,
  oslo-serialization,
  oslo-service,
  oslo-upgradecheck,
  oslo-utils,
  oslo-versionedobjects,
  oslo-vmware,
  oslotest,
  osprofiler,
  python-glanceclient,
  python-keystoneclient,
  python-novaclient,
  python-openstackclient,
  python-swiftclient,
  python3Packages,
  qemu-utils,
  taskflow,
  tooz,
  writeScript,
  cinder-src,
}:
let
  inherit (python3Packages)
    boto3
    ddt
    distro
    eventlet
    google-api-python-client
    hacking
    httplib2
    moto
    paramiko
    pbr
    pycodestyle
    pymysql
    python-memcached
    rtslib-fb
    sqlalchemy-utils
    stestr
    tabulate
    tenacity
    testresources
    testscenarios
    zstd
    ;

  testExcludes = [
    "cinder.tests.unit.volume.drivers.datacore.test_datacore_api.DataCoreClientTestCase.*"
  ];

  excludeListFile = writeScript "test_excludes" (lib.concatStringsSep "\n" testExcludes);
in
python3Packages.buildPythonPackage rec {
  pname = "cinder";
  doCheck = false;

  pyproject = true;
  build-system = [
    python3Packages.pbr
    python3Packages.setuptools
  ];

  nativeBuildInputs = [
    pbr
  ];

  propagatedBuildInputs = [
    boto3
    castellan
    cursive
    ddt
    distro
    eventlet
    google-api-python-client
    httplib2
    keystoneauth1
    keystonemiddleware
    os-brick
    oslo-concurrency
    oslo-config
    oslo-context
    oslo-db
    oslo-log
    oslo-messaging
    oslo-middleware
    oslo-policy
    oslo-privsep
    oslo-reports
    oslo-rootwrap
    oslo-serialization
    oslo-service
    oslo-upgradecheck
    oslo-utils
    oslo-versionedobjects
    oslo-vmware
    osprofiler
    paramiko
    pymysql
    python-glanceclient
    python-keystoneclient
    python-memcached
    python-novaclient
    python-openstackclient
    python-swiftclient
    qemu-utils
    rtslib-fb
    tabulate
    taskflow
    tenacity
    tooz
    zstd
  ];

  nativeCheckInputs = [
    hacking
    moto
    oslotest
    pycodestyle
    qemu-utils
    sqlalchemy-utils
    stestr
    testresources
    testscenarios
  ];

  checkInputs = [
  ];

  checkPhase = ''
    stestr run --exclude-list ${excludeListFile}
  '';

  postInstall = ''
    install -Dm644 cinder/db/alembic.ini \
      "$out/${python3Packages.python.sitePackages}/cinder/db/alembic.ini"
  '';

  pythonImportsCheck = [
    "cinder.objects.snapshot"
    "cinder.objects.volume"
    "cinder.volume.drivers.nfs"
    "cinder.volume.volume_utils"
  ];

  src = cinder-src;
  version = "25.0.0-block-encryption-poc";
  PBR_VERSION = "25.0.0";
}
