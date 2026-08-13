LOCAL_PATH := $(call my-dir)

# 桥接层只在 Gradle 显式启用 NDK 构建时参与编译；RKMPP 厂商库由运行期动态探测，
# 因而这里不直接链接 libmpp，避免不同柜机 ROM 的库名和安装分区差异阻断打包。
include $(CLEAR_VARS)
LOCAL_MODULE := smartcabinet_rkmpp
LOCAL_SRC_FILES := ../cpp/rkmpp_bridge.cpp
LOCAL_LDLIBS := -llog
include $(BUILD_SHARED_LIBRARY)
