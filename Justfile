# Generate new blog post, i.e. `just new nix-ld` -> content/posts/nix-ld.md
new NAME:
    hugo new "posts/{{NAME}}.md" || true
    ${EDITOR:-vim} "./content/posts/{{NAME}}.md"

# Build website
build:
    hugo

# Open local server for the blog
serve:
    hugo server

spellcheck:
    typos ./content

# Format content
fmt:
     treefmt
