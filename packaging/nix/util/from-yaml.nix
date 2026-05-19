{ runCommand
, yq
}:

yaml:

let
  yamlFile =
    if builtins.isPath yaml then yaml
    else builtins.toFile "input.yaml" yaml;
  yamlToJson = runCommand "yamlToJson"
    {
      nativeBuildInputs = [ yq ];
    }
    ''
      yq . '${yamlFile}' >"$out"
    '';
  parsedYaml = builtins.fromJSON (builtins.readFile yamlToJson);
in
parsedYaml

