{
  description = "A very basic flake for the DanXi project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-android.url =
      "github:sseu-buhzzi/nixpkgs?ref=20260505/fix-android-ndk-path";
    nixpkgs-jdk23.url = "github:nixos/nixpkgs?ref=25.05";
    nix-wpe-webkit.url = "github:eval-exec/nix-wpe-webkit";
  };

  outputs = { self, nixpkgs, nixpkgs-android, nixpkgs-jdk23, nix-wpe-webkit }:
    let
      system = "x86_64-linux";
      unfreeConfig = {
        allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "android-sdk-cmdline-tools"
            "android-sdk-platform-tools"
            "platform-tools"
            "android-sdk-tools"
            "android-sdk-emulator"
            "emulator"
            "tools"
            "android-sdk-build-tools"
            "build-tools"
            "android-sdk-platforms"
            "platforms"
            "cmake"
            "android-sdk-ndk"
            "ndk"
            "cmdline-tools"
            "google-chrome"
          ];
        android_sdk.accept_license = true;
      };
      pkgsAndroid = import nixpkgs-android {
        inherit system;
        config = unfreeConfig;
      };
      pkgsJdk23 = import nixpkgs-jdk23 { inherit system; };
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          nix-wpe-webkit.overlays.default
          (final: prev: {
            wpewebkit = prev.wpewebkit.overrideAttrs (old: {
              buildInputs = (old.buildInputs or [ ]) ++ [ final.expat ];
            });
          })
          (final: prev: { inherit (pkgsAndroid) androidenv; })
          (final: prev: { inherit (pkgsJdk23) jdk23; })
        ];
        config = unfreeConfig;
      };

      androidBuildToolsVersion = "35.0.0";
      androidPkg = pkgs.androidenv.composeAndroidPackages {
        platformVersions = [ "35" "36" "37" ];
        buildToolsVersions = [ androidBuildToolsVersion ];
        cmakeVersions = [ "3.22.1" ];
        includeNDK = true;
        ndkVersions = [
          "28.2.13676358"
          "29.0.14206865"
        ];
      };
      androidSdk = androidPkg.androidsdk;

      defaultDanXiPkg = pkgs.callPackage ./. { };
    in
    {

      defaultPackage.${system} = defaultDanXiPkg;
      packages.${system}.default = defaultDanXiPkg;

      devShells.${system}.default = pkgs.mkShell {
        inherit (defaultDanXiPkg) nativeBuildInputs;

        buildInputs = with pkgs; [
          androidSdk
          google-chrome

          jdk23
        ] ++ defaultDanXiPkg.buildInputs;

        env = {
          ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
          CHROME_EXECUTABLE = "google-chrome-stable";
        };

        shellHook = ''
          cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}"

          # Cannot run android/.gradlew directly since `/flutter_tools/gradle/.gradle` is immutable.
          # `https://github.com/NixOS/nixpkgs/issues/395096`
          mkdir -p "$cache_root/nix-flutter-shim"
          flutter_shim_path="$cache_root/nix-flutter-shim/$(basename '${pkgs.flutter}')"
          if [ ! -d "$flutter_shim_path" ]; then
            echo "Nix devShell: Copying SDK to writable cache: $flutter_shim_path"
            cp -a '${pkgs.flutter}' "$flutter_shim_path"
            (
              cd "$flutter_shim_path/packages/flutter_tools/gradle"
              chmod +w '.' '.gradle'
            )
          fi

          local_prop_path='android/local.properties'
          if [ -f "$local_prop_path" ]; then
            sed -i '/^flutter\./d' "$local_prop_path"
          fi
          cat >>"$local_prop_path" <<-EOF
          flutter.sdk=$flutter_shim_path
          EOF

          # Override the Maven-downloaded aapt2 with the Nix-patched system aapt2.
          # We have considered using `ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride=...`, where the dot inside the env name
          # is valid in Unix. But in bash we cannot set an env with a dot in its name, and Nix devShells does not provide a way
          # to set an env not relying on bash, we have to rewrite the user's system gradle properties.
          gradle_home="''${GRADLE_USER_HOME:-$HOME/.gradle}"
          mkdir -p "$gradle_home"
          gradle_prop_path="$gradle_home/gradle.properties"
          if [ -f "$gradle_prop_path" ]; then
            sed -i '/^android\.aapt2FromMavenOverride=/d' "$gradle_prop_path"
          fi
          cat >>"$gradle_prop_path" <<-EOF
          android.aapt2FromMavenOverride=$ANDROID_HOME/build-tools/${androidBuildToolsVersion}/aapt2
          EOF
        '';
      };

    };
}
