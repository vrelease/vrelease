# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

vrelease is a lightweight release tool for GitHub and GitLab written in Nim. It automatically generates releases with changelogs from git tags, requiring only `git` as an external dependency. The tool detects repository metadata (provider, protocol, username, repository) from the git remote URL.

## Build Commands

```bash
# Development build
make build

# Release build (optimized + stripped)
make release

# Run tests
make tests

# Clean build artifacts
make clean
```

The build process runs `writemeta.nim` first to generate `src/vr/meta.nim` from `src/vr/_meta`, injecting version info (git tag), commit hash, and compilation metadata.

## Architecture

**Entry point:** `src/vrelease.nim` → calls `main()` which orchestrates the release flow

**Core modules under `src/vr/`:**
- `cli/parser.nim` - CLI argument parsing using docopt library
- `cli/logger.nim` - Singleton logger with info/debug levels and color support
- `git/program.nim` - Git interface: remote URL parsing, tag listing, commit log extraction
- `git/release.nim` - Release object definition (creation logic incomplete)
- `attacheable.nim` - File attachment handling with optional SHA256 checksum
- `html.nim` - HTML changelog builder (incomplete)
- `helpers.nim` - Utility functions: command execution, string manipulation, terminal colors
- `meta.nim` - Auto-generated build metadata (do not edit directly; edit `_meta` template)

**Main flow:**
1. Parse CLI args → validate git availability → get auth token from `VRELEASE_AUTH_TOKEN` env
2. Parse remote URLs to identify provider (GitHub/GitLab) and protocol (HTTP/HTTPS/SSH)
3. Get tags sorted by date, filter to semver-compliant tags only
4. Extract commits between the two most recent semver tags
5. Build HTML changelog and create release via provider API

## Dependencies

Defined in `vrelease.nimble`:
- `nim >= 1.6.0`
- `docopt >= 0.7.1` (CLI parsing)
- `nimSHA2 >= 0.1.1` (checksum calculation)
- `semver >= 1.2.3` (version tag filtering)

## Key Patterns

- Logger is a singleton initialized once and retrieved via `getLogger()`
- `helpers.execCmd()` wraps shell commands with error handling
- `helpers.mapC()` provides indexed map iteration
- Git remote parsing handles SSH (`git@host:user/repo`) and HTTP(S) (`https://host/user/repo`) formats
