{
  description = "A very basic flake for the DanXi project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-android.url =
      "github:sseu-buhzzi/nixpkgs?ref=20260505/fix-android-ndk-path";
    nixpkgs-jdk23.url = "github:nixos/nixpkgs?ref=25.05";
    nix-wpe-webkit.url = "github:eval-exec/nix-wpe-webkit";
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-android
    , nixpkgs-jdk23
    , nix-wpe-webkit
    }:
    let
      system = "x86_64-linux";
      unfreeConfig = {
        allowUnfreePredicate = pkg:
          builtins.elem (pkgs.lib.getName pkg) [
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
          "30.0.14904198-rc1"
        ];
      };
      androidSdk = androidPkg.androidsdk;

      danXiRepo = {
        pname = "dan_xi";
        version = "1.5.2+349";

        meta = with pkgs.lib; {
          description =
            "[Windows / Mac / Linux / Android / iOS] Maybe the best all-rounded service app for Fudan University students. 可能是复旦学生最好的第三方校园服务APP。";
          homepage = "https://danxi.fduhole.com";
          license = licenses.gpl3Only;
          platforms = platforms.linux;
          maintainers = [ ];
        };

        autoPubspecLock = ../.. + "/pubspec.lock";
        gitHashes = {
          flutter_inappwebview_linux =
            "sha256-alwvKGs1mnM+JGOGBzV8d6PRAcAXaZA6AZ08X7zd6/M=";
          flutter_markdown_plus =
            "sha256-2Sd7elkECZQ3+NGSdx39BHJ9GYsSglCWLMwxZBFLO4A=";
          flutter_progress_dialog =
            "sha256-L8TD7HXLQdqnQHU40fOrtCEa962WCB1Gm5bHy0TB6JI=";
          flutter_secure_storage_linux =
            "sha256-cFNHW7dAaX8BV7arwbn68GgkkBeiAgPfhMOAFSJWlyY=";
          ical =
            "sha256-/f51DJkshr3VQ8CJdh7k+lNJ2gohCl2iI9Vx1YRol8Q=";
          linkify =
            "sha256-IgSrhN5EkTM+Wua5Ns5rS90iR5zSlA3QpVWWXJYE6sQ=";
          receive_intent =
            "sha256-wzYDVZZdaoxwCXLJLJDTNUzpl/brroUSyjB9s2AAWl8=";
          xiao_mi_push_plugin =
            "sha256-5emwkL33CU/k/FHY3EccRyPE/UUs3+i0+tXfMPa6Z4M=";
        };

        linkFlutterShimWith = { flutter, root }: ''
          shim_root="${root}"

          # Cannot run android/.gradlew directly since
          # `/flutter_tools/gradle/.gradle` is immutable.
          # `https://github.com/NixOS/nixpkgs/issues/395096`
          mkdir -p "$shim_root/nix-flutter-shim"
          flutter_shim_path="$shim_root/nix-flutter-shim/$(basename '${flutter}')"
          if [ ! -d "$flutter_shim_path" ]; then
            echo "Nix devShell: Copying SDK to writable cache: $flutter_shim_path"
            cp -a '${flutter}' "$flutter_shim_path"
            (
              cd "$flutter_shim_path/packages/flutter_tools/gradle"
              chmod +w '.' '.gradle'
            )
          fi

          # Because `flutter build apk` will overwrite the
          # `android/local.properties` to set the flutter SDK into
          # `/nix/store` which is immutable, we need to add another
          # method to inform the `pluginManagement.includeBuild()` to
          # use the shim like using environment variables.
          export FLUTTER_ROOT="$flutter_shim_path"
        '';

        configureAapt2 = ''
          # Override the Maven-downloaded aapt2 with the Nix-patched
          # system aapt2. We have considered using
          # `ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride=...`,
          # where the dot inside the env name is valid in Unix. But in
          # bash we cannot set an env with a dot in its name, and Nix
          # devShells does not provide a way to set an env not relying
          # on bash, we have to rewrite the user's system gradle
          # properties.
          gradle_home="''${GRADLE_USER_HOME:-$HOME/.gradle}"
          mkdir -p "$gradle_home"

          gradle_prop_path="$gradle_home/gradle.properties"
          if [ -f "$gradle_prop_path" ]; then
            args=(
              -i
              '/^\s*android\.aapt2FromMavenOverride\s*=/d'
              "$gradle_prop_path"
            )
            sed "''${args[@]}"
          fi
          cat >>"$gradle_prop_path" <<-EOF
          android.aapt2FromMavenOverride=$ANDROID_HOME/build-tools/${androidBuildToolsVersion}/aapt2
          EOF
        '';
      };
      danXiPackagesDefault = pkgs.callPackage ./packages {
        inherit danXiRepo;
      };
      danXiDevShellsDefault = pkgs.callPackage ./devShells {
        inherit danXiRepo androidSdk danXiPackagesDefault;
      };
    in
    {

      defaultPackage.${system} = danXiPackagesDefault;
      packages.${system}.default = danXiPackagesDefault;

      devShells.${system}.default = danXiDevShellsDefault;

    };
}
