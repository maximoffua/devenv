{ pkgs
, lib
, config
, ...
}:
let
  inherit (lib) types;
  cfg = config.mutagen;
  settingsFormat = pkgs.formats.yaml { };
  file = settingsFormat.generate "mutagen.yaml" cfg.settings;
  configPath = "${config.env.DEVENV_STATE}/mutagen.yaml";
in
{
  options.mutagen = {
    enable = lib.mkEnableOption "integration with mutagen.io for file synchronization and port forwarding";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.mutagen;
      description = lib.mdDoc ''
        Package for Mutagen.io installation.
      '';
    };

    settings = lib.mkOption {
      type = types.submodule {
        freeformType = settingsFormat.type;
      };
    };

    default = { };

    description = lib.mdDoc ''
      Mutagen settings which are written to mutagen.yaml project configuration.
    '';
  };

  config = lib.mkIf config.mutagen.enable {
    env.MUTAGEN_PROJECT_FILE = configPath;
    packages = [ cfg.package ];

    enterShell = ''
      if [ ! -f ${configPath} ]; then
        mkdir -p "$(dirname "${configPath}")"
        cat ${file} > ${configPath}
      fi
      mutagen daemon start
      mutagen project list -f ${configPath} >&2 2>/dev/null || mutagen project start -f ${configPath}
    '';
  };
}
