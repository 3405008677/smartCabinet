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

// Holds the pipeline bus so appsrc pushes can surface async RTSP connection errors.
GstBus *pipeline_bus = nullptr;

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
constexpr RK_S32 MPP_VIDEO_CodingHEVC = 0x01000004;
constexpr RK_S32 MPP_BUFFER_INTERNAL = 0;
constexpr RK_S32 MPP_BUFFER_TYPE_DRM = 3;
constexpr RK_S32 MPP_BUFFER_FLAGS_CACHABLE = 0x00020000;
constexpr RK_S32 MPP_FMT_YUV420SP = 0;
constexpr RK_S32 MPP_POLL_BLOCK = -1;
constexpr RK_S32 MPP_SET_OUTPUT_TIMEOUT = 0x00200007;
constexpr RK_S32 MPP_ENC_SET_CFG = 0x00320001;
constexpr RK_S32 MPP_ENC_GET_CFG = 0x00320002;
constexpr RK_S32 MPP_ENC_GET_HDR_SYNC = 0x0032000D;
constexpr RK_S32 MPP_ENC_GET_EXTRA_INFO = 0x0032000E;

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
  MPP_RET (*mpp_buffer_group_get)(MppBufferGroup *, RK_S32, RK_S32, const char *, const char *) = nullptr;
  MPP_RET (*mpp_buffer_group_put)(MppBufferGroup) = nullptr;
  MPP_RET (*mpp_buffer_get_with_tag)(MppBufferGroup, MppBuffer *, size_t, const char *, const char *) = nullptr;
  MPP_RET (*mpp_buffer_put_with_caller)(MppBuffer, const char *) = nullptr;
  void *(*mpp_buffer_get_ptr_with_caller)(MppBuffer, const char *) = nullptr;
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
  MppBuffer header_buffer = nullptr;
  RK_U32 width = 0;
  RK_U32 height = 0;
  RK_U32 stride = 0;
  size_t frame_size = 0;
  std::vector<unsigned char> header;
  bool header_sent = false;
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

  bool loaded = load_symbol(handle, "mpp_check_support_format", &rkmpp_api.mpp_check_support_format) &&
      load_symbol(handle, "mpp_create", &rkmpp_api.mpp_create) &&
      load_symbol(handle, "mpp_init", &rkmpp_api.mpp_init) &&
      load_symbol(handle, "mpp_destroy", &rkmpp_api.mpp_destroy) &&
      load_symbol(handle, "mpp_enc_cfg_init", &rkmpp_api.mpp_enc_cfg_init) &&
      load_symbol(handle, "mpp_enc_cfg_deinit", &rkmpp_api.mpp_enc_cfg_deinit) &&
      load_symbol(handle, "mpp_enc_cfg_set_s32", &rkmpp_api.mpp_enc_cfg_set_s32) &&
      load_symbol(handle, "mpp_enc_cfg_set_u32", &rkmpp_api.mpp_enc_cfg_set_u32) &&
      load_symbol(handle, "mpp_buffer_group_get", &rkmpp_api.mpp_buffer_group_get) &&
      load_symbol(handle, "mpp_buffer_group_put", &rkmpp_api.mpp_buffer_group_put) &&
      load_symbol(handle, "mpp_buffer_get_with_tag", &rkmpp_api.mpp_buffer_get_with_tag) &&
      load_symbol(handle, "mpp_buffer_put_with_caller", &rkmpp_api.mpp_buffer_put_with_caller) &&
      load_symbol(handle, "mpp_buffer_get_ptr_with_caller", &rkmpp_api.mpp_buffer_get_ptr_with_caller) &&
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
  if (!loaded) {
    rkmpp_api = RkMppApi();
    return false;
  }

  rkmpp_api.handle = handle;
  return true;
}

void release_rkmpp_encoder_locked(RkMppEncoder &encoder, const char *caller) {
  if (encoder.frame_buffer != nullptr) {
    rkmpp_api.mpp_buffer_put_with_caller(encoder.frame_buffer, caller);
  }
  if (encoder.header_buffer != nullptr) {
    rkmpp_api.mpp_buffer_put_with_caller(encoder.header_buffer, caller);
  }
  if (encoder.group != nullptr) {
    rkmpp_api.mpp_buffer_group_put(encoder.group);
  }
  if (encoder.cfg != nullptr) {
    rkmpp_api.mpp_enc_cfg_deinit(encoder.cfg);
  }
  if (encoder.ctx != nullptr) {
    rkmpp_api.mpp_destroy(encoder.ctx);
  }
  encoder = RkMppEncoder();
}

void stop_rkmpp_locked() {
  release_rkmpp_encoder_locked(rkmpp_encoder, "stopRkMppH265");
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
    if (pipeline_bus != nullptr) {
      gst_object_unref(pipeline_bus);
      pipeline_bus = nullptr;
    }
    gst_object_unref(pipeline);
    pipeline = nullptr;
    video_source = nullptr;
    LOGI("GStreamer H265 pipeline stopped");
  }
}

bool check_pipeline_bus_locked() {
  if (pipeline_bus == nullptr) {
    return true;
  }
  GstMessage *message = gst_bus_pop_filtered(
      pipeline_bus,
      static_cast<GstMessageType>(GST_MESSAGE_ERROR | GST_MESSAGE_WARNING | GST_MESSAGE_EOS));
  if (message == nullptr) {
    return true;
  }
  bool ok = true;
  if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_ERROR) {
    GError *error = nullptr;
    gchar *debug = nullptr;
    gst_message_parse_error(message, &error, &debug);
    const char *text = error != nullptr ? error->message : "unknown GStreamer error";
    set_last_error(std::string("GStreamer pipeline error: ") + text +
        (debug != nullptr ? std::string(", debug=") + debug : ""));
    if (error != nullptr) g_error_free(error);
    if (debug != nullptr) g_free(debug);
    ok = false;
  } else if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_WARNING) {
    GError *error = nullptr;
    gchar *debug = nullptr;
    gst_message_parse_warning(message, &error, &debug);
    const char *text = error != nullptr ? error->message : "unknown GStreamer warning";
    set_last_error(std::string("GStreamer pipeline warning: ") + text +
        (debug != nullptr ? std::string(", debug=") + debug : ""));
    if (error != nullptr) g_error_free(error);
    if (debug != nullptr) g_free(debug);
  } else if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_EOS) {
    set_last_error("GStreamer pipeline reached EOS");
    ok = false;
  }
  gst_message_unref(message);
  return ok;
}

bool has_gstreamer_element_factory(const char *name) {
  GstElementFactory *factory = gst_element_factory_find(name);
  if (factory == nullptr) {
    set_last_error(std::string("GStreamer element missing: ") + name);
    return false;
  }
  gst_object_unref(factory);
  return true;
}

std::string pop_pipeline_diagnostics_locked() {
  if (pipeline_bus == nullptr) {
    return "";
  }
  std::string diagnostics;
  while (true) {
    GstMessage *message = gst_bus_pop(pipeline_bus);
    if (message == nullptr) {
      break;
    }
    if (!diagnostics.empty()) {
      diagnostics += "\n";
    }
    const char *source = GST_OBJECT_NAME(message->src);
    if (source == nullptr) {
      source = "unknown";
    }
    diagnostics += "GStreamer bus ";
    diagnostics += GST_MESSAGE_TYPE_NAME(message);
    diagnostics += " from ";
    diagnostics += source;
    if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_ERROR) {
      GError *error = nullptr;
      gchar *debug = nullptr;
      gst_message_parse_error(message, &error, &debug);
      diagnostics += ": ";
      diagnostics += error != nullptr ? error->message : "unknown error";
      if (debug != nullptr) {
        diagnostics += ", debug=";
        diagnostics += debug;
      }
      if (error != nullptr) g_error_free(error);
      if (debug != nullptr) g_free(debug);
    } else if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_WARNING) {
      GError *error = nullptr;
      gchar *debug = nullptr;
      gst_message_parse_warning(message, &error, &debug);
      diagnostics += ": ";
      diagnostics += error != nullptr ? error->message : "unknown warning";
      if (debug != nullptr) {
        diagnostics += ", debug=";
        diagnostics += debug;
      }
      if (error != nullptr) g_error_free(error);
      if (debug != nullptr) g_free(debug);
    } else if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_STATE_CHANGED) {
      GstState old_state;
      GstState new_state;
      GstState pending_state;
      gst_message_parse_state_changed(message, &old_state, &new_state, &pending_state);
      diagnostics += ": ";
      diagnostics += gst_element_state_get_name(old_state);
      diagnostics += " -> ";
      diagnostics += gst_element_state_get_name(new_state);
      diagnostics += " pending=";
      diagnostics += gst_element_state_get_name(pending_state);
    } else if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_STREAM_STATUS) {
      GstStreamStatusType type;
      GstElement *owner = nullptr;
      gst_message_parse_stream_status(message, &type, &owner);
      diagnostics += ": type=";
      diagnostics += std::to_string(static_cast<int>(type));
      if (owner != nullptr) {
        diagnostics += " owner=";
        diagnostics += GST_OBJECT_NAME(owner);
      }
    } else if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_EOS) {
      diagnostics += ": eos";
    }
    gst_message_unref(message);
  }
  return diagnostics;
}

void copy_yuv420_to_nv12(
    const uint8_t *y,
    const uint8_t *u,
    const uint8_t *v,
    int width,
    int height,
    int y_row_stride,
    int y_pixel_stride,
    int u_row_stride,
    int u_pixel_stride,
    int v_row_stride,
    int v_pixel_stride,
    jbyte *output) {
  for (int row = 0; row < height; row += 1) {
    const uint8_t *source = y + row * y_row_stride;
    jbyte *target = output + row * width;
    if (y_pixel_stride == 1) {
      memcpy(target, source, static_cast<size_t>(width));
    } else {
      for (int col = 0; col < width; col += 1) {
        target[col] = static_cast<jbyte>(source[col * y_pixel_stride]);
      }
    }
  }
  jbyte *chroma = output + width * height;
  int out = 0;
  for (int row = 0; row < height / 2; row += 1) {
    const uint8_t *u_row = u + row * u_row_stride;
    const uint8_t *v_row = v + row * v_row_stride;
    for (int col = 0; col < width / 2; col += 1) {
      chroma[out++] = static_cast<jbyte>(u_row[col * u_pixel_stride]);
      chroma[out++] = static_cast<jbyte>(v_row[col * v_pixel_stride]);
    }
  }
}

jbyteArray encode_rkmpp_frame_locked(JNIEnv *env, RkMppEncoder &encoder, jlong pts_us) {
  MppFrame frame = nullptr;
  MPP_RET ret = rkmpp_api.mpp_frame_init(&frame);
  if (ret != MPP_OK || frame == nullptr) {
    set_last_error("RKMPP mpp_frame_init failed ret=" + std::to_string(ret));
    return nullptr;
  }
  rkmpp_api.mpp_frame_set_width(frame, encoder.width);
  rkmpp_api.mpp_frame_set_height(frame, encoder.height);
  rkmpp_api.mpp_frame_set_hor_stride(frame, encoder.stride);
  rkmpp_api.mpp_frame_set_ver_stride(frame, encoder.height);
  rkmpp_api.mpp_frame_set_fmt(frame, MPP_FMT_YUV420SP);
  rkmpp_api.mpp_frame_set_pts(frame, pts_us);
  rkmpp_api.mpp_frame_set_buffer(frame, encoder.frame_buffer);

  ret = encoder.mpi->encode_put_frame(encoder.ctx, frame);
  rkmpp_api.mpp_frame_deinit(&frame);
  if (ret != MPP_OK) {
    set_last_error("RKMPP encode_put_frame failed ret=" + std::to_string(ret));
    return nullptr;
  }

  MppPacket packet = nullptr;
  ret = encoder.mpi->encode_get_packet(encoder.ctx, &packet);
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
  const bool prepend_header = !encoder.header_sent && !encoder.header.empty();
  const size_t output_length = length + (prepend_header ? encoder.header.size() : 0);
  jbyteArray result = env->NewByteArray(static_cast<jsize>(output_length));
  if (result != nullptr) {
    jsize offset = 0;
    if (prepend_header) {
      env->SetByteArrayRegion(
          result,
          0,
          static_cast<jsize>(encoder.header.size()),
          reinterpret_cast<jbyte *>(encoder.header.data()));
      offset = static_cast<jsize>(encoder.header.size());
      encoder.header_sent = true;
    }
    env->SetByteArrayRegion(result, offset, static_cast<jsize>(length), reinterpret_cast<jbyte *>(pos));
  }
  rkmpp_api.mpp_packet_deinit(&packet);
  last_error.clear();
  return result;
}

jbyteArray encode_rkmpp_frame_locked(JNIEnv *env, jlong pts_us) {
  return encode_rkmpp_frame_locked(env, rkmpp_encoder, pts_us);
}

bool start_rkmpp_encoder_locked(RkMppEncoder &enc, jint width, jint height, jint fps, jint bitrate, jint gop, const char *tag) {
  const MPP_RET support = rkmpp_api.mpp_check_support_format(MPP_CTX_ENC, MPP_VIDEO_CodingHEVC);
  if (support != MPP_OK) {
    set_last_error("RKMPP HEVC encoder unsupported ret=" + std::to_string(support));
    return false;
  }

  enc.width = static_cast<RK_U32>(width);
  enc.height = static_cast<RK_U32>(height);
  enc.stride = static_cast<RK_U32>((width + 7) & ~7);
  enc.frame_size = static_cast<size_t>(enc.stride) * static_cast<size_t>(height) * 3 / 2;

  MPP_RET ret = rkmpp_api.mpp_buffer_group_get(&enc.group, MPP_BUFFER_TYPE_DRM | MPP_BUFFER_FLAGS_CACHABLE, MPP_BUFFER_INTERNAL, "SmartCabinet", tag);
  if (ret != MPP_OK) {
    set_last_error("RKMPP buffer group init failed ret=" + std::to_string(ret));
    return false;
  }
  ret = rkmpp_api.mpp_buffer_get_with_tag(enc.group, &enc.frame_buffer, enc.frame_size, "SmartCabinet", tag);
  if (ret != MPP_OK) {
    set_last_error("RKMPP frame buffer alloc failed ret=" + std::to_string(ret));
    release_rkmpp_encoder_locked(enc, tag);
    return false;
  }
  ret = rkmpp_api.mpp_create(&enc.ctx, &enc.mpi);
  if (ret != MPP_OK || enc.ctx == nullptr || enc.mpi == nullptr) {
    set_last_error("RKMPP mpp_create failed ret=" + std::to_string(ret));
    release_rkmpp_encoder_locked(enc, tag);
    return false;
  }
  RK_S32 timeout = MPP_POLL_BLOCK;
  enc.mpi->control(enc.ctx, MPP_SET_OUTPUT_TIMEOUT, &timeout);
  ret = rkmpp_api.mpp_init(enc.ctx, MPP_CTX_ENC, MPP_VIDEO_CodingHEVC);
  if (ret != MPP_OK) {
    set_last_error("RKMPP mpp_init HEVC failed ret=" + std::to_string(ret));
    release_rkmpp_encoder_locked(enc, tag);
    return false;
  }
  ret = rkmpp_api.mpp_enc_cfg_init(&enc.cfg);
  if (ret != MPP_OK) {
    set_last_error("RKMPP mpp_enc_cfg_init failed ret=" + std::to_string(ret));
    release_rkmpp_encoder_locked(enc, tag);
    return false;
  }
  enc.mpi->control(enc.ctx, MPP_ENC_GET_CFG, enc.cfg);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "codec:type", MPP_VIDEO_CodingHEVC);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "prep:width", width);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "prep:height", height);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "prep:hor_stride", static_cast<RK_S32>(enc.stride));
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "prep:ver_stride", height);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "prep:format", MPP_FMT_YUV420SP);
  rkmpp_api.mpp_enc_cfg_set_s32(enc.cfg, "rc:mode", 1);
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
    release_rkmpp_encoder_locked(enc, tag);
    return false;
  }

  ret = rkmpp_api.mpp_buffer_get_with_tag(enc.group, &enc.header_buffer, 4096, "SmartCabinet", "nativeStartRkMppH265Header");
  if (ret == MPP_OK && enc.header_buffer != nullptr) {
    const RK_S32 header_commands[] = {MPP_ENC_GET_HDR_SYNC, MPP_ENC_GET_EXTRA_INFO};
    const char *header_command_names[] = {"MPP_ENC_GET_HDR_SYNC", "MPP_ENC_GET_EXTRA_INFO"};
    for (size_t index = 0; index < 2 && enc.header.empty(); index += 1) {
      MppPacket header_packet = nullptr;
      ret = rkmpp_api.mpp_packet_init_with_buffer(&header_packet, enc.header_buffer);
      if (ret != MPP_OK || header_packet == nullptr) continue;
      rkmpp_api.mpp_packet_set_length(header_packet, 0);
      ret = enc.mpi->control(enc.ctx, header_commands[index], header_packet);
      if (ret == MPP_OK) {
        void *header_pos = rkmpp_api.mpp_packet_get_pos(header_packet);
        const size_t header_length = rkmpp_api.mpp_packet_get_length(header_packet);
        if (header_pos != nullptr && header_length > 0) {
          auto *bytes = reinterpret_cast<unsigned char *>(header_pos);
          enc.header.assign(bytes, bytes + header_length);
          LOGI("RKMPP H265 header generated by %s, bytes=%zu", header_command_names[index], header_length);
        }
      }
      rkmpp_api.mpp_packet_deinit(&header_packet);
    }
  }
  last_error.clear();
  LOGI("RKMPP H265 encoder started, size=%dx%d fps=%d bitrate=%d", width, height, fps, bitrate);
  return true;
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

  const char *required_factories[] = {"appsrc", "h265parse", "rtspclientsink"};
  for (const char *factory : required_factories) {
    if (!has_gstreamer_element_factory(factory)) {
      return JNI_FALSE;
    }
  }

  const std::string target_url = to_string(env, url);
  const std::string caps = "video/x-h265,stream-format=byte-stream,alignment=au,width=" +
      std::to_string(width) + ",height=" + std::to_string(height) + ",framerate=" +
      std::to_string(fps) + "/1";
  const std::string description =
      "rtspclientsink name=rtsp_sink protocols=tcp location=\"" + target_url +
      "\" appsrc name=video_source is-live=true do-timestamp=false format=time stream-type=stream caps=\"" +
      caps +
      "\" ! queue leaky=downstream max-size-buffers=30 ! h265parse config-interval=-1 ! "
      "rtsp_sink.sink_0";

  GError *error = nullptr;
  pipeline = gst_parse_launch(description.c_str(), &error);
  if (error != nullptr) {
    const char *message = error != nullptr ? error->message : "unknown error";
    set_last_error(std::string("GStreamer pipeline create failed: ") + message);
    if (error != nullptr) {
      g_error_free(error);
    }
    stop_pipeline_locked();
    return JNI_FALSE;
  }
  if (pipeline == nullptr) {
    set_last_error("GStreamer pipeline create failed: unknown error");
    return JNI_FALSE;
  }

  video_source = gst_bin_get_by_name(GST_BIN(pipeline), "video_source");
  if (video_source == nullptr) {
    set_last_error("GStreamer appsrc element not found");
    stop_pipeline_locked();
    return JNI_FALSE;
  }
  pipeline_bus = gst_element_get_bus(pipeline);

  GstStateChangeReturn result = gst_element_set_state(pipeline, GST_STATE_PLAYING);
  if (result == GST_STATE_CHANGE_FAILURE) {
    set_last_error("GStreamer pipeline failed to enter PLAYING state");
    stop_pipeline_locked();
    return JNI_FALSE;
  }
  if (!check_pipeline_bus_locked()) {
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

  if (!check_pipeline_bus_locked()) {
    gst_buffer_unref(buffer);
    return JNI_FALSE;
  }
  GstFlowReturn flow = gst_app_src_push_buffer(GST_APP_SRC(video_source), buffer);
  if (flow != GST_FLOW_OK) {
    set_last_error("GStreamer appsrc push failed flow=" + std::to_string(static_cast<int>(flow)));
    return JNI_FALSE;
  }
  return check_pipeline_bus_locked() ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativePollH265RtspDiagnostics(
    JNIEnv *env,
    jobject /* thiz */) {
  std::lock_guard<std::mutex> lock(stream_mutex);
  const std::string diagnostics = pop_pipeline_diagnostics_locked();
  return env->NewStringUTF(diagnostics.c_str());
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
  return start_rkmpp_encoder_locked(rkmpp_encoder, width, height, fps, bitrate, gop, "nativeStartRkMppH265") ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeCreateRkMppH265Encoder(
    JNIEnv * /* env */,
    jobject /* thiz */,
    jint width,
    jint height,
    jint fps,
    jint bitrate,
    jint gop) {
  std::lock_guard<std::mutex> lock(rkmpp_mutex);
  if (!load_rkmpp_locked()) {
    return 0L;
  }
  auto *encoder = new RkMppEncoder();
  if (!start_rkmpp_encoder_locked(*encoder, width, height, fps, bitrate, gop, "nativeCreateRkMppH265Encoder")) {
    delete encoder;
    return 0L;
  }
  return reinterpret_cast<jlong>(encoder);
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
  void *frame_ptr = rkmpp_api.mpp_buffer_get_ptr_with_caller(
      rkmpp_encoder.frame_buffer,
      "nativeEncodeRkMppH265Frame");
  if (frame_ptr == nullptr) {
    set_last_error("RKMPP frame buffer pointer is null");
    return nullptr;
  }
  env->GetByteArrayRegion(nv12, 0, input_size, reinterpret_cast<jbyte *>(frame_ptr));
  rkmpp_api.mpp_buffer_sync_end_f(rkmpp_encoder.frame_buffer, 0, "nativeEncodeRkMppH265Frame");
  return encode_rkmpp_frame_locked(env, pts_us);
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeEncodeRkMppH265ImageWithHandle(
    JNIEnv *env,
    jobject /* thiz */,
    jlong handle,
    jobject y_buffer,
    jobject u_buffer,
    jobject v_buffer,
    jint width,
    jint height,
    jint y_row_stride,
    jint y_pixel_stride,
    jint u_row_stride,
    jint u_pixel_stride,
    jint v_row_stride,
    jint v_pixel_stride,
    jlong pts_us) {
  std::lock_guard<std::mutex> lock(rkmpp_mutex);
  auto *encoder = reinterpret_cast<RkMppEncoder *>(handle);
  if (encoder == nullptr || encoder->ctx == nullptr || y_buffer == nullptr || u_buffer == nullptr || v_buffer == nullptr) {
    set_last_error("RKMPP encoder handle or YUV input is not ready");
    return nullptr;
  }
  if (width != static_cast<jint>(encoder->width) || height != static_cast<jint>(encoder->height)) {
    set_last_error("RKMPP image size mismatch width=" + std::to_string(width) + " height=" + std::to_string(height));
    return nullptr;
  }
  auto *y = reinterpret_cast<const uint8_t *>(env->GetDirectBufferAddress(y_buffer));
  auto *u = reinterpret_cast<const uint8_t *>(env->GetDirectBufferAddress(u_buffer));
  auto *v = reinterpret_cast<const uint8_t *>(env->GetDirectBufferAddress(v_buffer));
  if (y == nullptr || u == nullptr || v == nullptr) {
    set_last_error("RKMPP direct YUV buffer address is null");
    return nullptr;
  }
  void *frame_ptr = rkmpp_api.mpp_buffer_get_ptr_with_caller(encoder->frame_buffer, "nativeEncodeRkMppH265ImageWithHandle");
  if (frame_ptr == nullptr) {
    set_last_error("RKMPP frame buffer pointer is null");
    return nullptr;
  }
  copy_yuv420_to_nv12(
      y,
      u,
      v,
      width,
      height,
      y_row_stride,
      y_pixel_stride,
      u_row_stride,
      u_pixel_stride,
      v_row_stride,
      v_pixel_stride,
      reinterpret_cast<jbyte *>(frame_ptr));
  rkmpp_api.mpp_buffer_sync_end_f(encoder->frame_buffer, 0, "nativeEncodeRkMppH265ImageWithHandle");
  return encode_rkmpp_frame_locked(env, *encoder, pts_us);
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeEncodeRkMppH265Image(
    JNIEnv *env,
    jobject /* thiz */,
    jobject y_buffer,
    jobject u_buffer,
    jobject v_buffer,
    jint width,
    jint height,
    jint y_row_stride,
    jint y_pixel_stride,
    jint u_row_stride,
    jint u_pixel_stride,
    jint v_row_stride,
    jint v_pixel_stride,
    jlong pts_us) {
  std::lock_guard<std::mutex> lock(rkmpp_mutex);
  if (rkmpp_encoder.ctx == nullptr || y_buffer == nullptr || u_buffer == nullptr || v_buffer == nullptr) {
    set_last_error("RKMPP encoder or YUV input is not ready");
    return nullptr;
  }
  if (width != static_cast<jint>(rkmpp_encoder.width) || height != static_cast<jint>(rkmpp_encoder.height)) {
    set_last_error("RKMPP image size mismatch width=" + std::to_string(width) + " height=" + std::to_string(height));
    return nullptr;
  }
  auto *y = reinterpret_cast<const uint8_t *>(env->GetDirectBufferAddress(y_buffer));
  auto *u = reinterpret_cast<const uint8_t *>(env->GetDirectBufferAddress(u_buffer));
  auto *v = reinterpret_cast<const uint8_t *>(env->GetDirectBufferAddress(v_buffer));
  if (y == nullptr || u == nullptr || v == nullptr) {
    set_last_error("RKMPP direct YUV buffer address is null");
    return nullptr;
  }
  void *frame_ptr = rkmpp_api.mpp_buffer_get_ptr_with_caller(
      rkmpp_encoder.frame_buffer,
      "nativeEncodeRkMppH265Image");
  if (frame_ptr == nullptr) {
    set_last_error("RKMPP frame buffer pointer is null");
    return nullptr;
  }
  copy_yuv420_to_nv12(
      y,
      u,
      v,
      width,
      height,
      y_row_stride,
      y_pixel_stride,
      u_row_stride,
      u_pixel_stride,
      v_row_stride,
      v_pixel_stride,
      reinterpret_cast<jbyte *>(frame_ptr));
  rkmpp_api.mpp_buffer_sync_end_f(rkmpp_encoder.frame_buffer, 0, "nativeEncodeRkMppH265Image");
  return encode_rkmpp_frame_locked(env, pts_us);
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeConvertYuv420ToNv12(
    JNIEnv *env,
    jobject /* thiz */,
    jobject y_buffer,
    jobject u_buffer,
    jobject v_buffer,
    jint width,
    jint height,
    jint y_row_stride,
    jint y_pixel_stride,
    jint u_row_stride,
    jint u_pixel_stride,
    jint v_row_stride,
    jint v_pixel_stride) {
  if (width <= 0 || height <= 0 || y_buffer == nullptr || u_buffer == nullptr || v_buffer == nullptr) {
    set_last_error("YUV420 to NV12 invalid input");
    return nullptr;
  }
  auto *y = reinterpret_cast<const uint8_t *>(env->GetDirectBufferAddress(y_buffer));
  auto *u = reinterpret_cast<const uint8_t *>(env->GetDirectBufferAddress(u_buffer));
  auto *v = reinterpret_cast<const uint8_t *>(env->GetDirectBufferAddress(v_buffer));
  if (y == nullptr || u == nullptr || v == nullptr) {
    set_last_error("YUV420 to NV12 direct buffer address is null");
    return nullptr;
  }
  const int output_size = width * height * 3 / 2;
  jbyteArray result = env->NewByteArray(output_size);
  if (result == nullptr) {
    set_last_error("YUV420 to NV12 output alloc failed");
    return nullptr;
  }
  std::vector<jbyte> output(static_cast<size_t>(output_size));
  copy_yuv420_to_nv12(y, u, v, width, height, y_row_stride, y_pixel_stride, u_row_stride, u_pixel_stride, v_row_stride, v_pixel_stride, output.data());
  env->SetByteArrayRegion(result, 0, output_size, output.data());
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

extern "C" JNIEXPORT void JNICALL
Java_com_example_smart_1cabinet_kiosk_GStreamerBridge_nativeDestroyRkMppH265Encoder(
    JNIEnv * /* env */,
    jobject /* thiz */,
    jlong handle) {
  std::lock_guard<std::mutex> lock(rkmpp_mutex);
  auto *encoder = reinterpret_cast<RkMppEncoder *>(handle);
  if (encoder == nullptr) {
    return;
  }
  release_rkmpp_encoder_locked(*encoder, "nativeDestroyRkMppH265Encoder");
  delete encoder;
}
