{
  pkgs,
  lib,
  stdenv,
  fetchurl,
  undmg,
  makeWrapper,
  autoPatchelfHook,
  pango,
  gtk3,
  glibc,
  alsa-lib,
}:

let
  myZenVersion = "1.12.10b";
  x86_64-darwin-hash = "1jmqgnhhnckxmfxc84fdq1rc4kph0r3wipsf2d4qg93hi0kpxhkm";
  aarch64-darwin-hash = "1jmqgnhhnckxmfxc84fdq1rc4kph0r3wipsf2d4qg93hi0kpxhkm";
  x86_64-linux-hash = "1wj8ramw4rvff5mdal3gdhgcpll664vw0lbh6gnng1k2468kyldk";
  sources = {
    x86_64-darwin = fetchurl {
      url = "https://github.com/zen-browser/desktop/releases/download/${myZenVersion}/zen.macos-universal.dmg";
      sha256 = x86_64-darwin-hash;
    };
    aarch64-darwin = fetchurl {
      url = "https://github.com/zen-browser/desktop/releases/download/${myZenVersion}/zen.macos-aarch64.dmg";
      sha256 = aarch64-darwin-hash;
    };
    x86_64-linux = fetchurl {
      url = "https://github.com/zen-browser/desktop/releases/download/${myZenVersion}/zen.linux-x86_64.tar.xz";
      sha256 = x86_64-linux-hash;
    };
  };
in stdenv.mkDerivation (finalAttrs: {
  pname = "zen-browser";
  version = "${myZenVersion}";

  src = sources.${stdenv.hostPlatform.system} or (throw "unsupported system: ${stdenv.hostPlatform.system}");

  dontUnpack = stdenv.isDarwin;
  unpackPhase = ''
    mkdir -p $out
    tar xjvf ${finalAttrs.src} -C $out
  '';

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook stdenv.cc.cc.lib pango gtk3 glibc alsa-lib ];
  buildInputs = [ makeWrapper ] ++ lib.optionals stdenv.isDarwin [ undmg ];

  buildPhase = if stdenv.isDarwin then ''
    undmg ${finalAttrs.src}
    mkdir -p $out/bin
    cp -r "Zen Browser.app" $out
    makeWrapper "$out/Zen Browser.app/Contents/MacOS/zen" "$out/bin/zen"
  '' else ''
    mkdir -p $out/bin
    makeWrapper "$out/zen/zen-bin" "$out/bin/zen"
  '';
})
