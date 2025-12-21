REPO_ROOT := $(shell git rev-parse --show-toplevel)

.DEFAULT_GOAL := build
.PHONY: build release test run clean generate validate doc doc-preview api \
        build-ios build-ios-simulator build-tvos build-watchos build-visionos \
        build-all-platforms help

# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------

build:
	swift build

release:
	swift build -c release

test:
	swift test

run:
	swift run KiwiTest

clean:
	swift package clean

# ---------------------------------------------------------------------------
# Wrapper generation
# ---------------------------------------------------------------------------

generate:
	python3 $(REPO_ROOT)/Sources/CxxKiwi/generate_wrapper.py

validate:
	python3 $(REPO_ROOT)/Sources/CxxKiwi/generate_wrapper.py --validate-only

# ---------------------------------------------------------------------------
# Documentation
# ---------------------------------------------------------------------------

doc:
	swift package generate-documentation --target KiwiSolver

doc-preview:
	swift package --disable-sandbox preview-documentation --target KiwiSolver

api:
	xcrun swift build \
		-Xswiftc -emit-module-interface-path \
		-Xswiftc $(REPO_ROOT)/docs/build/KiwiSolver.swiftinterface \
		-Xswiftc -enable-library-evolution \
		-Xswiftc -no-verify-emitted-module-interface \
		--target KiwiSolver
	@echo "Wrote docs/build/KiwiSolver.swiftinterface"

# ---------------------------------------------------------------------------
# Cross-platform builds
# ---------------------------------------------------------------------------

build-ios:
	xcodebuild -scheme KiwiSolver -destination 'generic/platform=iOS' build

build-ios-simulator:
	xcodebuild -scheme KiwiSolver -destination 'generic/platform=iOS Simulator' build

build-tvos:
	xcodebuild -scheme KiwiSolver -destination 'generic/platform=tvOS' build

build-watchos:
	xcodebuild -scheme KiwiSolver -destination 'generic/platform=watchOS' build

build-visionos:
	xcodebuild -scheme KiwiSolver -destination 'generic/platform=visionOS' build

build-all-platforms: build build-ios build-ios-simulator build-tvos build-watchos build-visionos

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

help:
	@echo "KiwiSolver targets:"
	@echo "  build                 Build debug (default)"
	@echo "  release               Build release"
	@echo "  test                  Run tests"
	@echo "  run                   Run KiwiTest executable"
	@echo "  clean                 Clean build artifacts"
	@echo "  generate              Regenerate KiwiWrapper.h from kiwi headers"
	@echo "  validate              Check KiwiWrapper.h is up to date"
	@echo "  doc                   Generate DocC documentation"
	@echo "  doc-preview           Preview DocC documentation"
	@echo "  api                   Emit .swiftinterface file"
	@echo "  build-ios             Build for iOS"
	@echo "  build-ios-simulator   Build for iOS Simulator"
	@echo "  build-tvos            Build for tvOS"
	@echo "  build-watchos         Build for watchOS"
	@echo "  build-visionos        Build for visionOS"
	@echo "  build-all-platforms   Build for all platforms"
