# Norbu the yak: animation contract

This brief is for the animator who builds `yak.riv`. The app already drives a
yak drawn in code (`lib/widgets/yak_mascot.dart`) through this same contract,
so a Rive file that follows it can replace that yak without changing any
screen.

Source of truth in code: `lib/widgets/yak_controller.dart` (names and
timings) and `lib/widgets/rive_yak.dart` (how the inputs are fed in). If the
contract changes, update this file and the code in the same commit.

## Deliverable

- One file: `assets/rive/yak.riv`.
- One artboard, the default one, holding the full-body yak. Also add a
  `head` artboard if the head-only crop needs its own framing. The app uses
  head-only at small sizes (64 px in the answer banner) and the full body from
  96 px up.
- One state machine named **`yak_sm`**.
- Original art only. Base it on the Bojang yak logo (`logos/Bojang/logo.jpg`,
  with its horns, fringe, cream muzzle and thick dark outline) and on the
  code-drawn yak. Do not copy or imitate any other app's characters, poses or
  motion.

## Inputs

Keep the names exactly as written, suffixes included (`_trig`, `_num`,
`_bool`).

| Input | Type | Sent when | What the yak does |
|---|---|---|---|
| `correct_trig` | Trigger | A right answer | **Hop.** A small crouch for anticipation, one springy jump with some stretch in the air, a squash on landing, then idle. |
| `incorrect_trig` | Trigger | A wrong answer | **Head shake.** A gentle, damped "no" that turns side to side 2 or 3 times, with kind eyes. The yak is never sad, angry or scolding. |
| `correct_after_mistake_trig` | Trigger | The first right answer after a wrong one | **Cheer.** Arms go up, two little hops, a wiggle and a few gold sparkles. This is the biggest of the three reactions, because the learner recovered. |
| `reset_trig` | Trigger | The lesson ends, or the screen resets | Drop whatever is playing and go straight back to idle. |
| `idle_num` | Number, 0 to n | Set by the app; 0 by default | Idle variant. **0** is calm breathing with a blink about every 3 s. **1** looks around, with the eyes drifting left and right. **2** is slow and sleepy, with heavy lids and deep breaths. More are welcome; the app clamps to the count in `YakController.idleVariants`. Change variant at the next loop boundary so there is no pop. |
| `dark_mode_bool` | Boolean | The app is in dark mode | Keep the yak readable on `#121212`-style backgrounds. Lift the outline a little, or add a soft rim light, and turn the ground shadow into a faint glow. Do not make the yak glow. |
| `reduced_motion_bool` | Boolean | Motion is reduced or off (see below) | No idle loop and no hops. Each trigger becomes a short pose change of about 0.25 s, such as a smile, a small head tilt or arms up, and then holds. |

## Timing

Each reaction is a one-shot that returns to idle by itself. Answer feedback
stays on screen for 2 s, so every reaction has to finish well before that.

| State | Full motion | Reduced motion |
|---|---|---|
| `correct` | 0.46 s | about 0.23 s, small |
| `incorrect` | 0.52 s | about 0.26 s, small |
| `correct_after_mistake` | 0.82 s | about 0.41 s, small |

These numbers live in `YakState.duration` in the code.

- **A trigger always interrupts.** If a new trigger arrives while a reaction
  is playing, blend into the new reaction within about 80 ms. The newest
  answer wins.
- **Optional event:** fire a Rive event named **`reaction_done_event`** on
  the last frame of each reaction. The app listens for it. If the event is
  missing, the app falls back to the durations above.

## How the app sets the inputs

- **The motion level** comes from `lib/theme/motion.dart`. It combines the
  system Reduce Motion setting, Settings > Animations and a check for
  low-RAM phones. `reduced_motion_bool` is true whenever the level is not
  `full`. When the level is `static`, the app may skip triggers entirely, so
  the file must also look right when it shows only the idle pose.
- **Dark mode** comes from the app theme and is set before the first frame.
- **Triggers** come from `Feedback.play(...)` in
  `lib/services/feedback.dart`. Each one is paired with a sound and a haptic
  under the same event name:

| Feedback event | Yak trigger | Sound | Haptic |
|---|---|---|---|
| `correct` | `correct_trig` | `correct.mp3`, rising through `correct_1` to `correct_4` on a run of right answers | light |
| `incorrect` | `incorrect_trig` | `incorrect.mp3`, at reduced volume | medium |
| `correct_after_mistake` | `correct_after_mistake_trig` | `correct_after_mistake.mp3` | light, then medium |
| `lesson_complete` | `reset_trig` | `lesson_complete.mp3` | medium, light, heavy |

Sound and haptics are played by the app, not by the file. Do not put audio
in `yak.riv`.

## Technical notes

- **Runtime.** The target is the `rive` Flutter package. Its 0.14 line uses
  `rive_native`, and state-machine inputs still work there: `sm.trigger()`,
  `sm.number()` and `sm.boolean()`. Rive now prefers data binding. If you
  author with a view model, give its properties these same names and keep
  the state-machine inputs as well, until the app moves over.
- **Package not added yet (checked 2026-11-23).** `rive` 0.14.11 is not yet
  a dependency of the app. Adding it broke the iOS device build with
  undefined `rive_native` symbols (`_createRiveRenderer`, `_loadRiveFile`
  and others). When the file arrives:
  1. Add the package and check that both iOS and Android build.
  2. Write the sink adapter shown in `rive_yak.dart`.
  3. Set `RiveYak.runtimeAvailable` to true.
  4. Build with `--dart-define=RIVE_YAK=true` to try it out.
- **Size budget.** Keep `yak.riv` under 300 KB. Use vector shapes and avoid
  embedded raster images.
- **Later, not now.** A `viseme_num` input for lip sync on spoken words, and
  `rtl_bool`. Leave room for them in the rig, but do not add them yet.

## Checklist before handing over

- [ ] The state machine is named `yak_sm`, and all 7 inputs are present with
  the exact names listed above. `YakController.inputNames` holds the list.
- [ ] Each trigger plays, can be interrupted and returns to idle within its
  time budget.
- [ ] Idle variant 0 exists. Any other variants change without a pop.
- [ ] The yak reads well on both light and dark backgrounds, at 64 px
  head-only and at 160 px full body.
- [ ] With `reduced_motion_bool` on, there is no looping motion.
- [ ] The art is original.
