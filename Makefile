#  vim:ts=4:sts=4:sw=4:noet
#
#  Author: Hari Sekhon
#  Date: 2013-02-03 10:25:36 +0000 (Sun, 03 Feb 2013)
#
#  https://github.com/harisekhon/tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback
#  to help improve or steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

export PATH := $(PATH):/usr/local/bin

CPANM = cpanm

ifdef PERLBREW_PERL
	SUDO2 =
else
	SUDO2 = sudo
endif

# must come after to reset SUDO2 to blank if root
# EUID /  UID not exported in Make
# USER not populated in Docker
ifeq '$(shell id -u)' '0'
	SUDO =
	SUDO2 =
else
	SUDO = sudo
endif

# ===================
# bootstrap commands:

# Alpine:
#
#   apk add --no-cache git make && git clone https://github.com/harisekhon/tools && cd tools && make

# Debian / Ubuntu:
#
#   apt-get update && apt-get install -y make git && git clone https://github.com/harisekhon/tools && cd tools && make

# RHEL / CentOS:
#
#   yum install -y make git && git clone https://github.com/harisekhon/tools && cd tools && make

# ===================

.PHONY: build
build:
	@echo ===========
	@echo Tools Build
	@echo ===========

	if [ -x /sbin/apk ];        then make apk-packages; fi
	if [ -x /usr/bin/apt-get ]; then make apt-packages; fi
	if [ -x /usr/bin/yum ];     then make yum-packages; fi

	git submodule init
	git submodule update --recursive

	cd lib && make

	# don't track and commit your personal name, company name etc additions to scrub_custom.conf back to Git since they are personal to you
	git update-index --assume-unchanged scrub_custom.conf
	git update-index --assume-unchanged solr/solr-env.sh

	#@ [ $$EUID -eq 0 ] || { echo "error: must be root to install cpan modules"; exit 1; }
	# Module::CPANfile::Result and Module::Install::Admin are needed for Hijk which is auto-pulled by Search::Elasticsearch but doesn't auto-pull Module::CPANfile::Result

	# workaround for broken pod coverage tests
	#yes | $(SUDO) cpan --force XML::Validate

	# auto-configure cpan for Perl 5.8 which otherwise gets stuck prompting for a region for downloads
	# this doesn't work it's misaligned with the prompts, should use expect instead if I were going to do this
	#(echo y;echo o conf prerequisites_policy follow;echo o conf commit) | cpan
	which cpanm || { yes "" | $(SUDO2) cpan App::cpanminus; }
	yes "" | $(SUDO2) $(CPANM) --notest `sed 's/#.*//; /^[[:space:]]*$$/d;' < setup/cpan-requirements.txt`

	@echo
	@echo "BUILD SUCCESSFUL (tools)"

.PHONY: quick
quick:
	QUICK=1 make

.PHONY: apk-packages
apk-packages:
	$(SUDO) apk update
	$(SUDO) apk add `sed 's/#.*//; /^[[:space:]]*$$/d' setup/apk-packages.txt setup/apk-packages-dev.txt`

.PHONY: apk-packages-remove
apk-packages-remove:
	cd lib && make apk-packages-remove
	$(SUDO) apk del `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/apk-packages-dev.txt` || :
	$(SUDO) rm -fr /var/cache/apk/*

.PHONY: apt-packages
apt-packages:
	$(SUDO) apt-get update
	$(SUDO) apt-get install -y `sed 's/#.*//; /^[[:space:]]*$$/d' setup/deb-packages.txt setup/deb-packages-dev.txt`

.PHONY: apt-packages-remove
apt-packages-remove:
	cd lib && make apt-packages-remove
	$(SUDO) apt-get purge -y `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/deb-packages-dev.txt`

.PHONY: yum-packages
yum-packages:
	for x in `sed 's/#.*//; /^[[:space:]]*$$/d' setup/rpm-packages.txt setup/rpm-packages-dev.txt`; do rpm -q $$x || $(SUDO) yum install -y $$x; done

.PHONY: yum-packages-remove
yum-packages-remove:
	cd lib && make yum-packages-remove
	for x in `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/rpm-packages-dev.txt`; do rpm -q $$x && $(SUDO) yum remove -y $$x; done

.PHONY: lib-test
lib-test:
	cd lib && make test
	rm -fr lib/cover_db || :

.PHONY: test
test: lib-test
	tests/all.sh

.PHONY: basic-test
basic-test: lib-test
	. tests/excluded.sh; bash-tools/all.sh
	tests/help.sh

.PHONY: install
install:
	@echo "No installation needed, just add '$(PWD)' to your \$$PATH"

.PHONY: update
update: update2 build
	:
	@#make test

.PHONY: update2
update2: update-no-recompile
	:

.PHONY: update-no-recompile
update-no-recompile:
	git pull
	git submodule update --init --recursive

.PHONY: update-submodules
update-submodules:
	git submodule update --init --remote
.PHONY: updatem
updatem: update-submodules
	:

.PHONY: clean
clean:
	cd lib && make clean

.PHONY: deep-clean
deep-clean: clean
	cd lib && make deep-clean

.PHONY: docker-run
docker-run:
	docker run -ti --rm harisekhon/tools ${ARGS}

.PHONY: run
run:
	make docker-run

.PHONY: docker-mount
docker-mount:
	docker run -ti --rm -v $$PWD:/tools harisekhon/tools bash -c "cd /tools; exec bash"

.PHONY: mount
mount: docker-mount
	:

.PHONY: push
push:
	git push
