.PHONY: help install restart run

help:
	@echo "make install   deploy the shell to ~/.config/quickshell/caelestia"
	@echo "make restart   restart the running shell"
	@echo "make run       run this working tree directly, without installing"

install:
	@scripts/install.sh

restart:
	@scripts/restart.sh

run:
	@qs -p shell
