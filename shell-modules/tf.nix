{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.expo.tf.enable = lib.mkEnableOption "terraform tools";
  config = lib.mkIf config.expo.tf.enable {
    env.TENV_AUTO_INSTALL = "true";
    packages = [
      # We use atlantis to make changes to cloud infrastructure.  Atlantis can
      # read `required_version` statements in tf files.  tenv is a tool for
      # installing and managing terraform versions, which includes a
      # `terraform` shim which also reads `required_version` statements.  But
      # it _also_ includes a `tf` shim which _doesn't_ read `required_version`
      # statements!  To fix this layer a one-line `tf` script alias on top of
      # tenv.
      (pkgs.symlinkJoin {
        name = "tenv-with-working-tf";
        inherit (pkgs.tenv) meta;
        paths = [
          (pkgs.writeShellScriptBin "tf" ''exec ${pkgs.tenv}/bin/terraform "$@"'')
          pkgs.tenv
        ];
      })
    ];
  };
}
