{ lib, stdenv, bison, fetchFromGitHub, flex, perl, postgresql, buildPostgresqlExtension }:

let
  hashes = {
    # Issue tracking PostgreSQL 17 support: https://github.com/apache/age/issues/2111
    # "17" = "";
    "16" = "sha256-sXh/vmGyYj00ALfFVdeql2DZ6nCJQDNKyNgzlOZnPAw=";
    "15" = "sha256-webZWgWZGnSoXwTpk816tjbtHV1UIlXkogpBDAEL4gM=";
    "14" = "sha256-jZXhcYBubpjIJ8M5JHXKV5f6VK/2BkypH3P7nLxZz3E=";
    "13" = "sha256-HR6nnWt/V2a0rD5eHHUsFIZ1y7lmvLz36URt9pPJnCw=";
    "12" = "sha256-JFNk17ESsIt20dwXrfBkQ5E6DbZzN/Q9eS6+WjCXGd4=";
  };
in
buildPostgresqlExtension rec {
  pname = "age";
  version = "1.5.0-rc0";

  src = fetchFromGitHub {
    owner = "apache";
    repo = "age";
    rev = "PG${lib.versions.major postgresql.version}/v${builtins.replaceStrings ["."] ["_"] version}";
    hash = hashes.${lib.versions.major postgresql.version} or (throw "Source for Age is not available for ${postgresql.version}");
  };

  makeFlags = [
    "BISON=${bison}/bin/bison"
    "FLEX=${flex}/bin/flex"
    "PERL=${perl}/bin/perl"
  ];

  passthru.tests = stdenv.mkDerivation {
    inherit version src;

    pname = "age-regression";

    dontConfigure = true;

    buildPhase = let
      postgresqlAge = postgresql.withPackages (ps: [ ps.age ]);
    in ''
      # The regression tests need to be run in the order specified in the Makefile.
      echo -e "include Makefile\nfiles:\n\t@echo \$(REGRESS)" > Makefile.regress
      REGRESS_TESTS=$(make -f Makefile.regress files)

      ${lib.getDev postgresql}/lib/pgxs/src/test/regress/pg_regress \
        --inputdir=./ \
        --bindir='${postgresqlAge}/bin' \
        --encoding=UTF-8 \
        --load-extension=age \
        --inputdir=./regress --outputdir=./regress --temp-instance=./regress/instance \
        --port=61958 --dbname=contrib_regression \
        $REGRESS_TESTS
    '';

    installPhase = ''
      touch $out
    '';
  };

  meta = with lib; {
    broken = !builtins.elem (versions.major postgresql.version) (builtins.attrNames hashes);
    description = "Graph database extension for PostgreSQL";
    homepage = "https://age.apache.org/";
    changelog = "https://github.com/apache/age/raw/v${src.rev}/RELEASE";
    maintainers = [ ];
    platforms = postgresql.meta.platforms;
    license = licenses.asl20;
  };
}