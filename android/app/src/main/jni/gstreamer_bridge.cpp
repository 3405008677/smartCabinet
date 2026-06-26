#include <jni.h>
#include <gst/gst.h>
#include <gst/app/gstappsrc.h>
#include <android/log.h>
#include <dlfcn.h>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

#define LOG_TAG "SmartCabinetGst"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

// Protects native pipeline state shared by MediaCodec output and lifecycle calls.
std::mutex stream_mutex;

// Holds the active GStreamer pipeline instance.
GstElement *pipeline = nullptr;

// Holds the appsrc element that receives encoded H265 frames from Kotlin.
GstElement *video_source = nullptr;

// Tracks whether gst_init_check has completed successfully.
bool gstreamer_initialized = false;

// Minimal Rockchip MPP ABI declarations copied from public Rockchip MPP headers.
using RK_U32 = unsigned int;
using RK_S32 = signed int;
using RK_S64 = signed long long int;
using MPP_RET = RK_S32;
using MppCtx = void *;
using MppParam = void *;
using MppFrame = void *;
using MppPacket = void *;
using MppBuffer = void *;
using MppBufferGroup = void *;
using MppEncCfg = void *;

constexpr MPP_RET MPP_OK = 0;
constexpr RK_S32 MPP_CTX_ENC = 1;
constexpr RK_S32 MPP_VIDEO_CodingHEVC = 11;
constexpr RK_S32 MPP_BUFFER_TYPE_DRM = 3;
constexpr RK_S32 MPP_BUFFER_FLAGS_CACHABLE = 0x00020000;
constexpr RK_S32 MPP_FMT_YUV420SP = 0;
constexpr RK_S32 MPP_POLL_BLOCK = -1;
constexpr RK_S32 MPP_SET_OUTPUT_TIMEOUT = 0x00200008;
constexpr RK_S32 MPP_ENC_SET_CFG = 0x00320001;
constexpr RK_S32 MPP_ENC_GET_CFG = 0x00320002;
constexpr RK_S32 MPP_ENC_GET_HDR_SYNC = 0x0032000E;

struct MppApi {
  RK_U32 size;
  RK_U32 version;
  MPP_RET (*decode)(MppCtx, MppPacket, MppFrame *);
  MPP_RET (*decode_put_packet)(MppCtx, MppPacket);
  MPP_RET (*decode_get_frame)(MppCtx, MppFrame *);
  MPP_RET (*encode)(MppCtx, MppFrame, MppPacket *);
  MPP_RET (*encode_put_frame)(MppCtx, MppFrame);
  MPP_RET (*encode_get_packet)(MppCtx, MppPacket *);
  MPP_RET (*isp)(MppCtx, MppFrame, MppFrame);
  MPP_RET (*isp_put_frame)(MppCtx, MppFrame);
  MPP_RET (*isp_get_frame)(MppCtx, MppFrame *);
  MPP_RET (*poll)(MppCtx, RK_S32, RK_S32);
  MPP_RET (*dequeue)(MppCtx, RK_S32, void **);
  MPP_RET (*enqueue)(MppCtx, RK_S32, void *);
  MPP_RET (*reset)(MppCtx);
  MPP_RET (*control)(MppCtx, RK_S32, MppParam);
  RK_U32 reserv[16];
};

struct RkMppApi {
  void *handle = nullptr;
  MPP_RET (*mpp_check_support_format)(RK_S32, RK_S32) = nullptr;
  MPP_RET (*mpp_create)(MppCtx *, MppApi **) = nullptr;
  MPP_RET (*mpp_init)(MppCtx, RK_S32, RK_S32) = nullptr;
  MPP_RET (*mpp_destroy)(MppCtx) = nullptr;
  MPP_RET (*mpp_enc_cfg_init)(MppEncCfg *) = nullptr;
  MPP_RET (*mpp_enc_cfg_deinit)(MppEncCfg) = nullptr;
  MPP_RET (*mpp_enc_cfg_set_s32)(MppEncCfg, const char *, RK_S32) = nullptr;
  MPP_RET (*mpp_enc_cfg_set_u32)(MppEncCfg, const char *, RK_U32) = nullptr;
  MPP_RET (*mpp_buffer_group_get_internal)(MppBufferGroup *, RK_S32) = nullptr;
  MPP_RET (*mpp_buffer_group_put)(MppBufferGroup) = nullptr;
  MPP_RET (*mpp_buffer_get)(MppBufferGroup, MppBuffer *, size_t) = nullptr;
  MPP_RET (*mpp_buffer_put)(MppBuffer) = nullptr;
  void *(*mpp_buffer_get_ptr)(MppBuffer) = nullptr;
  MPP_RET (*mpp_buffer_sync_begin_f)(MppBuffer, RK_S32, const char *) = nullptr;
  MPP_RET (*mpp_buffer_sync_end_f)(MppBuffer, RK_S32, const char *) = nullptr;
  MPP_RET (*mpp_frame_init)(MppFrame *) = nullptr;
  MPP_RET (*mpp_frame_deinit)(MppFrame *) = nullptr;
  void (*mpp_frame_set_width)(MppFrame, RK_U32) = nullptr;
  void (*mpp_frame_set_height)(MppFrame, RK_U32) = nullptr;
  void (*mpp_frame_set_hor_stride)(MppFrame, RK_U32) = nullptr;
  void (*mpp_frame_set_ver_stride)(MppFrame, RK_U32) = nullptr;
  void (*mpp_frame_set_fmt)(MppFrame, RK_S32) = nullptr;
  void (*mpp_frame_set_pts)(MppFrame, RK_S64) = nullptr;
  void (*mpp_frame_set_buffer)(MppFrame, MppBuffer) = nullptr;
  MPP_RET (*mpp_packet_init_with_buffer)(MppPacket *, MppBuffer) = nullptr;
  MPP_RET (*mpp_packet_deinit)(MppPacket *) = nullptr;
  void (*mpp_packet_set_length)(MppPacket, size_t) = nullptr;
  void *(*mpp_packet_get_pos)(MppPacket) = nullptr;
  size_t (*mpp_packet_get_length)(MppPacket) = nullptr;
};

struct RkMppEncoder {
  MppCtx ctx = nullptr;
  MppApi *mpi = nullptr;
  MppEncCfg cfg = nullptr;
  MppBufferGroup group = nullptr;
  MppBuffer frame_buffer = nullptr;
  RK_U32 width = 0;
  RK_U32 height = 0;
  RK_U32 stride = 0;
  size_t frame_size = 0;
};

std::mutex rkmpp_mutex;
RkMppApi rkmpp_api;
RkMppEncoder rkmpp_encoder;

// Stores the last native GStreamer failure so Kotlin can surface actionable UI status.
std::string last_error;

void set_last_error(const std::string &message) {
  last_error = message;
  LOGE("%s", message.c_str());
}

template <typename T>
bool load_symbol(void *handle, const char *name, T *target) {
  *target = reinterpret_cast<T>(dlsym(handle, name));
  if (*target == nullptr) {
    set_last_error(std::string("RKMPP symbol missing: ") + name + ", " + dlerror());
    return false;
  }
  return true;
}

bool load_rkmpp_locked() {
  if (rkmpp_api.handle != nullptr) {
    return true;
  }
  const char *candidates[] = {
      "libmpp.so",
      "librockchip_mpp.so",
      "librkmpp.so",
      "/vendor/lib64/libmpp.so",
      "/vendor/lib64/librockchip_mpp.so",
      "/vendor/lib64/librkmpp.so",
      "/odm/lib64/libmpp.so",
      "/odm/lib64/librockchip_mpp.so",
      "/odm/lib64/librkmpp.so",
      "/product/lib64/libmpp.so",
      "/product/lib64/librockchip_mpp.so",
      "/product/lib64/librkmpp.so",
      "/system_ext/lib64/libmpp.so",
      "/system_ext/lib64/librockchip_mpp.so",
      "/system_ext/lib64/librkmpp.so",
      "/system/lib64/libmpp.so",
      "/system/lib64/librockchip_mpp.so",
      "/system/lib64/librkmpp.so",
  };

  std::string failures;
  void *handle = nullptr;
  const char *loaded_path = nullptr;
  for (const char *candidate : candidates) {
    dlerror();
    handle = dlopen(candidate, RTLD_NOW);
    if (handle != nullptr) {
      loaded_path = candidate;
      break;
    }
    const char *error = dlerror();
    if (!failures.empty()) {
      failures += "; ";
    }
    failures += candidate;
    failures += " => ";
    failures += error != nullptr ? error : "unknown dlopen error";
  }
  if (handle == nullptr) {
    set_last_error(std::string("RKMPP library load failed: ") + failures);
    return false;
  }

  LOGI("RKMPP library loaded from %s", loaded_path);

  rkmpp_api.handle = handle;
  return load_symbol(handle, "mpp_check_support_format", &rkmpp_api.mpp_check_support_format) &&
      load_symbol(handle, "mpp_create", &rkmpp_api.mpp_create) &&
      load_symbol(handle, "mpp_init", &rkmpp_api.mpp_init) &&
      load_symbol(handle, "mpp_destroy", &rkmpp_api.mpp_destroy) &&
      load_symbol(handle, "mpp_enc_cfg_init", &rkmpp_api.mpp_enc_cfg_init) &&
      load_symbol(handle, "mpp_enc_cfg_deinit", &rkmpp_api.mpp_enc_cfg_deinit) &&
      load_symbol(handle, "mpp_enc_cfg_set_s32", &rkmpp_api.mpp_enc_cfg_set_s32) &&
      load_symbol(handle, "mpp_enc_cfg_set_u32", &rkmpp_api.mpp_enc_cfg_set_u32) &&
      load_symbol(handle, "mpp_buffer_group_get_internal", &rkmpp_api.mpp_buffer_group_get_internal) &&
      load_symbol(handle, "mpp_buffer_group_put", &rkmpp_api.mpp_buffer_group_put) &&
      load_symbol(handle, "mpp_buffer_get", &rkmpp_api.mpp_buffer_get) &&
      load_symbol(handle, "mpp_buffer_put", &rkmpp_api.mpp_buffer_put) &&
      load_symbol(handle, "mpp_buffer_get_ptr", &rkmpp_api.mpp_buffer_get_ptr) &&
      load_symbol(handle, "mpp_buffer_sync_begin_f", &rkmpp_api.mpp_buffer_sync_begin_f) &&
      load_symbol(handle, "mpp_buffer_sync_end_f", &rkmpp_api.mpp_buffer_sync_end_f) &&
      load_symbol(handle, "mpp_frame_init", &rkmpp_api.mpp_frame_init) &&
      load_symbol(handle, "mpp_frame_deinit", &rkmpp_api.mpp_frame_deinit) &&
      load_symbol(handle, "mpp_frame_set_width", &rkmpp_api.mpp_frame_set_width) &&
      load_symbol(handle, "mpp_frame_set_height", &rkmpp_api.mpp_frame_set_height) &&
      load_symbol(handle, "mpp_frame_set_hor_stride", &rkmpp_api.mpp_frame_set_hor_stride) &&
      load_symbol(handle, "mpp_frame_set_ver_stride", &rkmpp_api.mpp_frame_set_ver_stride) &&
      load_symbol(handle, "mpp_frame_set_fmt", &rkmpp_api.mpp_frame_set_fmt) &&
      load_symbol(handle, "mpp_frame_set_pts", &rkmpp_api.mpp_frame_set_pts) &&
      load_symbol(handle, "mpp_frame_set_buffer", &rkmpp_api.mpp_frame_set_buffer) &&
      load_symbol(handle, "mpp_packet_init_with_buffer", &rkmpp_api.mpp_packet_init_with_buffer) &&
      load_symbol(handle, "mpp_packet_deinit", &rkmpp_api.mpp_packet_deinit) &&
      load_symbol(handle, "mpp_packet_set_length", &rkmpp_api.mpp_packet_set_length) &&
      load_symbol(handle, "mpp_packet_get_pos", &rkmpp_api.mpp_packet_get_pos) &&
      load_symbol(handle, "mpp_packet_get_length", &rkmpp_api.mpp_packet_get_length);
}

void stop_rkmpp_locked() {
  if (rkmpp_encoder.frame_buffer != nullptr) {
    rkmpp_api.mpp_buffer_put(rkmpp_encoder.frame_buffer);
  }
  if (rkmpp_encoder.group != nullptr) {
    rkmpp_api.mpp_buffer_group_put(rkmpp_encoder.group);
  }
  if (rkmpp_encoder.cfg != nullptr) {
    rkmpp_api.mpp_enc_cfg_deinit(rkmpp_encoder.cfg);
  }
  if (rkmpp_encoder.ctx != nullptr) {
    rkmpp_api.mpp_destroy(rkmpp_encoder.ctx);
  }
  rkmpp_encoder = RkMppEncoder();
}

// Converts a Java string into a UTF-8 std::string.
std::string to_string(JNIEnv *env, jstring value) {
  if (value == nullptr) {
    return "";
  }
  const char *chars = env->GetStringUTFChars(value, nullptr);
  std::string result(chars == nullptr ? "" : chars);
  if (chars != nullptr) {
    env->ReleaseStringUTFChars(value, chars);
  }
  return result;
}

// Stops and releases the active pipeline if one exists.
void stop_pipeline_locked() {
  if (pipeline != nullptr) {
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    pipeline = nullptr;
    video_source = nullptr;
    LOGI("GStreamer H265 pipeline stopped");
  }
}

}  // namespace

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeInitialize(
    JNIEnv *env,
    jobject /* thiz */) {
  GError *error = nullptr;
  if (!gst_init_check(nullptr, nullptr, &error)) {
    const char *message = error != nullptr ? error->message : "unknown error";
    set_last_error(std::string("GStreamer init failed: ") + message);
    if (error != nullptr) {
      g_error_free(error);
    }
    return JNI_FALSE;
  }

  gstreamer_initialized = true;
  last_error.clear();
  LOGI("GStreamer initialized, version=%s", gst_version_string());
  return JNI_TRUE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeVersion(
    JNIEnv *env,
    jobject /* thiz */) {
  return env->NewStringUTF(gst_version_string());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeLastError(
    JNIEnv *env,
    jobject /* thiz */) {
  std::lock_guard<std::mutex> lock(stream_mutex);
  return env->NewStringUTF(last_error.c_str());
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeStartH265Rtsp(
    JNIEnv *env,
    jobject /* thiz */,
    jstring url,
    jint width,
    jint height,
    jint fps) {
  std::lock_guard<std::mutex> lock(stream_mutex);
  if (!gstreamer_initialized) {
    if (Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeInitialize(env, nullptr) == JNI_FALSE) {
      return JNI_FALSE;
    }
  }

  stop_pipeline_locked();

  const std::string target_url = to_string(env, url);
  const std::string caps = "video/x-h265,stream-format=byte-stream,alignment=au,width=" +
      std::to_string(width) + ",height=" + std::to_string(height) + ",framerate=" +
      std::to_string(fps) + "/1";
  const std::string description =
      "appsrc name=video_source is-live=true do-timestamp=false format=time stream-type=stream caps=\"" +
      caps +
      "\" ! queue leaky=downstream max-size-buffers=30 ! h265parse config-interval=-1 ! "
      "rtph265pay pt=96 config-interval=1 ! rtspclientsink protocols=tcp location=\"" +
      target_url + "\"";

  GError *error = nullptr;
  pipeline = gst_parse_launch(description.c_str(), &error);
  if (pipeline == nullptr) {
    const char *message = error != nullptr ? error->message : "unknown error";
    set_last_error(std::string("GStreamer pipeline create failed: ") + message);
    if (error != nullptr) {
      g_error_free(error);
    }
    return JNI_FALSE;
  }

  video_source = gst_bin_get_by_name(GST_BIN(pipeline), "video_source");
  if (video_source == nullptr) {
    set_last_error("GStreamer appsrc element not found");
    stop_pipeline_locked();
    return JNI_FALSE;
  }

  GstStateChangeReturn result = gst_element_set_state(pipeline, GST_STATE_PLAYING);
  if (result == GST_STATE_CHANGE_FAILURE) {
    set_last_error("GStreamer pipeline failed to enter PLAYING state");
    stop_pipeline_locked();
    return JNI_FALSE;
  }

  last_error.clear();
  LOGI("GStreamer H265 RTSP pipeline started, url=%s", target_url.c_str());
  return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativePushH265Frame(
    JNIEnv *env,
    jobject /* thiz */,
    jbyteArray data,
    jlong pts_us,
    jboolean /* key_frame */) {
  std::lock_guard<std::mutex> lock(stream_mutex);
  if (video_source == nullptr || data == nullptr) {
    return JNI_FALSE;
  }

  const jsize size = env->GetArrayLength(data);
  if (size <= 0) {
    return JNI_TRUE;
  }

  GstBuffer *buffer = gst_buffer_new_allocate(nullptr, static_cast<gsize>(size), nullptr);
  if (buffer == nullptr) {
    return JNI_FALSE;
  }

  GstMapInfo map;
  if (!gst_buffer_map(buffer, &map, GST_MAP_WRITE)) {
    gst_buffer_unref(buffer);
    return JNI_FALSE;
  }
  env->GetByteArrayRegion(data, 0, size, reinterpret_cast<jbyte *>(map.data));
  gst_buffer_unmap(buffer, &map);

  GST_BUFFER_PTS(buffer) = static_cast<GstClockTime>(pts_us) * GST_USECOND;
  GST_BUFFER_DTS(buffer) = GST_BUFFER_PTS(buffer);
  GST_BUFFER_DURATION(buffer) = GST_CLOCK_TIME_NONE;

  GstFlowReturn flow = gst_app_src_push_buffer(GST_APP_SRC(video_source), buffer);
  return flow == GST_FLOW_OK ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeStopH265Rtsp(
    JNIEnv * /* env */,
    jobject /* thiz */) {
  std::lock_guard<std::mutex> lock(stream_mutex);
  stop_pipeline_locked();
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeRkMppStatus(
    JNIEnv *env,
    jobject /* thiz */) {
  std::lock_guard<std::mutex> lock(rkmpp_mutex);
  if (!load_rkmpp_locked()) {
    return env->NewStringUTF(last_error.c_str());
  }
  const MPP_RET support = rkmpp_api.mpp_check_support_format(MPP_CTX_ENC, MPP_VIDEO_CodingHEVC);
  if (support == MPP_OK) {
    return env->NewStringUTF("RKMPP libmpp.so loaded, HEVC encoder supported");
  }
  return env->NewStringUTF(("RKMPP loaded, but HEVC encoder support check failed ret=" + std::to_string(support)).c_str());
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeStartRkMppH265(
    JNIEnv * /* env */,
    jobject /* thiz */,
    jint width,
    jint height,
    jint fps,
    jint bitrate,
    jint gop) {
  std::lock_guard<std::mutex> lock(rkmpp_mutex);
  if (!load_rkmpp_locked()) {
    return JNI_FALSE;
  }

  stop_rkmpp_locked();

  const MPP_RET support = rkmpp_api.mpp_check_support_format(MPP_CTX_ENC, MPP_VIDEO_CodingHEVC);
  if (support != MPP_OK) {
    set_last_error("RKMPP HEVC encoder unsupported ret=" + std::to_string(support));
    return JNI_FALSE;
  }

  RkMppEncoder enc;
  enc.width = static_cast<RK_U32>(width);
  enc.height = static_cast<RK_U32>(height);
  enc.stride = static_cast<RK_U32>((width + 7) & ~7);
  enc.frame_size = static_cast<size_t>(enc.stride) * static_cast<size_t>(height) * 3 / 2;

  MPP_RET ret = rkmpp_api.mpp_buffer_group_get_internal(&enc.group, MPP_BUFFER_TYPE_DRM | MPP_BUFFER_FLAGS_CACHABLE);
  if (ret != MPP_OK) {
    set_last_error("RKMPP buffer group init failed ret=" + std::to_string(ret));
    return JNI_FALSE;
  }
  ret = rkmpp_api.mpp_buffer_get(enc.group, &enc.frame_buffer, enc.frame_size);
  if (ret != MPP_OK) {
    set_last_error("RKMPP frame buffer alloc failed ret=" + std::to_string(ret));
    rkmpp_api.mpp_buffer_group_put(enc.group);
    return JNI_FALSE;
  }
  ret = rkmpp_api.mpp_create(&enc.ctx, &enc.mpi);
  if (ret != MPP_OK || enc.ctx == nullptr || enc.mpi == nullptr) {
    set_last_error("RKMPP mpp_create failed ret=" + std::to_string(ret));
    rkmpp_api.mpp_buffer_put(enc.frame_buffer);
    rkmpp_api.mpp_buffer_group_put(enc.group);
    return JNI_FALSE;
  }
  RK_S32 timeout = MPP_POLL_BLOCK;
  enc.mpi->control(enc.ctx, MPP_SET_OUTPUT_TIMEOUT, &timeout);
  ret = rkmpp_api.mpp_init(enc.ctx, MPP_CTX_ENC, MPP_VIDEO_CodingHEVC);
  if (ret != MPP_OK) {
    set_last_error("RKMPP mpp_init HEVC failed ret=" + std::to_string(ret));
    rkmpp_api.mpp_destroy(enc.ctx);
    rkmpp_api.mpp_buffer_put(enc.frame_buffer);
    rkmpp_api.mpp_buffer_group_put(enc.group);
    return JNI_FALSE;
  }
  ret = rkmpp_api.mpp_enc_cfg_init(&enc.cfg);
  if (ret != MPP_OK) {
    set_last_error("RKMPP mpp_enc_cfg_init failed ret=" + std::to_string(ret));
    rkmpp_api.mpp_destroy(enc.ctx);
    rkmpp_api.mpp_buffer_put(enc.frame_buffer);
    rkmpp_api.mpp_buffer_group_put(enc.group);
    return JNI_FALSE;
  }
  enc.mpi->control(enc.ctx, MPP_ENC_GET_CFG, enc.cfg);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "codec:type", MPP_VIDEO_CodingHEVC);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "prep:width", width);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "prep:height", height);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "prep:hor_stride", static_cast<RK_S32>(enc.stride));
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "prep:ver_stride", height);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "prep:format", MPP_FMT_YUV420SP);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "rc:mode", 1);  // MPP_ENC_RC_MODE_CBR
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "rc:fps_in_flex", 0);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "rc:fps_in_num", fps);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "rc:fps_in_denom", 1);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "rc:fps_out_flex", 0);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "rc:fps_out_num", fps);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "rc:fps_out_denom", 1);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "rc:gop", gop <= 0 ? fps : gop * fps);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "rc:bps_target", bitrate);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "rc:bps_max", bitrate * 17 / 16);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "rc:bps_min", bitrate * 15 / 16);
  ret = enc.mpi->control(enc.ctx, MPP_ENC_SET_CFG, enc.cfg);
  if (ret != MPP_OK) {
    set_last_error("RKMPP MPP_ENC_SET_CFG failed ret=" + std::to_string(ret));
    if (enc.cfg) rkmpp_api.mpp_enc_cfg_deinit(enc.cfg);
    if (enc.ctx) rkmpp_api.mpp_destroy(enc.ctx);
    if (enc.frame_buffer) rkmpp_api.mpp_buffer_put(enc.frame_buffer);
    if (enc.group) rkmpp_api.mpp_buffer_group_put(enc.group);
    return JNI_FALSE;
  }

  rkmpp_encoder = enc;
  last_error.clear();
  LOGI("RKMPP H265 encoder started, size=%dx%d fps=%d bitrate=%d", width, height, fps, bitrate);
  return JNI_TRUE;
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeEncodeRkMppH265Frame(
    JNIEnv *env,
    jobject /* thiz */,
    jbyteArray nv12,
    jlong pts_us) {
  std::lock_guard<std::mutex> lock(rkmpp_mutex);
  if (rkmpp_encoder.ctx == nullptr || nv12 == nullptr) {
    set_last_error("RKMPP encoder is not started");
    return nullptr;
  }
  const jsize input_size = env->GetArrayLength(nv12);
  if (input_size <= 0 || static_cast<size_t>(input_size) > rkmpp_encoder.frame_size) {
    set_last_error("RKMPP invalid input frame size=" + std::to_string(input_size));
    return nullptr;
  }
  void *frame_ptr = rkmpp_api.mpp_buffer_get_ptr(rkmpp_encoder.frame_buffer);
  if (frame_ptr == nullptr) {
    set_last_error("RKMPP frame buffer pointer is null");
    return nullptr;
  }
  env->GetByteArrayRegion(nv12, 0, input_size, reinterpret_cast<jbyte *>(frame_ptr));
  rkmpp_api.mpp_buffer_sync_end_f(rkmpp_encoder.frame_buffer, 0, "nativeEncodeRkMppH265Frame");

  MppFrame frame = nullptr;
  MPP_RET ret = rkmpp_api.mpp_frame_init(&frame);
  if (ret != MPP_OK || frame == nullptr) {
    set_last_error("RKMPP mpp_frame_init failed ret=" + std::to_string(ret));
    return nullptr;
  }
  rkmpp_api.mpp_frame_set_width(frame, rkmpp_encoder.width);
  rkmpp_api.mpp_frame_set_height(frame, rkmpp_encoder.height);
  rkmpp_api.mpp_frame_set_hor_stride(frame, rkmpp_encoder.stride);
  rkmpp_api.mpp_frame_set_ver_stride(frame, rkmpp_encoder.height);
  rkmpp_api.mpp_frame_set_fmt(frame, MPP_FMT_YUV420SP);
  rkmpp_api.mpp_frame_set_pts(frame, pts_us);
  rkmpp_api.mpp_frame_set_buffer(frame, rkmpp_encoder.frame_buffer);

  ret = rkmpp_encoder.mpi->encode_put_frame(rkmpp_encoder.ctx, frame);
  rkmpp_api.mpp_frame_deinit(&frame);
  if (ret != MPP_OK) {
    set_last_error("RKMPP encode_put_frame failed ret=" + std::to_string(ret));
    return nullptr;
  }

  MppPacket packet = nullptr;
  ret = rkmpp_encoder.mpi->encode_get_packet(rkmpp_encoder.ctx, &packet);
  if (ret != MPP_OK || packet == nullptr) {
    set_last_error("RKMPP encode_get_packet failed ret=" + std::to_string(ret));
    return nullptr;
  }
  void *pos = rkmpp_api.mpp_packet_get_pos(packet);
  const size_t length = rkmpp_api.mpp_packet_get_length(packet);
  if (pos == nullptr || length == 0) {
    rkmpp_api.mpp_packet_deinit(&packet);
    set_last_error("RKMPP output packet is empty");
    return nullptr;
  }
  jbyteArray result = env->NewByteArray(static_cast<jsize>(length));
  if (result != nullptr) {
    env->SetByteArrayRegion(result, 0, static_cast<jsize>(length), reinterpret_cast<jbyte *>(pos));
  }
  rkmpp_api.mpp_packet_deinit(&packet);
  last_error.clear();
  return result;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeStopRkMppH265(
    JNIEnv * /* env */,
    jobject /* thiz */) {
  std::lock_guard<std::mutex> lock(rkmpp_mutex);
  if (rkmpp_api.handle != nullptr) {
    stop_rkmpp_locked();
  }
}
