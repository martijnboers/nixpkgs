{ lib
, stdenv
, fetchFromGitLab
, writeText
, bluez
, cjson
, cmake
, config
, dbus
, doxygen
, eigen
, elfutils
, glslang
, gst-plugins-base
, gstreamer
, hidapi
, libbsd
, libdrm
, libffi
, libGL
, libjpeg
, librealsense
, libsurvive
, libunwind
, libusb1
, libuv
, libuvc
, libv4l
, libXau
, libxcb
, libXdmcp
, libXext
, libXrandr
, nix-update-script
, onnxruntime
, opencv4
, openhmd
, openvr
, orc
, pcre2
, pkg-config
, python3
, SDL2
, shaderc
, tracy
, udev
, vulkan-headers
, vulkan-loader
, wayland
, wayland-protocols
, wayland-scanner
, zlib
, zstd
, nixosTests
, cudaPackages
, enableCuda ? config.cudaSupport
  # Set as 'false' to build monado without service support, i.e. allow VR
  # applications linking against libopenxr_monado.so to use OpenXR standalone
  # instead of via the monado-service program. For more information see:
  # https://gitlab.freedesktop.org/monado/monado/-/blob/master/doc/targets.md#xrt_feature_service-disabled
, serviceSupport ? true
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "monado";
  version = "24.0.0";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "monado";
    repo = "monado";
    rev = "refs/tags/v${finalAttrs.version}";
    hash = "sha256-lFy0VvaLD4Oyu2TZJnaIWjuaJUZjGGDJS0VsRfIUpcc=";
  };

  nativeBuildInputs = [
    cmake
    doxygen
    glslang
    pkg-config
    python3
  ];

  cmakeFlags = [
    (lib.cmakeBool "XRT_FEATURE_SERVICE" serviceSupport)
    (lib.cmakeBool "XRT_OPENXR_INSTALL_ABSOLUTE_RUNTIME_PATH" true)
    (lib.cmakeBool "XRT_HAVE_TRACY" true)
    (lib.cmakeBool "XRT_FEATURE_TRACING" true)
    (lib.cmakeBool "XRT_HAVE_STEAM" true)
    (lib.optionals enableCuda "-DCUDA_TOOLKIT_ROOT_DIR=${cudaPackages.cudatoolkit}")
  ];

  buildInputs = [
    bluez
    cjson
    dbus
    eigen
    elfutils
    gst-plugins-base
    gstreamer
    hidapi
    libbsd
    libdrm
    libffi
    libGL
    libjpeg
    librealsense
    libsurvive
    libunwind
    libusb1
    libuv
    libuvc
    libv4l
    libXau
    libxcb
    libXdmcp
    libXext
    libXrandr
    onnxruntime
    opencv4
    openhmd
    openvr
    orc
    pcre2
    SDL2
    shaderc
    tracy
    udev
    vulkan-headers
    vulkan-loader
    wayland
    wayland-protocols
    wayland-scanner
    zlib
    zstd
  ];

  # known disabled drivers/features:
  #  - DRIVER_DEPTHAI - Needs depthai-core https://github.com/luxonis/depthai-core (See https://github.com/NixOS/nixpkgs/issues/292618)
  #  - DRIVER_ILLIXR - needs ILLIXR headers https://github.com/ILLIXR/ILLIXR (See https://github.com/NixOS/nixpkgs/issues/292661)
  #  - DRIVER_ULV2 - Needs proprietary Leapmotion SDK https://api.leapmotion.com/documentation/v2/unity/devguide/Leap_SDK_Overview.html (See https://github.com/NixOS/nixpkgs/issues/292624)
  #  - DRIVER_ULV5 - Needs proprietary Leapmotion SDK https://api.leapmotion.com/documentation/v2/unity/devguide/Leap_SDK_Overview.html (See https://github.com/NixOS/nixpkgs/issues/292624)

  # Help openxr-loader find this runtime
  setupHook = writeText "setup-hook" ''
    export XDG_CONFIG_DIRS=@out@/etc/xdg''${XDG_CONFIG_DIRS:+:''${XDG_CONFIG_DIRS}}
  '';

  passthru = {
    updateScript = nix-update-script { };
    tests.basic-service = nixosTests.monado;
  };

  meta = with lib; {
    description = "Open source XR runtime";
    homepage = "https://monado.freedesktop.org/";
    license = licenses.boost;
    maintainers = with maintainers; [ Scrumplex prusnak ];
    platforms = platforms.linux;
    mainProgram = "monado-cli";
  };
})