{
  description = "Misskey, a decentralized microblogging platform";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    utils,
    ...
  } @ inputs:
    utils.lib.eachSystem (with utils.lib.system; [x86_64-linux]) (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
      in rec {
        packages.misskey = pkgs.callPackage ./pkg/default.nix {};
        packages.default = packages.misskey;
      }
    )
    // {
      nixosModule = {pkgs, ...} @ args:
        import ./module/misskey.nix (args
          // {misskey = self.packages.${pkgs.system}.misskey;});
    };
}
