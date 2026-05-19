{ androidSdk
, danXiRepo
, flutter
, google-chrome
, pkgs
, selfPkgs
}:

let
  linkFlutterShim = danXiRepo.linkFlutterShimWith {
    inherit flutter;
    root = "\${XDG_CACHE_HOME:-$HOME/.cache}";
  };
in

pkgs.mkShell {
  nativeBuildInputs = builtins.concatLists [
    selfPkgs.default.nativeBuildInputs
    selfPkgs.android.nativeBuildInputs
  ];

  buildInputs = builtins.concatLists [
    [
      flutter
      androidSdk
      google-chrome
    ]
    selfPkgs.default.buildInputs
    selfPkgs.android.buildInputs
  ];

  env = {
    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
    CHROME_EXECUTABLE = "google-chrome-stable";
  };

  shellHook = ''
    ${linkFlutterShim}

    local_prop_path='android/local.properties'
    if [ -f "$local_prop_path" ]; then
      args=(
        sed -i
        -e '/^\s*flutter\./d'
        -e '/^\s*sdk\.dir=/d'
        "$local_prop_path"
      ) && "''${args[@]}"
    fi
    cat >>"$local_prop_path" <<-EOF
    sdk.dir=$ANDROID_HOME
    flutter.sdk=$FLUTTER_ROOT
    EOF

    ${danXiRepo.configureAapt2}
  '';
}
