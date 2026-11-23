# Bojang analytics events

Events go to two places:

- **PostHog** (project "Bojang", id 754455, US Cloud): named events, `$screen`, person profiles,
  session replay and error tracking. Code: `lib/services/analytics.dart`.
- **Bojang backend**, table `app_events` (`POST /analytics/events`): every named event below, plus
  every tap, long press, swipe, scroll, screen dwell time and app session, with device context.
  Code: `lib/services/event_tracker.dart` and `lib/widgets/interaction_capture.dart`. Taps and other
  gesture events go only to the backend, not to PostHog (event volume).

- Release builds send events. Debug builds and tests send nothing unless they are run with
  `--dart-define=POSTHOG_IN_DEBUG=true`. Add `--dart-define=LOG_EVENTS=true` to print each backend
  event in a debug run, and `--dart-define=POSTHOG_KEY=` to keep PostHog off.
- Settings > Privacy > "Share usage analytics" turns both off (`Analytics.setOptOut`). While it is
  off nothing is sent, and the unsent backend queue is deleted.
- Calls are fire-and-forget (`Analytics.track(name, {...})`). They never throw, and null property
  values are dropped.
- Naming: `object_action`, snake_case. Properties are snake_case as well.
- Every event also carries the super properties `app_version`, `app_build` and `platform`.
- The server config (`GET /v1/config`, `lib/services/feature_flags.dart`) can drop events without a
  release: `analytics.blocklist` names events that are never sent, and `analytics.sampling` maps an
  event to the share of app sessions that send it (0.0 to 1.0). Sampling is decided per app session
  (hash of `bojang_session_id` and the event name), so a sampled-in session sends every occurrence
  and funnels stay whole; multiply counts by 1/rate. Both apply to PostHog and to the backend events,
  taps and scrolls included. `experiment_exposed` is never sampled. Change them with
  `PATCH /admin/config` (backend `functions/api/routes/config.py`).

## Automatic

- **`Application Opened` / `Application Backgrounded` / `Application Installed` / `Application Updated`**
  (SDK lifecycle): sessions, retention, installs and upgrades.
- **`$screen`**: every pushed page. The observer reads the name from `screenRoute('name', ...)` or
  `RouteSettings(name:)`. Main tabs are sent by hand as `$screen` with `tab_*` names.
- **`$exception`**: Flutter framework errors, uncaught Dart and isolate errors, and native
  crashes (error tracking).
- **Session replay**: screen recordings of sessions, with text visible. The auth form fields are
  masked with `PostHogMaskWidget`. Replay must also be switched on in the PostHog project settings.

## Backend-only interaction events

Every backend event has `event`, `ts` (UTC), `session_id`, `seq` (order within the session) and
`screen` (the screen on display). Each upload batch carries the context stored on every row:
`app_version`, `app_build`, `platform`, `os_version`, `device_model` (for example `iPhone17,1`),
`locale` and `timezone` (abbreviation and UTC offset).

| Event | Properties |
|---|---|
| `tap` / `long_press` | `widget` (control type, e.g. ElevatedButton, ListTile), `target` (visible label: text, tooltip or semantics label, max 80 chars, or `icon:<codepoint>`), `kind` (button/list_item/switch/checkbox/radio/slider/text_field/navigation/back), `key` (ValueKey), `value` (toggle state before the tap), `dead` (nothing tappable there), `masked` (inside `PostHogMaskWidget`, label left out), `x`, `y` (0–1 of the screen), `duration_ms` |
| `rage_tap` | `taps` (3+ within 1 s and 40 px), `target` |
| `swipe` | `direction` (left/right/up/down), `distance`, `duration_ms`, `x`, `y`, `end_x`, `end_y` |
| `multi_touch` | (pinch or other two-finger gesture) |
| `scroll` | `axis`, `offset`, `max_offset`, `depth` (0–1), `viewport`, `nested`, `page` (PageView) |
| `$screen` | `previous_screen`, plus the properties passed to `Analytics.screen` |
| `screen_exit` | `duration_ms` (time on that screen in the foreground), `next_screen` |
| `app_session_started` | `cold_start`, `screen_w`, `screen_h`, `pixel_ratio`, `text_scale`, `system_dark_mode` |
| `app_session_ended` | `duration_s` (foreground), `wall_s`, `taps`, `screens`, `reason` (timeout/killed_in_background/app_terminated) |
| `app_backgrounded` | `foreground_s`, `session_foreground_s` |
| `app_foregrounded` | `background_s` (a session continues if the app is back within 5 minutes) |
| `network_status` | `network` (wifi/mobile/none/...) at session start |
| `identify` | `auth_provider`, `is_anonymous` (no email or name) |
| `person_properties` | the same properties as PostHog person properties |
| `$exception` | `error_type`, `message` (200 chars), `where` |

Screen names come from `RouteSettings.name` (`screenRoute()`), `Analytics.screen()` for tabs and
dialogs, `root` for the first route, `<screen>:dialog` / `<screen>:popup` for unnamed dialogs and
sheets, and `unnamed_page` for unnamed routes (give those a name).

Admin views (Firebase admin token): `GET /admin/analytics/summary?days=7` (totals, top events,
screens and tap targets, platforms, versions) and `GET /admin/analytics/users/{uid}/events`
(one learner's timeline, newest first, `before`/`event`/`session_id` filters). Deleting an account
deletes its rows.

## Identity

- **`identify(uid)`**: on restored sign-in, anonymous session, email, Google and Apple sign-in.
  - The distinct id is the backend user id (or the Firebase uid as a fallback).
  - Person properties: `email`, `name`, `auth_provider`, `is_anonymous`.
  - `first_seen_version` is set once.
- **`reset()`**: on sign-out and account deletion.
- **Person properties** (set after each lesson or game, and on load): `xp`, `level`,
  `current_streak`, `longest_streak`, `completed_levels`, `accuracy`, `dark_mode`, `language`,
  `voice`, `lesson_style`, `sound_effects`, `haptics`, `daily_target`, `weekly_goal`,
  `notifications_enabled`, `reminder_time`.

## Events

| Event | Where | Properties |
|---|---|---|
| `app_launched` | splash | `restored_session` (bool), `auth_provider`, `is_anonymous` |
| `anonymous_session_started` | auth service | `success`, `error` |
| `sign_in_opened` | profile | `source` |
| `auth_screen_viewed` | auth screen | `source` (profile/settings/splash) |
| `auth_mode_switched` | auth screen | `mode` (sign_in/sign_up) |
| `sign_in_started` | auth screen | `method` (email/google/apple), `mode` |
| `sign_in_succeeded` | auth screen | `method`, `mode`, `linked_anonymous` |
| `sign_in_failed` | auth screen | `method`, `mode`, `error` |
| `sign_in_cancelled` | auth screen | `method` |
| `password_reset_requested` | auth screen | `success`, `error` |
| `auth_skipped` | auth screen | |
| `account_linked` | firebase_account_link | `provider`, `outcome` (linked/switched_to_existing/signed_in) |
| `signed_out` | profile | |
| `account_deletion_started` / `account_deletion_cancelled` / `account_deleted` / `account_deletion_failed` | settings | `step` |
| `tab_selected` | main nav | `tab` (home/practice/games/profile; `streak` before the Practice tab replaced it), `from_tab`, `via` |
| `home_shortcut_tapped` | home | `shortcut` (see_all_categories/topic/memory_match/hero/streak/share), `topic`, `position` |
| `app_shared` | home | |
| `levels_loaded` | level selection | `level_count`, `source` (api/bundled), `error` |
| `topic_selected` | level selection | `topic`, `topic_path`, `level`, `word_count`, `progress`, `completed` |
| `topic_locked_tapped` | level selection | `topic`, `required_xp`, `xp` |
| `lesson_style_selected` | style sheet | `style`, `previous_style`, `source` (quiz/settings) |
| `lesson_started` | quiz | `topic`, `topic_path`, `style`, `question_count` (core questions), `bonus_available` (harder bonus questions the server sent), `labels` (count per server label: new/mistake/weak/hard), `remote_session` (bool), `source` (`home_shortcut`, `topic_list`, `lesson_intro`, `lesson_complete_retry`) |
| `lesson_load_failed` | quiz | `topic`, `error` |
| `question_answered` | quiz | `topic`, `question_index`, `question_count` (grows when a word is missed or bonus questions join), `question_type`, `correct`, `combo`, `tibetan`, `english`, `chosen`, `correct_answer`, `response_ms`, `skill` (`script`/`vocabulary`), `has_audio`, `voice`, `reading_help`, `style`, `source`, `role` (`core`/`bonus`/`retry`), `attempt` (1, or 2 for a missed word asked again), `label` (`new`/`mistake`/`weak`/`hard`), `to_fix` (missed words still to come) |
| `lesson_bonus_added` | quiz | `topic`, `count` (1 or 2 harder questions), `first_try_accuracy` (0-100; 80+ earns 1, 90+ earns 2) |
| `lesson_quit` | quiz | `topic`, `question_index`, `question_count`, `score`, `reason` (`back`), `answered`, `question_s` (time on the open question), `source` |
| `lesson_intro_opened` | Basics lesson cards | `level`, `source` |
| `lesson_intro_practice` | Basics lesson cards | `level`, `items`, `heard` (cards tapped), `duration_s` |
| `script_course_opened` | Reading Tibetan chart (`/script`) | `source`, `offline` (bundled chart, no server), `seen`, `strong` (strength >= 0.6), `total`, `gate_passed` |
| `script_char_opened` | chart cell tapped (plays the letter, opens its sheet) | `char`, `kind` (`consonant`/`vowel`/`stack`), `strength` (0-100), `seen`, `has_audio`, `voice` |
| `script_learn_started` / `script_practice_started` | chart Learn / Practice buttons | `next` (the next weak characters), `seen`, `strong`. The lesson then logs the usual `lesson_*` and `question_answered` events (`question_type` `near_sound`, `build_stack`, `find_root`, `read_syllable`, `trace`), `topic_path` `api://script/learn` or `api://script/practice` |
| `script_gate_started` | alphabet gate (`/script/gate`) | `mode` (`full` = 10-question check, `quick` = "I already read Tibetan"), `source` |
| `script_gate_skip_chosen` | gate, "I already read Tibetan" | `source` |
| `script_gate_completed` | gate result | `mode`, `passed` (>= 80%), `correct`, `total`, `saved` (graded and stored by the server) |
| `voice_picked` | voice picker | `voice`, `source` (`settings`, `quiz`, `game`, `lesson_intro`, `chip`) |
| `memory_board_resized` | Memory Match | `pairs` (cards per board ÷ 2; more on iPad) |
| `lesson_completed` | quiz | `topic`, `topic_path`, `style`, `score`, `total`, `accuracy`, `xp_earned`, `streak`, `duration_s`, `recycled` (missed words asked again), `fixed` (of those, right the second time), `bonus_shown`, `bonus_correct` |
| `lesson_progress_submitted` | quiz | `success`, `answers` (attempts sent for server grading) |
| `dialogue_started` | dialogue player | `dialogue_id`, `status` (draft/reviewed), `lines`, `questions`, `has_audio`, `graded` (server session issued) |
| `dialogue_translation_toggled` | dialogue player | `dialogue_id`, `line` (1-based), `shown` |
| `dialogue_line_replayed` | dialogue player | `dialogue_id`, `line` |
| `dialogue_question_answered` | dialogue player | `dialogue_id`, `question_id`, `correct` (the app's check; the server grades again) |
| `dialogue_completed` | dialogue player | `dialogue_id`, `correct`, `total`, `graded`, `submitted`, `translations_opened`, `duration_s` |
| `dialogue_load_failed` | dialogue player | `dialogue_id` (missing, not reviewed, or offline) |
| `dialogue_disabled` | dialogue player | `dialogue_id` (`dialogues` kill switch on) |
| `lesson_result_shown` | lesson complete | `topic`, `celebration` (`big` for the first lesson and lesson milestones, `normal`, `quiet` below 70%), `lessons_completed`, `accuracy`, `recycled`, `fixed` |
| `lesson_complete_action` | lesson complete | `action` (continue/practice_again) |
| `lesson_goal_closed` | lesson goal (after a lessons-finished milestone) | `lessons_completed`, `next_goal` |
| `session_end_completed` | lesson complete | `steps` (in order, from `result`, `streak`, `goal`, `ask`), `celebration`, `lessons_completed` |
| `game_selected` | games tab | `game`, `skill` |
| `game_topic_selected` | game host | `game`, `topic`, `random` |
| `game_started` | game host / memory / speed | `game`, `topic`, `word_count` |
| `game_not_enough_words` | game host | `game`, `topic`, `usable`, `min_words` |
| `game_completed` | game host / memory / speed | `game`, `topic`, `correct`, `total`, `moves`, `best`, `new_best`, `duration_s` |
| `game_result_action` | game host / memory | `game`, `action` (play_again/change_topic/done) |
| `game_answered` | speed quiz | `game`, `correct`, `question_type`, `seconds_left` |
| `game_quit` | game host / memory / speed | `game`, `topic` |
| `pronunciation_played` | speaker button | `source` (tap/auto), `voice` |
| `pronunciation_failed` | player | `reason` (missing/offline/error), `error` |
| `xp_gained` | progress | `amount`, `xp`, `category` |
| `level_up` | progress | `level`, `previous_level` |
| `streak_extended` / `streak_reset` | progress | `current_streak`, `longest_streak` |
| `achievement_unlocked` | progress | `achievement`, `title` |
| `progress_reset` | settings / profile | `source` |
| `streak_practice_tapped` | streak screen | `practiced_today` |
| `streak_celebration_shown` | streak celebration | `streak`, `milestone`, `goal`, `goal_reached`, `freeze_earned`, `freezes_used`, `tier` (spark/flame/blaze/bonfire/golden), `tier_up`, `restored`, `earn_back_sessions` |
| `streak_tier_reached` | streak celebration | `streak`, `tier` (the flame grew at 7/14/30/50 days) |
| `streak_tier_teased` | streak celebration | `streak`, `tier` (the day before a tier: "tomorrow your flame grows") |
| `earn_back_started` | progress | `streak` (the broken streak), `days_left`, `sessions_needed` — first lesson counted in an Earn Back window |
| `earn_back_completed` | progress | `streak` (restored), `previous_streak`, `repaired_days` |
| `earn_back_expired` | progress | `streak`, `sessions_done` — the window ran out before enough lessons |
| `earn_back_card_tapped` | home / streak screen | `source` (home/streak), `streak`, `sessions_done`, `days_left` |
| `setting_changed` | settings / theme service | `setting`, `value` |
| `notifications_toggled` | notification settings | `enabled` |
| `reminder_time_changed` | notification settings | `hour`, `minute` |
| `notification_permission_result` | notification service (Settings reminder switches; never at launch) | `granted` |
| `player_name_changed` | profile | |
| `progress_exported` | settings | `success`, `reason` |
| `achievements_viewed` | settings | |
| `rate_app_tapped` / `about_opened` / `privacy_opened` / `made_by_opened` | settings / profile | |
| `api_error` | api service | `endpoint`, `method`, `status`, `error` |
| `push_permission` | push service | `status` (authorized/denied/provisional/notDetermined), `source` (`launch`: read without asking; `primer_streak` / `primer_freeze`: OS prompt after the primer; `settings`) |
| `push_token_registered` | push service | `refresh` |
| `push_token_unavailable` | push service | `reason` |
| `push_received` | push service (app open) | `campaign`, `screen`, `line_id`, `foreground` |
| `push_opened` | push service | `campaign`, `screen` |
| `notification_opened` | push service (any push tapped) | `campaign` (`streak_at_risk`, `streak_saver`, or an admin campaign), `kind` (`reminder`/`streak_saver`), `state` (`not_started`/`evening`/`late`/`frozen`/`earn_back`), `line_id` (copy line, e.g. `ev_03`), `notification_id`. Compare open rates per `line_id` against the backend's `server_push_sent` |
| `notification_primer_shown` | notification primer (the first session-end ask, after the streak celebration; games and speed quiz call it directly) | `moment` (`streak`/`freeze`), `ask` (1-3; at most 3 asks, 3+ days apart, only while the OS prompt can still be shown) |
| `notification_primer_answered` | notification primer | `moment`, `ask`, `choice` (`turn_on`/`maybe_later`) |
| `onboarding_started` | onboarding (new installs only; kill switch `onboarding`) | — |
| `onboarding_step_viewed` | onboarding, each step shown (funnel and drop-off) | `step` (`hello`/`motivation`/`knowledge`/`voice`/`goal`/`notifications`), `index`, `count`, `ms` since start |
| `onboarding_answered` | onboarding, one-tap answer | `step`, `answer` (motivation `heritage`/`buddhist`/`travel`/`curious`; knowledge `none`/`speak_some`/`can_read`/`conversational`; voice id; goal lessons a day 1/2/3/5; notifications `turn_on`/`maybe_later`; hello `start`) |
| `onboarding_back` | onboarding, Back (button or system back) | `step` left, `index`, `count`, `ms` |
| `onboarding_skipped` | onboarding, Skip (leaves for Home with defaults) | `step`, `index`, `count`, `ms` |
| `onboarding_backgrounded` | onboarding, app left the foreground mid-flow (drop-off) | `step`, `index`, `count`, `ms` |
| `onboarding_restarted` | splash, a previous onboarding was left unfinished and starts again | `last_step` |
| `onboarding_completed` / `onboarding_exited` | onboarding finished / skipped | `motivation`, `prior_knowledge`, `voice`, `daily_goal`, `start_level` (placement), `start_level_found`, `last_step`, `ms` |
| `onboarding_first_lesson_opened` | onboarding, straight into the placed lesson | `start_level` |
| `save_progress_shown` | session-end ask #2 "Save your progress" (anonymous learners; max 3, 4+ days apart; kill switch `account_linking`) | `moment` (`firstLesson`/`streak`/`later`), `ask`, `lessons_completed`, `streak` |
| `save_progress_answered` | save progress sheet | `moment`, `ask`, `choice` (`save`/`not_now`) |
| `save_progress_result` | after the account screen closes | `moment`, `ask`, `saved` |
| `reading_help_new_words_only_changed` | Settings > Reading help switch, or the wean-off sheet | `enabled`, `source` (`settings`/`wean_off`) |
| `reading_help_wean_off_shown` | session-end ask (last), once ever, after 20 right in a row with reading help shown | `run`, `mode`, `new_words_only` |
| `reading_help_wean_off_answered` | wean-off sheet | `choice` (`off`/`new_words`/`keep`) |
| `location_prompt_shown` / `location_prompt_answered` | lesson complete (first lesson, once) | `source`, `share` |
| `location_sharing_changed` | location service | `enabled`, `permission`, `source` (settings/lesson_complete) |
| `location_shared` | location service (at most daily) | `approx_lat`, `approx_lon` (rounded to 0.1°, ~10 km), `accuracy_km`, `country`, `country_code`, `region`, `city`; also set as `location_*` person properties |
| `location_unavailable` | location service | `reason` |
| `remote_config_activated` | remote settings | every `exp_*` parameter and its value |
| `announcement_viewed` / `announcement_tapped` / `announcement_dismissed` | home banner | `announcement`, `url` |
| `auth_token_refresh_failed` | api service | `error` |
| `force_update_shown` | update gate (iOS, Android) | `installed_version`, `store_version` (empty for a server wall), `reason` (`storeRelease`: newer App Store version; `belowMinimumBuild`: below `/v1/config` `min_supported_build`) |
| `force_update_tapped` | update gate (iOS, Android) | `installed_version`, `store_version`, `reason`, `opened` (bool: store app or web page opened) |
| `experiment_exposed` | `Experiments.exposed` / `ExperimentExposure` (any screen) | `experiment` (`exp_*` key or PostHog flag), `arm`, `surface` (where it was shown), `source` (`remote_config`/`posthog`) |
| `path_loaded` | home (learning path) | `units`, `active_node_id`, `daily_sessions`, `daily_goal` |
| `path_step_started` | home / learn path | `node_id` (`lesson:<level>`, `practice:<unit>`, `unit_review:<unit>`, `alphabet_gate:script`, ...), `type`, `state` (active/unlocked/passed), `unit`, `session` (1-based), `total_sessions`, `source` (home_path/learn_path) |
| `path_locked_tapped` | home / learn path | `node_id`, `type`, `active_node_id`, `source` |
| `path_gate_skipped` | reading-check placeholder | `source` |
| `learn_mode_switched` | learn screen | `mode` (path/topics) |
| `streak_sheet_opened` | home top bar flame, classic stats strip | `source` (home_top_bar/home_stats) |
| `streak_details_opened` | streak sheet | `source` |
| `daily_goal_tapped` | home top bar | `sessions`, `goal` |
| `review_loaded` | Practice tab | `words`, `mistakes`, `weak`, `offline` |
| `review_started` | Practice tab | `words`, `source` |
| `offline_queue_enqueued` | offline queue (`offline_mode` on) | `kind` (`lesson_complete`/`activity`/`kv_patch`/`notification_opened`) — every queueable write is queued first, then sent at once when nothing waits ahead of it |
| `offline_queue_replayed` | offline queue | `kind`, `attempts`, `status`, `age_minutes`, `replayed` (the server had already counted it) — a write that failed at least once reached the server |
| `offline_queue_dropped` | offline queue | `kind`, `reason` (`rejected`: a final 4xx such as 410 expired session or 409 kv conflict; `expired`: older than 7 days), `attempts`, `status`, `age_minutes` |
| `offline_mode_offline` / `offline_mode_back_online` | offline mode (connectivity) | `pending` (writes queued), `lessons_ready` |
| `offline_lessons_prefetched` | offline mode | `added`, `ready`, `reason` (`lesson`: after a lesson; `wifi_start`: app start on Wi-Fi), `media_mb` (offline media on disk, capped at 50 MB) |
| `offline_lesson_started` | api service (lesson start with no network) | `level_id`, `available` (a prefetched session was played), `lessons_left` |
| `offline_banner_viewed` | home offline banner | `state` (`offline`/`ready`), `lessons_ready`, `pending` |
| `leaderboard_opened` | Games header trophy, Profile card, weekly result sheet | `source` (`games`/`profile`/`weekly_result`) |
| `leaderboard_viewed` | leaderboard screen (first load) | `source`, `rank` (null: no XP or hidden), `xp`, `in_top` (top 50), `visible`, `learners` |
| `leaderboard_result_shown` | Profile, first launch of a new week ("You finished #12") | `rank`, `xp`, `learners` (last week) |
| `setting_changed` (`setting`: `show_on_leaderboard`) | Settings > Privacy | `value` |
| `family_invite_created` | Profile > Family streaks | `members` (already linked) |
| `family_invite_shared` | invite sheet | `via` (`share`/`copy`) |
| `family_invite_accepted` | enter-code sheet | `success`, `error` (`invalid`/`ownCode`/`alreadyLinked`/`full`/`theirFull`/`offline`) |
| `family_nudge_sent` | family member row | `outcome` (`sent`/`alreadyNudged`/`alreadyPractised`/`offline`/`failed`), `shared_streak` |
| `family_member_removed` | family member row | `success` |

## Experiments: assignment is not exposure

- **Assignment** is which arm a learner is in. Remote Config parameters named `exp_*` (set with a
  "user in random percentile" condition) are registered as super properties, so every later PostHog
  event carries them, and `remote_config_activated` lists them (see FIREBASE_SETUP.md). Reading an
  arm with `Experiments.arm(...)`, or `Experiments.posthogArm(...)` without `exposed: true`, logs
  nothing.
- **Exposure** is the learner actually seeing the arm. Log it only where the UI shows the part that
  differs between arms: wrap that widget in `ExperimentExposure(experiment:, arm:, surface:)`, or call
  `Experiments.exposed(experiment, arm, surface: ...)` at the moment it is shown. Never log exposure
  at start-up, on assignment, in a service, or for a screen the learner did not open.
- `experiment_exposed` goes out once per experiment and arm per app session (deduplicated in the app),
  is never sampled, and is sent for control too: the control arm needs exposures to compare against.
- For PostHog flags, `Experiments.posthogArm(flag, exposed: true)` also sends PostHog's own
  `$feature_flag_called`, which PostHog experiments use as their exposure; read the flag with
  `exposed: false` anywhere it is not on screen.
- Analyse an experiment on exposed learners only: start the funnel or trend at `experiment_exposed`
  filtered by `experiment`, and break down by `arm`.
- Rules that change XP or rewards are not Remote Config experiments: the backend grants XP and
  freezes, so such an experiment must be assigned and applied there. `/v1/config` reports the values
  in `rewards` (read-only) and has a `flags` map for server-owned switches.

## Not tracked on purpose

- Passwords and typed text (text field taps report the field label only).
- Labels inside `PostHogMaskWidget` (the sign-in form).
- Full answer option lists.
- Anything outside the app: contacts, photos, location, clipboard, other apps, the advertising ID
  (IDFA/AAID) or device fingerprints. Collecting these would need new permission prompts, App
  Tracking Transparency and new App Store privacy label entries.

## Super properties

Every PostHog event also carries `current_screen` (the screen on display,
from the tracker), `voice`, `lesson_style` and `bojang_session_id`.
`setting_changed` covers `transliteration` (`phonetics`, `wylie`, `both`, `off`).
`setting_changed` also covers `haptics` (`true`/`false`, Settings > Audio > Haptics; saved on the device, not in ThemeService). Feedback sounds, haptics and yak reactions (`Feedback.play`) send no events of their own.

## Server-side events (app_events, platform `server`)

Written by the backend itself, so the log is complete for old app versions
and unsent batches: `server_session_issued` (`session_id`, `level_id`,
`requested_types`, `supported_types`, `exercise_types`, `total_questions`,
`adaptive`, `labels`),
`server_lesson_cards` (`level_id`, `items`), `server_dialogue_issued`
(`dialogue_id`, `status`, `session_id`, `lines`, `questions`), `server_lesson_completed`
(`session_id`, `level_id`, `correct_answers`, `total_questions`,
`time_taken_seconds`, `xp_earned`, `level_completed`, `graded`, `offline`
(sent late from the app's queue), `local_date` (the day credited), and when the
app sent answers: `server_graded`, `client_trusted`, `grading_mismatches`,
`unknown_answers`, `recycled`, `fixed`, `adaptive_correct`),
`server_earn_back_started` (`streak`, `expires_at`, `sessions_done`) and
`server_earn_back_completed` (`streak`, `repaired_days`),
`server_script_session_issued` (`session_id`, `mode`, `focus`, `exercise_types`)
and `server_script_gate_completed` (`session_id`, `mode`, `correct`, `total`,
`passed`). Script answers also carry `exercise_responses.char` (the letter,
vowel sign or stack practised), which letter strength is computed from.
`server_session_issued` sessions from `/learn/session` now carry the path
node in `learning_sessions.path_node_id`. `server_review_session_issued`
(`session_id`, `node_id` null for the Practice tab, `words`, `flagged`) and
`server_path_node_completed` (`node_id`, `counted`, `state`,
`finished_sessions`) cover review sessions and routed path nodes
(alphabet, reading check, dialogue).

Every answer of a graded lesson is also a row in the backend's
`exercise_responses` table (not an event): exercise id and type, word
(lexeme) id, answer, correct, the app's own verdict, `graded_by`
(`server`/`client`), attempt, role, label and response time.

`server_push_sent` (`notification_id`, `kind` reminder/streak_saver, `state`,
`line_id`, `streak`, `devices`, `delivered`, `ttl_s` seconds until the
learner's local midnight, when the push expires): one per automated streak
push from `POST /jobs/streak-reminders`. The same sends are in the
`push_notifications` table with `opened_at`, set by the app's
`POST /notifications/opened`.

`server_family_linked` (`link_id`) when a family invite is accepted, and
`server_family_nudge_sent` (`link_id`, `line_id` from the `fn_*` pool in
`services/family.py`, `devices`, `delivered`) for each nudge push. Nudges are
logged in `family_nudges`, not `push_notifications`, so they never use up the
learner's streak-reminder cap; their push data carries `campaign`
`family_nudge` and `screen` `profile`.
