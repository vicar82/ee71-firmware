# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2016-2026 Entware

include $(TOPDIR)/rules.mk

PKG_NAME:=go-src
PKG_VERSION:=1.26.0
PKG_RELEASE:=1

PKG_SOURCE:=go$(PKG_VERSION).src.tar.gz
PKG_SOURCE_URL:= \
		https://dl.google.com/go/ \
		https://mirrors.ustc.edu.cn/golang/ \
		https://mirrors.nju.edu.cn/golang/
PKG_HASH:=c9132a8a1f6bd2aa4aad1d74b8231d95274950483a4950657ee6c56e6e817790

HOST_BUILD_DIR:=$(STAGING_DIR_HOST)/go

BOOTSTRAP_VERSION:= \
	$(shell grep '^PKG_VERSION' ../go-bootstrap/Makefile | cut -b14-17 )

include $(INCLUDE_DIR)/host-build.mk

BOOTSTRAP_GO_BIN:=$(HOST_BUILD_DIR)$(BOOTSTRAP_VERSION)/bin/go

export GOENV=$(STAGING_DIR_HOST)/etc/env

define Host/Configure
	$(BOOTSTRAP_GO_BIN) env -w GOCACHE="$(TMP_DIR)/go-build"
	$(BOOTSTRAP_GO_BIN) env -w GOMODCACHE="$(DL_DIR)/go-mod-cache"
	$(BOOTSTRAP_GO_BIN) env -w GOPATH="$(DL_DIR)/go-mod-cache"
	$(BOOTSTRAP_GO_BIN) env -w GOTMPDIR="$(TMP_DIR)"
endef

define Host/Compile
	( cd $(HOST_BUILD_DIR)/src; \
		GOTELEMETRY=off \
		CC="$(HOSTCC_NOCACHE)" \
		CXX="$(HOSTCXX_NOCACHE)" \
		GOROOT_BOOTSTRAP=$(HOST_BUILD_DIR)$(BOOTSTRAP_VERSION) \
		./make.bash; \
	)
	( cd $(STAGING_DIR_HOST)/bin; \
		for bins in go gofmt; do ln -nsf ../go/bin/$$$$bins $$$$bins; done \
	)
	$(STAGING_DIR_HOST)/bin/go telemetry off
endef

define Host/Install
endef

define Host/Clean
	rm -f $(STAGING_DIR_HOST)/bin/go{,fmt}
	rm -rf $(HOST_BUILD_DIR)
endef

$(eval $(call HostBuild))
