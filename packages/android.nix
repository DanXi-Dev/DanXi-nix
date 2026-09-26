{ androidSdk
, bash
, callPackage
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

  src = callPackage ../util/generated-src.nix { inherit danXiRepo; };

  nativeBuildInputs = [
    gradle_9
    jdk23
  ];

  mitmCache = gradle_9.fetchDeps {
    pkg = finalAttrs.finalPackage;
    data = ./deps.json;
    # bwrap's --clearenv removes /bin/sh which ninja needs to spawn
    # build commands. Symlink bash from the Nix store into the sandbox.
    bwrapFlags = "--symlink ${bash}/bin/bash /bin/sh";
  };
  # this is required for using mitm-cache on Darwin
  __darwinAllowLocalNetworking = true;

  gradleUpdateTask = "assembleRelease";
  gradleFlags = [
    "-p android"
  ];

  env = {
    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
  };

  preBuild = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    ${linkFlutterShim}

    # When MITM_CACHE_HOST is set (update script only), delete the default
    # jvmargs line and rewrite it WITH proxy/truststore settings so the
    # Gradle daemon JVM picks them up (command-line -D flags aren't
    # forwarded to the daemon).
    if [[ -n ''${MITM_CACHE_HOST:-} ]]; then
      if [[ -f android/gradle.properties ]]; then
        args=(
          sed
          -i
          '/^[[:space:]]*org\.gradle\.jvmargs[[:space:]]*=/d'
          android/gradle.properties
        ) && "''${args[@]}"
      fi
      args=(
        -Xmx4096M
        -XX:MaxNewSize=4G
        -Dhttps.proxyHost="$MITM_CACHE_HOST"
        -Dhttps.proxyPort="$MITM_CACHE_PORT"
        -Dhttp.proxyHost="$MITM_CACHE_HOST"
        -Dhttp.proxyPort="$MITM_CACHE_PORT"
        -Djavax.net.ssl.trustStore="''${MITM_CACHE_KEYSTORE:-$MITM_CACHE_CERT_DIR/keystore}"
        -Djavax.net.ssl.trustStorePassword="''${MITM_CACHE_KS_PWD:-}"
      )
      cat >>android/gradle.properties <<EOF

    org.gradle.jvmargs=''${args[*]}
    EOF

      # Flutter's build runs android/gradlew directly. Its bundled wrapper
      # would download a Gradle distribution from services.gradle.org (not
      # reachable in the sandbox) and would bypass the nixpkgs Gradle hook.
      # Flutter only injects its wrapper when android/gradlew is missing, so
      # drop a shim that execs the Nix Gradle with the flags the hook already
      # assembled in gradleFlagsArray (init script + mitm-cache proxy and
      # truststore). No `-p android` here: Flutter runs with cwd=android/.
      gradle_flags="$(printf '%q ' "''${gradleFlagsArray[@]}")"
      cat >android/gradlew <<GRADLEW
    #!${bash}/bin/bash
    case "\$1" in
      --version|-v) exec gradle "\$@";;
    esac
    exec gradle ''${gradle_flags} "\$@"
    GRADLEW
      chmod +x android/gradlew

    fi

    local_prop_path='android/local.properties'
    cat >>"$local_prop_path" <<-EOF
    flutter.sdk=$FLUTTER_ROOT
    EOF

    ${danXiRepo.configureAapt2}

    echo 'Generate the debug keystore.'
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

    # Flutter writes flutter.versionName/versionCode into
    # android/local.properties from pubspec.yaml before invoking Gradle, so
    # the APK carries the real version. --no-pub: package_config.json comes
    # from the Nix pubcache and pub would try to reach pub.dev in the sandbox.
    flutter build apk --release --no-pub

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
