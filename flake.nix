{
  description = "A very basic flake for the DanXi project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nix-wpe-webkit.url = "github:eval-exec/nix-wpe-webkit";
  };

  outputs = { self, nixpkgs, nix-wpe-webkit }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          nix-wpe-webkit.overlays.default
          (final: prev: {
            wpewebkit = prev.wpewebkit.overrideAttrs (old: {
              buildInputs = (old.buildInputs or [ ]) ++ [ final.expat ];
            });
          })
        ];
        config.allowUnfreePredicate = pkg: builtins.elem
          (nixpkgs.lib.getName pkg) [ "google-chrome" ];
      };
      defaultDanXiPkg = pkgs.callPackage ./default.nix { };
    in
    {

      defaultPackages.${system} = defaultDanXiPkg;
      packages.${system}.default = defaultDanXiPkg;

      devShells.${system}.default = pkgs.mkShell {
        inherit (defaultDanXiPkg) nativeBuildInputs;

        buildInputs = with pkgs; [
          flutter
          google-chrome
        ] ++ defaultDanXiPkg.buildInputs;

        env = {
          FLUTTER_ROOT = "${pkgs.flutter}";
          CHROME_EXECUTABLE = "google-chrome-stable";
        };

        shellHook = ''
          dart run intl_utils:generate
          dart run build_runner build --delete-conflicting-outputs
        '';
      };

    };
}
