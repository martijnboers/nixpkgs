{ lib
, stdenv
, substituteAll
, fetchFromGitLab
, buildGoModule
, wrapQtAppsHook
, python3Packages
, pkg-config
, openvpn
, cmake
, qmake
, which
, iproute2
, iptables
, procps
, qtbase
, qtdeclarative
, qtsvg
, qttools
, qtwayland
, CoreFoundation
, Security
, provider ? "riseup"
}:
let
  version = "0.24.8";

  src = fetchFromGitLab {
    domain = "0xacab.org";
    owner = "leap";
    repo = "bitmask-vpn";
    rev = "8b3ac473f64b6de0262fbf945ff25af8029134f1";
    sha256 = "sha256-nYMfO091w6H7LyY1+aYubFppg4/3GiZZm4e+0m9Gb3k=";
  };

  # bitmask-root is only used on GNU/Linux
  # and may one day be replaced by pkg/helper
  bitmask-root = stdenv.mkDerivation {
    inherit src version;
    sourceRoot = "${src.name}/helpers";
    pname = "bitmask-root";
    nativeBuildInputs = [ python3Packages.wrapPython ];
    postPatch = ''
      substituteInPlace bitmask-root \
        --replace 'swhich("ip")' '"${iproute2}/bin/ip"' \
        --replace 'swhich("iptables")' '"${iptables}/bin/iptables"' \
        --replace 'swhich("ip6tables")' '"${iptables}/bin/ip6tables"' \
        --replace 'swhich("sysctl")' '"${procps}/bin/sysctl"' \
        --replace /usr/sbin/openvpn ${openvpn}/bin/openvpn
      substituteInPlace se.leap.bitmask.policy \
        --replace /usr/sbin/bitmask-root $out/bin/bitmask-root
    '';
    installPhase = ''
      runHook preInstall

      install -m 755 -D -t $out/bin bitmask-root
      install -m 444 -D -t $out/share/polkit-1/actions se.leap.bitmask.policy
      wrapPythonPrograms

      runHook postInstall
    '';
  };
in

buildGoModule rec {
  inherit src version;
  pname = "${provider}-vpn";
  vendorHash = null;

  patches = [
    # This patch fixes the paths in the build script generated by qmake
    # to use the correct paths for qmlcachegen and lrelease
    (substituteAll {
      src = ./fix_paths.patch;
      inherit qtbase qtdeclarative qttools;
    })

    # Don't build the debug version
    ./build_release.patch
  ];

  postPatch = ''
    substituteInPlace pkg/pickle/helpers.go \
      --replace /usr/share $out/share

    # Using $PROVIDER is not working,
    # thus replacing directly into the vendor.conf
    substituteInPlace providers/vendor.conf \
      --replace "provider = bitmask" "provider = ${provider}"

    substituteInPlace branding/templates/debian/app.desktop-template \
      --replace "Icon=icon" "Icon=${pname}"

    patchShebangs gui/build.sh
    wrapPythonProgramsIn branding/scripts
  '' + lib.optionalString stdenv.hostPlatform.isLinux ''
    substituteInPlace pkg/helper/linux.go \
      --replace /usr/sbin/openvpn ${openvpn}/bin/openvpn
    substituteInPlace pkg/launcher/launcher_linux.go \
      --replace /usr/sbin/openvpn ${openvpn}/bin/openvpn \
      --replace /usr/sbin/bitmask-root ${bitmask-root}/bin/bitmask-root \
      --replace /usr/bin/lxpolkit /run/wrappers/bin/polkit-agent-helper-1 \
      --replace '"polkit-gnome-authentication-agent-1",' '"polkit-gnome-authentication-agent-1","polkitd",'
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    python3Packages.wrapPython
    which
    wrapQtAppsHook
    qmake
    qttools
    qtsvg
  ];

  buildInputs = [
    qtbase
    qtdeclarative
    qtsvg
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [ CoreFoundation Security ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ qtwayland ];

  # FIXME: building on Darwin currently fails
  # due to missing debug symbols for Qt,
  # this should be fixable once darwin.apple_sdk >= 10.13
  # See https://bugreports.qt.io/browse/QTBUG-76777

  # Not using buildGoModule's buildPhase:
  # gui/build.sh will build Go modules into lib/libgoshim.a
  buildPhase = ''
    runHook preBuild

    # TODO: this is a hack that copies the qrc file that should by built by qmlcachegen
    # qmlcachegen is in qtdeclarative/libexec, but qmake is in qtbase/bin
    # but qmake searches for qmlcachegen in qtbase/libexec which leads to the error
    mkdir -p build/qt
    cp ${./gui_gui_qmlcache.qrc} build/qt/gui_gui_qmlcache.qrc

    make build

    runHook postBuild
  '';

  postInstall = ''
    install -m 755 -D -t $out/bin build/qt/release/${pname}

    VERSION=${version} VENDOR_PATH=providers branding/scripts/generate-debian branding/templates/debian/data.json
    (cd branding/templates/debian && ${python3Packages.python}/bin/python3 generate.py)
    install -m 444 -D branding/templates/debian/app.desktop $out/share/applications/${pname}.desktop
    install -m 444 -D providers/${provider}/assets/icon.svg $out/share/icons/hicolor/scalable/apps/${pname}.svg
  '' + lib.optionalString stdenv.hostPlatform.isLinux ''
    install -m 444 -D -t $out/share/polkit-1/actions ${bitmask-root}/share/polkit-1/actions/se.leap.bitmask.policy
  '';

  # Some tests need access to the Internet:
  # Post "https://api.black.riseup.net/3/cert": dial tcp: lookup api.black.riseup.net on [::1]:53: read udp [::1]:56553->[::1]:53: read: connection refused
  doCheck = false;

  passthru = { inherit bitmask-root; };

  meta = {
    description = "Generic VPN client by LEAP";
    longDescription = ''
      Bitmask, by LEAP (LEAP Encryption Access Project),
      is an application to provide easy and secure encrypted communication
      with a VPN (Virtual Private Network). It allows you to select from
      a variety of trusted service provider all from one app.
      Current providers include Riseup Networks
      and The Calyx Institute, where the former is default.
      The <literal>${pname}</literal> executable should appear
      in your desktop manager's XDG menu or could be launch in a terminal
      to get an execution log. A new icon should then appear in your systray
      to control the VPN and configure some options.
    '';
    homepage = "https://bitmask.net";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ julm ];
    # darwin requires apple_sdk >= 10.13
    platforms = lib.platforms.linux;
  };
}