{
  description = "blog.thalheim.io";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hugo-vitae = {
      url = "github:datacobra/hugo-vitae";
      flake = false;
    };
    hugo-atom-feed = {
      url = "github:kaushalmodi/hugo-atom-feed";
      flake = false;
    };
    nixbot = {
      url = "github:Mic92/nixbot";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      hugo-vitae,
      hugo-atom-feed,
      nixbot,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
      treefmtFor =
        system:
        treefmt-nix.lib.evalModule (pkgsFor system) {
          projectRootFile = "flake.nix";
          programs.prettier.enable = true;
          settings.formatter.prettier = {
            options = [
              "--prose-wrap"
              "always"
            ];
            # Hugo templates in *.html are not valid HTML for prettier
            includes = nixpkgs.lib.mkForce [
              "*.md"
              "*.yaml"
              "*.yml"
            ];
          };
          programs.nixfmt.enable = true;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          website = pkgs.stdenvNoCC.mkDerivation {
            name = "blog.thalheim.io";
            src = self;
            nativeBuildInputs = [ pkgs.hugo ];
            buildPhase = ''
              runHook preBuild
              mkdir themes
              ln -s ${hugo-vitae} themes/hugo-vitae
              ln -s ${hugo-atom-feed} themes/hugo-atom-feed
              hugo --minify --destination $out
              runHook postBuild
            '';
            dontInstall = true;
          };
          default = self.packages.${system}.website;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            # Hugo needs the themes in ./themes; link them from the flake inputs.
            shellHook = ''
              mkdir -p themes
              ln -sfn ${hugo-vitae} themes/hugo-vitae
              ln -sfn ${hugo-atom-feed} themes/hugo-atom-feed
            '';
            packages = [
              pkgs.bashInteractive
              pkgs.hugo
              pkgs.pandoc
              pkgs.just
              pkgs.typos
              (treefmtFor system).config.build.wrapper
            ];
          };
        }
      );

      formatter = forAllSystems (system: (treefmtFor system).config.build.wrapper);

      herculesCI =
        { primaryRepo, ... }:
        let
          system = "x86_64-linux";
          pkgs = pkgsFor system;
          inherit (nixbot.lib.effects { inherit pkgs; }) mkEffect runIf;
          website = self.packages.${system}.website;
        in
        {
          onPush.default.outputs = {
            checks = self.checks.${system};
            # Publish the website to the gh-pages branch.
            effects.gh-pages = runIf (primaryRepo.branch or null == "main") (mkEffect {
              name = "gh-pages";
              inputs = [ pkgs.git ];
              secretsMap.github.type = "GitToken";
              effectScript = ''
                token=$(jq -r '.github.data.token' "$HERCULES_CI_SECRETS_JSON")
                remote=$(printf '%s' ${nixpkgs.lib.escapeShellArg primaryRepo.remoteHttpUrl} \
                  | sed "s#https://#https://x-access-token:$token@#")

                git config --global user.email "nixbot@thalheim.io"
                git config --global user.name "nixbot"

                work=$(mktemp -d)
                cp -r --no-preserve=mode,ownership ${website}/. "$work/"
                touch "$work/.nojekyll"

                cd "$work"
                git init -q -b gh-pages
                git add -A
                git commit -q -m "Deploy ${primaryRepo.rev}"
                git push -f "$remote" gh-pages
              '';
            });
          };
        };

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          website = self.packages.${system}.website;
          formatting = (treefmtFor system).config.build.check self;

          typos = pkgs.runCommand "typos-check" { nativeBuildInputs = [ pkgs.typos ]; } ''
            typos --config ${self}/typos.toml ${self}/content
            touch $out
          '';
        }
      );
    };
}
