# Build Base Generic SVOX Pico Library

LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE := libsvoxpico
LOCAL_MULTILIB := both

LOCAL_SRC_FILES := \
	picoacph.c \
	picoapi.c \
	picobase.c \
	picocep.c \
	picoctrl.c \
	picodata.c \
	picodbg.c \
	picoextapi.c \
	picofftsg.c \
	picokdbg.c \
	picokdt.c \
	picokfst.c \
	picoklex.c \
	picoknow.c \
	picokpdf.c \
	picokpr.c \
	picoktab.c \
	picoos.c \
	picopal.c \
	picopam.c \
	picopr.c \
	picorsrc.c \
	picosa.c \
	picosig.c \
	picosig2.c \
	picospho.c \
	picotok.c \
	picotrns.c \
	picowa.c

LOCAL_CFLAGS+= $(TOOL_CFLAGS)
LOCAL_LDFLAGS+= $(TOOL_LDFLAGS)

LOCAL_CFLAGS += \
    -Wall -Werror \
    -Wno-error=infinite-recursion \
    -Wno-parentheses-equality \
    -Wno-self-assign \
    -Wno-sign-compare \
    -Wno-unneeded-internal-declaration \
    -Wno-unused-parameter \
    -DPICO_ARCH_INFO

# 64位架构支持
ifeq ($(TARGET_ARCH),arm64)
    LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT -DPICO_ARM64
endif
ifeq ($(TARGET_ARCH),x86_64)
    LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT -DPICO_X86_64
endif

include $(BUILD_STATIC_LIBRARY)




