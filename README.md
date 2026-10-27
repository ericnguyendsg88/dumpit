# DumpIt

A brain dump journal for iPhone, iPad and Mac. Write 500 words in one sitting, without backspace or editing. Completed sessions stay on your device.

## Try the Mac app

[Download the latest Mac build](https://github.com/ericnguyendsg88/dumpit/releases/latest). Unzip and move DumpIt.app to Applications. Requires macOS 14 or later; this preview is built for Apple silicon.

The preview is ad-hoc signed, not notarized. If macOS blocks it, use System Settings → Privacy & Security → Open Anyway after attempting to open it. Only do this for a download you trust.

## Build from source

Requires Xcode with macOS SDKs.

```sh
git clone https://github.com/ericnguyendsg88/dumpit.git
cd dumpit
./build.sh
open .build/Build/Products/Release/DumpIt.app
```

For iPhone or iPad, open Unload.xcodeproj, choose the Unload iOS scheme, and select your signing team. iOS 17 or later is required. There is no public iOS binary in this repository.

Project configuration is in project.yml and the generated Xcode project is included. Personal journals, signing profiles and build output are excluded.
