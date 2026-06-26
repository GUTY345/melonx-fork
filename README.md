# MeloNX Fork

MeloNX Fork is an iOS/iPadOS-focused downstream fork of MeloNX, which itself is based on Ryujinx. This fork exists so we can improve mobile stability, thermal behavior, memory handling, firmware setup, and usability without pushing experimental changes back into the main MeloNX project.

Current fork version: **1.0.1 Fork**

## Project Goals

- Keep this fork separate from the main MeloNX project.
- Improve stability across all supported games, not just one title.
- Optimize for iPhone and iPad thermal limits, memory pressure, and sustained frame pacing.
- Make setup easier on iOS/iPadOS, especially firmware import and common first-run tasks.
- Keep upstream MeloNX/Ryujinx changes mergeable so new fixes can be pulled in later.
- Avoid distributing copyrighted content, keys, firmware, games, or shader caches.

## Upstream Workflow

This repository is intended to track the main MeloNX project as an upstream source while keeping fork-specific changes in this repo.

Recommended remote layout:

```bash
git remote -v
```

- `upstream`: original MeloNX source.
- `origin`: this fork.

To bring in future upstream updates:

```bash
git fetch upstream
git merge upstream/main
```

If the upstream branch name is different, replace `main` with the upstream branch being tracked. Resolve conflicts locally, test on device, then commit the merge in this fork.

## iOS/iPadOS Requirements

MeloNX Fork requires capabilities that normal App Store apps cannot use freely.

- JIT is required. Games will not run correctly without JIT.
- Increased Memory Limit entitlement is strongly required.
- Extended Virtual Addressing may be required on some devices.
- Devices with less RAM or older SoCs are more likely to crash under memory pressure.
- Sustained performance depends on device temperature, power mode, resolution, shader cache state, and game workload.

## Legal And Content Policy

This project does not include or distribute Nintendo firmware, prod.keys, title.keys, games, DLC, updates, shader caches, or any other copyrighted console content.

Users must dump their own firmware, keys, games, updates, and DLC from hardware and software they legally own. Do not open issues or discussions asking for copyrighted content or links to copyrighted content.

Nintendo Switch is a trademark of Nintendo Co., Ltd. This project is independent and is not affiliated with, endorsed by, or associated with Nintendo, Ryujinx, or the main MeloNX project maintainers.

## Current Fork Changes

- Added a Switch Home applet launcher entry.
- Improved firmware import so folders or multiple registered firmware files can be selected and copied into the expected BIS location.
- Added iOS/iPadOS stability-oriented defaults for memory and mobile performance.
- Added thermal-stability behavior to reduce heat and improve sustained play.
- Fixed several file access, per-game settings, and JIT crash-prone paths.
- Removed iOS SDK future-only glass APIs from the build path for compatibility with the current Xcode SDK.

## Build Notes

The iOS build uses Xcode plus the .NET iOS workload to build the Ryujinx native component.

Example unsigned archive build:

```bash
PATH="$HOME/.dotnet:$PATH" xcodebuild archive \
  -project src/MeloNX/MeloNX.xcodeproj \
  -scheme MeloNX \
  -configuration Archive \
  -destination 'generic/platform=iOS' \
  -archivePath build/MeloNX.xcarchive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=''
```

Unsigned IPAs must be signed by your sideloading workflow before installation. For real device testing, make sure the final signature includes the entitlements required by your device and iOS version.

## License

This fork preserves the upstream license terms. See [LICENSE.txt](LICENSE.txt) and [distribution/legal/THIRDPARTY.md](distribution/legal/THIRDPARTY.md).

## Credits

- MeloNX main project, for the iOS-focused emulator frontend and integration work.
- Ryujinx, for the emulator core this project builds on.
- LibHac and other third-party projects listed in the upstream notices.
