.PHONY: run test check package-local release
run:
	./script/build_and_run.sh
test:
	./script/test.sh
check:
	./script/check.sh
package-local:
	./script/package-local.sh
release:
	./script/release.sh
