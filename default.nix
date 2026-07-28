with import <nixpkgs> {};
mkShell {
  nativeBuildInputs = [
    bashInteractive
    hugo
    pandoc
    just
    treefmt
    prettier
    typos
  ];
}
