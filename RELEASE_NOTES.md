# ChillMate Release Notes

ChillMate is a private, judgment-free wellbeing and harm-reduction companion.
Everything stays on your device by default. The app does not diagnose, treat,
recommend substance use, or give dosage advice.

---

## Version 3.0 (build 301)

Release date: 18 June 2026
Minimum OS: iOS 26 (built and verified against the iOS 27 SDK)

Version 3.0 is a large modernization and reach update. It adopts the newest iOS
frameworks, adds three more languages, makes every help resource match the
country you choose, and triples the size of the daily affirmation library.

Build 301 follows the first 3.0 upload (build 300) with two changes:

- The tab bar now stays fully visible instead of minimizing to a single icon
  while scrolling.
- You can change your country directly in Edit Profile, not only during setup.
  Changing it updates your default emergency number and the support resources
  shown across the app.

### Languages

ChillMate now ships fully localized in five languages, with English as the
source language:

- English
- Dutch (Nederlands)
- Spanish (Español, Spain)
- German (Deutsch, Germany)
- French (Français, France) — new in 3.0

All 1,581 interface strings are translated in every language, including
notifications, safety information, the risk checker, onboarding, and the new
affirmations. You can switch language from setup and in Settings.

### Country-aware help and emergency resources

When you pick your country during setup, ChillMate now tailors its support and
emergency content to where you are:

- Country-specific crisis lines: 113 (Netherlands), Zelfmoordlijn 1813
  (Belgium), TelefonSeelsorge 0800 111 0 111 (Germany), Samaritans 116 123
  (United Kingdom), 3114 (France), and 024 (Spain).
- The correct default emergency number per country (112 across the EU, 999 in
  the United Kingdom).
- Localized resources for sexual health and STI testing, GP or clinic contact,
  drug information and harm reduction, support after sexual assault, and
  LGBTQ+ support.
- The Emergency Information page now reads the country you chose. The call
  button, the non-urgent healthcare label, and the support links all follow
  that choice. You can still override the emergency number and healthcare
  contact by hand.
- Picking "Other" keeps the Dutch resources as a sensible default.

### Daily affirmations

- Added 210 new curated affirmations, growing the offline library from 28 to
  238. They are gentle, second-person, non-judgmental, and harm-reduction
  minded, with no medical or dosing claims.
- Every affirmation is localized in all five languages.
- When Apple Intelligence is available, ChillMate can still generate fresh,
  on-device affirmations in your chosen language (Dutch, Spanish, German,
  French, or English). The curated library is the private, offline fallback.

### Clearer age verification on setup

- Added a plain-language "Why verify your age, and how it works" explainer to
  the setup screen. It describes why ChillMate is adults-only and how the
  privacy-preserving check works.
- ChillMate uses Apple's DeclaredAgeRange so the optional Apple Account check
  returns only a yes-or-no "18 or older" answer. It never shares your birthdate
  or name with the app.
- Your age is used only on your device to unlock the app. It is never sent to
  the developer, never uploaded, and never shared. You can skip the Apple check
  and simply use your date of birth.

### iOS 26 and 27 modernization

- Adopted DeclaredAgeRange for a privacy-preserving 18+ confirmation in setup.
- Adopted interactive Liquid Glass surfaces, with corrected tint and
  interactivity throughout the app.
- Hardened layout for resizable windows and larger screens.
- Toolbars now minimize on scroll, with Save actions kept pinned and reachable.
- On the iOS 27 development branch, the trailing toolbar Save action is pinned
  using the newest placement APIs.
- Refreshed App Intents: log a skipped night, log hydration, and open the
  check-in timers from Shortcuts, Spotlight, and the Action button. Retired the
  older quick actions that no longer had a destination.
- Added on-device affirmation generation through Foundation Models, with a
  static fallback when the model is unavailable.

### Apple Watch

- Replaced the Watch app icon with the circular ChillMate brand mark.
- iPhone-side preparation for Watch features stays in place: hydration
  reminders, elevated heart-rate warnings, haptic breathing, discreet
  check-ins, and timer visibility.

### Fixes and housekeeping

- Fixed App Intents that had no working destination, corrected hydration
  logging, and made the age gate persist correctly.
- Resolved 15 String Catalog issues (13 stale keys and 2 percentage-format
  warnings).
- Removed stale, now-unused help strings and kept the String Catalog clean
  (zero stale entries) across all five languages.

### Privacy, unchanged and intact

- No ads, no selling of personal information, and no sharing of health or
  sexual-health details for marketing.
- Data stays on your device by default. iCloud backup is optional and is
  encrypted before it leaves the app.
- Face ID or PIN can lock the app, and your local files can stay encrypted
  while ChillMate is closed.

---

### App Store "What's New" (short version)

ChillMate 3.0 speaks more languages and knows where you are.

- New: full French localization, joining English, Dutch, Spanish, and German.
- Help, support, and emergency numbers now match the country you choose, with
  the right crisis line and emergency number for the Netherlands, Belgium,
  Germany, the United Kingdom, France, and Spain.
- 210 new daily affirmations, all localized.
- A clearer, privacy-first explanation of why and how ChillMate confirms you
  are 18 or older.
- Polished for the latest iOS with interactive Liquid Glass, refreshed
  Shortcuts actions, and a new Apple Watch icon.

Everything stays private and on your device. ChillMate is free, with no ads.
