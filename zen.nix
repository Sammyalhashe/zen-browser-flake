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
  runtimeLibs =
    with pkgs;
    [
      libGL
      libGLU
      libevent
      libffi
      libjpeg
      libpng
      libstartup_notification
      libvpx
      libwebp
      stdenv.cc.cc
      fontconfig
      libxkbcommon
      zlib
      freetype
      gtk3
      libxml2
      dbus
      xcb-util-cursor
      alsa-lib
      libpulseaudio
      pango
      atk
      cairo
      gdk-pixbuf
      glib
      udev
      libva
      mesa
      libnotify
      cups
      pciutils
      ffmpeg
      libglvnd
      pipewire
    ]
    ++ (with pkgs.xorg; [
      libxcb
      libX11
      libXcursor
      libXrandr
      libXi
      libXext
      libXcomposite
      libXdamage
      libXfixes
      libXScrnSaver
    ]);
in
stdenv.mkDerivation (
  finalAttrs:
  let
    derivationStatement =
      if stdenv.isDarwin then
        {
          pname = "zen-browser";
          version = "${myZenVersion}";

          src =
            sources.${stdenv.hostPlatform.system}
              or (throw "unsupported system: ${stdenv.hostPlatform.system}");

          dontUnpack = stdenv.isDarwin;
          unpackPhase = ''
            mkdir -p $out
            tar xjvf ${finalAttrs.src} -C $out
          '';

          nativeBuildInputs = lib.optionals stdenv.isLinux [
            autoPatchelfHook
            stdenv.cc.cc.lib
            pango
            gtk3
            glibc
            alsa-lib
          ];
          buildInputs = [ makeWrapper ] ++ lib.optionals stdenv.isDarwin [ undmg ];

          buildPhase =
            if stdenv.isDarwin then
              ''
                undmg ${finalAttrs.src}
                mkdir -p $out/bin
                cp -r "Zen.app" $out
                makeWrapper "$out/Zen.app/Contents/MacOS/zen" "$out/bin/zen"
              ''
            else
              ''
                mkdir -p $out/bin
                makeWrapper "$out/zen/zen-bin" "$out/bin/zen"
              '';
        }
      else
        {
          pname = "zen-browser";
          version = "${myZenVersion}";
          src =
            sources.${stdenv.hostPlatform.system}
              or (throw "unsupported system: ${stdenv.hostPlatform.system}");
          desktopSrc = ./.;

          phases = [
            "installPhase"
            "fixupPhase"
          ];

          nativeBuildInputs = [
            pkgs.makeWrapper
            pkgs.copyDesktopItems
            pkgs.wrapGAppsHook
          ];

          installPhase = ''
                      mkdir -p $out/src
            		  mkdir -p $out/bin
                      tar xf $src -C $out/src
                      ls $out
                      ls $out/src/zen
                      cp -r $out/src/zen/* $out/bin

            		  install -D $desktopSrc/zen.desktop $out/share/applications/zen.desktop
            		  install -D $out/src/zen/browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/zen.png
            		'';

          fixupPhase = ''
            		  chmod 755 $out/bin/*
            		  patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/zen
            		  wrapProgram $out/bin/zen --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}" \
                                --set MOZ_LEGACY_PROFILES 1 --set MOZ_ALLOW_DOWNGRADE 1 --set MOZ_APP_LAUNCHER zen --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"
            		  patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/zen-bin
            		  wrapProgram $out/bin/zen-bin --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}" \
                                --set MOZ_LEGACY_PROFILES 1 --set MOZ_ALLOW_DOWNGRADE 1 --set MOZ_APP_LAUNCHER zen --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"
            		  patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/glxtest
            		  wrapProgram $out/bin/glxtest --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"
            		  patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/updater
            		  wrapProgram $out/bin/updater --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"
            		  patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/vaapitest
            		  wrapProgram $out/bin/vaapitest --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"
            		'';

          meta.mainProgram = "zen";
        };
  in
  derivationStatement
)
