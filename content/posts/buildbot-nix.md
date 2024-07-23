# Buildbot-nix

In this article my journey that let me to create [buildbot-nix](https://github.com/Mic92/buildbot-nix),
an extension to the buildbot CI framework to make nix a first class citizen.

## How did it come to be, what was the initial motivation?

Since maintain a number of project around nix, I often also need a CI to build and test nix-based projects.

Over the years, I tried almost every CI that exists: Hydra, Hercules CI, self-hosted GitHub Actions, Garnix, Drone.io, Gitlab runner, Gitea runner.

<!--
If you know, I fork everything. All of these projects are doing great things, but they were't exactly hittin spot you know?
-->

The main thing that was missing was:

- Fast evaluation
- Good github integration
- Support for contributor pull-requests
- It should share the same /nix/store for all the builds, for speed
- Support for virtualization for NixOS tests
- Build matrix based on Nix
- No arbitrary code outside of the Nix sandbox (like GitHub Actions).

What if all we needed for CI, was a flake, and the CI would build that.

## Why buildbot

## What are the requirements?

## What's the status of it, what can it do?

## What is the vision?

You start this with a vision in mind, what is the status, and what are the things that are missing, that you want to do. And what if other people are helping you, would it help to get other things done?

## Validation: Where is it being used?

## How does it compare to Hydra? Hercules CI
