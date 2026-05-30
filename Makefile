.PHONY: build run clean release test

build:
	xcrun swift build

run: build
	xcrun swift run KiwiTest

clean:
	xcrun swift package clean
	rm -rf .build

release:
	xcrun swift build -c release

test:
	xcrun swift test
