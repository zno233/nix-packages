# Generic builder for the honk variants; consumed by ../package.nix, which
# merges in the flavor metadata and the pin data from ./honk.nix (refreshed
# by tools/update-pins).
#
# honk publishes prebuilt release archives per arch/ABI; see ../package.nix
# for the asset naming scheme. NixOS has no FHS /lib64/ld-linux or
# libstdc++, so autoPatchelfHook rewrites the interpreter and rpath of the
# glibc builds (the musl builds are static and not packaged here).
{
  pname,
  version,
  # <system>.<flavor> map of sha256 sri values, from ./honk.nix
  hashes,
  # "full": mimalloc allocator (upstream default); "stock": system allocator
  flavor,
  # allocator fragment of the meta.description
  allocator,
}:
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  arch =
    {
      x86_64-linux = "x86_64";
      aarch64-linux = "aarch64";
    }
    .${stdenv.hostPlatform.system}
      or (throw "make-honk.nix: no prebuilt archive for ${stdenv.hostPlatform.system} (only x86_64-linux/aarch64-linux)");

  assertValid = lib.assertMsg (builtins.elem flavor [
    "full"
    "stock"
  ]) "make-honk.nix: flavor must be one of full, stock (got: ${flavor})";

  target = "${arch}-unknown-linux-gnu";
  asset =
    {
      full = "full";
      stock = "stock-full";
    }
    .${flavor};
  archive = "honk-core-${version}-${target}-${asset}";
in

assert assertValid;

stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/daeuniverse/honk/releases/download/${version}/${archive}.tar.gz";
    hash = hashes.${stdenv.hostPlatform.system}.${flavor};
  };

  # the archive has a single top-level directory; skip the auto-detection
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  # The archive's ELF needs /lib64/ld-linux-x86-64.so.2, libstdc++.so.6,
  # libgcc_s.so.1, libm.so.6 and libc.so.6. The hook takes the interpreter
  # from the stdenv's dynamic-linker and treats libm/libc as libc deps, so
  # only libstdc++/libgcc_s have to come from buildInputs.
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    install -Dm755 ${archive}/honk-core "$out/bin/honk"
    install -Dm644 ${archive}/LICENSE "$out/share/doc/honk/LICENSE"
    install -Dm644 ${archive}/README.md "$out/share/doc/honk/README.md"

    runHook postInstall
  '';

  meta = {
    description = "Linux high-performance transparent proxy solution based on eBPF (prebuilt glibc build with ${allocator})";
    homepage = "https://github.com/daeuniverse/honk";
    license = lib.licenses.gpl3Only;
    mainProgram = "honk";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
