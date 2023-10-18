{ pkgs
, config
, lib
, ...
}:
let
  cfg = config.languages.javascript;

  nodeModulesPath = "node_modules";

  pms = {
    npm = {
      install = "npm install";
      lock = "package-lock.json";
    };
    pnpm = {
      install = "pnpm install";
      lock = "pnpm-lock.yaml";
    };
    yarn = {
      install = "yarn";
      lock = "yarn.lock";
    };
  };

  initScriptTemplate = pm: ''
    function _devenv-${pm}-install()
    {
      # Avoid running "${pms.${pm}.install}" for every shell.
      # Only run it when the "${pms.${pm}.lock}" file or nodejs version has changed.
      # We do this by storing the nodejs version and a hash of "${pms.${pm}.lock}" in node_modules.
      local ACTUAL_NPM_CHECKSUM="${cfg.package.version}:$(${pkgs.nix}/bin/nix-hash --type sha256 ${pms.${pm}.lock})"
      local NPM_CHECKSUM_FILE="${nodeModulesPath}/${pms.${pm}.lock}.checksum"
      if [ -f "$NPM_CHECKSUM_FILE" ]
        then
          read -r EXPECTED_NPM_CHECKSUM < "$NPM_CHECKSUM_FILE"
        else
          EXPECTED_NPM_CHECKSUM=""
      fi

      if [ "$ACTUAL_NPM_CHECKSUM" != "$EXPECTED_NPM_CHECKSUM" ]
      then
        if ${cfg.package}/bin/${pms.${pm}.install}
        then
          echo "$ACTUAL_NPM_CHECKSUM" > "$NPM_CHECKSUM_FILE"
        else
          echo "Npm install failed. Run '${pms.${pm}.install}' manually."
        fi
      fi
    }

    if [ ! -f package.json ]
    then
      echo "No package.json found. Run '${pm} init' to create one." >&2
    else
      _devenv-${pm}-install
    fi
  '';
  initNpmScript = pm: pkgs.writeShellScript "init-${pm}.sh" (initScriptTemplate pm);
in
{
  options.languages.javascript = {
    enable = lib.mkEnableOption "tools for JavaScript development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nodejs;
      defaultText = lib.literalExpression "pkgs.nodejs";
      description = "The Node package to use.";
    };

    corepack = {
      enable = lib.mkEnableOption "shims for package managers besides npm";
    };

    npm.install = {
      enable = lib.mkEnableOption "npm install during devenv initialisation";
    };
    pnpm.install = {
      enable = lib.mkEnableOption "pnpm install during devenv initialisation";
    };
    yarn.install = {
      enable = lib.mkEnableOption "yarn install during devenv initialisation";
    };
  };

  config = lib.mkIf cfg.enable {
    packages =
      [
        cfg.package
      ]
      ++ lib.optional cfg.corepack.enable (pkgs.runCommand "corepack-enable" { } ''
        mkdir -p $out/bin
        ${cfg.package}/bin/corepack enable --install-directory $out/bin
      '')
      ++ lib.optional cfg.pnpm.install.enable pkgs.nodePackages.pnpm
      ++ lib.optional cfg.yarn.install.enable pkgs.nodePackages.yarn;

    enterShell = lib.concatStringsSep "\n" (
      (lib.optional cfg.pnpm.install.enable ''
        source ${initNpmScript "pnpm"}
      '')
        (lib.optional cfg.yarn.install.enable ''
          source ${initNpmScript "yarn"}
        '')
        (lib.optional cfg.npm.install.enable ''
          source ${initNpmScript "npm"}
        '')
    );
  };
}
