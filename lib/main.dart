import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'services/tilt_control_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the entire application to landscape orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Immersive edge-to-edge UI suited for arcade & controller dashboards
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await StorageService.instance.init();
  await TiltControlService.instance.init();

  runApp(const ApexTiltApp());
}

class ApexTiltApp extends StatelessWidget {
  const ApexTiltApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apex Tilt RC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: const HomeScreen(),
    );
  }
}
