# Current runtime rules

## Floors and resources

Start new run → confirm the first entry loadout → clear occupied chambers → walk to the entry exit → next venue → six-floor victory. Twelve venue shells contain four or five combat rooms; the 100-composition deck and SwarmLayout supply 18–24 enemies per floor.

A new scene entry, including death retry, changes the formation nonce. Explicit preview seeds remain deterministic. Retry restores that floor's entry resources rather than granting a fresh kit; floor completion and rewards are credited once. Six venues are distinct within one run.

Run sessions are in memory. Permanent weapon builds and score/victory records are saved separately. The application does not claim to resume a world after quitting. Checkpoints carry exact loadout, ammunition, health, armor, blood and perk state; inactive legacy snapshot fields remain compatible.

## Enemy knowledge

Untouched rooms patrol without perception or gun updates. Room entry opens normal perception; direct harm also activates the victim's room and communicates the attack source to its companions while preserving hitstun. Other untouched rooms are not awakened by global noise or radio dispatch.

Within engaged rooms, visible contact acquires the player after reaction time. Lost sight expires chase memory into search. Heard sources assign bounded investigation/sweep/guard roles; repeated gunshots share an incident. Enemy gunfire does not recruit another attack wave. Search timers start on arrival, with navigation recovery for unreachable points.

## Blood Rage and rewards

Normal fire consumes magazines; R reloads, Q throws and E interacts. RMB only siphons. B and X and the old RMB+Q/E/R blood skills do not activate in the current mode.

A full meter starts Rage; normal ammunition remains intact until it ends. Base drain is 14/s, automatic real-blood recovery is at most 10/s. The Blood Clock perk lowers drain to 12/s, still strictly above recovery. Rage projectiles share a finite spray budget across pellets; the retired paid-shot return formula is only a compatibility path.

After every third cleared room, one optional F1–F3 choice can be taken per floor after a quiet second, with no engaged rooms. Entering a fight or pausing blocks selection. The first unlearned rewards are offered. Current effects and labels are specified in `run_combat_perks.gd` and [BLOOD_RAGE.md](BLOOD_RAGE.md). One trigger transaction applies one-shot rewards consistently to every pellet. Timers continue in the current blood update path and freeze when controls are disabled.

## Presentation and engineering boundaries

Standard buildings occupy 768×448 native world-pixel space with 8px cells and 24px doors. The 320×180 UI uses independent cards: ammunition and health at lower left, blood at lower right. The help page scrolls while Back remains fixed. Palette and postprocessing remain centralized.

CombatLevel (Main) owns scene lifetime and signal adapters. FloorFlowController owns deployment, checkpoints, exits and completion; CombatEventController owns trigger records and hit/death dispatch. RunSnapshot, LoadoutSnapshot, PerkSnapshot, FloorReport and typed shot events define the new internal data boundaries. See [ARCHITECTURE.md](ARCHITECTURE.md). ProjectileSpawner handles projectile construction and modifiers, EnemyVisualController handles actor presentation, and WorldAcoustics handles portal propagation. Legacy authoring and save interfaces remain available without enabling retired cleaning/restoration gameplay.

AtomicJsonStore stages complete JSON before replacing the primary and preserves a previous-valid backup. Corrupt primary files fall back to that backup, malformed values are sanitized, and failed writes emit store failure signals plus a warning. Resetting a test/save removes associated backup and staging files too.

## Verification

`python3 tools/run_regressions.py --godot /path/to/Godot --output build/regressions` runs the exact manifest used by CI. Summary JSON and per-scene output are retained, including failures and shutdown warnings. See [LATEST_VERIFICATION.md](LATEST_VERIFICATION.md) for the latest measured results.

`test_rage_perk_integration` claims a real room reward, completes a reload and fires a real shotgun before comparing all pellets, timer expiry and checkpoint state. `test_room_run_visibility` measures actual dormant movement and local hit responses. `test_atomic_saves` exercises corrupt files, interrupted writes and nested malformed data. Real renderer captures supplement these checks; a sustained human playthrough and target-device profiling are separate release work.
