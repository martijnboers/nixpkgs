#! /usr/bin/env nix-shell
#! nix-shell -i bash -p nix curl jq git gnused -I nixpkgs=.

# See regenerate-hackage-packages.sh for details on the purpose of this script.

set -euo pipefail

pin_file=pkgs/data/misc/hackage/pin.json
current_commit="$(jq -r .commit $pin_file)"
old_date="$(jq -r .msg $pin_file | sed 's/Update from Hackage at //')"
git_info="$(curl -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/commercialhaskell/all-cabal-hashes/branches/hackage)"
head_commit="$(echo "$git_info" | jq -r .commit.sha)"
commit_msg="$(echo "$git_info" | jq -r .commit.commit.message)"
new_date="$(echo "$commit_msg" | sed 's/Update from Hackage at //')"

if [ "$current_commit" != "$head_commit" ]; then
   url="https://github.com/commercialhaskell/all-cabal-hashes/archive/$head_commit.tar.gz"
   hash="$(nix-prefetch-url "$url")"
   jq -n \
     --arg commit "$head_commit" \
     --arg hash "$hash" \
     --arg url "$url" \
     --arg commit_msg "$commit_msg" \
     '{commit: $commit, url: $url, sha256: $hash, msg: $commit_msg}' \
     > $pin_file
fi

if [[ "${1:-}" == "--do-commit" ]]; then
git add pkgs/data/misc/hackage/pin.json
git commit -F - << EOF
all-cabal-hashes: $old_date -> $new_date

This commit has been generated by maintainers/scripts/haskell/update-hackage.sh
EOF
fi