TOPLEVEL := svn2rpm svn2rpm.spec Makefile DEBIAN test

TESTTEMP := $(CURDIR)/test/temp
TESTOUT := $(TESTTEMP)/out
SVNDIR := $(TESTTEMP)/svn
SVNURL := file://$(SVNDIR)

GITREV := HEAD

VERSION := $(shell cat VERSION 2>/dev/null)
REVISION := "$(shell git rev-list $(GITREV) -- $(TOPLEVEL) 2>/dev/null| wc -l)$(EXTRAREV)"
PV = svn2rpm-$(VERSION)

# we bring a copy of spectool as this is not available on Debian systems and only a Perl script
PATH := $(PATH):$(CURDIR)/test/bin

.PHONY: all test deb srpm clean rpm info debinfo rpminfo

all: deb rpm
	ls -l dist/*.deb dist/*.rpm

test: clean
	@echo
	@echo "Building Version $(VERSION) Revision $(REVISION)"
	@echo
	mkdir -p $(TESTOUT) $(SVNDIR)
	svnadmin create $(SVNDIR)
	svn import test/data $(SVNURL) -m import
	@echo
	@echo "TEST variant 1 no download"
	./svn2rpm -b .great -o $(TESTOUT) $(SVNURL)/test1
	rpm -qp $(TESTOUT)/test1-19-75.1.great.noarch.rpm
	@echo
	@echo "TEST variant 1 with download only source rpm"
	./svn2rpm -s -o $(TESTOUT) $(SVNURL)/test2
	rpm -qp $(TESTOUT)/test2-19-75.1.src.rpm
	test ! -f $(TESTOUT)/test2-19-75.1.noarch.rpm
	@echo
	@echo "TEST variant 1 with download"
	./svn2rpm -o $(TESTOUT) $(SVNURL)/test2
	rpm -qp $(TESTOUT)/test2-19-75.1.noarch.rpm
	@echo
	@echo "TEST variant 2 only source rpm"
	./svn2rpm -s -o $(TESTOUT) $(SVNURL)/test3
	rpm -qp $(TESTOUT)/test3-19-75.1.src.rpm
	test ! -f $(TESTOUT)/test3-19-75.1.noarch.rpm
	@echo
	@echo "TEST variant 2"
	./svn2rpm -o $(TESTOUT) $(SVNURL)/test3
	rpm -qp $(TESTOUT)/test3-19-75.1.noarch.rpm
	@echo


deb: test
	mkdir -p dist build/deb/usr/bin build/deb/usr/share/doc/svn2rpm build/deb/usr/share/lintian/overrides build/deb/DEBIAN
	install -m 0755 svn2rpm build/deb/usr/bin/svn2rpm
	install -m 0644 DEBIAN/* build/deb/DEBIAN
	sed -i -e s/__VERSION__/$(VERSION).$(REVISION)/ build/deb/usr/bin/svn2rpm
	sed -i -e s/__VERSION__/$(VERSION).$(REVISION)/ build/deb/DEBIAN/control
	mv build/deb/DEBIAN/copyright build/deb/usr/share/doc/svn2rpm/copyright
	mv build/deb/DEBIAN/overrides build/deb/usr/share/lintian/overrides/svn2rpm
	chmod -R go-w build # remove group writeable in case you have it in your umask
	find build/deb -type f -name \*~ | xargs rm -vf
	fakeroot dpkg -b build/deb dist
	lintian --quiet -i dist/*deb

srpm: test
	mkdir -p dist build/$(PV) build/BUILD
	cp -r $(TOPLEVEL) Makefile build/$(PV)
	mv build/$(PV)/*.spec build/
	sed -i -e s/__VERSION__/$(VERSION)/ -e /^Release/s/$$/.$(REVISION)/ build/*.spec
	sed -i -e s/__VERSION__/$(VERSION).$(REVISION)/ build/$(PV)/svn2rpm
	tar -czf build/$(PV).tar.gz -C build $(PV)
	rpmbuild --define="_topdir $(CURDIR)/build" --define="_sourcedir $(CURDIR)/build" --define="_srcrpmdir $(CURDIR)/dist" --nodeps -bs build/*.spec

rpm: srpm
	ln -svf ../dist build/noarch
	rpmbuild --nodeps --define="_topdir $(CURDIR)/build" --define="_rpmdir %{_topdir}" --rebuild $(CURDIR)/dist/*.src.rpm
	@echo
	@echo
	@echo
	@echo 'WARNING! THIS RPM IS NOT INTENDED FOR PRODUCTION USE. PLEASE USE rpmbuild --rebuild dist/*.src.rpm TO CREATE A PRODUCTION RPM PACKAGE!'
	@echo
	@echo
	@echo

info: rpminfo debinfo

debinfo: deb
	dpkg-deb -I dist/*.deb

rpminfo: rpm
	rpm -qip dist/*.noarch.rpm

debrepo: deb
	/data/mnt/is24-ubuntu-repo/putinrepo.sh dist/*.deb

rpmrepo: rpm
	echo "##teamcity[buildStatus text='{build.status.text} RPM Version $(shell rpm -qp dist/*src.rpm --queryformat "%{VERSION}-%{RELEASE}")']"
	repoclient uploadto "$(TARGET_REPO)" dist/*.rpm

clean:
	rm -Rf dist/*.rpm dist/*.deb build test/temp

# todo: create debian/RPM changelog automatically, e.g. with git-dch --full --id-length=10 --ignore-regex '^fixes$' -S -s 68809505c5dea13ba18a8f517e82aa4f74d79acb src doc *.spec

