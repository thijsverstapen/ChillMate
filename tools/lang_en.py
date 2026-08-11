# -*- coding: utf-8 -*-
"""English copy. The source text every other language is translated from.

Two deliberate decisions live in here.

**Voice.** One person makes ChillMate, so the site says "I" and not "we".
An earlier draft used "we do not run servers", which is a small fiction, and a
small fiction is a strange thing to put in the paragraph asking you to believe
the big claim.

**Discretion.** `home_title` and `home_desc` are deliberately vague, because
they are what leaks: into a link preview, a browser history, a shared screen.
The body of the page is specific, because only someone who chose to open it
ever reads that. Being coy in both places meant nobody could tell the app was
for them; being explicit in both meant a shared laptop could out someone.
"""

S = {
    # ---------- chrome ----------
    "skip": "Skip to content",
    "nav_home": "Home",
    "nav_privacy": "Privacy",
    "nav_support": "Support",
    "nav_about": "About",
    "nav_github": "GitHub",
    "lang_label": "Language",
    "theme_dark": "Dark",
    "theme_light": "Light",
    "theme_hint": "Switch colour theme",
    "to_top": "Back to top",
    "made": "made by one person in the Netherlands",
    "copy": "Copy",
    "copied": "Copied",
    "call": "Call",
    "open": "Open",
    "policy_en_note": "The privacy policy is kept in English only, so there is one authoritative text rather than five that can drift apart.",

    # The one disclaimer, worded once and used everywhere.
    "disclaimer": "ChillMate supports reflection, planning and your own wellbeing. It does not replace a clinician and it never decides whether anything is safe. If someone may be in immediate danger, call your local emergency number.",

    # ---------- help categories ----------
    "cat_emergency": "Emergency services",
    "cat_crisis": "Crisis and suicide support",
    "cat_sexual_health": "Sexual health and STI testing",
    "cat_gp": "Your doctor",
    "cat_drugs": "Drug information and harm reduction",
    "cat_assault": "After sexual assault",
    "cat_lgbtq": "LGBTQ+ support",
    "cat_emergency_d": "Immediate danger, unconsciousness, or someone who cannot be woken.",
    "cat_crisis_d": "Free and confidential, if you might hurt yourself or cannot stay safe.",
    "cat_sexual_health_d": "STI testing, PrEP, PEP questions, vaccination, and sexual health support.",
    "cat_gp_d": "Medication interactions, sleep, mental health, substance use, and referrals.",
    "cat_drugs_d": "Trusted, non-judgemental drug information and harm reduction.",
    "cat_assault_d": "Support after assault, coercion, or a consent concern.",
    "cat_lgbtq_d": "A listening ear, information, and referral.",
    "cat_generic_local": "Ask your local health service.",

    # ---------- home: head ----------
    "home_title": "ChillMate · A calm, private place to look after yourself",
    "home_desc": "A private overview of your own nights, plans, reminders and safety tools, kept entirely on your iPhone. Free, open source, no account and no server.",

    # ---------- home: hero ----------
    "h1": "A calm, private place to look after yourself.",
    # Short enough to survive a 1200x630 share card.
    "og_sub": "No account. No servers. Everything stays on your iPhone.",
    "og_foot": "Open source · iPhone and Apple Watch",
    "lede": "ChillMate keeps your nights, plans, reminders and safety tools in one private overview on your iPhone. It is free, it is open source, and there is no server, so there is nowhere else for any of it to be.",
    "cta_notify": "Tell me when it is out",
    "cta_see": "See how it works",
    "status_note": "Not on the App Store yet. Send an empty email and you will hear from me once, on the day it is.",
    "notify_subject": "Tell me when ChillMate is out",
    "notify_body": "Nothing to write. I will reply once, on the day it launches, and then delete your address.",

    # ---------- home: who it is for ----------
    "audience_eyebrow": "Who it is for",
    "audience_h2": "Made for the nights this is actually about",
    "audience_p": "Chems, hookups, or both. ChillMate has no opinion about that, and it will never ask you to justify a night to it. What it does is hold the practical parts you would rather not be working out at four in the morning.",
    "audience_points": [
        "A risk checker that knows what you already take, including your own prescription.",
        "A check-in timer, so somebody knows you got home without you having to text them.",
        "A PEP window that starts counting the moment it might matter.",
        "Testing reminders that never say why on your lock screen.",
    ],
    "audience_chill": "The app calls a night a <strong>Chill</strong>. Yours, whatever it was.",

    # ---------- home: the walk ----------
    "walk_eyebrow": "A look inside",
    "walk_h2": "Five screens, and what each one is for.",
    "walk": [
        ("It arranges itself", "Whatever tonight turned into",
         "Log a night and the home screen rearranges around it. Here it has worked out that a PEP conversation might be worth having, and put the countdown at the top by itself. Get help now stays pinned above everything, always."),
        ("It says what is known", "And refuses to say it is safe",
         "Pick what is in play, including your own medication, and the risk checker tells you what is documented about that combination. It has no green light. Nothing in ChillMate will ever tell you something is fine."),
        ("A room with the lights turned down", "For when it is already going wrong",
         "Low stimulation, one thing at a time. Start the breathing timer, work through the grounding steps, and call someone only if you decide you want to."),
        ("Real services, offline", "Help from people, not an app",
         "Crisis lines, sexual health, drugs, LGBTQ+ support and practical care for the country you set. It is a list held on your phone, so it still works with no signal and nothing to look up."),
        ("A plain map of your own data", "In the app, not just in a policy",
         "What is on the device, what an encrypted backup would contain, which Health categories you allowed, and what ChillMate never sends. You should not have to read a policy to find that out."),
    ],

    # ---------- home: one night ----------
    "night_eyebrow": "How it fits",
    "night_h2": "One night, in three beats.",
    "night": [
        ("Before you go", "Decide while it is easy",
         "Run the combination past the risk checker, set what you are and are not up for, and start a check-in timer. Five minutes now, while you are clear-headed and nothing has happened yet."),
        ("While you are out", "One tap, nothing typed",
         "The timer asks if you are alright. I'm safe is one tap. Get help is the other, and it already knows your trusted contact and the right emergency number for where you are. Your watch can answer for you."),
        ("The morning after", "Remember it accurately",
         "Sleep, how you feel, what actually helped. It takes a minute and it is the part you will be glad of in three months, when the patterns are the only honest record you have."),
    ],

    # ---------- home: features ----------
    "features_eyebrow": "What is in it",
    "features": [
        ("book", "tint-blue", "Private log",
         "Record a night the way you want to remember it: sleep, how you felt, and what helped afterwards."),
        ("chart", "tint-mint", "Your patterns",
         "30 and 90 day views of what actually changes for you, and a score for the day that only you ever see."),
        ("life", "tint-purple", "Care tools",
         "Breathing, a craving pause, a safer-session plan, and a route home when you want one."),
        ("flask", "tint-pink", "Risk checker",
         "Plain-language cautions for combinations, including the medication you already take."),
        ("bell", "tint-amber", "Reminders that fit",
         "Check-in timers, a PEP window, and testing reminders, worded discreetly if you prefer."),
        ("watch", "tint-blue", "On your wrist",
         "Timers, check-ins and an emergency number on Apple Watch, without reaching for your phone."),
    ],

    # ---------- home: is this for you ----------
    "foryou_eyebrow": "Is this for you",
    "foryou_h2": "You will know from these.",
    "foryou": [
        "You want last night remembered accurately, not vaguely, and not by anyone else.",
        "You are on PrEP and would rather the reminder did not say PrEP on your lock screen.",
        "You want a reason to check in with someone that is not a whole conversation.",
        "You have wondered, mid-week, whether it is more often than it used to be.",
        "You want the emergency number for wherever you are, without unlocking a browser.",
    ],
    "foryou_not": "It is probably not for you if you want something that will judge the night for you, score your behaviour, or tell you a combination is safe. It does none of those on purpose.",

    # ---------- home: privacy ----------
    "privacy_eyebrow": "Private by design",
    "privacy_h2": "Your phone, and nowhere else",
    "privacy_intro": "Privacy here is not a setting to switch on. It is the shape of the app.",
    "privacy_checks": [
        "No account and no sign-up. No server holds your log, because there is no server.",
        "No ads, no analytics, no trackers, and nothing is ever sold or shared.",
        "Lock it behind Face ID or a PIN, with everything encrypted on the device.",
        "Backups are optional and encrypted, and they go to your own iCloud Drive.",
        "Notifications can stay deliberately vague on the lock screen.",
    ],
    "privacy_link": "Read the full privacy policy",

    # ---------- home: proof ----------
    "proof_eyebrow": "Verify it yourself",
    "proof_h2": "Do not take my word for it",
    "proof_p": "ChillMate is open source. Every line that touches your data is in public, which turns the claim above into something you can check instead of something you have to trust me about.",
    "proof_fact": "There is not a single network call in the app's own code. No analytics SDK, no crash reporter, no <code>URLSession</code> anywhere. The only things that leave your phone are the ones you tap: a call, a link, a message you wrote.",
    "proof_cta_repo": "Read the source",
    "proof_cta_store": "Where your data lives",
    "proof_caption": "Verified against ChillMate 4.2.1 (build 422).",

    "diagram_title": "Where your data goes",
    "diagram_you": "You",
    "diagram_phone": "Your iPhone",
    "diagram_icloud": "Your iCloud",
    "diagram_optional": "optional, encrypted",
    "diagram_server": "My servers",
    "diagram_none": "there are none",

    # ---------- home: what it refuses to do ----------
    "refuse_eyebrow": "By design",
    "refuse_h2": "What it will not do",
    "refuse_p": "Most of the work went into the things it does not do. They are harder to keep than features, because every one of them is a thing somebody will eventually ask for.",
    "refuse": [
        ("It will not tell you something is safe.", "It shows what is documented about a combination and hands the decision back to you, because it does not know your body, your dose, or your night."),
        ("It will not score you as a person.", "There is a number for the day, and it stays on your phone, and nothing is unlocked or withheld by it."),
        ("It will not nag.", "Every reminder is off until you turn it on, and can be worded so a lock screen gives nothing away."),
        ("It will not want an account.", "Adding one would mean adding a server, and a server is a copy of you that exists somewhere you cannot reach."),
        ("It will not charge you.", "Free, all of it. The tip unlocks nothing, because a safety tool with a paywall is not a safety tool."),
    ],

    # ---------- home: watch and languages ----------
    "watch_h3": "It works while the phone stays in a pocket",
    "watch_p": "Dose timers, hydration, discreet check-ins, a breathing exercise, and one tap to your trusted contact or your local emergency number, all on Apple Watch, plus complications for the watch face and the Smart Stack.",
    "watch_quote": "If something feels wrong, get help. You are not in trouble.",
    "watch_quote_note": "The whole of the watch's Safety screen, wording included.",
    "langs_h3": "It works in your language",
    "langs_p": "The app and this site are in English, Dutch, German, French and Spanish. Help resources follow the country you set, not the language you read, because those are two different questions.",

    # ---------- home: questions ----------
    "faq_teaser_eyebrow": "Before you ask",
    "faq_teaser_h2": "The three questions everyone asks.",
    "faq_teaser_link": "The rest of the questions, and real help services",

    # ---------- support page ----------
    "support_title": "ChillMate · Support and help",
    "support_desc": "Crisis lines and health services for your country, offline and printable, plus common questions and how to reach me.",
    "support_h1": "Help, and how to reach me",
    "support_lede": "Real services first, because that is what this page is most useful for. Questions about the app are further down, and one person reads every message.",
    "support_urgent": "<strong>In an emergency, do not wait for the app.</strong> If you or someone else may be in immediate danger, call your local emergency number now.",
    "support_contact_eyebrow": "Get in touch",
    "support_contact_h2": "Contact",
    "support_contact_p": "Email {email}. Replies usually take a few days. Your iOS version and what you were doing when something went wrong helps a lot.",
    "support_email_btn": "Email me",
    "support_issue_btn": "Report an issue",
    "support_faq_eyebrow": "Common questions",
    "support_help_eyebrow": "Real services",
    "support_help_h2": "Help from people, not an app",
    "support_help_p": "ChillMate is not a crisis service. Pick where you are and these organisations can help directly. This page prints, and it works with no signal, because that is exactly when these numbers matter.",
    "support_country_label": "Where are you?",
    "support_emergency_is": "Emergency number here:",
    "support_emergency_local": "your local emergency number",
    "support_print": "Print this page",

    "faq": [
        ("Is my data private?",
         "Yes, and you do not have to believe me. ChillMate keeps everything on your iPhone, has no account and no server, and runs no ads, analytics or trackers. The app is open source, so you can read exactly what it does with what you type in."),
        ("What does it cost?",
         "Nothing, and there is no paid tier. An optional tip goes through Apple's In-App Purchase and unlocks nothing at all. Every feature is available to everyone, because a safety tool behind a paywall is not a safety tool."),
        ("Does it tell me whether something is safe?",
         "No, and it never will. The risk checker shows what is documented about a combination, including with medication you already take, and stops there. It has no green light. For anything that matters, a clinician or pharmacist is the right place."),
        ("How do I back up, or move to a new phone?",
         "Turn on iCloud backup in Settings to save an encrypted backup to your own iCloud Drive, or export an encrypted backup file yourself. On a new device, restore from iCloud or import that file during setup."),
        ("How do I lock the app, or hide it?",
         "In Settings, under Privacy and lock, turn on Face ID or set a PIN. You can also switch on discreet notifications so lock-screen wording gives nothing away, and ChillMate hides its contents in the App Switcher and while your screen is recorded or mirrored. One tap blanks the screen to a moon."),
        ("How do I delete my data?",
         "Individual entries or everything at once, inside the app. Deleting the app removes its local data, and iCloud data can be removed from the backup controls or from iCloud settings. There is no copy anywhere else to ask about."),
        ("Which countries does it support?",
         "ChillMate works anywhere. Help resources follow the country you pick in setup, with services built in for the Netherlands, Belgium, Germany, the UK, Ireland, France, Spain, the United States and Australia, and international fallbacks everywhere else."),
        ("Which languages does it speak?",
         "English, Dutch, German, French and Spanish, on the phone and on Apple Watch. Set the language inside the app or in iOS Settings, and whichever you changed last is the one that applies."),
    ],
    # Which of the above to lift onto the home page.
    "faq_teaser_indices": [0, 1, 2],

    # ---------- chapter navigation ----------
    "nav_chapters": [("who", "Who it is for"), ("inside", "A look inside"),
                     ("try", "Try it"), ("privacy", "Privacy"), ("specs", "Specs")],
    "scroll_cue": "Scroll",

    # ---------- the statement ----------
    "statement": [("0", "servers"), ("0", "accounts"), ("0", "trackers")],
    "statement_note": "Not a policy. An architecture. Everything below explains how, and links to the line of code that proves it.",

    # ---------- the playable risk checker ----------
    "demo_eyebrow": "Try it",
    "demo_h2": "This is the real risk checker.",
    "demo_p": "Not a screenshot of it. The same 30 combinations, the same wording, the same refusal to call anything safe, running here in your browser. Pick two and see.",
    "demo_pick": "Pick what is in play",
    "demo_none_title": "Nothing documented for this combination",
    "demo_none_body": "That is not the same as safe. It means this table has nothing on file, and this table is not the last word on anything.",
    "demo_empty": "Pick at least two to see what the app would say.",
    "demo_reset": "Clear",
    "demo_note": "Runs entirely in this page. Nothing you tap here is sent anywhere, for the same reason nothing in the app is.",
    "demo_try": "Try GHB and alcohol",

    # ---------- tech specs ----------
    "specs_eyebrow": "The details",
    "specs_h2": "Specifications",
    "specs": [
        ("Requires", "iPhone with iOS 26 or later"),
        ("Apple Watch", "Native app, watchOS 26 or later"),
        ("Price", "Free. No paid tier, no subscription, no ads."),
        ("Account", "None. There is nothing to sign up for."),
        ("Data collected", "None"),
        ("Languages", "English, Nederlands, Deutsch, Français, Español"),
        ("Help services", "10 regions, held on the device, works offline"),
        ("Combinations checked", "30 documented interactions, on-device"),
        ("Written summaries", "On-device, Apple Foundation Models"),
        ("Sync and backup", "Optional, encrypted, your own iCloud"),
        ("Lock", "Face ID, or a PIN derived with 200,000 PBKDF2 rounds"),
        ("Source", "Open, MIT licensed"),
        ("Version", "4.2.1 (build 422)"),
    ],

    # ---------- footnotes ----------
    "footnotes_title": "Every claim on this page, and where to check it",
    "footnotes_intro": "Marketing pages footnote their claims to the small print. This one footnotes them to the source code.",
    "footnotes": [
        "No networking anywhere in the app. Search the repository yourself for URLSession.",
        "Sync goes to your own private CloudKit database, never to a shared one.",
        "The PIN is derived with 200,000 PBKDF2 rounds and held in the Keychain, never stored as typed.",
        "Contents are hidden in the App Switcher and while the screen is captured or mirrored.",
        "Backups are sealed with AES-GCM before they ever reach a file.",
        "Notification wording can be made deliberately vague on the lock screen.",
        "Written summaries use Apple's on-device model. Nothing leaves the phone.",
        "The 30 combinations shown above, exactly as the app carries them.",
        "The help directory for all 10 regions, held on the device.",
    ],
}
