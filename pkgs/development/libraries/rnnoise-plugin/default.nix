{ lib
, stdenv
, cmake
, fetchFromGitHub
, freetype
, gtk3-x11
, pcre
, pkg-config
, webkitgtk_4_0
, xorg
, WebKit
, MetalKit
, CoreAudioKit
, simd
}:
stdenv.mkDerivation rec {
  pname = "rnnoise-plugin";
  version = "1.10";

  src = fetchFromGitHub {
    owner = "werman";
    repo = "noise-suppression-for-voice";
    rev = "v${version}";
    sha256 = "sha256-sfwHd5Fl2DIoGuPDjELrPp5KpApZJKzQikCJmCzhtY8=";
  };

  nativeBuildInputs = [ cmake pkg-config ];

  patches = lib.optionals stdenv.hostPlatform.isDarwin [
    # Ubsan seems to be broken on aarch64-darwin, it produces linker errors similar to https://github.com/NixOS/nixpkgs/issues/140751
    ./disable-ubsan.patch
  ];

  buildInputs =
    [
      freetype
      gtk3-x11
      pcre
      xorg.libX11
      xorg.libXrandr
    ] ++ lib.optionals stdenv.hostPlatform.isLinux [
      webkitgtk_4_0
    ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
      WebKit
      MetalKit
      CoreAudioKit
      simd
    ];

  meta = with lib; {
    description = "Real-time noise suppression plugin for voice based on Xiph's RNNoise";
    homepage = "https://github.com/werman/noise-suppression-for-voice";
    license = licenses.gpl3;
    platforms = platforms.all;
    maintainers = with maintainers; [ panaeon henrikolsson sciencentistguy ];
  };
}