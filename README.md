# asdf-iyi

[asdf](https://asdf-vm.com) and [mise](https://mise.jdx.dev) plugin for
[iyi](https://iyi.dev), the compiled programming language.

The plugin installs the official release archives from
[`iyilang/iyi`](https://github.com/iyilang/iyi): nothing is built from source,
and every archive is checked against the release's `SHA256SUMS` before it is
unpacked.

## Platforms

| OS      | Architecture          | Archive                            |
| ------- | --------------------- | ---------------------------------- |
| Linux   | x86_64 (glibc 2.31+)  | `iyi-<version>-linux-x86_64.tar.gz` |
| macOS   | arm64 (14.4+)         | `iyi-<version>-darwin-arm64.tar.gz` |
| Windows | x86_64                | `iyi-<version>-windows-x86_64.zip`  |

A platform with no release is refused at install time. iyi 0.12.0 and earlier
published no `SHA256SUMS`; those versions install with a warning, and the
release files are still fetched over HTTPS.

Windows is not an officially supported asdf platform, and mise does not run
asdf plugins there. The plugin still recognizes Windows and installs the zip
when it is run from Git Bash rather than silently picking the Linux archive;
native Windows users should use [iyi's installer](https://iyi.dev/install/).

## asdf

```sh
asdf plugin add iyi https://github.com/sdogruyol/asdf-iyi.git
asdf install iyi latest
asdf set -u iyi latest        # or, on asdf before 0.16: asdf global iyi latest
iyi version
```

For a project, write the version to `.tool-versions`:

```
iyi 0.21.0
```

Upgrade with `asdf plugin update iyi` followed by
`asdf install iyi latest`. `asdf latest iyi` prints the newest release, and
`asdf latest iyi 0.20` the newest matching that prefix.

## mise

mise can install the plugin from this repository directly, no registry entry
needed:

```sh
mise use -g asdf:sdogruyol/asdf-iyi@0.21.0
mise exec -- iyi version
```

Or, under a short name:

```sh
mise plugins install iyi https://github.com/sdogruyol/asdf-iyi
mise use -g iyi@latest
iyi version
```

The equivalent `mise.toml` entry is:

```toml
[tools]
"asdf:sdogruyol/asdf-iyi" = "0.21.0"
```

Versions resolve with `bin/latest-stable`, and the plugin's `bin/download` /
`bin/install` scripts run exactly as they do under asdf.

## Configuration

`IYI_RELEASE_URL` points the plugin at a mirror. It must serve the platform
archive and `SHA256SUMS`, and must be an `https://` or `file://` URL:

```sh
IYI_RELEASE_URL=https://mirror.example/iyi/v0.21.0 asdf install iyi 0.21.0
```

The plugin itself needs `git` (2.18 or newer, for `git ls-remote --sort`),
`curl` and `tar` (`unzip` on Windows), plus a `sha256sum` or `shasum` to verify
downloads. Building iyi programs also needs a C toolchain — `cc` on Linux and
macOS, the MSVC toolset and Windows SDK on Windows — which the release archives
do not carry.

## How it works

- `bin/list-all` lists release tags over Git, so it needs no GitHub token and
  never hits the API rate limit.
- `bin/latest-stable` returns the newest tag, optionally filtered by prefix.
- `bin/download` fetches the archive for the current platform, verifies it
  against `SHA256SUMS`, and unpacks it into `$ASDF_DOWNLOAD_PATH`.
- `bin/install` copies the unpacked release into `$ASDF_INSTALL_PATH` and runs
  `iyi version` once. On failure the install path is removed, so a retry does
  not look like a completed install.

The archive is installed whole because iyi finds its prelude, stdlib and
Crystal library beside the executable (`bin/../share/iyi`). Installing only
`bin/iyi` would produce a compiler that cannot build anything.

## Development

```sh
asdf plugin test iyi . "iyi version"
```

CI runs the same test under asdf on Linux and macOS, and installs the plugin
under mise on both platforms.

## License

MIT
