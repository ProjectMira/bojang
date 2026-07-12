# Bojang UI Revamp — Design Spec (v1)

**Scope: visual/layout redesign only. No functionality, data, or API behavior changes.**
The only new interactions are ones explicitly requested: shortcut cards, "See all" link,
share button → https://www.bojang.in, and a profile footer.

Implementer notes: every color below must work in BOTH light and dark themes. Where a
hex is given, it is the light-mode value; dark-mode variant is listed or derived via the
rule in §1.4. Keep Poppins with `fontFamilyFallback: ['Jomolhari']` everywhere (existing
pattern).

---

## 1. Foundation — design tokens (new file `lib/theme/app_tokens.dart`)

Today every screen re-declares colors, shadows and radii inline. Centralize once; all
redesigned widgets import from here. This is the highest-leverage change for consistency.

### 1.1 Palette
| Token | Light | Dark | Use |
|---|---|---|---|
| `primary` | `#2C97DD` | same | brand blue, CTAs |
| `primaryDeep` | `#1976D2` | same | gradient end |
| `ink` | `#2C3E50` | `#FFFFFF` | titles |
| `inkSoft` | `#7F8C9B` (replaces greyade600) | `#9AA4B0` | subtitles |
| `surface` | `#FFFFFF` | `#242A31` | cards (dark: warmer than current `#2D2D2D`) |
| `background` | `#F5F7FA` | `#151A1F` | scaffold |
| `green` | `#58CC02` | same | success / streaks-adjacent |
| `orange` | `#FF9600` | same | streak fire |
| `purple` | `#CE82FF` | same | games |
| `gold` | `#FFC800` | same | XP / trophies |
| `red` | `#FF4B4B` | same | wrong answers |

Tint rule: colored chip/card backgrounds = accent at **10% opacity light / 22% dark**
(one helper: `tint(Color c, BuildContext ctx)`).

### 1.2 Shape & elevation
- Radius scale: **12 (chips) / 16 (cards) / 20 (hero) / 28 (buttons, stadium)**.
- One shadow token only: `BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: Offset(0, 4))`. Kill all other ad-hoc shadows. In dark mode use borders (`Colors.white.withOpacity(0.08)`) instead of shadows.

### 1.3 Spacing
4-pt scale: 4/8/12/16/20/24/32. Screen gutter = 20 (up from 16 — content breathes more).
Section gap = 28.

### 1.4 Type ramp (extend `lib/widgets/app_text_style.dart`)
- `display` 26/bold — screen headlines ("Ready for Tibetan?")
- `title` 18/semibold — card titles, section headers
- `body` 14/regular
- `caption` 12/medium, color `inkSoft`
- `tibetan` — sizes ×1.15 when text is Tibetan script (Jomolhari renders small)

---

## 2. Success experience (quiz feedback + lesson complete)

### 2.1 Problem
`quiz_screen.dart:315` shows a bare `AlertDialog` for every answer, and
`quiz_screen.dart:212` shows another plain dialog on completion. Dialogs feel like system
errors, not celebration; the white dialog also ignores dark mode.

### 2.2 Answer feedback → bottom banner (Duolingo pattern)
Replace `_showFeedbackDialog` with an animated **bottom sheet-style banner** (not a
dialog; non-blocking visually, same 2 s auto-advance timing — behavior unchanged):
- Slides up from bottom, full width, rounded top corners (20), safe-area padded.
- Correct: `green` 12% tint background, `check_circle_rounded` in solid green circle
  (44 px), title **"ལེགས་སོ། Amazing!"** in green 18/bold, subtle haptic
  (`HapticFeedback.lightImpact`).
- Wrong: `red` 12% tint, `close_rounded` in solid red circle, **"སེམས་ཤུགས་མ་ཆག — try again!"**.
- Meanwhile the tapped option card gets a 2 px green/red border + tint (options are
  currently hardcoded `Colors.white` at `quiz_screen.dart:652` — switch to `surface`
  token, fixes dark mode too).

### 2.3 Lesson complete → full-screen success page ("first image")
Replace the completion dialog with a **full-screen route** (fade-through transition):

Layout top→bottom, centered, gutter 24:
1. **Confetti** — `confetti` package is already in pubspec; two emitters from top
   corners, brand colors (blue/gold/green/purple), 2.5 s burst.
2. **Score ring** — 160 px circular progress (animated 0→score% over 800 ms,
   `Curves.easeOutCubic`), 12 px stroke, gold for ≥70%, blue otherwise; inside the ring a
   large emoji: 🏆 (≥70%) / ⭐ (else) and `score/total` in 32/bold.
3. Headline: **"ལེགས་སོ། Excellent!"** or **"Keep practicing!"** — display style.
4. Sub-line: "You scored X of Y (Z%)" — body, `inkSoft`.
5. **Stat chips row** (3 pills, 12-radius, tinted): `⚡ +{score×10} XP` (gold),
   `🎯 {accuracy}%` (blue), `🔥 streak` (orange). Same numbers already computed —
   display only.
6. Full-width primary button **"Continue"** (stadium, primary, 56 px tall) → pops back
   to topic list (same navigation as today).
7. Ghost text button **"Practice again"** → re-push same `QuizScreen` (same as tapping
   the topic again; no new logic).

Background: scaffold `background` with a very soft radial glow of the result color at
8% behind the ring. Dark mode: same tokens, glow at 16%.

---

## 3. Home page restructure (`home_page.dart`)

New order (user-specified), inside the existing `SingleChildScrollView`, gutter 20:

```
① Header row        (greeting + settings — keep, minor polish)
② Stats strip       (ONE container, ONE line: streak + XP + lessons)
③ "Categories" header  +  "See all →"
④ 2×2 shortcut grid (3 topics + Memory game)
⑤ Blue hero card    (Start/Continue lesson — existing, refined)
⑥ Info box          (Cultural tip — restyled)
⑦ Share button      (→ https://www.bojang.in)
```

### ② Stats strip — one container, one line
Replaces the three separate `_buildStatCard` columns (`home_page.dart:251-335`).
- Single `surface` card, radius 16, padding `16×14`, one shadow token.
- Row of three equal `Expanded` stats separated by 1 px vertical dividers
  (`inkSoft` @ 15%): each stat is a **horizontal** pair — emoji/icon in a 34 px tinted
  rounded square + column of value (18/bold) over label (caption).
  - 🔥 `currentStreak` "Day streak" (orange)
  - ⚡ `xp` "XP" (gold)  — keep the existing accuracy fallback when xp == 0
  - 📚 `completedLevelsCount` "Lessons" (green) — keep level fallback
- Whole strip is tappable → switches to the Streak tab (call the nav callback — see §6
  note on exposing tab switching; simplest: `DefaultTabController`-free approach where
  `MainNavigationScreen` passes an `onGoToStreak` callback into `HomePage`).

### ③ Section header + See all
Reusable `SectionHeader(title, actionLabel, onAction)` widget:
- Title in `title` style; trailing **"See all"** in primary 13/semibold with a
  `chevron_right_rounded` 16 px, min tap target 44 px.
- "See all" → `Navigator.push(LevelSelectionScreen())` (the "third page").
Use it for "Categories" and reuse for "Cultural tip" (no action there).

### ④ Shortcut grid — 4 cards, 2×2
`GridView.count` (shrinkWrap, no scroll), crossAxisCount 2, spacing 12,
`childAspectRatio ≈ 1.45`.

Cards 1–3 — first three **unlocked** topics from the same levels source the categories
page uses. To avoid duplicating load logic, extract the level-loading from
`level_selection_screen.dart:43-81` into `lib/services/levels_repository.dart`
(pure move, same code path: API → bundled `assets/quiz_data/levels.json` fallback) and
call it from both screens. While loading / on failure, show three static fallbacks so
the home never looks broken: **Alphabet ཀ**, **Numbers 🔢**, **Greetings 🙏** (bundled
asset paths from `levels.json`). Tap → `QuizScreen(topicFilePath: …)` (existing route).

Card 4 — **Memory Game** 🧠 (purple) → `MemoryMatchGame()` (existing route from the
Games tab).

Card anatomy (this is the "welcoming" moment — make them candy-colored, not white):
- Background: accent tint (10%/22%), **no border, no shadow** — flat + colorful reads
  friendlier than outlined white boxes.
- Accent per card: blue, green, orange for the topics; purple for Memory.
- Content, left-aligned, padding 14: emoji 26 px in a 40 px white (dark: `surface`)
  rounded-12 squircle → `Spacer` → name 15/semibold `ink` (1 line, ellipsis) → caption
  ("12 words" / "Game").
- Press state: `InkWell` with accent @ 12% splash, scale-down 0.97 via
  `AnimatedScale` on tap-down (150 ms) — small, delightful.

### ⑤ Hero card (keep, refine)
Existing gradient hero (`home_page.dart:164`) moves BELOW the grid. Polish:
- Radius 20, padding 20 (was 24 — slightly denser now that it's mid-page).
- Shadow: primary @ 25%, blur 20, offset (0,10) — it's the one element allowed a
  colored shadow (it's the primary CTA).
- Add a faint decorative ཀ watermark, 96 px, white @ 8%, bottom-right, clipped.
- Title stays dynamic: "Continue Learning" / "Start a Lesson".

### ⑥ Info box (cultural tip)
Keep `CulturalTipCard` data/logic; restyle in `cultural_tip_card.dart`:
- Drop the colored border + shadow combo → flat accent tint (10%) background, radius 16.
- Icon chip 40 px solid accent with white icon (more contrast than current 10% tint).
- Tibetan phrase block: `surface` background (not accent 5%), radius 12 — script pops.
- Cap tip text at 3 lines… no, keep full text (no behavior change), but set
  `height: 1.5` and caption-colored body — already close; mainly the container changes.

### ⑦ Share button
Full-width `OutlinedButton.icon` (56 px, stadium radius 28, 1.5 px primary border,
primary text, transparent fill): `favorite_rounded` (or 🇮🇳-free simple ❤️ emoji) +
**"Share Bojang — bojang.in"**.
- Opens `https://www.bojang.in` externally → requires **`url_launcher`** (add to
  pubspec; only new dependency besides §5's `package_info_plus`).
- Below it 24 px bottom padding so it never kisses the nav bar.

### ① Header polish
- Keep greeting; settings icon gets a 40 px tinted circle container (quiet affordance).
- "Welcome back" caption style; "Ready for Tibetan?" display style. Nothing else.

---

## 4. Categories listing revamp (`level_selection_screen.dart`) — "third page"

### 4.1 Problems (current `_buildTopicCard`, lines 274-390)
- `childAspectRatio: 1.5` → squat letterbox cards; emoji chip is tiny and lost top-left.
- White card + hairline border + shadow = clinical; every card identical regardless of
  section → no scannability.
- Progress bar only appears sometimes (layout jumps between cards).
- Section header (colored tick + text) is weak; "N topics" trailing text is noise.

### 4.2 New topic card
Grid: crossAxisSpacing/mainAxisSpacing **14**, `childAspectRatio: 1.18` (taller,
proportional; 3 columns ≥600 px stays).

Card (radius 16, padding 14, flat — no shadow):
- **Background: section-color tint** (10% light / 22% dark). Cards inherit their
  section's hue → the page reads as colorful bands, immediately livelier.
- Top row: emoji **26 px** in a 44 px WHITE (dark: `surface`) rounded-14 squircle —
  inverted from today (white chip on tinted card instead of tinted chip on white card).
  Trailing status: ✓ in 22 px solid green circle (completed) / 🔒 lock 16 px in `inkSoft`
  40% circle (locked) / nothing.
- `Spacer`
- Name 15/semibold `ink`, max 2 lines.
- Caption: "{wordCount} words" or "Lesson".
- **Progress bar always present** (6 px, radius 3): track = white @ 60% (dark:
  black @ 25%), fill = section color, green when completed, 0-width when untouched —
  cards stop jumping in height.
- Locked treatment: entire card at 45% opacity + tint drops to 6%; keep snackbar tap
  behavior.
- Press: same `AnimatedScale` 0.97 pattern as home shortcuts.

### 4.3 Section headers
Replace tick-bar with: 28 px rounded-8 solid section-color square containing a white
mini-icon (`menu_book_rounded`, `translate_rounded`, `record_voice_over_rounded`,
`extension_rounded` — cycle like colors) + title 18/bold + trailing **count pill**
("12", section color 12% tint, 11/semibold, radius 10). Add 8 px more top spacing
between sections (32 total) so bands separate clearly.

### 4.4 Page top
- Keep transparent app bar; headline "Pick a topic" display style; replace the plain
  subtitle with: "**{n} topics** · each lesson is a short quiz" where the count is
  primary-colored semibold.
- Optional (nice, cheap): staggered entrance — each section fades/slides up 12 px,
  60 ms apart, once, on first build.

---

## 5. Profile page (`profile_screen.dart`)

### 5.1 Footer (user request)
At the very bottom of the scroll column, centered, 24 px vertical padding:
- ཀ glyph 20 px in `inkSoft` @ 50% (tiny brand mark)
- **"Bojang v{version} ({buildNumber})"** — caption style, from **`package_info_plus`**
  (add dependency; version currently drifts: pubspec says `1.0.1+10` while the About
  dialog at `profile_screen.dart:527` hardcodes "2.0.0" — the dialog must use the same
  dynamic value).
- **"made by ta4tsering.com"** — caption, tappable → opens `https://ta4tsering.com` via
  `url_launcher`. ⚠️ Confirm domain spelling with owner (account email is *ta3*tsering@…).

### 5.2 Dark-mode + consistency fixes (design bugs, in scope)
- Header gradient `[#2C97DD → #F5F7FA]` (line 191) hardcodes the light background —
  in dark mode it fades to light grey. Fix: fade to `Theme.scaffoldBackgroundColor`.
- `_buildStatCard` (line 384) and `_buildSettingsCard` (line 427): `Colors.white`
  and fixed `#2C3E50` text → use `surface`/`ink` tokens.
- Blue `AppBar` here (and on Games) clashes with Home/Categories' transparent bars →
  switch Profile & Games to transparent app bar, `ink` title, keeping the blue only in
  the header gradient. One app bar language everywhere.
- Stats grid: reuse the **same stat-chip visual** as the home strip (§3②) at 2×2 for
  visual kinship; `childAspectRatio: 1.35` so they're plaques, not near-squares.
- Avatar: add 3 px white ring + soft shadow; name in display style.

---

## 6. Global polish (small, do last)

1. **Bottom nav** (`main_navigation_screen.dart`): container is hardcoded
   `Colors.white` (line 33) → `surface` (dark-mode bug). Remove the icon size jump
   24↔28 and font size jump 10↔12 (causes row shift); constant sizes, selection shown by
   the existing tinted pill + color only. Label always 11/semibold.
2. **Tab switching from Home**: convert `MainNavigationScreen`'s screens list to build
   `HomePage(onSeeStreak: () => setState(() => _currentIndex = 1))` — needed for §3②'s
   tappable strip. Pure wiring, no behavior change elsewhere.
3. **Quiz screen dark mode**: option cards `Colors.white` (line 652) and app-bar title
   `Colors.black87` (line 361) → tokens.
4. **Snackbars**: floating, radius 12, `ink` background with `surface` text (both modes).
5. Replace every `withOpacity(0.05–0.08)` shadow variation with the single token (§1.2).

---

## 7. Dependencies & file map

New deps (pubspec): `url_launcher: ^6.3.0`, `package_info_plus: ^8.0.0`.

| File | Change |
|---|---|
| `lib/theme/app_tokens.dart` | **new** — palette, tint(), shadow, radii, spacing |
| `lib/widgets/app_text_style.dart` | extend ramp (§1.4) |
| `lib/widgets/section_header.dart` | **new** (§3③) |
| `lib/widgets/stat_strip.dart` | **new** — used by Home + Profile |
| `lib/widgets/shortcut_card.dart` | **new** (§3④) |
| `lib/screens/lesson_complete_screen.dart` | **new** (§2.3) |
| `lib/widgets/answer_feedback_banner.dart` | **new** (§2.2) |
| `lib/services/levels_repository.dart` | **new** — extracted loader (§3④) |
| `lib/screens/home_page.dart` | reorder + new sections (§3) |
| `lib/screens/level_selection_screen.dart` | card/section redesign (§4) |
| `lib/screens/profile_screen.dart` | footer + dark-mode fixes (§5) |
| `lib/screens/quiz_screen.dart` | swap dialogs for banner/success screen (§2) |
| `lib/screens/main_navigation_screen.dart` | nav polish + callback (§6) |
| `lib/widgets/cultural_tip_card.dart` | restyle (§3⑥) |
| `lib/screens/extra_games_screen.dart` | transparent app bar only (§5.2) |

## 8. Implementation order (each step ships green)

1. Tokens + text ramp (§1) — no visual change yet.
2. Global dark-mode/consistency fixes (§6) — safe, mechanical.
3. Home restructure (§3) incl. `levels_repository` extraction + `url_launcher`.
4. Categories revamp (§4).
5. Success experience (§2).
6. Profile footer + fixes (§5) incl. `package_info_plus`.
7. `flutter analyze` + run on iPhone simulator, screenshot Home / Categories /
   lesson-complete in **both themes** for review.

**Out of scope / unchanged**: all services, models, API calls, progress logic, quiz
logic, auth, settings, streak screen internals, memory & speed game internals.
