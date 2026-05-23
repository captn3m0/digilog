.PHONY: build

Digilog.xcodeproj: project.yml
	xcodegen generate

build: Digilog.xcodeproj Digilog
	xcodebuild -project Digilog.xcodeproj -scheme Digilog -configuration Release -derivedDataPath build build

site/index.html: README.md
	pandoc -s README.md -o index.html
