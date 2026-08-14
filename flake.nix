{
  description = "papicom's macOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, ... }:
    let
      hostname = "papinocom";
    in
    {
      darwinConfigurations.${hostname} =
        nix-darwin.lib.darwinSystem {
          modules = [
            ./nix/darwin.nix
          ];
        };
    };
}

