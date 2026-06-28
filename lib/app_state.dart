import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 传感器数据模型
class SensorData {
  final double temp;
  final double humi;
  final double lux;
  final bool alarm;
  final bool fan;
  final DateTime time;

  const SensorData({
    required this.temp,
    required this.humi,
    required this.lux,
    required this.alarm,
    required this.fan,
    required this.time,
  });

  factory SensorData.fromJson(String jsonStr) {
    final m = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SensorData(
      temp:  (m['temp']  as num).toDouble(),
      humi:  (m['humi']  as num).toDouble(),
      lux:   (m['lux']   as num).toDouble(),
      alarm: m['alarm']  as bool? ?? false,
      fan:   m['fan']    as bool? ?? false,
      time:  DateTime.now(),
    );
  }
}

/// 连接状态枚举
enum ConnState { disconnected, connecting, connected }

/// 全局应用状态（ChangeNotifier，由 Provider 注入）
class AppState extends ChangeNotifier {
  ConnState _connState = ConnState.disconnected;
  SensorData? _sensorData;
  bool _ledGreen = false;
  bool _ledRed   = false;
  bool _fanOn    = false;
  String _log    = '';

  /* ---- Getter ---- */
  ConnState   get connState  => _connState;
  SensorData? get sensorData => _sensorData;
  bool        get ledGreen   => _ledGreen;
  bool        get ledRed     => _ledRed;
  bool        get fanOn      => _fanOn;
  String      get log        => _log;
  bool        get isConnected => _connState == ConnState.connected;

  /* ---- Setter（由 MqttService 调用） ---- */
  void setConnState(ConnState s) {
    _connState = s;
    notifyListeners();
  }

  void updateSensor(String jsonStr) {
    try {
      _sensorData = SensorData.fromJson(jsonStr);
      notifyListeners();
    } catch (e) {
      addLog('解析传感器数据失败: $e');
    }
  }

  void setLedGreen(bool v) {
    _ledGreen = v;
    notifyListeners();
  }

  void setLedRed(bool v) {
    _ledRed = v;
    notifyListeners();
  }

  void setFanOn(bool v) {
    _fanOn = v;
    notifyListeners();
  }

  void addLog(String msg) {
    final ts = DateTime.now();
    final line = '[${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}:'
        '${ts.second.toString().padLeft(2, '0')}] $msg\n';
    _log = line + _log;
    if (_log.length > 2000) _log = _log.substring(0, 2000);
    notifyListeners();
  }
}
