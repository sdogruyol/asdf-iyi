# asdf-iyi

[asdf](https://asdf-vm.com) and [mise](https://mise.jdx.dev) plugins for
[iyi](https://iyi.dev), the compiled programming language.

The repository provides both:

- an **asdf plugin** (`bin/`) for asdf on Linux and macOS;
- a **mise tool plugin** (`metadata.lua`, `hooks/`) that also runs on Windows,
  where mise does not support asdf plugins.

Both install the official release archives from
[`iyilang/iyi`](https://github.com/iyilang/iyi): nothing is built from source,
and every archive is checked against a published SHA-256 before it is unpacked.

## Platforms

| OS      | Architecture          | Archive                             | asdf | mise |
| ------- | --------------------- | ----------------------------------- | ---- | ---- |
| Linux   | x86_64 (glibc 2.31+)  | `iyi-<version>-linux-x86_64.tar.gz` | yes  | yes  |
| macOS   | arm64 (14.4+)         | `iyi-<version>-darwin-arm64.tar.gz` | yes  | yes  |
| Windows | x86_64                | `iyi-<version>-windows-x86_64.zip`  | no   | yes  |

A platform with no release is refused at install time. Linux releases are
glibc builds: musl (Alpine) and non-x86_64 Linux, Intel macOS, and arm64
Windows have no release. iyi releases before 0.12.0 published no
`SHA256SUMS`; those versions install with a warning.

asdf has no official Windows support, and **mise does not run asdf plugins on
Windows at all**. That is why this repository also ships the Lua tool plugin:
on Windows, install `iyi` through the `vfox:iyi` plugin name, not `asdf:`.

## mise

mise uses the native Lua tool plugin in this repository. Install it under the
name `vfox:iyi`, then use `iyi`:

```sh
mise plugins install vfox:iyi https://github.com/sdogruyol/asdf-iyi
mise use -g iyi@0.21.0
mise exec -- iyi version
```

The equivalent `mise.toml` entry, once the plugin is installed on the machine,
is:

```toml
[tools]
iyi = "0.21.0"
```

For a project, run `mise use iyi@0.21.0` in the project directory instead of
`-g`.

If you tried the old instruction and mise already cloned this repository as an
asdf plugin, remove it first:

```sh
mise plugins uninstall asdf:sdogruyol/asdf-iyi
mise plugins install vfox:iyi https://github.com/sdogruyol/asdf-iyi
mise use -g iyi@0.21.0
```

`mise plugins install iyi <url>` without the `vfox:` prefix installs the
repository as an asdf plugin, so it fails on Windows. Use `vfox:iyi`.

The Lua plugin lists only versions that publish an archive for the current
platform, so `mise ls-remote iyi` on Windows starts at 0.14.0 and on macOS at
0.5.1.

## asdf

Linux and macOS only; asdf is not supported on Windows.

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

## Configuration

The asdf plugin honours `IYI_RELEASE_URL`: it must serve the platform archive
and `SHA256SUMS`, and must be an `https://` or `file://` URL:

```sh
IYI_RELEASE_URL=https://mirror.example/iyi/v0.21.0 asdf install iyi 0.21.0
```

The mise plugin uses mise's own download path and honours mise's
[`url_replacements`](https://mise.jdx.dev/url-replacements.html) for mirrors.

Requirements:

- **asdf plugin:** `git` (2.18 or newer, for `git ls-remote --sort`), `curl`,
  `tar` (`unzip` on Windows), and `sha256sum` or `shasum`.
- **mise plugin:** `mise` itself. It downloads, verifies and extracts the
  archive; Git is only needed to clone this plugin repository.
- **Building iyi programs:** a C toolchain — `cc` on Linux and macOS, the MSVC
  toolset and Windows SDK on Windows — which the release archives do not carry.

## How it works

asdf (`bin/`):

- `bin/list-all` lists release tags over Git, so it needs no GitHub token and
  never hits the API rate limit.
- `bin/latest-stable` returns the newest tag, optionally filtered by prefix.
- `bin/download` fetches the archive for the current platform, verifies it
  against `SHA256SUMS`, and unpacks it into `$ASDF_DOWNLOAD_PATH`.
- `bin/install` copies the unpacked release into `$ASDF_INSTALL_PATH` and runs
  `iyi version` once. On failure the install path is removed, so a retry does
  not look like a completed install.

mise (`metadata.lua`, `hooks/`):

- `hooks/available.lua` reads the GitHub releases API and returns the versions
  with an archive for the current platform.
- `hooks/pre_install.lua` returns the archive URL and its SHA-256, taken from
  the release asset digest or `SHA256SUMS`; mise downloads, verifies and
  extracts it.
- `hooks/env_keys.lua` puts the installed `bin` directory on `PATH`.

The archive is installed whole because iyi finds its prelude, stdlib and
Crystal library beside the executable (`bin/../share/iyi`). Installing only
`bin/iyi` would produce a compiler that cannot build anything.

## Development

```sh
# asdf plugin (Linux/macOS)
asdf plugin test iyi . "iyi version"

# mise tool plugin
mise plugins link iyi .
mise ls-remote iyi
mise use iyi@0.21.0
mise exec -- iyi version
```

CI runs the asdf test on Linux and macOS, and the mise test on Linux, macOS and
Windows.

## License

MIT
