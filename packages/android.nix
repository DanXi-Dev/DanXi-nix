{
  androidSdk,
  bash,
  callPackage,
  danXiRepo,
  flutter,
  gradle_9,
  jdk23,
  lib,
}:

let
  linkFlutterShim = danXiRepo.linkFlutterShimWith {
    inherit flutter;
    root = "$TMPDIR";
  };
in

(flutter.buildFlutterApplication (finalAttrs: {
  inherit (danXiRepo)
    pname
    version
    meta
    autoPubspecLock
    gitHashes
    ;

  src = callPackage ../util/generated-src.nix { inherit danXiRepo; };

  # AGP's SdkDependencyDataGeneratorTask (Play SDK Console metadata) embeds a
  # non-reproducible blob into the APK signing block, so repeated builds of the
  # same derivation differ. The blob has no effect on the installed app, so turn
  # it off to make the APK deterministic.
  patches = [
    ./android-dependencies-info.patch
  ];
  # -F0 disables fuzz, so a drifted context fails the build instead of being
  # silently applied somewhere else.
  patchFlags = [
    "-p1"
    "-F0"
  ];

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

  gradleUpdateTask = "assembleRelease --info";
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

    # When MITM_CACHE_HOST is set (recording and sealed replay builds, both
    # run under mitm-cache), delete the default jvmargs line and rewrite it
    # WITH proxy/truststore settings so the Gradle daemon JVM picks them up
    # (command-line -D flags aren't forwarded to the daemon).
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

    # Use the keystore committed in this repository instead of running
    # `keytool -genkey`: keytool cannot be made deterministic (random RSA
    # key, random certificate serial, current-time validity), so every build
    # would sign the APK with a different certificate. This is the standard
    # public Android debug key, not a release signing secret.
    cat >android/key.properties <<-EOF
    storeFile=${./android-debug.keystore}
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
})).overrideAttrs
  (oldAttrs: {
    outputs = lib.lists.subtractLists [
      "debug"
      "pubcache"
    ] oldAttrs.outputs;

    # `flutter` calls `BotDetector.isRunningOnBot` on startup
    # (flutter_tools/.../runner/flutter_command_runner.dart). Without a CI
    # marker it falls through to `AzureDetector`, which probes the Azure
    # instance metadata endpoint
    #   http://169.254.169.254/metadata/instance
    # (flutter_tools/.../base/bot_detector.dart). In mitm-cache builds (the
    # update-deps recording and the sealed replay) http(s)_proxy points at
    # mitm-cache, and Flutter only bounds the socket to the proxy
    # (HttpClient.connectionTimeout); `request.close()` has no timeout, so the
    # probe waits for mitm-cache's own upstream connect to 169.254.169.254 to
    # give up. That address is routed into the TUN and never answered here, so
    # the probe stalls until the kernel's SYN retries exhaust (host-dependent,
    # up to minutes) once per build. BOT=true makes `isRunningOnBot` return
    # before any network I/O and matches this unattended build (analytics/update
    # checks off).
    #
    # nixpkgs sets `sdkSetupScript` on its right-hand side, so it can only be
    # extended here; the upstream script is kept and our export prepended.
    #
    # This also covers the update-deps recording run: `finalAttrs.finalPackage`
    # resolves to this fully overridden derivation, and gradle's fetchDeps
    # re-derives `pkg` from it (pkgs/.../gradle/update-deps.nix).
    sdkSetupScript = ''
      export BOT=true
    ''
    + (oldAttrs.sdkSetupScript or "");
  })
