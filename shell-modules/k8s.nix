{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.expo.k8s;
in
{
  options.expo.k8s = {
    enable = lib.mkEnableOption "kubernetes project";
    cluster = lib.mkOption {
      default = null;
      type = lib.types.nullOr lib.types.str;
    };
    region = lib.mkOption {
      default = "us-central1";
      type = lib.types.str;
    };
  };
  config = lib.mkIf cfg.enable {
    packages = [
      pkgs.kubectl
      pkgs.minikube
    ];
    gcloud.enable = true;
    gcloud.extra-components = [ "gke-gcloud-auth-plugin" ];
    interactiveShellHook = lib.optionalString (
      cfg.cluster != null
    ) "gcloud container clusters get-credentials ${cfg.cluster} --region ${cfg.region}";
  };
}
