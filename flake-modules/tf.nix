{ flake-parts-lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.expo.tf.enable = lib.mkEnableOption "terraform project";
      config = lib.mkIf config.expo.tf.enable {
        update.after.bash = "nix run ./#update-tf-version";
        packages.update-tf-version = pkgs.writeShellApplication {
          name = "update-tf-version";
          runtimeInputs = [
            pkgs.tenv
            pkgs.ripgrep
            pkgs.gnused
          ];
          # Whenever the flake is updated:
          # 1. Find all subdirectories with terraform files containing a
          # "backend" block.
          # 2. Find any instance of 'required_version = ' in terraform files in
          # those directories.
          # 3. Update the version number using `tenv tf list-remote`
          text = ''
            for rootModule in $(rg 'backend ".*" \{' --type tf --files-with-matches | xargs dirname); do
              rg 'required_version = ' --files-with-matches "$rootModule"/*.tf | xargs sed --in-place "s/required_version.*/required_version = \"$(tenv tf list-remote --stable --descending | head -n 2 | tail -n 1)\"/"
            done
          '';
        };
        treefmt.programs.terraform.enable = true;
        # See shell-modules/tf.nix
        make-shells.default.expo.tf.enable = true;
      };
    }
  );
}
