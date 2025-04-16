{
  description = "Phoenix development environment for DatacubePortal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = with pkgs; mkShell {
          packages = [
            # Elixir and Erlang
            beam.packages.erlang_27.elixir_1_18
            
            # Node.js for asset compilation
            nodejs_20
            
            # Git for mix deps
            git
            # SSL certificates
            cacert
          ] 
          ++
          # Linux only
          lib.optionals stdenv.isLinux [
            # For file_system package
            inotify-tools
          ] 
          ++
          # macOS only
          lib.optionals stdenv.isDarwin [
            # For file_system package
            darwin.apple_sdk.frameworks.CoreFoundation
            darwin.apple_sdk.frameworks.CoreServices
          ];

          # Environment variables
          shellHook = ''
            # Set Erlang env for history
            export ERL_AFLAGS="-kernel shell_history enabled"
            
            # Automatically run hex update on entering shell
            echo "Updating Hex to ensure compatibility with Erlang 27..."
            mix local.hex --force
            
            echo "Phoenix development environment ready!"
            echo "Run 'mix deps.get' to fetch dependencies"
          '';
        };
      }
    );
}
