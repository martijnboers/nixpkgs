{ lib
, dataDir ? "/var/lib/snipe-it"
, fetchFromGitHub
, mariadb
, nixosTests
, php
}:

php.buildComposerProject2 (finalAttrs: {
  pname = "snipe-it";
  version = "7.0.13";

  src = fetchFromGitHub {
    owner = "snipe";
    repo = "snipe-it";
    rev = "v${finalAttrs.version}";
    hash = "sha256-LfE45ConH8/NPOhD+uDwJP3nNf040QEGZDdHAg1qwXg=";
  };

  vendorHash = "sha256-4csHTqhkTJBzoe0Vfc7Gu1qaDG3ixj6vPMYoVLIWUV0=";

  postInstall = ''
    snipe_it_out="$out/share/php/snipe-it"

    # Before symlinking the following directories, copy the invalid_barcode.gif
    # to a different location. The `snipe-it-setup` oneshot service will then
    # copy the file back during bootstrap.
    mkdir -p $out/share/snipe-it
    cp $snipe_it_out/public/uploads/barcodes/invalid_barcode.gif $out/share/snipe-it/

    rm -R $snipe_it_out/storage $snipe_it_out/public/uploads $snipe_it_out/bootstrap/cache
    ln -s ${dataDir}/.env $snipe_it_out/.env
    ln -s ${dataDir}/storage $snipe_it_out/
    ln -s ${dataDir}/public/uploads $snipe_it_out/public/uploads
    ln -s ${dataDir}/bootstrap/cache $snipe_it_out/bootstrap/cache

    chmod +x $snipe_it_out/artisan

    substituteInPlace $snipe_it_out/config/database.php --replace-fail "env('DB_DUMP_PATH', '/usr/local/bin')" "env('DB_DUMP_PATH', '${mariadb}/bin')"
  '';

  passthru = {
    tests = nixosTests.snipe-it;
    phpPackage = php;
  };

  meta = with lib; {
    description = "Free open source IT asset/license management system";
    longDescription = ''
      Snipe-IT was made for IT asset management, to enable IT departments to track
      who has which laptop, when it was purchased, which software licenses and accessories
      are available, and so on.
      Details for snipe-it can be found on the official website at https://snipeitapp.com/.
    '';
    homepage = "https://snipeitapp.com/";
    changelog = "https://github.com/snipe/snipe-it/releases/tag/v${finalAttrs.version}";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [ yayayayaka ];
    platforms = platforms.linux;
  };
})