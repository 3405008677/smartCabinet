package com.example.smart_cabinet.kiosk

import android.app.admin.DeviceAdminReceiver

/**
 * 提供给 [android.app.admin.DevicePolicyManager] 的清单组件标识。
 *
 * Receiver 本身不会授予设备所有者权限；柜机仍需在部署阶段完成 device-owner
 * 配置，之后 [KioskManager] 才能设置锁定任务白名单和用户限制。
 */
class KioskDeviceAdminReceiver : DeviceAdminReceiver()
