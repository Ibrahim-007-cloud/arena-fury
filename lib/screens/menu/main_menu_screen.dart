import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/app_user.dart';
import '../../data/models/stage_data.dart';
import '../../game/match_setup.dart';
import '../../services/app_services.dart';
import '../../widgets/menu_button.dart';
import '../../widgets/stage_backdrop.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../select/fighter_select_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  @override
  void initState() {
    super.initState();
    AppServices.matches.ensureProfile(widget.user).catchError((_) {});
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const StageBackdrop(stage: Stages.sunsetTemple, dim: 0.35),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ARENA FURY', style: AppTheme.titleStyle),
                        const SizedBox(height: 6),
                        Chip(
                          avatar: Icon(user.isGuest ? Icons.person_outline : Icons.person, size: 18),
                          label: Text(user.displayName),
                        ),
                        if (!AppServices.firebaseReady)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'OFFLINE DEMO MODE • run `flutterfire configure` to enable Firebase',
                              style: TextStyle(color: AppColors.gold, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MenuButton(
                          label: 'ARCADE',
                          subtitle: 'Best of 3 vs CPU',
                          icon: Icons.sports_mma,
                          onTap: () => _open(FighterSelectScreen(user: user, mode: GameMode.arcade)),
                        ),
                        MenuButton(
                          label: 'TRAINING',
                          subtitle: 'Practice combos on a dummy',
                          icon: Icons.fitness_center,
                          color: const Color(0xFF7C4DFF),
                          onTap: () => _open(FighterSelectScreen(user: user, mode: GameMode.training)),
                        ),
                        MenuButton(
                          label: 'CHARACTER STUDIO',
                          subtitle: 'Create a fighter with your selfie',
                          icon: Icons.face_retouching_natural,
                          color: const Color(0xFF00B8D4),
                          onTap: () => _open(FighterSelectScreen(user: user)),
                        ),
                        MenuButton(
                          label: 'LEADERBOARD',
                          subtitle: 'Global ranks & your record',
                          icon: Icons.emoji_events,
                          color: const Color(0xFFFFA000),
                          onTap: () => _open(LeaderboardScreen(user: user)),
                        ),
                        MenuButton(
                          label: 'SIGN OUT',
                          icon: Icons.logout,
                          color: Colors.blueGrey,
                          onTap: AppServices.auth.signOut,
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
    );
  }
}
