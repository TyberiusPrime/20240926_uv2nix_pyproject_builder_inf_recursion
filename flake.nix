{
  description = "A basic flake using uv2nix";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";
    uv2nix.url = "github:/adisbladis/uv2nix";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";
    pyproject-nix.url = "github:/nix-community/pyproject.nix";
    pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.inputs.pyproject-nix.follows = "pyproject-nix";
  };
  outputs = {
    nixpkgs,
    uv2nix,
    #pyproject-nix,
    ...
  }: let
    #inherit (nixpkgs) lib;
    lib = nixpkgs.lib // {match = builtins.match;};

    pyproject-nix = uv2nix.inputs.pyproject-nix;
    workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./.;};

    pkgs = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };

    defaultPackage = let
      # Generate overlay
      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
      pyprojectOverrides = final: prev: {
        jaeger-client = prev.jaeger-client.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs or [] ++ (final.resolveBuildSystem {setuptools = [];});
        });
        opentracing = prev.opentracing.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs or [] ++ (final.resolveBuildSystem {setuptools = [];});
        });
        threadloop = prev.threadloop.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs or [] ++ (final.resolveBuildSystem {setuptools = [];});
        });

        thrift = prev.thrift.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs or [] ++ (final.resolveBuildSystem {setuptools = [];});
        });
      };
      interpreter = pkgs.python310; # 3.9 and 3.10 >infinite recursion, 3.11/3.12 work
      spec = {
        app = [];
      };

      # Construct package set
      pythonSet' =
        (pkgs.callPackage pyproject-nix.build.packages {
          python = interpreter;
        })
        .overrideScope
        overlay;

      # Override host packages with build fixups
      pythonSet = pythonSet'.pythonPkgsHostHost.overrideScope pyprojectOverrides;
    in
      # Render venv
      pythonSet.mkVirtualEnv "test-venv" spec;
  in {
    packages.x86_64-linux.default = defaultPackage;
    # TODO: A better mkShell withPackages example.
  };
}
