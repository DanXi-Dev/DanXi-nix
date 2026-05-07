{ androidSdk
, danXiPackagesDefault
, danXiRepo
, flutter
, google-chrome
, jdk23
, pkgs
}:

let
  linkFlutterShim = danXiRepo.linkFlutterShimWith {
    inherit flutter;
    root = "\${XDG_CACHE_HOME:-$HOME/.cache}";
  };
in

pkgs.mkShell {
  inherit (danXiPackagesDefault) nativeBuildInputs;

  buildInputs = [
    androidSdk
    google-chrome

    jdk23
  ] ++ danXiPackagesDefault.buildInputs;

  env = {
    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
    CHROME_EXECUTABLE = "google-chrome-stable";
  };

  shellHook = ''
    ${linkFlutterShim}

    local_prop_path='android/local.properties'
    if [ -f "$local_prop_path" ]; then
      sed -i '/^\s*flutter\./d' "$local_prop_path"
    fi
    cat >>"$local_prop_path" <<-EOF
    flutter.sdk=$FLUTTER_ROOT
    EOF

    ${danXiRepo.configureAapt2}
  '';
}
