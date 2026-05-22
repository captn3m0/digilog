## Build

Requires Xcode 15+ and macOS 13+.

```sh
brew install xcodegen
xcodegen generate
open Digilog.xcodeproj
```

Build & run from Xcode (`⌘R`), or from the command line:

```sh
xcodebuild -scheme Digilog -configuration Release build
```
