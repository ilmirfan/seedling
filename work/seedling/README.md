# Seedling 0.1

A minimal native torrent client for macOS, built with SwiftUI and a private Transmission 4.1.3 engine. No separate Transmission installation is required.

## Requirements

Apple Silicon Mac running macOS 14 or later. This development build is locally signed, but it is not notarized or signed with a Developer ID for public distribution.

## Install and first launch

Download **Seedling-macOS.dmg** from [GitHub Releases](https://github.com/ilmirfan/seedling/releases), open it, and drag Seedling to Applications.

If macOS blocks this development build, first try opening Seedling, then go to **System Settings → Privacy & Security → Open Anyway**. Only allow a build you trust. See [Apple's instructions](https://support.apple.com/en-gb/102445).

Alternatively, if you trust the downloaded build, run this command in Terminal after copying it to Applications:

```sh
xattr -dr com.apple.quarantine "/Applications/Seedling.app"
```

This removes the quarantine attribute from Seedling and its contents, bypassing the quarantine-based first-launch protection for this app. It does not sign or notarize the app. Keep the full app path shown above; targeting `/Applications/` would affect every app in that folder. Each user must allow the app on their own Mac.

## Use

Open Seedling.app. Click **Add download** or press Command-N to paste a magnet link. Use Command-O to choose .torrent files, or drag files and magnet links onto the window. The app declares support for magnet URLs and .torrent files; it does not replace your existing default torrent app. Finder's Open With menu can open a .torrent in Seedling.

Downloads show a colored progress bar, speed, time remaining, size, and small connected seed/peer counts. Pause and resume with the control on each card. Right-click a card to reveal its folder, change its destination, or remove its list entry while keeping files.

Settings contain a **Make Default…** button for opening magnet links and .torrent files with Seedling. Confirm each change if macOS asks. The status checks both associations whenever Settings opens or becomes active, and the button can retry any association that was not changed.

Settings also contain two destination folders and a checkbox for removing completed downloads. Movies default to ~/Movies. Everything else defaults to ~/Downloads; choose a different folder if needed.

## Movie routing

Automatic mode treats a single non-sample video file as a likely movie. Recognizable TV episode and season names go to the other folder. This is a heuristic: a filename cannot reliably distinguish every movie, tutorial, personal video, or series. Choose Movie or Other when adding a download to override detection. Right-click an existing card to change the destination.

Magnet links reveal filenames only after metadata arrives. Seedling routes their payload once it has that information. A small amount of data may initially enter the other folder before the engine moves it.

## Completion and uploads

Seedling requires all files, all bytes, complete metadata, no unchecked data, and no download errors. It then asks the engine to recheck the payload. Only after that check succeeds does auto-remove clear the entry. Downloaded files and original .torrent files are never deleted by list removal. A failed check resumes downloading.

Uploads are capped at 20 KB/s while downloading. Completed items stop sharing. The cap is an absolute speed, not a percentage of download speed.

## Storage and lifecycle

Settings and resume state live in ~/Library/Application Support/Seedling. Closing the window leaves Seedling running; Quit exits the app and its engine. Downloads resume on the next launch. The first build has no crash-recovery supervisor or automatic updater.

## Validation

Local generated fixtures exercised real downloads, movie/other routing, full integrity checks, keep/remove behavior, payload preservation, original .torrent preservation, fresh magnet acceptance, duplicate handling, pause/resume, and the upload cap. Negative checks covered partial files, unchecked bytes, missing metadata, active rechecks and incomplete magnets. The native empty state, add dialog and folder settings were inspected on macOS. Public tracker/DHT transfers, browser-default association flows, and Intel Macs were not tested.

## Build

Install Xcode command-line tools and Python 3. In the source directory, run:

    python3 fetch_engine.py
    ./build.sh

The helper fetches Homebrew's official Apple Silicon bottles and verifies their SHA-256 checksums. It bundles the engine's non-system libraries and signs them locally. The result is build/Seedling.app. The included Transmission source archive corresponds to the bundled engine. Homebrew build metadata and license notices accompany the source.

## Next release work

Developer ID signing and notarization, Intel/universal support if required, a dedicated icon, public-network testing, startup/crash lifecycle hardening and accessibility review before wider distribution.

## Liquid Glass

On macOS 26 and later, the add, settings, pause, and folder controls use Apple’s native Liquid Glass button styles. Download cards and progress bars stay solid for readability. The resume control uses a white play icon on a solid green circle, including when the window is inactive. Earlier macOS versions use standard bordered controls. Native button styles inherit system accessibility behavior.

## Movie artwork

Likely movies use Wikipedia artwork when an exact cleaned title and release year can be matched confidently. The app sends the cleaned title and year to English Wikipedia; file paths, hashes, source-site tags, and file contents are not sent. Matching is conservative: ambiguous results, wrong years, unavailable images, and network failures retain the film icon. Coverage depends on Wikipedia and is more limited for transliterated or obscure titles.

Artwork loads in the background, is cached locally for seven days, and never blocks downloads. Right-click a poster for its Wikipedia page or image source and credits. No API key is required.

Artwork checks cover filename cleaning, numeric titles, TV exclusions, wrong years, ambiguous remakes, unrelated soundtracks, accepted image hosts, live image decoding, and cache reuse.

## Empty-state animation

The empty-state illustration has gently pulsing rings and a small arrow bounce. Animation stops when the app is inactive and stays still when macOS Reduce Motion is enabled. It appears only when the download list is empty.

## Upgrade from the previous name

On first launch, Seedling moves the previous app’s complete private state directory to ~/Library/Application Support/Seedling, preserving preferences, engine resume data and cached artwork. Download payloads stay in the folders you selected. Quit the previous app before launching Seedling. Migration is safe to retry and will not overwrite an existing Seedling data directory.

For rollback, quit Seedling and rename its private Application Support directory back to Ayra before launching the previous release. The file formats are unchanged.
