{ androidSdk
, danXiRepo
, flutter
, gradle_9
, jdk23
, lib
}:

let
  linkFlutterShim = danXiRepo.linkFlutterShimWith {
    inherit flutter;
    root = "$TMPDIR";
  };
in

(flutter.buildFlutterApplication (finalAttrs: {
  inherit (danXiRepo) pname version meta autoPubspecLock gitHashes;

  src = ../../..;

  nativeBuildInputs = [
    flutter
    gradle_9
    jdk23
  ];

  mitmCache = gradle_9.fetchDeps {
    pkg = finalAttrs.finalPackage;
    data = ./deps.json;
  };
  # this is required for using mitm-cache on Darwin
  __darwinAllowLocalNetworking = true;

  env = {
    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
  };

  preBuild = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    ${linkFlutterShim}

    local_prop_path='android/local.properties'
    cat >>"$local_prop_path" <<-EOF
    flutter.sdk=$FLUTTER_ROOT
    EOF

    ${danXiRepo.configureAapt2}

    ${danXiRepo.generateDartFiles}

    # Generate the debug keystore.
    args=(
      keytool
      -genkey -v
      -keystore debug.keystore
      -alias androiddebugkey
      -storepass android
      -keypass android
      -keyalg RSA
      -keysize 2048
      -validity 10000
      -dname 'CN=Android Debug,O=Android,C=US'
    ) && "''${args[@]}"
    cat >android/key.properties <<-EOF
    storeFile=../../debug.keystore
    storePassword=android
    keyAlias=androiddebugkey
    keyPassword=android
    EOF
  '';

  buildPhase = ''
    runHook preBuild

    args=(
      gradle
      --no-daemon
      --full-stacktrace --info -Pverbose=true
      -p android
      assembleRelease
    ) && "''${args[@]}"

    runHook postBuild
  '';

  installPhase = ''
    mkdir -p "$out"
    cp build/app/outputs/flutter-apk/app-release.apk "$out/$name.apk"
  '';
})).overrideAttrs (oldAttrs: {
  outputs = lib.lists.subtractLists
    [ "debug" "pubcache" ]
    oldAttrs.outputs;
})
