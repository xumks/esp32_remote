import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/app_state.dart';

/// HTTP 服务：直接访问 ESP32 AP 热点的 HTTP API（192.168.4.1）
class HttpService {
  final AppState _state;

  static const _baseUrl = 'http://192.168.4.1';
  Timer? _pollTimer;
  bool _disposed = false;

  HttpService(this._state);

  /// 开始轮询传感器数据（每 2 秒）
  void startPolling() {
    _state.setConnState(ConnState.connecting);
    _state.addLog('正在连接 ESP32 ($_baseUrl)...');
    _fetchSensor();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_disposed) _fetchSensor();
    });
  }

  Future<void> _fetchSensor() async {
    try {
      _state.addLog('请求 $_baseUrl/sensor ...');
      final resp = await http
          .get(Uri.parse('$_baseUrl/sensor'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        if (_state.connState != ConnState.connected) {
          _state.setConnState(ConnState.connected);
          _state.addLog('已连接到 ESP32');
        }
        _state.updateSensor(resp.body);
        // 同步 fan 状态（固件会在 /sensor 响应中附带 fan 字段）
        try {
          final m = jsonDecode(resp.body) as Map<String, dynamic>;
          if (m.containsKey('fan')) {
            _state.setFanOn(m['fan'] as bool? ?? false);
          }
        } catch (_) {}
      } else {
        _handleDisconnect('服务器返回 ${resp.statusCode}');
      }
    } on TimeoutException {
      _handleDisconnect('请求超时，请检查热点连接');
    } on http.ClientException catch (e) {
      _handleDisconnect('网络错误: ${e.message}');
    } catch (e) {
      _handleDisconnect('连接失败: $e');
    }
  }

  void _handleDisconnect(String reason) {
    if (_state.connState != ConnState.disconnected) {
      _state.setConnState(ConnState.disconnected);
      _state.addLog(reason);
    }
  }

  /// 控制 LED（向 POST /led 发送 {"state": true/false}）
  void controlLed(String color, bool on) {
    if (_state.connState != ConnState.connected) {
      _state.addLog('未连接，无法发送指令');
      return;
    }
    _postControl('/led', {'state': on});
    if (color == 'green') {
      _state.setLedGreen(on);
    } else {
      _state.setLedRed(on);
    }
    _state.addLog('发送: /led state=$on');
  }

  /// 控制风扇继电器（向 POST /fan 发送 {"state": true/false}）
  void controlFan(bool on) {
    if (_state.connState != ConnState.connected) {
      _state.addLog('未连接，无法发送指令');
      return;
    }
    _postControl('/fan', {'state': on});
    _state.setFanOn(on);
    _state.addLog('发送: /fan state=$on');
  }

  Future<void> _postControl(String path, Map<String, dynamic> body) async {
    try {
      await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      _state.addLog('控制失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
  }
}
