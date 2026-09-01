{ openstackPkgs }:
{
  controllerModule = import ./controller/openstack-controller.nix {
    inherit (openstackPkgs)
      nova
      neutron
      keystone
      glance
      horizon
      cinder
      barbican
      ;
    placement = openstackPkgs.openstack-placement;
  };

  computeModule = import ./compute/compute.nix {
    inherit (openstackPkgs)
      neutron
      nova
      libvirt-chv
      cloud-hypervisor
      chv-ovmf
      luks-vhost-blk
      ;
  };

  storageModule = import ./storage/cinder-storage-node.nix { inherit (openstackPkgs) cinder; };

  testModules = import ./testing { inherit (openstackPkgs) python-openstackclient; };
}
