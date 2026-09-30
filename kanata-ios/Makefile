SIM ?= Totem iPad Air 11-inch (M4)
DEST = platform=iOS Simulator,name=$(SIM)
XB = xcodebuild -project Totem.xcodeproj -scheme Totem -derivedDataPath build/DerivedData

.PHONY: project test test-core test-ui build device

project:
	xcodegen generate

test: test-core test-ui

test-core:
	cd TotemKit && swift test

test-ui: project
	$(XB) -destination '$(DEST)' test

build: project
	$(XB) -destination '$(DEST)' build

# iPad on USB; automatic signing with team JY4PD9Q24B.
device: project
	$(XB) -destination 'generic/platform=iOS' -allowProvisioningUpdates build
	xcrun devicectl device install app --device $(DEVICE) build/DerivedData/Build/Products/Debug-iphoneos/Totem.app
