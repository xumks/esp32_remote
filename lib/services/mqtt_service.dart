import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/app_state.dart';

/// MQTT Topic 定义（与 ESP32 保持一致）
class MqttTopics {
  static const sensorData  = 'esp32/env/sensor';
  static const deviceStatus = 'esp32/env/status';
  static const ledGreen    = 'esp32/env/led/green';
  static const ledRed      = 'esp32/env/led/red';
  static const fan         = 'esp32/env/fan';
  static const fanStatus   = 'esp32/env/fan/status';
}

/// MQTT 服务：管理连接、订阅、发布
class MqttService {
  final AppState _state;

  MqttServerClient? _client;
  Timer? _reconnectTimer;
  bool _disposed = false;

  /// Broker 配置
  static const _broker   = 'broker.emqx.io';
  static const _port     = 1883;

  MqttService(this._state);

  /// 启动连接
  Future<void> connect() async {
    if (_client != null &&
        _client!.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }

    _state.setConnState(ConnState.connecting);
    _state.addLog('正在连接 Broker: $_broker:$_port');

    // 使用时间戳保证 Client ID 唯一
    final clientId = 'flutter_esp32_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient.withPort(_broker, clientId, _port);
    _client!.keepAlivePeriod     = 30;
    _client!.connectTimeoutPeriod = 10000;
    _client!.autoReconnect       = true;
    _client!.logging(on: kDebugMode);

    _client!.onConnected    = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onAutoReconnect = () => _state.addLog('MQTT 自动重连中...');

    final connMsg = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic(MqttTopics.deviceStatus)
        .withWillMessage('offline')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMsg;

    try {
      await _client!.connect();
    } catch (e) {
      _state.addLog('连接失败: $e');
      _state.setConnState(ConnState.disconnected);
      _scheduleReconnect();
    }
  }

  void _onConnected() {
    _state.setConnState(ConnState.connected);
    _state.addLog('MQTT 连接成功');

    // 订阅传感器数据和设备状态
    _client!.subscribe(MqttTopics.sensorData,   MqttQos.atLeastOnce);
    _client!.subscribe(MqttTopics.deviceStatus, MqttQos.atLeastOnce);
    _client!.subscribe(MqttTopics.fanStatus,    MqttQos.atLeastOnce);

    // 监听消息
    _client!.updates?.listen(_onMessage);
  }

  void _onDisconnected() {
    _state.setConnState(ConnState.disconnected);
    _state.addLog('MQTT 连接断开');
    if (!_disposed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_disposed) connect();
    });
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final pub = msg.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
          pub.payload.message);

      if (msg.topic == MqttTopics.sensorData) {
        _state.updateSensor(payload);
      } else if (msg.topic == MqttTopics.deviceStatus) {
        _state.addLog('设备状态: $payload');
      } else if (msg.topic == MqttTopics.fanStatus) {
        _state.setFanOn(payload.trim().toUpperCase() == 'ON');
        _state.addLog('风扇状态反馈: $payload');
      }
    }
  }

  /// 控制 LED（发布到对应 topic）
  void controlLed(String color, bool on) {
    if (_client == null ||
        _client!.connectionStatus?.state != MqttConnectionState.connected) {
      _state.addLog('未连接，无法发送指令');
      return;
    }

    final topic   = color == 'green' ? MqttTopics.ledGreen : MqttTopics.ledRed;
    final payload = on ? 'ON' : 'OFF';

    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

    _state.addLog('发送: $topic = $payload');

    if (color == 'green') {
      _state.setLedGreen(on);
    } else {
      _state.setLedRed(on);
    }
  }

  /// 控制风扇继电器
  void controlFan(bool on) {
    if (_client == null ||
        _client!.connectionStatus?.state != MqttConnectionState.connected) {
      _state.addLog('未连接，无法发送指令');
      return;
    }
    final payload = on ? 'ON' : 'OFF';
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client!.publishMessage(
        MqttTopics.fan, MqttQos.atLeastOnce, builder.payload!);
    _state.addLog('发送: ${MqttTopics.fan} = $payload');
    _state.setFanOn(on);
  }

  /// 释放资源
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _client?.disconnect();
  }
}
