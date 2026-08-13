# 目标柜机仅部署 64 位 ARM；共享 libc++ 必须与 jniLibs 中随包分发的
# libc++_shared.so 保持一致，最低平台也需覆盖本桥接层使用的 NDK API。
APP_STL := c++_shared
APP_PLATFORM := android-24
APP_ABI := arm64-v8a
