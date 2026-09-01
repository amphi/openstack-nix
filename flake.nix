{
  description = "OpenStack Packages and Modules for NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cinder-src = {
      url = "github:amphi/cinder?ref=block-encryption-poc";
      flake = false;
    };

    nova-src = {
      url = "github:amphi/nova?ref=block-encryption-poc";
      flake = false;
    };

    cloud-hypervisor = {
      url = "github:cyberus-technology/cloud-hypervisor?ref=gardenlinux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    libvirt-chv = {
      url = "git+https://github.com/amphi/libvirt?ref=block-encryption-poc&submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.cloud-hypervisor.follows = "cloud-hypervisor";
    };

    luks-vhost-blk = {
      url = "github:amphi/luks-vhost-blk";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.cloud-hypervisor.follows = "libvirt-chv/cloud-hypervisor";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      pre-commit-hooks-nix,
      cinder-src,
      nova-src,
      libvirt-chv,
      luks-vhost-blk,
      ...
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.problems.handlers.pysaml2.broken = "warn";
          overlays = [
            (_final: prev: {
              python3 = prev.python3.override {
                packageOverrides = _: pyPrev: {
                  pysaml2 = pyPrev.pysaml2.overridePythonAttrs (_old: {
                    doCheck = false;
                  });
                };
              };
              python3Packages = _final.python3.pkgs;
            })
          ];
        };
        pre-commit-hooks-run = pre-commit-hooks-nix.lib.${system}.run;
        customLibvirt = libvirt-chv.packages.${system}.libvirt;

        customPythonLibvirt = pkgs.python3Packages.libvirt.override {
          libvirt = customLibvirt;
        };
      in
      rec {
        formatter = pkgs.nixfmt-tree;
        devShells.default = pkgs.mkShellNoCC {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
          buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
          packages = with pkgs; [ gitlint ];
        };

        lib = {
          generateRootwrapConf =
            {
              package,
              filterPath,
              execDirs,
            }:
            pkgs.callPackage ./lib/rootwrap-conf.nix {
              inherit package filterPath;
              utils_env = execDirs;
            };
        };

        packages =
          import ./packages {
            inherit (pkgs)
              callPackage
              python3Packages
              writeText
              lib
              ;
            inherit cinder-src nova-src customPythonLibvirt;
          }
          // {
            libvirt-chv = customLibvirt;
            cloud-hypervisor = libvirt-chv.packages.${system}.cloud-hypervisor;
            chv-ovmf = libvirt-chv.packages.${system}.chv-ovmf;
            luks-vhost-blk = luks-vhost-blk.packages.${system}.default;
          };

        checks = import ./checks { inherit pkgs pre-commit-hooks-run; };

        nixosModules = import ./modules { openstackPkgs = packages; };

        tests = import ./tests/default.nix {
          inherit pkgs nixosModules;
          inherit (lib) generateRootwrapConf;
        };
      }
    )
    // {
      ci = import ./lib/gitlab-ci.nix { input = { inherit (self) packages tests; }; };
    };
}
