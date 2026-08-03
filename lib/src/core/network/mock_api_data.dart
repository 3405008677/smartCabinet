/// GET 接口假数据。
const Map<String, Object> mockGetApiData = {
  '/api/home': {
    'cabinetCode': 'CAB-A01',
    'region': 'A · B 区',
    'status': '在线运行',
    'headline': '智能柜统计信息',
    'stats': {
      'documentCount': '12 份',
      'occupiedSlots': '6 / 12',
      'pendingPickup': '3 份',
      'todayStored': '5 份',
      'todayPickedUp': '2 份',
      'occupancyRateText': '50%',
      'occupancyRateValue': 0.5,
    },
  },
  '/api/admin/device-status': {
    'cabinetCode': 'CAB-A01',
    'region': 'A · B 区',
    'wifiName': 'SmartCabinet-5G',
    'rj45Status': '未连接',
    'nfcStatus': '正常 · 读卡器在线',
    'fingerprintStatus': '正常 · 指纹模块在线',
    'cabinetBoardStatus': '正常 · 12 路柜控板已连接',
    'scannerStatus': '正常 · 扫码器待命',
  },
};

/// POST 接口假数据。
const Map<String, Object> mockPostApiData = {
  '/api/admin/login': {
    'username': '666666',
    'password': '666666',
    'authorized': true,
    'adminName': '系统管理员',
    'permissionLevel': 'L5 · 设备管理权限',
    'message': '管理员权限校验通过',
  },
};
