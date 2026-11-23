# Builds Podflow.app from the Swift package.
# Requires full Xcode (XCODE below) because of SwiftUI.

# Not DEVELOPER_DIR: a devbox/nix shell already exports that, pointing at its own SDK.
XCODE ?= /Applications/Xcode.app/Contents/Developer
SWIFT = env -u SDKROOT -u NIX_CFLAGS_COMPILE -u NIX_LDFLAGS DEVELOPER_DIR=$(XCODE) /usr/bin/swift
CLI = build/podflow
# Signing: "Developer ID Application" when available (runs on any Mac after
# notarization), else "Apple Development" (this Mac only). A stable signature
# keeps Keychain "Always Allow" across rebuilds; ad-hoc ("-") is the fallback.
# Identities are picked by hash because names can be duplicated.
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $$2; exit}')
ifeq ($(SIGN_IDENTITY),)
SIGN_IDENTITY := $(shell security find-identity -v -p codesigning | awk '/Apple Development/ {print $$2; exit}')
endif
ifeq ($(SIGN_IDENTITY),)
SIGN_IDENTITY := -
endif
# Hardened runtime + secure timestamp are required for notarization.
SIGN_FLAGS = --force --options runtime --timestamp --sign $(SIGN_IDENTITY)
ifeq ($(SIGN_IDENTITY),-)
SIGN_FLAGS = --force --sign -
endif
# Credentials stored once with `xcrun notarytool store-credentials podflow`.
NOTARY_PROFILE ?= podflow
VERSION = $(shell /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
DMG = build/Podflow-$(VERSION).dmg
BUILD_DIR = .build
APP = build/Podflow.app
SPARKLE = $(APP)/Contents/Frameworks/Sparkle.framework
SPARKLE_BIN = .build/artifacts/sparkle/Sparkle/bin
# Updates: each release is a GitHub release "desktop-v<version>" with the dmg;
# the Sparkle feed (SUFeedURL in Info.plist) is appcast.xml on the fixed
# release "desktop-appcast". Both are kept out of "latest" (that is the CLI).
REPO = floriankimmel/podflow
TAG = desktop-v$(VERSION)
FEED_TAG = desktop-appcast
NOTES ?=
ICONSET = build/Podflow.iconset

.PHONY: all app install release publish check-version test test-plugin cli icon clean run

all: app

test: $(CLI) test-plugin
	$(SWIFT) test

test-plugin:
	bash Tests/plugin/run.sh

# The podflow CLI the app bundles for the WordPress publish step.
cli: $(CLI)

$(CLI): $(shell find ../cmd ../internal -name '*.go') ../go.mod
	mkdir -p build
	cd .. && CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -o desktop/build/podflow-arm64 ./cmd/podflow
	cd .. && CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o desktop/build/podflow-amd64 ./cmd/podflow
	lipo -create -output $(CLI) build/podflow-arm64 build/podflow-amd64
	rm build/podflow-arm64 build/podflow-amd64

$(BUILD_DIR)/release/Podflow: $(shell find Sources -name '*.swift') Package.swift
	$(SWIFT) build -c release

icon: build/Podflow.icns

build/Podflow.icns: scripts/make-icon.swift
	mkdir -p $(ICONSET)
	for size in 16 32 64 128 256 512 1024; do \
		$(SWIFT) scripts/make-icon.swift $(ICONSET)/icon_$${size}x$${size}.png $$size; \
	done
	cp $(ICONSET)/icon_32x32.png   $(ICONSET)/icon_16x16@2x.png
	cp $(ICONSET)/icon_64x64.png   $(ICONSET)/icon_32x32@2x.png
	cp $(ICONSET)/icon_256x256.png $(ICONSET)/icon_128x128@2x.png
	cp $(ICONSET)/icon_512x512.png $(ICONSET)/icon_256x256@2x.png
	cp $(ICONSET)/icon_1024x1024.png $(ICONSET)/icon_512x512@2x.png
	rm $(ICONSET)/icon_64x64.png $(ICONSET)/icon_1024x1024.png
	iconutil -c icns $(ICONSET) -o build/Podflow.icns
	rm -r $(ICONSET)

app: $(BUILD_DIR)/release/Podflow build/Podflow.icns $(CLI)
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp Info.plist $(APP)/Contents/Info.plist
	cp $(BUILD_DIR)/release/Podflow $(APP)/Contents/MacOS/Podflow
	cp $(CLI) $(APP)/Contents/Resources/podflow
	cp -R plugin $(APP)/Contents/Resources/plugin
	cp build/Podflow.icns $(APP)/Contents/Resources/Podflow.icns
	mkdir -p $(APP)/Contents/Frameworks
	ditto $(BUILD_DIR)/release/Sparkle.framework $(SPARKLE)
	install_name_tool -add_rpath @executable_path/../Frameworks $(APP)/Contents/MacOS/Podflow
	# Inside out: Sparkle's helpers, the framework, the bundled CLI, then the app.
	codesign $(SIGN_FLAGS) $(SPARKLE)/Versions/B/XPCServices/Installer.xpc
	codesign $(SIGN_FLAGS) --preserve-metadata=entitlements $(SPARKLE)/Versions/B/XPCServices/Downloader.xpc
	codesign $(SIGN_FLAGS) $(SPARKLE)/Versions/B/Autoupdate
	codesign $(SIGN_FLAGS) $(SPARKLE)/Versions/B/Updater.app
	codesign $(SIGN_FLAGS) $(SPARKLE)
	codesign $(SIGN_FLAGS) $(APP)/Contents/Resources/podflow
	codesign $(SIGN_FLAGS) $(APP)
	@echo "Built $(APP)"

install: app
	osascript -e 'quit app "Podflow"' 2>/dev/null || true
	rm -rf /Applications/Podflow.app
	cp -R $(APP) /Applications/Podflow.app
	@echo "Installed /Applications/Podflow.app"

# Signed, notarized and stapled .dmg for other Macs (needs a Developer ID
# Application certificate and the notarytool profile).
release: app
	@security find-identity -v -p codesigning | grep -q "$(SIGN_IDENTITY).*Developer ID Application" || \
		{ echo "No Developer ID Application certificate. Create one in Xcode > Settings > Accounts > Manage Certificates."; exit 1; }
	rm -f $(DMG)
	hdiutil create -volname Podflow -srcfolder $(APP) -ov -format UDZO $(DMG)
	codesign --force --timestamp --sign $(SIGN_IDENTITY) $(DMG)
	xcrun notarytool submit $(DMG) --keychain-profile $(NOTARY_PROFILE) --wait
	xcrun stapler staple $(DMG)
	spctl --assess --type open --context context:primary-signature -v $(DMG)
	@echo "Release ready: $(DMG)"

# Ships an update: notarized dmg as GitHub release $(TAG), then replaces the
# Sparkle feed. Bump CFBundleShortVersionString and CFBundleVersion in
# Info.plist first; HEAD must be pushed. Optional: make publish NOTES="…"
publish: check-version release
	scripts/appcast.sh $(DMG) https://github.com/$(REPO)/releases/download/$(TAG)/$(notdir $(DMG)) "$(NOTES)" > build/appcast.xml
	gh release create $(TAG) $(DMG) --repo $(REPO) --target $$(git rev-parse HEAD) --latest=false \
		--title "Podflow $(VERSION)" --notes "$(if $(NOTES),$(NOTES),Podflow desktop $(VERSION))"
	gh release view $(FEED_TAG) --repo $(REPO) >/dev/null 2>&1 || \
		gh release create $(FEED_TAG) --repo $(REPO) --prerelease --latest=false \
			--title "Podflow update feed" --notes "Sparkle appcast for the desktop app. Do not delete."
	gh release upload $(FEED_TAG) build/appcast.xml --repo $(REPO) --clobber
	@echo "Published $(TAG); installed apps update from the feed"

check-version:
	@! gh release view $(TAG) --repo $(REPO) >/dev/null 2>&1 || \
		{ echo "$(TAG) already released. Bump the version in Info.plist."; exit 1; }
	@git fetch -q origin && git branch -r --contains HEAD | grep -q . || \
		{ echo "Push HEAD first: the release tag points at it."; exit 1; }

run: app
	open $(APP)

clean:
	rm -rf $(BUILD_DIR) build
