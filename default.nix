{ flutter
, glib
, lib
, libGL
, libsecret
, libsoup_3
, libwpe
, libwpe-fdo
, libxkbcommon
, pkgs
, pkg-config
, wpewebkit
, wayland
}:

let
  nlohmannJsonSrc = pkgs.fetchFromGitHub {
    owner = "nlohmann";
    repo = "json";
    rev = "v3.11.3";
    sha256 = "sha256-7F0Jon+1oWL7uqet5i1IgHX0fUw/+z0QwEcA3zs5xHg=";
  };
  customFlutterInappwebviewLinux = { src, ... }: pkgs.runCommand
    "custom-flutter_inappwebview_linux"
    { passthru = src.passthru; }
    '' cp -R '${src}' "$out"
      # chmod -R u+w "$out"

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
flutter.buildFlutterApplication rec {
  pname = "dan_xi";
  version = "1.5.2+349";

  meta = with lib; {
    description =
      "[Windows / Mac / Linux / Android / iOS] Maybe the best all-rounded service app for Fudan University students. 可能是复旦学生最好的第三方校园服务APP。";
    platforms = platforms.linux;
    license = licenses.gpl3;
  };

  src = ./.;
  targetFlavor = "linux";

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

  autoPubspecLock = src + "/pubspec.lock";
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


  customSourceBuilders = {
    flutter_inappwebview_linux = customFlutterInappwebviewLinux;
  };

  preBuild = ''
    packageRun intl_utils -e generate
    packageRun build_runner build --delete-conflicting-outputs
  '';
}
