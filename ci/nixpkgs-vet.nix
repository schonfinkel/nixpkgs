{
  lib,
  nix,
  nixpkgs-vet,
  runCommand,
}:
{
  base ? ../.,
  head ? ../.,
}:
let
  filtered =
    with lib.fileset;
    path:
    toSource {
      fileset = (gitTracked path);
      root = path;
    };
in
runCommand "nixpkgs-vet"
  {
    nativeBuildInputs = [
      nixpkgs-vet
    ];
    env.NIXPKGS_VET_NIX_PACKAGE = nix;
  }
  ''
    export NIX_STATE_DIR=$(mktemp -d)

    nixpkgs-vet --base ${filtered base} ${filtered head}

    touch $out
  ''
