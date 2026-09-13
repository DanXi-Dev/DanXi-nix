# Regenerates packages/deps.json with the upstream mitm-cache updateScript and
# then drops the "Google Play SDK Index" metadata endpoint
#   https://dl.google.com/play-sdk/index/snapshot(.gz)
# from the freshly generated lockfile by its current URL. AGP fetches it during
# normal builds but never needs it to build (a sealed build just 404s on it and
# continues, see d403373), and its content changes on every run, so its
# recorded hash would otherwise keep churning packages/deps.json.
#
# Run with `nix run .#updateDepsJson` from anywhere inside the repository.
{
  git,
  jq,
  updateScript,
  writeShellApplication,
}:

writeShellApplication {
  name = "update-deps-json";
  runtimeInputs = [
    git
    jq
  ];

  text = ''
    # The upstream mitm-cache script writes packages/deps.json relative to the
    # current directory, so relocate to the repository root first.
    cd "$(git rev-parse --show-toplevel)"

    '${updateScript}'

    jq '
      del(."https://dl.google.com"."play-sdk/index/snapshot")
      | if (."https://dl.google.com" // {}) | length == 0 then del(."https://dl.google.com") else . end
    ' "packages/deps.json" | sponge "packages/deps.json"
  '';
}
