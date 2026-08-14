# -*- coding: utf-8 -*-
"""English copy. The source text every other language is translated from.

Four deliberate decisions live in here.

**Voice.** One person makes ChillMate, so the site says "I" and not "we".
An earlier draft used "we do not run servers", which is a small fiction, and a
small fiction is a strange thing to put in the paragraph asking you to believe
the big claim.

**Discretion.** `home_title` and `home_desc` are deliberately unspecific,
because they are what leaks: into a link preview, a browser history, a shared
screen. The body of the page is specific, because only someone who chose to
open it ever reads that. Being coy in both places meant nobody could tell the
app was for them; being explicit in both meant a shared laptop could out
someone.

**Warmth over wit.** An earlier version of this file was arch: it led chapters
with refusals ("What it will not do", "Do not take my word for it"), told the
reader when the app was *not* for them, and kept congratulating itself for not
being a marketing page. That reads as clever and lands as cold. Every claim
here is the same claim it always was. What changed is that each one leads with
what the reader gets, and the commitments are written as promises rather than
as things the app refuses to do.

**Plain words.** This is the one that matters most, and it is a product
requirement rather than a style preference. People read this page tired,
anxious, coming down, worried about a test result, or in their third or fourth
language. Every one of those states costs comprehension. So: short sentences,
one idea each; contractions, because a person saying this out loud would use
them; everyday words instead of careful ones ("what's known" rather than "what
is documented"); and every piece of jargon either explained in the same
breath or kept off these pages entirely. `tools/readability.py` measures it and
the build refuses to regress it.
"""

S = {
    # ---------- chrome ----------
    "skip": "Skip to content",
    "nav_home": "Home",
    "nav_privacy": "Privacy",
    "nav_support": "Help",
    "nav_github": "GitHub",
    "lang_label": "Language",
    "to_top": "Back to top",
    "made": "made by one person in the Netherlands",
    "copy": "Copy",
    "copied": "Copied",
    "call": "Call",
    "open": "Open",
    "policy_en_note": "The privacy policy is in English only. That way there's one official text, instead of five that could slowly drift apart.",

    # The one disclaimer, worded once and used everywhere.
    "disclaimer": "ChillMate helps you think things through, plan ahead and look after yourself. It doesn't replace a doctor, and it never decides whether something is safe. If someone might be in immediate danger, call your local emergency number.",

    # ---------- help categories ----------
    "cat_emergency": "Emergency services",
    "cat_crisis": "Crisis and suicide support",
    "cat_sexual_health": "Sexual health and STI testing",
    "cat_gp": "Your doctor",
    "cat_drugs": "Drug information and harm reduction",
    "cat_assault": "After sexual assault",
    "cat_lgbtq": "LGBTQ+ support",
    "cat_emergency_d": "Immediate danger, unconsciousness, or someone you can't wake up.",
    "cat_crisis_d": "Free and confidential, if you might hurt yourself or can't stay safe.",
    "cat_sexual_health_d": "Testing, PrEP, PEP, vaccination, and sexual health support.",
    "cat_gp_d": "Medication interactions, sleep, mental health, drug use, and referrals.",
    "cat_drugs_d": "Straight, non-judgemental drug information and safer-use advice.",
    "cat_assault_d": "Support after assault, coercion, or a worry about consent.",
    "cat_lgbtq_d": "Someone to talk to, information, and a referral.",
    "cat_generic_local": "Ask your local health service.",

    # ---------- home: head ----------
    "home_title": "ChillMate · A calm, private place to look after yourself",
    "home_desc": "Look after yourself around your nights out. Track how you felt, see what mixes badly, and let a friend know you got home. Private, and free.",

    # ---------- home: hero ----------
    "h1": "A calm, private place to look after yourself.",
    # Short enough to survive a 1200x630 share card.
    "og_sub": "Free. No account. Everything stays on your iPhone.",
    "og_foot": "Open source · iPhone and Apple Watch",
    "lede": 'Enjoy your night, and wake up glad you looked after yourself. ChillMate keeps track of what you took and how you felt, tells you what mixes badly, and can quietly let a friend know you got home. All private. All free.',
    "cta_get": "Download on the App Store",
    # The sub-nav button sits next to five chapter links and has to stay short.
    "cta_get_short": "Get the app",
    "cta_see": "See how it works",
    "status_note": "Free on the App Store, for iPhone and Apple Watch. No account, and nothing to set up: open it and it works.",

    # ---------- home: who it is for ----------
    "audience_eyebrow": "Who it’s for",
    "audience_h2": "Made for the nights other apps skip",
    "audience_p": 'Chems, hookups, or both. ChillMate takes the night as it was. It won’t ask you to explain it.',
    "audience_points": [
        "A risk checker that already knows the medication you’re on, so the answer fits you.",
        "A check-in timer, so a friend knows you got home without you having to text.",
        "A countdown for PEP, the medicine you take after a possible HIV exposure. It only works if you start fast, and this starts counting straight away.",
        "Test reminders that turn up on time and never say why on your lock screen.",
    ],
    "audience_chill": "The app calls a night a <strong>Chill</strong>. Yours is yours, whatever it turned into.",

    # ---------- home: the walk ----------
    "walk_eyebrow": "A look inside",
    "walk_h2": "Five screens, and what each one does for you.",
    "walk": [
        ('It sorts itself out', 'The thing you need, already at the top', 'Log a night and the home screen rearranges itself around it. Here it has worked out that a PEP conversation might be worth having, so it put that countdown right at the top.'),
        ('Straight answers', 'What’s known, in plain words', 'Pick what’s in play, including your own medication. It tells you what’s on record about that mix, in words you can read at 4am. The choice stays yours.'),
        ('When it’s already hard', 'One calm thing at a time', 'Dim screen, nothing flashing, one step at a time. Breathe, work through the grounding steps, and call someone the moment you want to.'),
        ('Real help, offline', 'People, one tap away', 'Crisis lines, sexual health, drug information and LGBTQ+ support for your country. The list sits on your phone, so it still works with no signal.'),
        ('Your data, on one screen', 'In the app, not in the small print', 'What’s on your phone, what a backup would hold, and what ChillMate never sends. One screen shows you all of it. No legal text to wade through.'),
    ],

    # ---------- home: one night ----------
    "night_eyebrow": "How it fits",
    "night_h2": "One night, in three moments.",
    "night": [
        ('Before you go', 'Decide while it’s easy', 'Run the mix past the risk checker. Set what you are and aren’t up for. Start a check-in timer. Five minutes, while you’re still clear-headed.'),
        ('While you’re out', 'One tap, nothing to type', 'The timer asks if you’re alright. Get help already knows your trusted contact and the right emergency number for where you are. Your watch can answer for you.'),
        ('The morning after', 'Get it down while it’s fresh', 'Sleep, how you feel, what actually helped. A minute now is the bit you’ll be glad of in three months.'),
    ],

    # ---------- home: features ----------
    "features_eyebrow": "What’s in it",
    "features": [
        ("book", "tint-blue", "Private log",
         "Write down a night the way you want to remember it: sleep, how you felt, what helped afterwards."),
        ("chart", "tint-mint", "Your patterns",
         "See what really changes for you over 30 and 90 days, plus a daily score nobody else will ever see."),
        ("life", "tint-purple", "Care tools",
         "Breathing, a pause when a craving hits, a plan for a safer session, and a route home when you want one."),
        ("flask", "tint-pink", "Risk checker",
         "Plain warnings about mixes, including the medication you already take."),
        ("bell", "tint-amber", "Reminders that fit",
         "Check-in timers, a PEP countdown, and test reminders, worded quietly if you like."),
        ("watch", "tint-blue", "On your wrist",
         "Timers, check-ins and an emergency number on Apple Watch, without reaching for your phone."),
    ],

    # ---------- home: is this for you ----------
    "foryou_eyebrow": "Sound familiar",
    "foryou_h2": "If any of these is you, it’s for you.",
    "foryou": [
        "You want last night remembered properly, by you and nobody else.",
        "You’re on PrEP, the daily pill that stops you getting HIV, and you’d rather your lock screen didn’t say so.",
        "You want a way to check in with someone that isn’t a whole conversation.",
        "You’ve wondered, mid-week, whether it’s more often than it used to be.",
        "You want the emergency number for wherever you are, without opening a browser.",
    ],
    "foryou_not": "What you can expect, so nothing surprises you. ChillMate never judges a night, never scores you as a person, and never calls a mix safe. It tells you what’s known and trusts you with the rest.",

    # ---------- home: privacy ----------
    "privacy_eyebrow": "Private by design",
    "privacy_h2": "Your phone, and nowhere else",
    "privacy_intro": 'Nothing you write here goes anywhere. Not to me, not to a company, not to an advertiser. It stays on your phone.',
    "privacy_checks": [
        'Lock it with Face ID or a PIN. Everything on the phone is encrypted, which means it is unreadable to anyone without your key.',
        'Backups are optional and encrypted too, and they go to your own iCloud Drive.',
        'Notifications can be worded so your lock screen gives nothing away.',
    ],
    "privacy_link": "Read the full privacy policy",

    # ---------- home: proof ----------
    "proof_eyebrow": "Check it yourself",
    "proof_h2": "You can check every word of this",
    "proof_p": 'ChillMate is open source. Every line that touches your data is public. So you can check this, instead of having to trust me.',
    "proof_fact": "The app’s own code makes no internet connections at all. No analytics, no crash reporter, no <code>URLSession</code> anywhere. The only things that leave your phone are the ones you tap.",
    "proof_cta_repo": "Read the code",
    "proof_cta_store": "Where your data lives",
    "proof_caption": "Checked against ChillMate 4.2.1 (build 422).",

    "diagram_title": "Where your data goes",
    "diagram_you": "You",
    "diagram_phone": "Your iPhone",
    "diagram_icloud": "Your iCloud",
    "diagram_optional": "optional, encrypted",
    "diagram_server": "My servers",
    "diagram_none": "there are none",

    # ---------- home: the promises ----------
    "refuse_eyebrow": "Promises",
    "refuse_h2": "What you can count on",
    "refuse": [
        ("You get the facts, never a verdict.", "It shows what’s known about a mix and leaves the call to you. It doesn’t know your body, your dose, or your night."),
        ("You’re never scored as a person.", "There’s a number for the day. It stays on your phone, and nothing is ever locked, withheld or judged because of it."),
        ("Every reminder is yours to switch on.", "They all start off. Turn on the ones you want, and word them so a lock screen gives nothing away."),
        ("You’ll never be asked for an account.", "An account needs a server. A server means a copy of you, somewhere you can’t reach. So there’s neither."),
        ("It’s free, and it stays free.", "Every feature, for everyone. The optional tip unlocks nothing, because a safety tool behind a paywall helps the wrong people."),
    ],
    "refuse_p": "Five promises. They’re the reason you can put anything in here without wondering who else is reading.",

    # ---------- home: watch and languages ----------
    "watch_h3": "It works while your phone stays in your pocket",
    "watch_p": "Dose timers, water reminders, quiet check-ins, a breathing exercise, and one tap to your trusted contact or the local emergency number. All on the watch, plus a shortcut you can put on your watch face.",
    "langs_h3": "It works in your language",
    "langs_p": "The app and this site are in English, Dutch, German, French and Spanish. Help services follow the country you set, not the language you read. Those are two different questions.",

    # ---------- home: questions ----------
    "faq_teaser_eyebrow": "Before you ask",
    "faq_teaser_h2": "The three questions everyone asks.",
    "faq_teaser_link": "The rest of the questions, and real help services",

    # ---------- home: the closing ask ----------
    "close_eyebrow": "One last thing",
    "close_h2": "It’s free, and it stays free.",
    "close_p": "Every feature is there from the first launch, with no account to make and nothing to unlock. And if you would rather not install anything, the risk checker above works right now, and every number on the help page works with no signal.",

    # ---------- support page ----------
    "support_title": "ChillMate · Help and support",
    "support_desc": "Crisis lines and health services for your country. Works offline, prints cleanly, and answers the questions people ask most.",
    "support_h1": "Help, and how to reach me",
    "support_lede": "Real services first, because that’s what this page is most useful for. Questions about the app are further down. A person reads every message.",
    "support_urgent": "<strong>In an emergency, don’t wait for the app.</strong> If you or someone else might be in immediate danger, call your local emergency number now.",
    "support_contact_eyebrow": "Get in touch",
    "support_contact_h2": "Contact",
    "support_contact_p": "Email {email}. Replies usually take a few days. It helps a lot if you say which iOS version you’re on and what you were doing when it went wrong.",
    "support_email_btn": "Email me",
    "support_issue_btn": "Report a problem",
    "support_faq_eyebrow": "Common questions",
    "support_help_eyebrow": "Real services",
    "support_help_h2": "Help from people, not an app",
    "support_help_p": "ChillMate isn’t a crisis service. Pick where you are, and these organisations can help you directly. This page prints, and it works with no signal, because that’s exactly when these numbers matter.",
    "support_country_label": "Where are you?",
    "support_emergency_is": "Emergency number here:",
    "support_emergency_local": "your local emergency number",
    "support_print": "Print this page",

    "faq": [
        ("Is my data private?",
         "Yes, and you don’t have to take my word for it. ChillMate keeps everything on your iPhone. There’s no account and no server, and no ads, analytics or trackers. The app is open source, so you can read exactly what it does with what you type in."),
        ("What does it cost?",
         "Nothing, and there’s no paid version. There’s an optional tip, handled by Apple, and it unlocks nothing at all. Everyone gets every feature, because a safety tool behind a paywall helps the wrong people."),
        ("Does it tell me if something is safe?",
         "No, and that’s on purpose. The risk checker shows what’s known about a mix, including with medication you already take, and then leaves the decision to you. For anything that really matters, ask a doctor or a pharmacist."),
        ("How do I back up, or move to a new phone?",
         "Turn on iCloud backup in Settings, and an encrypted backup goes to your own iCloud Drive. You can also export a backup file yourself. On a new phone, restore from iCloud or import that file while you set it up."),
        ("How do I lock the app, or hide it?",
         "Go to Settings, then Privacy and lock, and turn on Face ID or set a PIN. You can also switch on quiet notifications, so your lock screen gives nothing away. ChillMate hides what’s on screen when you swap apps, and while your screen is being recorded or mirrored. One tap blanks it to a moon."),
        ("How do I delete my data?",
         "One entry at a time, or everything at once, inside the app. Deleting the app wipes what’s on your phone. iCloud data goes from the backup settings, or from iCloud itself. There’s no copy anywhere else to ask about."),
        ("Which countries does it work in?",
         "Anywhere. Help services follow the country you pick when you set up. Built in: the Netherlands, Belgium, Germany, the UK, Ireland, France, Spain, the United States and Australia. Everywhere else gets international services."),
        ("Which languages does it speak?",
         "English, Dutch, German, French and Spanish, on the phone and on the watch. Set it in the app or in iOS Settings. Whichever you changed last is the one that counts."),
    ],
    "footnotes": [
        'The app makes no internet connections.',
        'Sync goes to your own private database.',
        'The PIN: 200,000 PBKDF2 rounds, held in the Keychain.',
        'Hidden when you swap apps, and during screen recording.',
        'Backups sealed with AES-GCM.',
        'Lock-screen wording that gives nothing away.',
        'Summaries run on Apple’s on-device model.',
        'The 30 combinations above.',
        'The help directory for 10 regions.',
    ],
    "statement2_big": 'It tells you what’s known, and leaves the choice to you.',
    "statement2_note": 'The risk checker won’t call anything safe. Neither will the summaries. Nowhere in the app will you be told something is fine. You get what’s on record, in plain words, and you decide.',
    "nav_howto": 'How it works',
    "howto_title": 'ChillMate · How it works',
    "howto_desc": 'A night from the first plan to the morning after, the promises the app keeps, everything that’s in it, and the Apple Watch.',
    "howto_h1": 'How it works',
    "howto_lede": 'A night from the first plan to the morning after, the promises the app keeps, and everything that’s actually in it.',
    "howto_back": 'Back to the front page',
    "demo_meds_label": 'Anything you already take',
    "demo_meds_ph": 'Medicine name, optional',
    "demo_timing_label": 'How close together',
    "demo_assess_label": 'Standing checks',
    "demo_share": 'Copy a link to this',
    "demo_shared": 'Link copied',
    "demo_print": 'Print this',
    "demo_meds_hit": 'Matched',
    "demo_meds_none": 'That didn’t match anything on the list.',
    "faq_teaser_indices": [0, 1, 2],

    # ---------- chapter navigation ----------
    "nav_chapters": [("who", "Who it’s for"), ("inside", "A look inside"),
                     ("try", "Try it"), ("privacy", "Privacy"), ("specs", "Specs")],
    "scroll_cue": "Scroll",


    # ---------- the playable risk checker ----------
    "demo_eyebrow": "Try it",
    "demo_h2": "This is the real risk checker.",
    "demo_p": 'Not a picture of it. The same 30 combinations and the same words as the app, running right here. Nothing to install.',
    "demo_pick": "Pick what’s in play",
    "demo_none_title": "Nothing on record for this mix",
    "demo_none_body": "That doesn’t mean it’s safe. It means there’s nothing on file here. This list isn’t the last word, and a pharmacist can tell you more.",
    "demo_empty": 'Pick something, or type a medicine, to see what the app would say.',
    "demo_reset": "Clear",
    "demo_note": "This runs inside the page. Nothing you tap gets sent anywhere, exactly like the app.",
    "combos_h2": "All 30 combinations, in one list",
    "combos_meds_h2": "The medication groups it recognises",
    "demo_try": "Try GHB and alcohol",

    # ---------- tech specs ----------
    "specs_eyebrow": "The details",
    "specs_h2": "Specifications",
    "specs": [
        ("Requires", "iPhone with iOS 26 or later"),
        ("Apple Watch", "Its own app, watchOS 26 or later"),
        # The store badge reads "Free · In-App Purchases", which on its own
        # looks like a paywall. Saying what the purchase actually is here means
        # the two pages agree instead of appearing to contradict each other.
        ("Price", "Free. No paid version, no subscription, no ads. One optional tip, which unlocks nothing."),
        ("Account", "None. There’s nothing to sign up for."),
        ("Data collected", "None"),
        ("Languages", "English, Nederlands, Deutsch, Français, Español"),
        ("Help services", "10 regions, kept on the phone, works offline"),
        ("Combinations checked", "30 known interactions, on the phone"),
        ("Written summaries", "On the phone, Apple Foundation Models"),
        ("Sync and backup", "Optional, encrypted, your own iCloud"),
        ("Lock", "Face ID, or a PIN protected by 200,000 PBKDF2 rounds"),
        ("Source", "Open, MIT licensed"),
        ("Version", "4.2.1 (build 422)"),
    ],

    # ---------- footnotes ----------
    "footnotes_title": "Every claim on this page, and where to check it",
    "footnotes_intro": "Every claim on this page links to the code behind it. You can check any of them in about a minute.",
}
