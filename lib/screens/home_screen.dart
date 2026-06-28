import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/http_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(context),
      body: const _Body(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('ESP32 远程控制',
          style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFF1565C0),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        Consumer<AppState>(
          builder: (_, state, __) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  state.connState == ConnState.connected
                      ? Icons.wifi
                      : state.connState == ConnState.connecting
                          ? Icons.wifi_find
                          : Icons.wifi_off,
                  color: state.connState == ConnState.connected
                      ? Colors.greenAccent
                      : state.connState == ConnState.connecting
                          ? Colors.yellowAccent
                          : Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  state.connState == ConnState.connected
                      ? '已连接'
                      : state.connState == ConnState.connecting
                          ? '连接中'
                          : '未连接 ESP32',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _SensorCard(),
          SizedBox(height: 16),
          _LedControlCard(),
          SizedBox(height: 16),
          _FanControlCard(),
          SizedBox(height: 16),
          _LogCard(),
        ],
      ),
    );
  }
}

/* ============================================================
 *  传感器数据卡片
 * ============================================================ */
class _SensorCard extends StatelessWidget {
  const _SensorCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (_, state, __) {
        final d = state.sensorData;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sensors, color: Color(0xFF1565C0)),
                    const SizedBox(width: 8),
                    const Text('环境数据',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (d != null)
                      Text(
                        '${d.time.hour.toString().padLeft(2, '0')}:'
                        '${d.time.minute.toString().padLeft(2, '0')}:'
                        '${d.time.second.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
                const Divider(height: 24),
                // 报警横幅
                if (d?.alarm == true)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 18),
                        SizedBox(width: 6),
                        Text('⚠  环境数据超出阈值，请注意！',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    _SensorTile(
                      icon: Icons.thermostat,
                      label: '温度',
                      value: d != null ? '${d.temp.toStringAsFixed(1)} °C' : '--',
                      color: _tempColor(d?.temp),
                    ),
                    const SizedBox(width: 12),
                    _SensorTile(
                      icon: Icons.water_drop,
                      label: '湿度',
                      value: d != null ? '${d.humi.toStringAsFixed(1)} %' : '--',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _SensorTile(
                      icon: Icons.light_mode,
                      label: '光照',
                      value: d != null ? '${d.lux.toStringAsFixed(0)} lux' : '--',
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _tempColor(double? t) {
    if (t == null) return Colors.grey;
    if (t < 10 || t > 35) return Colors.red;
    if (t < 18 || t > 30) return Colors.orange;
    return Colors.green;
  }
}

class _SensorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SensorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
 *  LED 控制卡片
 * ============================================================ */
class _LedControlCard extends StatelessWidget {
  const _LedControlCard();

  @override
  Widget build(BuildContext context) {
    final mqtt = context.read<HttpService>();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.lightbulb_outline, color: Color(0xFF1565C0)),
                SizedBox(width: 8),
                Text('LED 远程控制',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            Consumer<AppState>(
              builder: (_, state, __) => Row(
                children: [
                  Expanded(
                    child: _LedButton(
                      label: '绿灯',
                      isOn: state.ledGreen,
                      activeColor: Colors.green,
                      icon: Icons.circle,
                      enabled: state.isConnected,
                      onToggle: (v) => mqtt.controlLed('green', v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _LedButton(
                      label: '红灯',
                      isOn: state.ledRed,
                      activeColor: Colors.red,
                      icon: Icons.circle,
                      enabled: state.isConnected,
                      onToggle: (v) => mqtt.controlLed('red', v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Consumer<AppState>(
              builder: (_, state, __) => state.isConnected
                  ? const SizedBox.shrink()
                  : const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '请先连接热点 ESP32-EnvMonitor 后再控制 LED',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedButton extends StatelessWidget {
  final String label;
  final bool isOn;
  final Color activeColor;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _LedButton({
    required this.label,
    required this.isOn,
    required this.activeColor,
    required this.icon,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? (isOn ? activeColor : Colors.grey[400]!) : Colors.grey[300]!;
    return GestureDetector(
      onTap: enabled ? () => onToggle(!isOn) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(isOn ? 0.15 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(isOn ? 0.8 : 0.3),
            width: isOn ? 2 : 1,
          ),
          boxShadow: isOn
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 42),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              isOn ? '● 亮' : '○ 灭',
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight:
                      isOn ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
 *  日志卡片
 * ============================================================ */
class _LogCard extends StatelessWidget {
  const _LogCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.terminal, color: Color(0xFF1565C0), size: 18),
                SizedBox(width: 8),
                Text('通信日志',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Consumer<AppState>(
              builder: (_, state, __) => Container(
                height: 140,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    state.log.isEmpty ? '等待日志...' : state.log,
                    style: const TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/* ============================================================
 *  风扇继电器控制卡片
 * ============================================================ */
class _FanControlCard extends StatelessWidget {
  const _FanControlCard();

  @override
  Widget build(BuildContext context) {
    final mqtt = context.read<HttpService>();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.air, color: Color(0xFF1565C0)),
                SizedBox(width: 8),
                Text('风扇控制',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            Consumer<AppState>(
              builder: (_, state, __) {
                final isOn = state.fanOn;
                final enabled = state.isConnected;
                final color = enabled
                    ? (isOn ? Colors.cyan[700]! : Colors.grey[400]!)
                    : Colors.grey[300]!;
                return Column(
                  children: [
                    GestureDetector(
                      onTap: enabled ? () => mqtt.controlFan(!isOn) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: color.withOpacity(isOn ? 0.15 : 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: color.withOpacity(isOn ? 0.8 : 0.3),
                            width: isOn ? 2 : 1,
                          ),
                          boxShadow: isOn
                              ? [BoxShadow(
                                  color: color.withOpacity(0.3),
                                  blurRadius: 12)]
                              : [],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.air, color: color, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              isOn ? '风扇运行中' : '风扇已关闭',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isOn ? '点击关闭风扇' : '点击开启风扇',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!enabled)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '请先连接热点 ESP32-EnvMonitor 后再控制风扇',
                          style:
                              TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}