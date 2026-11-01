# Builds Podflow.app from the Swift package.
# Requires full Xcode (DEVELOPER_DIR below) because of SwiftUI.

DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
SWIFT = env DEVELOPER_DIR=$(DEVELOPER_DIR) /usr/bin/swift
BUILD_DIR = .build
APP = build/Podflow.app
ICONSET = build/Podflow.iconset

.PHONY: all app test icon clean run

all: app

test:
	$(SWIFT) test

$(BUILD_DIR)/release/Podflow: $(shell find Sources -name '*.swift') Package.swift
	$(SWIFT) build -c release

icon: build/Podflow.icns

build/Podflow.icns: scripts/make-icon.swift
	mkdir -p $(ICONSET)
	for size in 16 32 64 128 256 512 1024; do \
		env DEVELOPER_DIR=$(DEVELOPER_DIR) /usr/bin/swift scripts/make-icon.swift $(ICONSET)/icon_$${size}x$${size}.png $$size; \
	done
	cp $(ICONSET)/icon_32x32.png   $(ICONSET)/icon_16x16@2x.png
	cp $(ICONSET)/icon_64x64.png   $(ICONSET)/icon_32x32@2x.png
	cp $(ICONSET)/icon_256x256.png $(ICONSET)/icon_128x128@2x.png
	cp $(ICONSET)/icon_512x512.png $(ICONSET)/icon_256x256@2x.png
	cp $(ICONSET)/icon_1024x1024.png $(ICONSET)/icon_512x512@2x.png
	rm $(ICONSET)/icon_64x64.png $(ICONSET)/icon_1024x1024.png
	iconutil -c icns $(ICONSET) -o build/Podflow.icns
	rm -r $(ICONSET)

app: $(BUILD_DIR)/release/Podflow build/Podflow.icns
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp Info.plist $(APP)/Contents/Info.plist
	cp $(BUILD_DIR)/release/Podflow $(APP)/Contents/MacOS/Podflow
	cp -R $(BUILD_DIR)/release/Podflow_Podflow.bundle $(APP)/Contents/Resources/ 2>/dev/null || \
		cp -R $$(find $(BUILD_DIR) -name 'Podflow_Podflow.bundle' | head -1) $(APP)/Contents/Resources/
	cp build/Podflow.icns $(APP)/Contents/Resources/Podflow.icns
	codesign --force --deep --sign - $(APP)
	@echo "Built $(APP)"

run: app
	open $(APP)

clean:
	rm -rf $(BUILD_DIR) build
