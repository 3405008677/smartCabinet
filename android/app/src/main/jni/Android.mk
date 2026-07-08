LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := smartcabinet_rkmpp
LOCAL_SRC_FILES := rkmpp_bridge.cpp
LOCAL_LDLIBS := -llog
include $(BUILD_SHARED_LIBRARY)
