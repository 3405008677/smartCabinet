#include <jni.h>
#include <gst/gst.h>
#include <gst/app/gstappsrc.h>
#include <android/log.h>
#include <mutex>
#include <string>

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

// Stores the last native GStreamer failure so Kotlin can surface actionable UI status.
std::string last_error;

void set_last_error(const std::string &message) {
  last_error = message;
  LOGE("%s", message.c_str());
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
