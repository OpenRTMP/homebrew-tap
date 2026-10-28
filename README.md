# OpenRTMP Homebrew Tap

Homebrew formula for [librtmp2](https://github.com/OpenRTMP/librtmp2), the
modern RTMP and RTMPS protocol library.

## Install

```bash
brew install openrtmp/tap/librtmp2
```

Homebrew 6.0+ requires third-party taps to be trusted before their formulae
are loaded ([Tap Trust](https://docs.brew.sh/Tap-Trust)). Installing the fully
qualified formula name (`brew install openrtmp/tap/librtmp2`) trusts just that
formula automatically. To trust the whole tap up front instead, run
`brew trust openrtmp/tap`.

On macOS Sequoia, Tahoe, and Golden Gate (arm64) - plus Sequoia and Tahoe on
Intel - `brew install` fetches a precompiled bottle from
`packages.openrtmp.org`; other platforms build librtmp2 from source.

## Moving from `openrtmp/packages`

The formula used to live in
[OpenRTMP/packages](https://github.com/OpenRTMP/packages). `brew update` moves
an installed librtmp2 to this tap on its own. Afterwards remove the old, much
larger tap:

```bash
brew untap openrtmp/packages
```

## Updates

This repository is updated automatically by the release workflows in
[OpenRTMP/packages](https://github.com/OpenRTMP/packages): one writes the
formula for each new librtmp2 release, another adds the `bottle do` block once
the bottles are built. Please don't edit `Formula/librtmp2.rb` by hand; change
the workflows there instead.

Linux, Windows, and other package formats are documented in
[OpenRTMP/packages](https://github.com/OpenRTMP/packages).
