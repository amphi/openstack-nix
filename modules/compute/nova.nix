{
  nova,
  libvirt-chv,
  cloud-hypervisor,
  chv-ovmf,
  luks-vhost-blk,
}:
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.nova;
  nova_env = pkgs.python3.buildEnv.override {
    extraLibs = [ cfg.novaPackage ];
  };
  utils_env = pkgs.buildEnv {
    name = "utils";
    paths = [ nova_env ];
  };

  novaConf = pkgs.writeText "nova.conf" ''
    [DEFAULT]
    log_dir = /var/log/nova
    lock_path = /var/lock/nova
    state_path = /var/lib/nova
    rootwrap_config = ${rootwrapConf}
    compute_driver = libvirt.LibvirtDriver
    my_ip = ${cfg.myIp}
    transport_url = rabbit://openstack:openstack@controller

    [api]
    auth_strategy = keystone

    [api_database]
    connection = sqlite:////var/lib/nova/nova_api.sqlite

    [database]
    connection = sqlite:////var/lib/nova/nova.sqlite

    [glance]
    api_servers = http://controller:9292

    [keystone_authtoken]
    www_authenticate_uri = http://controller:5000/
    auth_url = http://controller:5000/
    memcached_servers = controller:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = nova
    password = nova

    [libvirt]
    virt_type = ch
    connection_uri = ch:///system
    images_type = raw

    [neutron]
    auth_url = http://controller:5000
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    region_name = RegionOne
    project_name = service
    username = neutron
    password = neutron

    [os_vif_ovs]
    ovsdb_connection = unix:/run/openvswitch/db.sock

    [oslo_concurrency]
    lock_path = /var/lib/nova/tmp

    [placement]
    region_name = RegionOne
    project_domain_name = Default
    project_name = service
    auth_type = password
    user_domain_name = Default
    auth_url = http://controller:5000/v3
    username = placement
    password = placement

    [service_user]
    send_service_user_token = true
    auth_url = http://controller:5000/
    auth_strategy = keystone
    auth_type = password
    project_domain_name = Default
    project_name = service
    user_domain_name = Default
    username = nova
    password = nova

    [serial_console]
    enabled = false

    [vnc]
    enabled = true
    server_listen = 0.0.0.0
    server_proxyclient_address = $my_ip
    novncproxy_base_url = http://127.0.0.1:6080/vnc_lite.html

    [cells]
    enable = False

    [os_region_name]
    openstack =

    [cinder]
    os_region_name = RegionOne

    [key_manager]
    backend = barbican

    [barbican]
    auth_endpoint = http://controller:5000/v3
    barbican_endpoint = http://controller:9311
    barbican_region_name = RegionOne
    barbican_endpoint_type = internal
  '';

  rootwrapConf = pkgs.callPackage ../../lib/rootwrap-conf.nix {
    package = nova_env;
    filterPath = "/etc/nova/rootwrap.d";
    inherit utils_env;
  };
in
{
  options.nova = {
    enable = mkEnableOption "Enable OpenStack Nova." // {
      default = true;
    };
    myIp = mkOption {
      default = "10.0.0.39";
      type = types.str;
      description = "Management address advertised by nova-compute.";
    };
    config = mkOption {
      default = novaConf;
      description = ''
        The Nova config.
      '';
    };
    novaPackage = mkOption {
      default = nova;
      type = types.package;
      description = ''
        The OpenStack Nova package to use.
      '';
    };
    extraPkgs = mkOption {
      default = [ ];
      type = types.listOf types.package;
      description = ''
        Extra packages to be available in the PATH of the nova-compute service
        e.g. an additional hypervisor.
      '';
    };
  };

  config = mkIf cfg.enable {
    users.extraUsers.nova = {
      group = "nova";
      isSystemUser = true;
    };
    users.groups.nova = {
      name = "nova";
      members = [ "nova" ];
    };

    # Nova requires libvirtd and RabbitMQ.
    virtualisation.libvirtd = {
      enable = true;
      package = libvirt-chv;
    };

    boot.kernelModules = [
      "dm_crypt"
      "dm_mod"
      "loop"
    ];

    systemd.tmpfiles.settings = {
      "10-libvirt-ch" = {
        "/usr/share/cloud-hypervisor".d = {
          group = "root";
          mode = "0755";
          user = "root";
        };
        "/usr/share/cloud-hypervisor/CLOUDHV_EFI.fd"."L+".argument = "${chv-ovmf}";
        "/var/log/libvirt/ch".d = {
          group = "root";
          mode = "0755";
          user = "root";
        };
      };
      "10-nova" = {
        "/var/log/nova" = {
          D = {
            group = "nova";
            mode = "0755";
            user = "nova";
          };
        };
        "/var/lock/nova" = {
          D = {
            group = "nova";
            mode = "0755";
            user = "nova";
          };
        };
        "/var/lib/nova" = {
          D = {
            group = "nova";
            mode = "0755";
            user = "nova";
          };
        };
        "/var/lib/nova/instances" = {
          D = {
            group = "nova";
            mode = "0755";
            user = "nova";
          };
        };
        # we don't need tgt on a compute node -> only iscsi-client (openiscsi)
      };
    };

    services.openiscsi = {
      enable = true;
      name = "iqn.iscsi.${config.networking.hostName}";
    };

    environment.systemPackages = [
      pkgs.openiscsi
      pkgs.nfs-utils
      pkgs.cryptsetup
      luks-vhost-blk
      cloud-hypervisor
    ];

    systemd = {
      services = {
        nova-compute = {
          description = "OpenStack Nova Scheduler Daemon";
          after = [
            "rabbitmq.service"
            "network.target"
            "virtchd.socket"
            "virtsecretd.socket"
            "openvswitch.service"
          ];
          wants = [
            "virtchd.socket"
            "virtsecretd.socket"
          ];
          wantedBy = [ "multi-user.target" ];
          path =
            with pkgs;
            [
              sudo
              nova_env
              qemu
              util-linux
              lvm2
              openiscsi
              nfs-utils
              "/run/wrappers"
            ]
            ++ cfg.extraPkgs;
          environment.PYTHONPATH = "${nova_env}/${pkgs.python3.sitePackages}";
          serviceConfig = {
            ExecStart = pkgs.writeShellScript "nova-compute.sh" ''
              ${cfg.novaPackage}/bin/nova-compute --config-file=${cfg.config}
            '';
          };
        };

        virtchd = {
          path = mkForce [
            pkgs.cryptsetup
            pkgs.dmidecode
            pkgs.openssh
            pkgs.util-linux
            luks-vhost-blk
            cloud-hypervisor
          ];
          serviceConfig = {
            AmbientCapabilities = [ "CAP_SYS_ADMIN" ];
          };
        };

        virt-secret-init-encryption.serviceConfig = {
          StateDirectory = "libvirt/secrets";
          StateDirectoryMode = "0700";
        };
      };

      sockets.virtsecretd.wantedBy = [ "sockets.target" ];
    };

    security.sudo.extraConfig = ''
      nova ALL = (root) NOPASSWD: \
        ${nova_env}/bin/nova-rootwrap ${rootwrapConf} *
    '';
  };
}
