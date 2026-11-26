import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';

import '../game/arcade_race_game.dart';
import '../game/game_hud_state.dart';
import '../models/car_spec.dart';
import '../services/storage_service.dart';
import '../services/tilt_control_service.dart';
import '../theme/app_theme.dart';

class ArcadeRaceScreen extends StatefulWidget {
  const ArcadeRaceScreen({super.key});

  @override
  State<ArcadeRaceScreen> createState() => _ArcadeRaceScreenState();
}

class _ArcadeRaceScreenState extends State<ArcadeRaceScreen> {
  TrackType _selectedTrack = TrackType.neonCircuit;
  late CarSpec _selectedCar;
  ArcadeRaceGame? _activeGame;

  @override
  void initState() {
    super.initState();
    _selectedCar = CarSpec.byId(StorageService.instance.selectedCarId);
  }

  void _startRace() {
    StorageService.instance.setSelectedCarId(_selectedCar.id);
    setState(() {
      _activeGame = ArcadeRaceGame(
        trackType: _selectedTrack,
        carSpec: _selectedCar,
      );
    });
  }

  void _exitToSetup() {
    setState(() {
      _activeGame = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeGame == null) {
      return _buildSetupScreen();
    }
    return _buildGameplayScreen(_activeGame!);
  }

  Widget _buildSetupScreen() {
    final storage = StorageService.instance;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Text(
                    'ARCADE RACE // GARAGE & TRACKS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () {
                      TiltControlService.instance.calibrateRollZero();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Resting roll angle saved as neutral!'),
                          duration: Duration(milliseconds: 900),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.cyan,
                      side: const BorderSide(color: AppTheme.cyan),
                    ),
                    icon: const Icon(Icons.center_focus_strong_rounded,
                        size: 16),
                    label: const Text(
                      'CALIBRATE ZERO',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),

            // Body: Track Selector + Car Selector
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    // Left: Track Selection
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SELECT TRACK',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _TrackOptionCard(
                              track: TrackType.neonCircuit,
                              selected: _selectedTrack == TrackType.neonCircuit,
                              recordLine:
                                  'Best Lap: ${StorageService.formatDurationMs(storage.bestLapMs)}  •  3-Lap: ${StorageService.formatDurationMs(storage.bestRaceMs)}',
                              accent: AppTheme.cyan,
                              onTap: () => setState(
                                () => _selectedTrack = TrackType.neonCircuit,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _TrackOptionCard(
                              track: TrackType.endlessHighway,
                              selected:
                                  _selectedTrack == TrackType.endlessHighway,
                              recordLine:
                                  'High Score: ${storage.highwayBestScore} pts  •  Max: ${storage.highwayBestDistance} m',
                              accent: AppTheme.green,
                              onTap: () => setState(
                                () => _selectedTrack = TrackType.endlessHighway,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Right: Car Selector + Start Race CTA
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SELECT VEHICLE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Row(
                              children: CarSpec.roster
                                  .map(
                                    (car) => Expanded(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: _CarSelectorCard(
                                          car: car,
                                          selected: _selectedCar.id == car.id,
                                          onTap: () =>
                                              setState(() => _selectedCar = car),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _SteeringSensitivityCard(),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _startRace,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.green,
                                foregroundColor: const Color(0xFF04140B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.flag_rounded, size: 22),
                              label: Text(
                                'START ${_selectedTrack.title.toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameplayScreen(ArcadeRaceGame game) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      body: Stack(
        children: [
          GameWidget<ArcadeRaceGame>(game: game),

          // Live In-Game HUD Overlay
          SafeArea(
            child: ValueListenableBuilder<GameTelemetry>(
              valueListenable: game.hud,
              builder: (context, telemetry, _) {
                return Stack(
                  children: [
                    // Top-Left Telemetry Cluster
                    Positioned(
                      top: 10,
                      left: 12,
                      child: _buildTopLeftHud(telemetry),
                    ),

                    // Top-Right Steering Sensitivity, Calibrate Zero & Pause
                    Positioned(
                      top: 10,
                      right: 12,
                      child: Row(
                        children: [
                          const _HudSensitivityControl(),
                          const SizedBox(width: 8),
                          _HudActionButton(
                            icon: Icons.center_focus_strong_rounded,
                            label: 'CALIBRATE ZERO',
                            color: AppTheme.cyan,
                            onTap: () {
                              TiltControlService.instance.calibrateRollZero();
                            },
                          ),
                          const SizedBox(width: 8),
                          _HudActionButton(
                            icon: Icons.pause_rounded,
                            label: 'PAUSE',
                            color: AppTheme.amber,
                            onTap: game.pauseRace,
                          ),
                        ],
                      ),
                    ),

                    // Center-Top Event Banner
                    if (telemetry.bannerMessage != null)
                      Positioned(
                        top: 64,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.background.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: telemetry.boostActive
                                    ? AppTheme.green
                                    : AppTheme.cyan,
                              ),
                            ),
                            child: Text(
                              telemetry.bannerMessage!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Bottom-Center Mini Steering & Pedal Feedback Pill
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: _MiniInputIndicator(telemetry: telemetry),
                        ),
                      ),
                    ),

                    // Multi-Touch Pedals (BRAKE / REV bottom-left, GAS bottom-right)
                    if (!telemetry.isPaused &&
                        !telemetry.isFinished &&
                        !telemetry.isGameOver) ...[
                      Positioned(
                        bottom: 14,
                        left: 16,
                        child: _TouchPedalButton(
                          label: 'BRAKE / REV',
                          subLabel: 'S / ↓',
                          icon: Icons.arrow_downward_rounded,
                          accentColor: AppTheme.red,
                          externalActive: telemetry.brakeActive,
                          onPressedChanged: game.setBrakePressed,
                        ),
                      ),
                      Positioned(
                        bottom: 14,
                        right: 16,
                        child: _TouchPedalButton(
                          label: 'GAS',
                          subLabel: 'W / ↑',
                          icon: Icons.arrow_upward_rounded,
                          accentColor: AppTheme.green,
                          externalActive: telemetry.gasActive,
                          onPressedChanged: game.setGasPressed,
                        ),
                      ),
                    ],

                    // Pause / Finish / Game Over Modal Overlay
                    if (telemetry.isPaused ||
                        telemetry.isFinished ||
                        telemetry.isGameOver)
                      _buildEndOrPauseOverlay(game, telemetry),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopLeftHud(GameTelemetry telemetry) {
    final isCircuit = telemetry.trackType == TrackType.neonCircuit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${telemetry.speedKmh.round()}',
                style: AppTheme.monoTelemetry.copyWith(
                  fontSize: 24,
                  color: telemetry.boostActive ? AppTheme.green : AppTheme.cyan,
                ),
              ),
              const Text(
                'KM/H',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: AppTheme.border,
          ),
          if (isCircuit) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LAP ${telemetry.currentLap}/${telemetry.totalLaps}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'TIME ${StorageService.formatDurationMs(telemetry.currentLapTimeMs)}',
                  style: AppTheme.monoTelemetry.copyWith(
                    fontSize: 11,
                    color: AppTheme.cyan,
                  ),
                ),
                Text(
                  'BEST ${StorageService.formatDurationMs(telemetry.bestLapTimeMs)}',
                  style: AppTheme.monoTelemetry.copyWith(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ] else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SCORE ${telemetry.score}',
                  style: AppTheme.monoTelemetry.copyWith(
                    fontSize: 13,
                    color: AppTheme.green,
                  ),
                ),
                Text(
                  'DIST ${telemetry.distanceMeters} m  •  BEST ${telemetry.bestScore}',
                  style: AppTheme.monoTelemetry.copyWith(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: List.generate(
                    telemetry.maxShields,
                    (i) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.shield_rounded,
                        size: 13,
                        color: i < telemetry.shields
                            ? AppTheme.cyan
                            : AppTheme.border,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEndOrPauseOverlay(
    ArcadeRaceGame game,
    GameTelemetry telemetry,
  ) {
    final String title;
    final Color titleColor;
    if (telemetry.isFinished) {
      title = 'RACE COMPLETE';
      titleColor = AppTheme.green;
    } else if (telemetry.isGameOver) {
      title = 'RUN ENDED';
      titleColor = AppTheme.red;
    } else {
      title = 'PAUSED';
      titleColor = AppTheme.amber;
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.68),
      child: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: titleColor.withValues(alpha: 0.7), width: 1.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: titleColor,
                ),
              ),
              if (telemetry.isNewRecord) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'NEW PERSONAL RECORD!',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.amber,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (telemetry.trackType == TrackType.neonCircuit) ...[
                Text(
                  'Total Time: ${StorageService.formatDurationMs(telemetry.totalRaceTimeMs)}',
                  style: AppTheme.monoTelemetry.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Best Lap: ${StorageService.formatDurationMs(telemetry.bestLapTimeMs)}',
                  style: AppTheme.monoTelemetry.copyWith(
                    fontSize: 12,
                    color: AppTheme.cyan,
                  ),
                ),
              ] else ...[
                Text(
                  'Score: ${telemetry.score} pts',
                  style: AppTheme.monoTelemetry.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Distance: ${telemetry.distanceMeters} m  •  Best: ${telemetry.bestScore}',
                  style: AppTheme.monoTelemetry.copyWith(
                    fontSize: 12,
                    color: AppTheme.green,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (telemetry.isPaused &&
                  !telemetry.isFinished &&
                  !telemetry.isGameOver) ...[
                _SteeringSensitivityCard(),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      TiltControlService.instance.calibrateRollZero();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.cyan,
                      side: const BorderSide(color: AppTheme.cyan),
                    ),
                    icon: const Icon(Icons.center_focus_strong_rounded,
                        size: 16),
                    label: const Text(
                      'CALIBRATE ZERO (SAVE ROLL)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  if (telemetry.isPaused &&
                      !telemetry.isFinished &&
                      !telemetry.isGameOver) ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: game.resumeRace,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.green,
                          foregroundColor: const Color(0xFF04140B),
                        ),
                        child: const Text('RESUME',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: game.restartRace,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cyan,
                        foregroundColor: const Color(0xFF061018),
                      ),
                      child: const Text('RESTART',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _exitToSetup,
                      child: const Text('TRACKS / CARS'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('HOME'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInputIndicator extends StatelessWidget {
  final GameTelemetry telemetry;

  const _MiniInputIndicator({required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final tilt = TiltControlService.instance;
    return ListenableBuilder(
      listenable: tilt,
      builder: (context, _) {
        final s = (tilt.arcadeSteering * 100).round();
        final t = (telemetry.throttleInput * 100).round();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.background.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            'STEER ${s >= 0 ? '+' : ''}$s%  •  PEDAL ${t >= 0 ? '+' : ''}$t%',
            style: AppTheme.monoTelemetry.copyWith(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

class _SteeringSensitivityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tilt = TiltControlService.instance;
    return ListenableBuilder(
      listenable: tilt,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'STEERING SENSITIVITY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '${tilt.sensitivity.toStringAsFixed(2)}x',
                    style: AppTheme.monoTelemetry.copyWith(
                      fontSize: 11,
                      color: AppTheme.cyan,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 22,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.cyan,
                    thumbColor: AppTheme.cyan,
                    overlayColor: AppTheme.cyan.withValues(alpha: 0.16),
                  ),
                  child: Slider(
                    value: tilt.sensitivity.clamp(0.5, 2.0),
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    onChanged: tilt.setSensitivity,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HudSensitivityControl extends StatelessWidget {
  const _HudSensitivityControl();

  @override
  Widget build(BuildContext context) {
    final tilt = TiltControlService.instance;
    return ListenableBuilder(
      listenable: tilt,
      builder: (context, _) {
        return Container(
          width: 158,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.background.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'STEER SENS',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '${tilt.sensitivity.toStringAsFixed(2)}x',
                    style: AppTheme.monoTelemetry.copyWith(
                      fontSize: 9,
                      color: AppTheme.cyan,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 16,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5.5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                    activeTrackColor: AppTheme.cyan,
                    thumbColor: AppTheme.cyan,
                  ),
                  child: Slider(
                    value: tilt.sensitivity.clamp(0.5, 2.0),
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    onChanged: tilt.setSensitivity,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TouchPedalButton extends StatefulWidget {
  final String label;
  final String subLabel;
  final IconData icon;
  final Color accentColor;
  final bool externalActive;
  final ValueChanged<bool> onPressedChanged;

  const _TouchPedalButton({
    required this.label,
    required this.subLabel,
    required this.icon,
    required this.accentColor,
    required this.externalActive,
    required this.onPressedChanged,
  });

  @override
  State<_TouchPedalButton> createState() => _TouchPedalButtonState();
}

class _TouchPedalButtonState extends State<_TouchPedalButton> {
  final Set<int> _activePointers = <int>{};

  void _handleDown(PointerDownEvent event) {
    final wasEmpty = _activePointers.isEmpty;
    _activePointers.add(event.pointer);
    if (wasEmpty) {
      setState(() {});
      widget.onPressedChanged(true);
    }
  }

  void _handleUpOrCancel(int pointer) {
    if (_activePointers.remove(pointer) && _activePointers.isEmpty) {
      setState(() {});
      widget.onPressedChanged(false);
    }
  }

  @override
  void dispose() {
    if (_activePointers.isNotEmpty) {
      _activePointers.clear();
      widget.onPressedChanged(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _activePointers.isNotEmpty || widget.externalActive;
    final color = widget.accentColor;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handleDown,
      onPointerUp: (e) => _handleUpOrCancel(e.pointer),
      onPointerCancel: (e) => _handleUpOrCancel(e.pointer),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: 118,
        height: 92,
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.36)
              : AppTheme.background.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.55),
            width: isActive ? 2.4 : 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: 28,
              color: isActive ? Colors.white : color,
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
                color: isActive ? Colors.white : color,
              ),
            ),
            Text(
              widget.subLabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HudActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.background.withValues(alpha: 0.84),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackOptionCard extends StatelessWidget {
  final TrackType track;
  final bool selected;
  final String recordLine;
  final Color accent;
  final VoidCallback onTap;

  const _TrackOptionCard({
    required this.track,
    required this.selected,
    required this.recordLine,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.14)
          : AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : AppTheme.border,
              width: selected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(track.icon, color: accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      track.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recordLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.monoTelemetry.copyWith(
                        fontSize: 10,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarSelectorCard extends StatelessWidget {
  final CarSpec car;
  final bool selected;
  final VoidCallback onTap;

  const _CarSelectorCard({
    required this.car,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? car.primaryColor.withValues(alpha: 0.13)
          : AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? car.primaryColor : AppTheme.border,
              width: selected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: car.primaryColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      car.role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: car.primaryColor,
                      ),
                    ),
                  ),
                  Icon(Icons.directions_car_filled_rounded,
                      color: car.primaryColor, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                car.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _StatBar(label: 'SPD', value: car.speedStat, color: car.primaryColor),
              const SizedBox(height: 4),
              _StatBar(label: 'ACC', value: car.accelStat, color: car.primaryColor),
              const SizedBox(height: 4),
              _StatBar(
                  label: 'HDL', value: car.handlingStat, color: car.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: AppTheme.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}
