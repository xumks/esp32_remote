import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/app_state.dart';
import 'services/http_service.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const Esp32RemoteApp());
}

class Esp32RemoteApp extends StatelessWidget {
  const Esp32RemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 创建全局 AppState
    final appState = AppState();
    // 创建 HttpService，持有 AppState 引用
    final httpService = HttpService(appState);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        Provider.value(value: httpService),
      ],
      child: MaterialApp(
        title: 'ESP32 远程控制',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
          useMaterial3: true,
          fontFamily: 'Roboto',
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
        home: const _AppRoot(),
      ),
    );
  }
}

/// 应用根 Widget：启动时自动发起 MQTT 连接
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void initState() {
    super.initState();
    // 在第一帧渲染后启动连接，避免阻塞 UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HttpService>().startPolling();
    });
  }

  @override
  void dispose() {
    context.read<HttpService>().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
