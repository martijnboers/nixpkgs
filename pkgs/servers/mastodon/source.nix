# This file was generated by pkgs.mastodon.updateScript.
{ fetchFromGitHub, applyPatches, patches ? [] }:
let
  version = "4.3.1";
in
(
  applyPatches {
    src = fetchFromGitHub {
      owner = "mastodon";
      repo = "mastodon";
      rev = "v${version}";
      hash = "sha256-JlpQGyVPTLcB3RcWMBrmYc1AAUT1JLfS4IDas9ZoWh4=";
    };
    patches = patches ++ [];
  }) // {
  inherit version;
  yarnHash = "sha256-e5c04M6XplAgaVyldU5HmYMYtY3MAWs+a8Z/BGSyGBg=";
}