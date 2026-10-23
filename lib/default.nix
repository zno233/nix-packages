{ lib }:
lib.makeExtensible (
  final:
  let
    import' = file: import file { inherit lib; };
  in
  {
    inherit (final.derivations) filterDerivations;

    derivations = import' ./derivations.nix;
    licenses = import' ./licenses.nix;
  }
)
