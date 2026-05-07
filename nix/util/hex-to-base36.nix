{ python3
, runCommand
}:

hex:
let
  hexToBase36Pkg = runCommand "hex-to-base36"
    {
      src = ./hex_to_base36.py;
      buildInputs = [ python3 ];
    } ''
    echo '#### hex-to-base36: ${hex}'
    python3 "$src" ${hex} >$out
  '';
  base36 = builtins.readFile hexToBase36Pkg;
in
base36
