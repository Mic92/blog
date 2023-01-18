# Generate new blog post. i.e. hugo new posts/nix-ld.md
new PAGE:
    hugo new "{{PAGE}}" || true
    ${EDITOR:-vim} "./content/{{PAGE}}"

# Build website
build:
    hugo

# Open local server for the blog
serve:
    hugo server
