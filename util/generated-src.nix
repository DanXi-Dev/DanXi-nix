{ danXiRepo
, flutter
, gradle_9
, lib
}:

(flutter.buildFlutterApplication (finalAttrs: {
  inherit (danXiRepo) src version meta autoPubspecLock gitHashes;

  pname = "${danXiRepo.pname}-generated-src";

  nativeBuildInputs = [
    gradle_9
  ];

  buildPhase = ''
    runHook preBuild

    ${danXiRepo.generateDartFiles}

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
})
