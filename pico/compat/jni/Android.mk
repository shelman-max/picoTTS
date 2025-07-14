LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE:= libttscompat
LOCAL_MULTILIB := both

LOCAL_SRC_FILES:= \
	com_android_tts_compat_SynthProxy.cpp

LOCAL_C_INCLUDES += \
	frameworks/base/native/include \
	$(JNI_H_INCLUDE)

LOCAL_SHARED_LIBRARIES := \
	libandroid_runtime \
	libnativehelper \
	libmedia \
	libutils \
	libcutils \
	liblog \
	libdl

LOCAL_CFLAGS := \
    -Wall -Werror \
    -Wno-unused-parameter \
    -DPICO_ARCH_INFO

# 64位架构支持
ifeq ($(TARGET_ARCH),arm64)
    LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT -DPICO_ARM64
endif
ifeq ($(TARGET_ARCH),x86_64)
    LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT -DPICO_X86_64
endif

include $(BUILD_SHARED_LIBRARY)
