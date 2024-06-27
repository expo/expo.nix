{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.expo.aws = {
    enable = lib.mkEnableOption "project which interacts with Amazon Web Services";
    profile = lib.mkOption {
      description = "The shell's AWS configuration profile ($AWS_PROFILE)";
      default = "expo";
      type = lib.types.str;
    };
  };
  config =
    let
      cfg = config.expo.aws;
    in
    lib.mkIf cfg.enable {
      env.AWS_PROFILE = cfg.profile;
      packages = [ pkgs.awscli2 ];
      interactiveShellHook = ''
        if ! aws configure list; then
          echo "Set your AWS access key id and secret access key! (Other values can be blank)"
          aws configure --profile "$AWS_PROFILE"
        fi
      '';
    };
}
