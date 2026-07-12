# App Store Submission Pack — v1.0.1 (current, supersedes older APP_STORE_* docs)

> Updated 2026-07-12. The older metadata docs in this repo predate Google sign-in
> and the backend, and their privacy answers are now WRONG. Use this file.

## Basic Info

- **App Name (30 max):** Bojang - Learn Tibetan
- **Subtitle (30 max):** Interactive Tibetan Learning
- **Bundle ID:** com.bojang.app
- **Version:** 1.0.1
- **Primary Category:** Education
- **Secondary Category:** Reference
- **Price:** Free
- **Age Rating:** 4+

## Promotional Text (170 max)

Learn Tibetan through interactive quizzes! Master alphabet, vocabulary, and real-life conversations with authentic audio feedback. Perfect for all levels!

## Keywords (100 max)

tibetan,language,learning,quiz,education,buddhism,culture,dharamshala,tibet,alphabet

## Description

Learn Tibetan the fun and interactive way with Bojang!

Bojang is a comprehensive Tibetan language learning app designed for English speakers who want to master the beautiful Tibetan language. Whether you're a complete beginner or looking to advance your skills, Bojang offers a structured learning path with engaging quizzes and authentic audio feedback.

FEATURES:

Progressive Learning System
• 3 skill levels: Beginner, Intermediate, and Advanced
• Topic-based lessons covering everything from alphabet to real-life conversations
• Structured curriculum that builds upon previous knowledge

Interactive Quizzes
• Multiple-choice questions with instant feedback
• Audio pronunciation for correct and incorrect answers
• Score tracking to monitor your progress

Authentic Learning Experience
• Native Tibetan script display
• Cultural context in advanced lessons
• Practical phrases for real-world situations

Optional Account Sync
• Sign in with Google to keep your progress and streaks across devices
• Or skip sign-in entirely and learn on this device — no account required

Perfect for:
• Students of Tibetan Buddhism
• Travelers to Tibet and Tibetan communities
• Cultural enthusiasts and language learners
• Anyone interested in preserving Tibetan culture

Start your Tibetan language journey today with Bojang!

ལེགས་སོ། (Excellent!) — Begin learning now!

## Release Notes (What's New — v1.0.1)

• Simplified sign-in: one-tap Google sign-in, or skip and learn without an account
• Improved stability and performance
• Bug fixes across quizzes and progress tracking

## App Review Information

- **Contact:** Tashi Tsering, ta3tsering@gmail.com (add phone in ASC)
- **Sign-in required?** No — sign-in is OPTIONAL. A "Skip" option on the first
  screen unlocks the full app. Google sign-in only adds cross-device progress sync.
- **Demo account:** Not required (all features reachable via Skip). State this
  clearly in review notes so the reviewer doesn't ask for Google credentials.

### Review Notes (paste into ASC)

Bojang is an educational app that teaches the Tibetan language through
interactive quizzes across three skill levels.

SIGN-IN IS OPTIONAL: On the first screen, tap "Skip" (below the Google
button) to access the entire app with no account. Google sign-in is offered
only to sync learning progress across devices. No feature is locked behind
sign-in, so no demo account is needed.

HOW TO TEST:
1. Launch the app and tap Skip (or sign in with any Google account).
2. Pick a level (Beginner / Intermediate / Advanced) and a topic.
3. Answer quiz questions — audio feedback plays for right/wrong answers.
4. Progress and streaks are tracked on the profile screen.

CONTENT: educational only; Tibetan script with English translations; no
user-generated content, no social features, no in-app purchases or ads.

## Privacy — App Privacy Details (Nutrition Label)

The app OFFERS Google sign-in (optional). When a user signs in, we collect
via Google and store on our backend (Google Cloud Run):

**Data collected, linked to the user's identity:**
- Contact Info → Email Address (app functionality / user account)
- Contact Info → Name (app functionality / user account)
- User Content → Photos or Videos: NO (only the Google profile photo URL) —
  declare **Identifiers → User ID** and **Contact Info → Name/Email** instead
- Identifiers → User ID (account management)
- Usage Data → Product Interaction (quiz progress, streaks — app functionality)

**Tracking (across apps/websites for ads):** NO
**Third-party advertising:** NO
**Analytics SDKs:** None (Firebase Analytics is DISABLED in the plist)

Privacy policy: PRIVACY_POLICY.md in repo — MUST be hosted at a public URL
before submission (App Store requires a working Privacy Policy URL).

## Export Compliance

- Uses encryption? **Yes — but only standard HTTPS/ATS** (exempt).
- `ITSAppUsesNonExemptEncryption = false` is already set in Info.plist, so
  App Store Connect will not prompt per-build.

## Age Rating Questionnaire — all "None/No" except:

- Unrestricted Web Access: No
- Everything else (violence, gambling, mature themes, etc.): None
- Result: **4+**

## ⚠️ Known Rejection Risks

1. **Guideline 4.8 (Login Services):** The app offers Google sign-in but not
   Sign in with Apple or an equivalent privacy-focused option. Apple has
   rejected apps for this even when login is optional. Mitigation if rejected:
   add Sign in with Apple, or argue the Skip option makes login non-primary.
2. **Privacy Policy URL** must be live and must describe the Google sign-in
   data collection (email, name, profile photo, progress data).
3. **Screenshots** (6.9"/6.7" iPhone required) must show the actual current UI.
