#!/usr/bin/env nix-shell
#! nix-shell -i python -p nix-prefetch-github python3Packages.githubkit
import json
import subprocess

from githubkit import GitHub, UnauthAuthStrategy
from githubkit.versions.latest.models import (
    Commit,
    ContentSubmodule,
    Tag,
)

DEPS_PATH: str = "./pkgs/by-name/ed/edopro/deps.nix"

with GitHub(UnauthAuthStrategy()) as github:
    edopro: Tag = github.rest.repos.list_tags("edo9300", "edopro").parsed_data[0]

    # This dep is not versioned in anyway and is why we check below to see if this is a new version.
    irrlicht: Commit = github.rest.repos.list_commits(
        "edo9300", "irrlicht1-8-4"
    ).parsed_data[0]

    irrlicht: Commit = github.rest.repos.get_commit(
        "edo9300", "irrlicht1-8-4", "7edde28d4f8c0c3589934c398a3a441286bb7c22"
    ).parsed_data


edopro_working_version: str = ""
try:
    with open(DEPS_PATH, "r") as file:
        for line in file.readlines():
            if "edopro-version" in line:
                edopro_working_version = line.split('"')[1]
except FileNotFoundError:
    print("Error: Dep file not found.")
    exit(2)

if edopro_working_version == "":
    print("Working version is unbound")
    exit(5)

if edopro_working_version == edopro.name:
    print("Version is updated")
    exit(0)


def get_hash(owner: str, repo: str, rev: str, submodule: bool = False) -> str:
    args: list[str] = ["nix-prefetch-github", owner, repo, "--rev", rev]

    if submodule:
        args.append("--fetch-submodules")

    out: subprocess.CompletedProcess = subprocess.run(args, capture_output=True)
    out_json = json.loads(out.stdout.decode())

    return out_json["hash"]


edopro_hash = get_hash("edo9300", "edopro", edopro.commit.sha)
irrlicht_hash = get_hash("edo9300", "irrlicht1-8-4", irrlicht.sha)

asset_legacy_hash: str = (
    subprocess.run(
        [
            "nix-prefetch-url",
            f"https://github.com/ProjectIgnis/edopro-assets/releases/download/{edopro.name}/ProjectIgnis-EDOPro-{edopro.name}-linux.tar.gz",
            "--unpack",
        ],
        capture_output=True,
    )
    .stdout.decode()
    .strip()
)
asset_hash: str = (
    subprocess.run(
        [
            "nix",
            "--extra-experimental-features",
            "nix-command",
            "hash",
            "to-sri",
            "--type",
            "sha256",
            asset_legacy_hash,
        ],
        capture_output=True,
    )
    .stdout.decode()
    .strip()
)


with open(DEPS_PATH, "w") as file:
    contents = f"""# This is automatically generated by the update script.
# DO NOT MANUALLY EDIT.
{{
  assets-hash = "{asset_hash}";
  edopro-version = "{edopro.name}";
  edopro-rev = "{edopro.commit.sha}";
  edopro-hash = "{edopro_hash}";
  irrlicht-version = "{"1.9.0-unstable-" + irrlicht.commit.committer.date.split("T")[0]}";
  irrlicht-rev = "{irrlicht.sha}";
  irrlicht-hash = "{irrlicht_hash}";
}}
"""

    file.write(contents)