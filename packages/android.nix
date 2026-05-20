{ androidSdk
, bash
, danXiRepo
, flutter
, gradle_9
, jdk23
, lib
, ninja
}:

let
  linkFlutterShim = danXiRepo.linkFlutterShimWith {
    inherit flutter;
    root = "$TMPDIR";
  };

  generatedSrc = (flutter.buildFlutterApplication (finalAttrs: {
    inherit (danXiRepo) src pname version meta autoPubspecLock gitHashes;

    nativeBuildInputs = [
      gradle_9
      jdk23
      ninja
    ];

    env = {
      ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
    };

    preBuild = ''
      cp -a "$src/." .
      chmod -R +w .

      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"

      ${linkFlutterShim}

      local_prop_path='android/local.properties'
      cat >>"$local_prop_path" <<-EOF
      flutter.sdk=$FLUTTER_ROOT
      EOF

      ${danXiRepo.configureAapt2}

      export PATH="${ninja}/bin:$PATH"

      ${danXiRepo.generateDartFiles}

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

      runHook postBuild
    '';

    installPhase = ''
      mkdir -p "$out"
      cp -aL . "$out"
    '';
  })).overrideAttrs (oldAttrs: {
    outputs = lib.lists.subtractLists
      [ "debug" "pubcache" ]
      oldAttrs.outputs;
  });
in

(flutter.buildFlutterApplication (finalAttrs: {
  inherit (danXiRepo) pname version meta autoPubspecLock gitHashes;

  src = generatedSrc;

  nativeBuildInputs = [
    gradle_9
    jdk23
    ninja
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
    "--stacktrace"
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
    fi

    local_prop_path='android/local.properties'
    cat >>"$local_prop_path" <<-EOF
    flutter.sdk=$FLUTTER_ROOT
    EOF

    ${danXiRepo.configureAapt2}

    export PATH="${ninja}/bin:$PATH"
  '';

  buildPhase = ''
    runHook preBuild

    # gradle already includes -p android --stacktrace from gradleFlags
    args=(
      gradle
      --no-daemon
      --full-stacktrace --info -Pverbose=true
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
