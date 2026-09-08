.PHONY: run test check package-local release
run:
	./script/build_and_run.sh
test:
	SDKROOT="$$(xcrun --sdk macosx --show-sdk-path)" swift test --package-path Packages/HypergateCore
check:
	git diff --check
package-local:
	./script/package-local.sh
release:
	./script/release.sh
