{ lib
, stdenv
, fetchurl
, postgresql
, openssl
, libxcrypt
, withPam ? stdenv.hostPlatform.isLinux
, pam
}:

stdenv.mkDerivation rec {
  pname = "pgpool-II";
  version = "4.5.4";

  src = fetchurl {
    url = "https://www.pgpool.net/mediawiki/download.php?f=pgpool-II-${version}.tar.gz";
    name = "pgpool-II-${version}.tar.gz";
    hash = "sha256-0TkudM4oB/iuYohyyxq3kUJJkhGA3JnfQKHWAmR6EP0=";
  };

  buildInputs = [
    postgresql
    openssl
    libxcrypt
  ] ++ lib.optional withPam pam;

  configureFlags = [
    "--sysconfdir=/etc"
    "--localstatedir=/var"
    "--with-openssl"
  ] ++ lib.optional withPam "--with-pam";

  installFlags = [
    "sysconfdir=\${out}/etc"
  ];

  patches = lib.optionals (stdenv.hostPlatform.isDarwin) [
    # Build checks for strlcpy being available in the system, but doesn't
    # actually exclude its own copy from being built
    ./darwin-strlcpy.patch
  ];

  enableParallelBuilding = true;

  meta = with lib; {
    homepage = "https://www.pgpool.net/mediawiki/index.php/Main_Page";
    description = "Middleware that works between PostgreSQL servers and PostgreSQL clients";
    changelog = "https://www.pgpool.net/docs/latest/en/html/release-${builtins.replaceStrings ["."] ["-"] version}.html";
    license = licenses.free;
    platforms = platforms.unix;
    maintainers = [ ];
  };
}