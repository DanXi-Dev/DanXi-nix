{ runCommand
, yq
}:

yaml:

let
  yamlToJson = runCommand "yamlToJson"
    {
      nativeBuildInputs = [ yq ];
      env.INPUT_YAML = toString yaml;
    }
    ''
      yq . "$INPUT_YAML" >"$out"
    '';
  parsedYaml = builtins.fromJSON (builtins.readFile yamlToJson);
in
parsedYaml

