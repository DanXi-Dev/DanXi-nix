{ danXiRepo
, fetchFromGitHub
, flutter
, glib
, libGL
, libsecret
, libsoup_3
, libwpe
, libwpe-fdo
, libxkbcommon
, pkg-config
, runCommand
, wpewebkit
, wayland
}:

let
  nlohmannJsonSrc = fetchFromGitHub {
    owner = "nlohmann";
    repo = "json";
    rev = "v3.11.3";
    sha256 = "sha256-7F0Jon+1oWL7uqet5i1IgHX0fUw/+z0QwEcA3zs5xHg=";
  };
  customFlutterInappwebviewLinux = { src, ... }: runCommand
    "custom-flutter_inappwebview_linux"
    { passthru = src.passthru; }
    ''
      cp -r '${src}' "$out"

      cmakeFile="$out/${src.passthru.packageRoot}/linux/CMakeLists.txt"
      args=(
        "$cmakeFile"
        --replace-fail
        'URL https://github.com/nlohmann/json/releases/download/v''${NLOHMANN_JSON_VERSION}/json.tar.xz'
        'SOURCE_DIR ${nlohmannJsonSrc}'
      )
      substituteInPlace "''${args[@]}"
    '';
in

flutter.buildFlutterApplication {
  inherit (danXiRepo) src pname version meta autoPubspecLock gitHashes;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    wpewebkit
    glib
    libsoup_3
    libwpe
    libwpe-fdo
    libsecret
    libxkbcommon
    libGL
    wayland
  ];

  customSourceBuilders = {
    flutter_inappwebview_linux = customFlutterInappwebviewLinux;
  };

  preBuild = ''
    ${danXiRepo.generateDartFiles}
  '';
}
