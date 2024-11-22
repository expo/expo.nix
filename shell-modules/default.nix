{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ./aliases.nix
    ./aws.nix
    ./direnv.nix
    ./dotenv.nix
    ./gcloud.nix
    ./interactive.nix
    ./k8s.nix
    ./skaffold.nix
    ./tf.nix
  ];
  stdenv = pkgs.stdenvNoCC; # Don't include a C compiler in our shells
  # Utilities we've decided to have everywhere
  packages = [
    pkgs.fd
    pkgs.jq
    pkgs.process-compose
    pkgs.ripgrep
    pkgs.shellcheck
    pkgs.shfmt
    pkgs.yamlfmt
    pkgs.yq
  ];
  # shellcheck all our bash code
  additionalArguments = {
    doCheck = true;
    phases = [
      "buildPhase"
      "checkPhase"
    ];
    checkPhase = ''
      ${pkgs.shellcheck}/bin/shellcheck --shell bash <(echo "$shellHook")
    '';
  };
  # Install the yarn corepack shim wherever we install node directly
  javascript.node.corepack-shims = [ "yarn" ];
  javascript.node.env = lib.mkDefault "development";
  # unset some environment variables we never want in shells
  env = {
    CONFIG_SHELL = null;
    DETERMINISTIC_BUILD = null;
    DEVELOPER_DIR = null;
    HOST_PATH = null;
    MACOSX_DEPLOYMENT_TARGET = null;
    NIX_BUILD_CORES = null;
    NIX_CFLAGS_COMPILE = null;
    NIX_DONT_SET_RPATH = null;
    NIX_DONT_SET_RPATH_FOR_BUILD = null;
    NIX_ENFORCE_NO_NATIVE = null;
    NIX_IGNORE_LD_THROUGH_GCC = null;
    NIX_NO_SELF_RPATH = null;
    NIX_STORE = null;
    PATH_LOCALE = null;
    PYTHONHASHSEED = null;
    SOURCE_DATE_EPOCH = null;
    __darwinAllowLocalNetworking = null;
    __impureHostDeps = null;
    __propagatedImpureHostDeps = null;
    __propagatedSandboxProfile = null;
    __sandboxProfile = null;
    __structuredAttrs = null;
    buildInputs = null;
    buildPhase = null;
    builder = null;
    checkPhase = null;
    cmakeFlags = null;
    configureFlags = null;
    depsBuildBuild = null;
    depsBuildBuildPropagated = null;
    depsBuildTarget = null;
    depsBuildTargetPropagated = null;
    depsHostHost = null;
    depsHostHostPropagated = null;
    depsTargetTarget = null;
    depsTargetTargetPropagated = null;
    doCheck = null;
    doInstallCheck = null;
    dontAddDisableDepTrack = null;
    mesonFlags = null;
    name = null;
    nativeBuildInputs = null;
    out = null;
    outputs = null;
    patches = null;
    phases = null;
    preferLocalBuild = null;
    propagatedBuildInputs = null;
    propagatedNativeBuildInputs = null;
    shell = null;
    shellHook = null;
    stdenv = null;
    strictDeps = null;
    system = null;
  };
}
