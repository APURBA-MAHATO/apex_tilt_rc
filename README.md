# Apex Tilt RC

Cross-platform **Flutter + Flame 2D** mobile application (Android & iOS, with web/desktop keyboard fallback) locked in **landscape orientation**.

## Features
- **Shared `TiltControlService` (`sensors_plus`)**: Complementary filter fusing accelerometer + gyroscope readings with low-pass jitter smoothing, configurable deadzone (`0%–20%`), sensitivity (`0.5x–2.0x`), axis inversion, `calibrateCenter()`, and automatic **WASD / Arrow Key** desktop/web fallback.
- **RC Car Controller Mode**:
  - **BLE GATT** (`flutter_blue_plus`) with device scanner modal and auto-discovery of Nordic UART / HM-10 / writable characteristics.
  - **Wi-Fi WebSocket** (`web_socket_channel`) defaulting to `ws://192.168.4.1:81`.
  - **20Hz (50ms) Telemetry Stream** sending `"S:<steer>,T:<throttle>\n"` or toggleable JSON `{"s":0,"t":0}`.
  - Left-thumb **CALIBRATE ZERO**, **EMERGENCY STOP** (`S:0,T:0\n` + pause), live packet log, and on-screen touch slider override.
- **Arcade Race Mode (`flame`)**:
  - Zero-asset procedural vector graphics with drift friction and speed-dependent steering.
  - **Neon Circuit** (3-lap time trial with sector anti-cheat checkpoints & best-lap persistence).
  - **Endless Highway** (3-lane traffic dodge, nitro boost pads, 3-shield integrity, high-score persistence).
  - **3 Vehicles**: `APEX MK-IV` (Balanced), `VIPER GT` (High Speed), `DRIFT HORNET` (High Handling).

## Quick Start
```bash
flutter pub get
flutter test
flutter run -d chrome   # Desktop/Web preview (WASD / Arrow Keys + C to calibrate)
flutter run             # Android / iOS device
```
