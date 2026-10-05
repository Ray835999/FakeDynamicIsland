TARGET := iphone:clang:15.6:14.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FakeDynamicIsland
FakeDynamicIsland_FILES = Tweak.xm
FakeDynamicIsland_CFLAGS = -fobjc-arc

FakeDynamicIslandPrefs_NAME = FakeDynamicIslandPrefs
FakeDynamicIslandPrefs_FILES = FakeDynamicIslandPrefs.m
FakeDynamicIslandPrefs_INSTALL_PATH = /Library/PreferenceBundles
FakeDynamicIslandPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
FakeDynamicIslandPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
