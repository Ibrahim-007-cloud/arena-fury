# Arena Fury 🥊

A 2D arcade fighting game for Android/iOS inspired by classic 90s 3D brawlers, built with
**Flutter + Flame 1.38 + Firebase**. All fighters, stages and effects are original and drawn
procedurally in code, so the game runs without any art assets.

## Features
- **6-slot roster**: 4 built-in fighters (Kaito Blaze, Mira Volt, Brutus Stone, Zara Storm)
  + 2 custom fighter slots.
- **Combat**: virtual joystick + LP / HK / SP / COMBO buttons. Each moveset has 3 basic attacks
  and a multi-hit combo attack, triggered by an input sequence (½ meter) or the COMBO button
  (full meter, +25% damage, unblockable).
- Flame `RectangleHitbox` hurtboxes (passive) and attack boxes (active only during active frames),
  projectiles, block (hold away), crouch (dodges high attacks), juggles, combo damage scaling,
  hit-stop, screen shake, K.O. slow-mo, animated health bars with a damage trail, combo meter.
- **Character Studio**: selfie (front camera) or gallery → circular crop → the face is composited
  live onto the fighter **inside a Flame preview game**. Pick costume, build, colours, moveset and
  stats (10-point budget), then save.
- **4 stages**: Neon Rooftop, Sunset Temple, Frozen Peak, Harbor Docks (animated).
- **Modes**: Arcade (best of 3 vs AI bot, Easy/Normal/Hard), Training (dummy, infinite meter,
  hitbox viewer), Global leaderboard + personal match history.
- **Firebase**: Auth (email/password + guest), Firestore (fighters, matches, leaderboard),
  Storage (face textures). Without Firebase the app runs in **offline demo mode**.

## Folder structure
```
lib/
  main.dart / app.dart          app entry, AuthGate
  firebase_options.dart         placeholder → replaced by `flutterfire configure`
  core/                         constants (all tuning numbers), theme
  data/
    models/                     FighterConfig, FighterStats, Moveset/AttackData, MatchRecord, ...
    repositories/               Auth / Fighter / Match / FaceStorage (Firebase + offline impls)
    roster.dart                 built-in fighters
  services/                     AppServices (service locator), FaceCache (ui.Image cache)
  game/
    fight_game.dart             FlameGame: rounds, timer, hit resolution, hit-stop, shake, controls
    match_setup.dart            MatchSetup, BotDifficulty, MatchSummary
    components/                 Fighter (state machine), AttackBox, Projectile, HitSpark, StageBackground
    hud/                        health bars, meter, timer, announcer, combo counter, arcade buttons
    input/                      FighterIntent, joystick/keyboard controller, InputBuffer (sequences)
    ai/bot_controller.dart      CPU opponent
    logic/combat_rules.dart     damage + meter formulas
    rendering/                  Pose, PoseLibrary, FighterPainter (body + selfie), StagePainter
    preview/                    FighterPreviewGame used by the Studio
  screens/                      auth, menu, select (fighter/stage), studio, fight, leaderboard
  widgets/                      shared UI
test/widget_test.dart           unit tests for combat logic & models
docs/FIRESTORE_DATA_MODEL.md    database schema
firestore.rules / storage.rules / firebase.json
platform_setup/                 AndroidManifest + Info.plist snippets
```

## Setup

1. **Flutter** 3.32+ (stable). In this folder generate the platform projects (existing files
   are kept):
   ```bash
   flutter create . --platforms=android,ios --org com.yourname --project-name arena_fury
   flutter pub get
   ```
2. **Android** – in `android/app/build.gradle(.kts)` set `minSdk = 24` (required by Firebase
   Android BoM 35). Add the uCrop activity from `platform_setup/AndroidManifest_snippet.xml`
   inside `<application>` in `android/app/src/main/AndroidManifest.xml`.
3. **iOS** – add the keys from `platform_setup/ios_Info_plist_snippet.xml` to
   `ios/Runner/Info.plist` and set `platform :ios, '15.0'` in `ios/Podfile`.
4. **Run it now (offline demo)**: `flutter run` — works before Firebase is configured.
5. **Firebase**
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure            # overwrites lib/firebase_options.dart
   ```
   In the Firebase console: enable **Authentication → Email/Password** and **Anonymous**,
   create a **Firestore** database and **Storage** bucket, then deploy the rules:
   ```bash
   npm i -g firebase-tools && firebase login
   firebase deploy --only firestore:rules,storage
   ```
6. `flutter test` runs the combat/model unit tests.

## Controls
| Action | Touch | Keyboard (emulator) |
|---|---|---|
| Walk / jump / crouch | Joystick | WASD / arrows |
| Block | Hold away from the opponent | Hold away |
| Light Punch / Heavy Kick / Special | LP / HK / SP | J / K / L |
| Combo (full meter) | COMBO | Space |
| Pause (hitbox viewer) | ⏸ | Esc |

Combo sequences (need ½ meter): Striker `↓ → SP`, Brawler `← → HK`, Ninja `LP LP HK`,
Tempest `↓ ↓ SP`.

## Next steps (ideas)
- Local 2-player on one device or online multiplayer (Firestore/RTDB match rooms).
- Replace procedural bodies with sprite sheets (`SpriteAnimationComponent`) – keep the hitbox data.
- Move leaderboard writes into a Cloud Function to stop score tampering.
- Sound effects with `flame_audio`.
