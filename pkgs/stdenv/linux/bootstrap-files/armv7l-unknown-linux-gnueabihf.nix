# Autogenerated by maintainers/scripts/bootstrap-files/refresh-tarballs.bash as:
# $ ./refresh-tarballs.bash --targets=armv7l-unknown-linux-gnueabihf
#
# Metadata:
# - nixpkgs revision: b92edf1104c47016385e85c87c2d953cf5cd2f98
# - hydra build: https://hydra.nixos.org/job/nixpkgs/cross-trunk/bootstrapTools.armv7l-unknown-linux-gnueabihf.build/latest
# - resolved hydra build: https://hydra.nixos.org/build/276944599
# - instantiated derivation: /nix/store/ldvkcqvzvwqv6frf6aqkl44jja88gvbx-stdenv-bootstrap-tools-armv7l-unknown-linux-gnueabihf.drv
# - output directory: /nix/store/y2xac60x8qkli271qn4dz78lzm2sqiv8-stdenv-bootstrap-tools-armv7l-unknown-linux-gnueabihf
# - build time: Thu, 31 Oct 2024 20:57:35 +0000
{
  bootstrapTools = import <nix/fetchurl.nix> {
    url = "http://tarballs.nixos.org/stdenv/armv7l-unknown-linux-gnueabihf/b92edf1104c47016385e85c87c2d953cf5cd2f98/bootstrap-tools.tar.xz";
    hash = "sha256-FpBUnMI20l4LVdtmPpaGWP5+V52ZpvAH1JmHkOqFhCI=";
  };
  busybox = import <nix/fetchurl.nix> {
    url = "http://tarballs.nixos.org/stdenv/armv7l-unknown-linux-gnueabihf/b92edf1104c47016385e85c87c2d953cf5cd2f98/busybox";
    hash = "sha256-LSK7lkzpD1Zv5aFzp45W+3JGLi8iqOIk8brl1TNIl4g=";
    executable = true;
  };
}