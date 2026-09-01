{
  neutron,
  nova,
  libvirt-chv,
  cloud-hypervisor,
  chv-ovmf,
  luks-vhost-blk,
}:
{ ... }:
{
  imports = [
    ../generic/controller-host-entry.nix
    (import ./neutron.nix { inherit neutron; })
    (import ./nova.nix {
      inherit
        nova
        libvirt-chv
        cloud-hypervisor
        chv-ovmf
        luks-vhost-blk
        ;
    })
  ];
}
