# Seedling

A minimal native torrent client for macOS, built with SwiftUI and powered by a bundled Transmission engine.

**[Download Seedling v0.1.0 for macOS](https://github.com/ilmirfan/seedling/releases/download/v0.1.0/Seedling-macOS.dmg)** · [Release notes](https://github.com/ilmirfan/seedling/releases/tag/v0.1.0) · [All releases](https://github.com/ilmirfan/seedling/releases)

## Requirements

- Apple Silicon Mac (M1 or later).
- macOS 14 or later.

Version 0.1.0 is a prerelease for early testing. It is locally signed, but is not notarized or signed with an Apple Developer ID. Intel Macs are not supported by this build.

## Installation

1. Download **Seedling-macOS.dmg** from the [v0.1.0 release](https://github.com/ilmirfan/seedling/releases/tag/v0.1.0).
2. Open the DMG and drag **Seedling** to **Applications**.
3. Open **Seedling** from Applications.

### If macOS blocks the app

If you trust the downloaded build, first try opening Seedling, then go to **System Settings → Privacy & Security → Open Anyway** and confirm. See [Apple's instructions](https://support.apple.com/en-gb/102445).

Alternatively, after copying Seedling to Applications, run this command in Terminal:

```sh
xattr -dr com.apple.quarantine "/Applications/Seedling.app"
```

This removes the quarantine attribute from Seedling and its contents, bypassing its quarantine-based first-launch protection. Use it only for a build you trust. It does not sign or notarize the app. Keep the full `Seedling.app` path; targeting `/Applications/` would affect every app in that folder.

## Features

- Add magnet links or `.torrent` files, including by drag and drop.
- Pause and resume downloads, with saved state between launches.
- Automatically route likely movies to a separate folder, with manual overrides.
- Show optional movie artwork matched through Wikipedia.
- Verify downloaded files before optionally removing completed list entries; downloaded files stay on disk.
- Use native Liquid Glass controls on macOS 26 and later.

## Getting started

Click **Add download** or press **Command-N** to paste a magnet link. Press **Command-O** to choose a `.torrent` file.

Choose your download folders in Settings. Right-click a download to reveal its folder, change its destination, or remove its list entry while keeping the downloaded files.

Closing the window leaves Seedling running. Use **Quit** to stop the app and its engine.

## Source and development

The app source, build scripts, tests, and detailed documentation are in [`work/seedling`](work/seedling). See the [development README](work/seedling/README.md) for build instructions and known limitations.

## License

See the [Seedling license](work/seedling/LICENSE) and [third-party notices](work/seedling/THIRD-PARTY.md).
