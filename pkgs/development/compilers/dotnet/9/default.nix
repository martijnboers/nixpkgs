{ callPackage
, dotnetCorePackages
}: callPackage ../dotnet.nix {
  releaseManifestFile = ./release.json;
  releaseInfoFile = ./release-info.json;
  bootstrapSdkFile = ./bootstrap-sdk.nix;
  allowPrerelease = true;
  depsFile = ./deps.nix;
}