<p align="center">
  <p align="center">
    <img width="128" height="128" src="./src-tauri/icons/128x128@2x.png" alt="RML Launcher logo">
  </p>
  <h1 align="center"><b>RML Launcher</b></h1>
  <p align="center">
    The desktop companion for <a href="https://github.com/revolutionxk/roblox-modloader">Roblox ModLoader</a> — manage Studio versions, install the mod loader and your mods, and tune engine flags from one place.
  </p>
</p>

<div align="center">

![develop build](https://img.shields.io/github/actions/workflow/status/revolutionxk/rml-launcher/ci.yml?style=for-the-badge&branch=develop&logo=github&label=develop%20build)
![main build](https://img.shields.io/github/actions/workflow/status/revolutionxk/rml-launcher/ci.yml?style=for-the-badge&branch=main&logo=github&label=main%20build)
![nightly](https://img.shields.io/github/v/release/revolutionxk/rml-launcher?include_prereleases&style=for-the-badge&logo=github&label=release)

</div>

> [!NOTE]
> This project is still in development and may contain bugs or incomplete features.

## Cross-Platform Support

- [x] Windows
- [x] Linux (via [Vinegar](https://github.com/vinegarhq/vinegar))
- [ ] macOS (in progress)

## What it does

- **Instances** — every installed Roblox Studio build is its own instance with its own mod loader, mods and engine flags. Download, launch, set a default, and configure each one independently.
- **Mod Loader installer** — install, update or remove [Roblox ModLoader](https://github.com/revolutionxk/roblox-modloader) per instance, straight from GitHub releases. Channels are resolved dynamically (stable, nightly, experimental, …) so new ones appear automatically. Downloads are verified by size and SHA-256.
- **Mods manager** — import mods from a `.zip` archive or a folder, enable/disable them (without deleting), remove them, and open the mods folder — scoped to each instance.
- **Engine / Fast Flags** — search and edit Studio Fast Flags with per-version profiles, type detection (bool / int / string / list), diff against defaults, and snapshot import/export.

## Quick Start

1. Download the latest build from the [Releases page](https://github.com/revolutionxk/rml-launcher/releases):
   - **Windows** — `.exe` (NSIS) or `.msi`
   - **macOS** — `.dmg` (universal)
   - **Linux** — `.AppImage` or `.deb`
2. Install and open RML Launcher.
3. Go to **Instances → Add**, install a Studio version, then open the instance to install the **Mod Loader** and your **Mods**.
4. Launch Studio from the instance — the loader and enabled mods are applied.

> Nightly builds from the `develop` branch are published as a rolling [`nightly`](https://github.com/revolutionxk/rml-launcher/releases/tag/nightly) pre-release for early testing.

### Linux (Vinegar)

On Linux, Roblox Studio runs through [Vinegar](https://github.com/vinegarhq/vinegar). The launcher replaces the instances list with a single Vinegar surface that:

1. installs Vinegar via Flatpak if it is missing,
2. lets you launch Studio (Vinegar downloads it on first run),
3. installs the mod loader into Vinegar's Studio and enables the Wine `dwmapi` override, and
4. mirrors your engine Fast Flags into Vinegar's `config.toml` (`[studio.fflags]`).

## Development

### Prerequisites

- [Bun](https://bun.sh) (package manager and runtime)
- [Rust](https://www.rust-lang.org/tools/install) (stable) and the [Tauri v2 prerequisites](https://v2.tauri.app/start/prerequisites/)
- On Linux, the system libraries Tauri needs:

  ```bash
  sudo apt-get install -y libwebkit2gtk-4.1-dev libgtk-3-dev librsvg2-dev \
    libayatana-appindicator3-dev libxdo-dev libssl-dev patchelf
  ```

### Run

```bash
git clone https://github.com/revolutionxk/rml-launcher.git
cd rml-launcher

bun install
bun run tauri dev
```

### Build

```bash
bun run tauri build
```

Installers are written to `src-tauri/target/release/bundle/`.

### Checks

```bash
bun run lint                                   # oxlint
bunx tsc --noEmit                              # type check
cargo test --manifest-path src-tauri/Cargo.toml
```

## Tech stack

- [Tauri 2](https://v2.tauri.app/) (Rust) for the native shell and backend
- [React 19](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/) + [Vite](https://vite.dev/)
- [TanStack Router](https://tanstack.com/router) and [TanStack Query](https://tanstack.com/query) for routing and cached data
- [Tailwind CSS](https://tailwindcss.com/) + [Base UI](https://base-ui.com/) + [Motion](https://motion.dev/)
- [Fluent](https://projectfluent.org/) for localization

## Releases & CI

Releases are published automatically by GitHub Actions:

| Trigger | Result |
| --- | --- |
| Push to `develop` | Rebuilds the rolling `nightly` pre-release for all platforms |
| Version bump merged to `main` | Publishes `vX.Y.Z` if that version was not released yet |
| Push of a `v*` tag | Publishes that version |

Every pull request and push to `develop`/`main` runs lint, type checks and Rust tests.

## Contributing

Contributions are welcome. Please open an issue to discuss substantial changes first, keep pull
requests focused, and follow the existing code style. The launcher pairs with the main
[Roblox ModLoader](https://github.com/revolutionxk/roblox-modloader) project.

- [Discord server](https://discord.gg/revolutionxk)
- [Sponsor](https://github.com/sponsors/revolutionxk)

## License

Released under the MIT License, matching the main Roblox ModLoader project.

## Disclaimer

This project is provided for educational and research purposes. You are responsible for complying
with Roblox's Terms of Service and any applicable laws. It is not affiliated with or endorsed by
Roblox Corporation.
