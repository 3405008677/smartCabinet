LOCAL_PATH := $(call my-dir)

ifeq ($(GSTREAMER_ROOT_ANDROID),)
GSTREAMER_ROOT_ANDROID := E:/GStreamer/1.0/android
endif

ifeq ($(TARGET_ARCH_ABI),arm64-v8a)
GSTREAMER_ROOT := $(GSTREAMER_ROOT_ANDROID)/arm64
else ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
GSTREAMER_ROOT := $(GSTREAMER_ROOT_ANDROID)/armv7
else ifeq ($(TARGET_ARCH_ABI),x86)
GSTREAMER_ROOT := $(GSTREAMER_ROOT_ANDROID)/x86
else ifeq ($(TARGET_ARCH_ABI),x86_64)
GSTREAMER_ROOT := $(GSTREAMER_ROOT_ANDROID)/x86_64
else
$(error Unsupported ABI $(TARGET_ARCH_ABI))
endif

GSTREAMER_PLUGINS := coreelements app videoparsersbad rtp rtsp rtspclientsink udp tcp isomp4
GSTREAMER_EXTRA_DEPS := gstreamer-app-1.0 gstreamer-rtsp-1.0
GSTREAMER_JAVA_SRC_DIR := $(LOCAL_PATH)/src

include $(GSTREAMER_ROOT)/share/gst-android/ndk-build/gstreamer-1.0.mk

include $(CLEAR_VARS)
LOCAL_MODULE := smartcabinet_gstreamer
LOCAL_SRC_FILES := gstreamer_bridge.cpp
LOCAL_SHARED_LIBRARIES := gstreamer_android
LOCAL_LDLIBS := -llog
include $(BUILD_SHARED_LIBRARY)
