{ lib
, stdenv
, fetchpatch
, fetchurl
, buildPackages
, coreutils
, pam
, groff
, sssd
, nixosTests
, sendmailPath ? "/run/wrappers/bin/sendmail"
, withInsults ? false
, withSssd ? false
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "sudo";
  # be sure to check if nixos/modules/security/sudo.nix needs updating when bumping
  # e.g. links to man pages, value constraints etc.
  version = "1.9.16";

  __structuredAttrs = true;

  src = fetchurl {
    url = "https://www.sudo.ws/dist/sudo-${finalAttrs.version}.tar.gz";
    hash = "sha256-wNhNeX8GtzL8Vz0LeYroMSjCvDMFIFfwW1YOxry/oD0=";
  };

  prePatch = ''
    # do not set sticky bit in nix store
    substituteInPlace src/Makefile.in --replace 04755 0755
  '';

  patches = [
    # Fix for https://github.com/NixOS/nixpkgs/issues/354544
    (fetchpatch {
      url = "https://www.sudo.ws/repos/sudo/raw-rev/71e3f5a288e1ac21151b1b9577f0fe3745671cf7";
      hash = "sha256-L4AF1ee+qW9QKLrUzL5+hC5EznNC9k7sNeVGNBAJ6S4=";
    })
  ];

  configureFlags = [
    "--with-env-editor"
    "--with-editor=/run/current-system/sw/bin/nano"
    "--with-rundir=/run/sudo"
    "--with-vardir=/var/db/sudo"
    "--with-logpath=/var/log/sudo.log"
    "--with-iologdir=/var/log/sudo-io"
    "--with-sendmail=${sendmailPath}"
    "--enable-tmpfiles.d=no"
    "--with-passprompt=[sudo] password for %p: " # intentional trailing space
  ] ++ lib.optionals withInsults [
    "--with-insults"
    "--with-all-insults"
  ] ++ lib.optionals withSssd [
    "--with-sssd"
    "--with-sssd-lib=${sssd}/lib"
  ];

  postConfigure =
    ''
      cat >> pathnames.h <<'EOF'
        #undef _PATH_MV
        #define _PATH_MV "${coreutils}/bin/mv"
      EOF
      makeFlags="install_uid=$(id -u) install_gid=$(id -g)"
      installFlags="sudoers_uid=$(id -u) sudoers_gid=$(id -g) sysconfdir=$out/etc rundir=$TMPDIR/dummy vardir=$TMPDIR/dummy DESTDIR=/"
    '';

  depsBuildBuild = [ buildPackages.stdenv.cc ];
  nativeBuildInputs = [ groff ];
  buildInputs = [ pam ];

  enableParallelBuilding = true;

  doCheck = false; # needs root

  postInstall = ''
    rm $out/share/doc/sudo/ChangeLog
  '';

  passthru.tests = { inherit (nixosTests) sudo; };

  meta = with lib; {
    description = "Command to run commands as root";
    longDescription =
      ''
        Sudo (su "do") allows a system administrator to delegate
        authority to give certain users (or groups of users) the ability
        to run some (or all) commands as root or another user while
        providing an audit trail of the commands and their arguments.
      '';
    homepage = "https://www.sudo.ws/";
    # From https://www.sudo.ws/about/license/
    license = with licenses; [ sudo bsd2 bsd3 zlib ];
    maintainers = with maintainers; [ rhendric ];
    platforms = platforms.linux ++ platforms.freebsd;
    mainProgram = "sudo";
  };
})