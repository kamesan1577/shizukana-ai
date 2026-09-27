.PHONY: project check
project:
	cd App && xcodegen generate
check: project
	bash scripts/privacy-guard.sh
	xcodebuild -project App/QuietApp.xcodeproj -scheme QuietApp -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO test
