{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.gcloud.enable {
    interactiveShellHook = ''
      gcloudAccount=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
      if [ -z ''${gcloudAccount:+set} ]; then
        echo "Google Cloud SDK is not authorized"
        read -rp "In the browser tab about to open, authenticate to your Expo Google Cloud account. (press enter to continue)"
        gcloud auth login
      fi
      if ! gcloud auth application-default print-access-token&>/dev/null; then
        read -rp "You don't have any default application credentials for Google Cloud. In the browser tab about to open, authorize the use of your Expo Google Cloud account. (press enter to continue)"
        gcloud auth application-default login
      fi
    '';
  };
}
