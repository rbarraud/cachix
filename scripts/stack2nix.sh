#/usr/bin/env bash
set -xe

scriptDir="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
NIX_PATH="nixpkgs=$(nix-instantiate nixpkgs.nix -A path --eval)"

pushd $scriptDir/../
  $(nix-build https://github.com/input-output-hk/stack2nix/tarball/master --no-out-link)/bin/stack2nix \
    --platform x86_64-linux --test --hackage-snapshot 2018-07-01T00:00:00Z . > stack2nix.nix
  git diff -w --text --exit-code
popd
