{ lib, stdenv, fetchFromGitHub
, cmake
, CoreServices
, curlHTTP3
}:

stdenv.mkDerivation rec {
  pname = "nghttp3";
  version = "1.6.0";

  src = fetchFromGitHub {
    owner = "ngtcp2";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-5QsJLN79SkbrCfIGfeJ91AUEf9/V6BWkNE60wOkxdow=";
    fetchSubmodules = true;
  };

  outputs = [ "out" "dev" "doc" ];

  nativeBuildInputs = [ cmake ];
  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    CoreServices
  ];

  cmakeFlags = [
    (lib.cmakeBool "ENABLE_STATIC_LIB" false)
  ];

  doCheck = true;

  passthru.tests = {
    inherit curlHTTP3;
  };

  meta = with lib; {
    homepage = "https://github.com/ngtcp2/nghttp3";
    description = "nghttp3 is an implementation of HTTP/3 mapping over QUIC and QPACK in C";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = with maintainers; [ izorkin ];
  };
}