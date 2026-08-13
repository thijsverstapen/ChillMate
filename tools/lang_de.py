# -*- coding: utf-8 -*-
"""German copy. Translated from lang_en.

**du, not Sie.** The app says "du", and a safety tool that switches to a formal
register the moment you open its website sounds like a different product than
the one you install. So the site says "du" too, all the way through.

**Plain German.** This is the harder half of the job, and it is a product
requirement rather than a matter of taste. People read this page tired,
anxious, coming down, or in their third language, and German punishes all three
harder than English does. So: no Schachtelsätze, one idea per sentence, the
verb near the front. Verbs instead of nominalisations, "wenn du etwas einträgst"
and not "bei der Eintragung". Two short words instead of a three-noun compound.
Loanwords only where the scene actually uses them (Chems, Hookups, Harm
Reduction, Check-in) and never as decoration. Every sentence here was read back
out loud, and the ones nobody would say that way were rewritten.
"""

S = {
    # ---------- chrome ----------
    "skip": "Zum Inhalt springen",
    "nav_home": "Start",
    "nav_privacy": "Datenschutz",
    "nav_support": "Hilfe",
    "nav_github": "GitHub",
    "lang_label": "Sprache",
    "to_top": "Nach oben",
    "made": "von einer Person in den Niederlanden gemacht",
    "copy": "Kopieren",
    "copied": "Kopiert",
    "call": "Anrufen:",
    "open": "Öffnen:",
    "policy_en_note": "Die Datenschutzerklärung gibt es nur auf Englisch. So gibt es einen offiziellen Text und nicht fünf, die langsam auseinanderdriften.",

    # The one disclaimer, worded once and used everywhere.
    "disclaimer": "ChillMate hilft dir, nachzudenken, vorauszuplanen und auf dich zu achten. Es ersetzt keinen Arztbesuch, und es entscheidet nie, ob etwas sicher ist. Wenn jemand in akuter Gefahr sein könnte, ruf den örtlichen Notruf.",

    # ---------- help categories ----------
    "cat_emergency": "Notruf",
    "cat_crisis": "Krisen- und Suizidhilfe",
    "cat_sexual_health": "Sexuelle Gesundheit und STI-Tests",
    "cat_gp": "Deine Ärztin oder dein Arzt",
    "cat_drugs": "Drogeninfo und Harm Reduction",
    "cat_assault": "Nach sexualisierter Gewalt",
    "cat_lgbtq": "LGBTQ+ Unterstützung",
    "cat_emergency_d": "Akute Gefahr, Bewusstlosigkeit oder jemand, der nicht aufwacht.",
    "cat_crisis_d": "Kostenlos und vertraulich, wenn du dir etwas antun könntest oder dich nicht sicher fühlst.",
    "cat_sexual_health_d": "Tests, PrEP, PEP, Impfungen und Hilfe rund um sexuelle Gesundheit.",
    "cat_gp_d": "Wechselwirkungen, Schlaf, Psyche, Substanzgebrauch und Überweisungen.",
    "cat_drugs_d": "Klare Drogeninfos ohne Bewertung, dazu Tipps für sichereren Gebrauch.",
    "cat_assault_d": "Unterstützung nach Gewalt, Nötigung oder Zweifeln an Einvernehmlichkeit.",
    "cat_lgbtq_d": "Ein offenes Ohr, Information und Weitervermittlung.",
    "cat_generic_local": "Frag bei deiner örtlichen Gesundheitsstelle nach.",

    # ---------- home: head ----------
    "home_title": "ChillMate · Ein ruhiger, privater Ort, um auf dich zu achten",
    "home_desc": "Achte auf dich, rund um deine Nächte. Halt fest, wie es dir ging, sieh, was sich schlecht verträgt, und lass jemanden wissen, dass du zu Hause bist. Privat und kostenlos.",

    # ---------- home: hero ----------
    "h1": "Ein ruhiger, privater Ort, um auf dich zu achten.",
    # Short enough to survive a 1200x630 share card.
    "og_sub": "Kostenlos. Kein Konto. Alles bleibt auf deinem iPhone.",
    "og_foot": "Open Source · iPhone und Apple Watch",
    "lede": 'Genieß deine Nacht und wach mit dem Gefühl auf, gut auf dich geachtet zu haben. ChillMate hält fest, was du genommen hast und wie es dir ging, sagt dir, was sich schlecht verträgt, und lässt jemanden leise wissen, dass du zu Hause bist. Alles privat. Alles kostenlos.',
    "cta_notify": "Sag mir Bescheid, wenn es da ist",
    "cta_see": "So funktioniert es",
    "status_note": "Im App Store ist es noch nicht. Lass deine Mailadresse da, dann hörst du genau einmal von mir, an dem Tag, an dem es so weit ist. Sonst nie.",
    "notify_subject": "Sag mir Bescheid, wenn ChillMate da ist",
    "notify_body": "Du musst nichts schreiben. Ich antworte einmal, am Tag des Starts, und lösche deine Adresse danach.",

    # ---------- home: who it is for ----------
    "audience_eyebrow": "Für wen es ist",
    "audience_h2": "Für die Nächte, die andere Apps auslassen",
    "audience_p": 'Chems, Hookups, oder beides. ChillMate nimmt die Nacht so, wie sie war. Erklären musst du nichts.',
    "audience_points": [
        "Ein Risikocheck, der deine Medikamente schon kennt. So passt die Antwort zu dir.",
        "Ein Check-in-Timer, damit jemand weiß, dass du zu Hause bist, ohne dass du schreiben musst.",
        "Ein Countdown für PEP, die Medikamente nach einem möglichen HIV-Kontakt. Sie wirken nur, wenn du schnell anfängst. Deshalb läuft die Uhr hier sofort.",
        "Test-Erinnerungen, die pünktlich kommen und auf dem Sperrbildschirm nie sagen, worum es geht.",
    ],
    "audience_chill": "Die App nennt eine Nacht einen <strong>Chill</strong>. Deiner gehört dir, was auch daraus wurde.",

    # ---------- home: the walk ----------
    "walk_eyebrow": "Ein Blick hinein",
    "walk_h2": "Fünf Screens, und was jeder für dich tut.",
    "walk": [
        ('Es sortiert sich selbst', 'Was du brauchst, steht schon oben', 'Trag eine Nacht ein, und der Startbildschirm ordnet sich neu darum herum. Hier hat er gemerkt: Ein Gespräch über PEP könnte sich lohnen. Also steht der Countdown ganz oben.'),
        ('Klare Antworten', 'Was bekannt ist, in einfachen Worten', 'Wähl aus, was im Spiel ist, deine eigenen Medikamente eingeschlossen. Es zeigt dir, was zu dieser Mischung bekannt ist, in Worten, die du um vier Uhr nachts lesen kannst. Die Entscheidung bleibt bei dir.'),
        ('Wenn es schon schwer ist', 'Ruhig, eins nach dem anderen', 'Gedimmter Bildschirm, nichts blinkt, ein Schritt nach dem anderen. Atme, geh die Grounding-Schritte durch, und ruf jemanden an, sobald du willst.'),
        ('Echte Hilfe, offline', 'Menschen, nur einen Fingertipp entfernt', 'Krisentelefone, sexuelle Gesundheit, Drogeninfos und LGBTQ+ Hilfe für dein Land. Die Liste liegt auf deinem Handy, sie funktioniert also auch ohne Empfang.'),
        ('Deine Daten, auf einem Screen', 'In der App, nicht im Kleingedruckten', 'Was auf deinem Handy liegt, was in einem Backup wäre, und was ChillMate nie verschickt. Ein Screen zeigt dir alles. Kein Juristendeutsch zum Durchkämpfen.'),
    ],

    # ---------- home: one night ----------
    "night_eyebrow": "Wie es passt",
    "night_h2": "Eine Nacht, in drei Momenten.",
    "night": [
        ('Bevor du losgehst', 'Entscheide, solange es leicht fällt', 'Lass die Mischung vom Risikocheck prüfen. Halt fest, worauf du Lust hast und worauf nicht. Starte einen Check-in-Timer. Fünf Minuten, solange du klar im Kopf bist.'),
        ('Wenn du unterwegs bist', 'Einmal tippen, nichts schreiben', 'Der Timer fragt, ob alles gut ist. Der Button Hilfe holen kennt deine Vertrauensperson schon und weiß, welche Notrufnummer für deinen Ort gilt. Deine Uhr kann für dich antworten.'),
        ('Der Morgen danach', 'Schreib es auf, solange es frisch ist', 'Schlaf, wie es dir geht, was wirklich geholfen hat. Eine Minute jetzt, und in drei Monaten bist du froh darüber.'),
    ],

    # ---------- home: features ----------
    "features_eyebrow": "Was drin ist",
    "features": [
        ("book", "tint-blue", "Privates Log",
         "Halte eine Nacht so fest, wie du sie erinnern willst: Schlaf, wie es dir ging, was danach geholfen hat."),
        ("chart", "tint-mint", "Deine Muster",
         "Sieh über 30 und 90 Tage, was sich bei dir wirklich ändert. Dazu ein Tageswert, den sonst nie jemand sieht."),
        ("life", "tint-purple", "Selbstfürsorge",
         "Atmen, eine Pause bei Verlangen, ein Plan für eine sicherere Session, und ein Weg nach Hause, wenn du ihn willst."),
        ("flask", "tint-pink", "Risikocheck",
         "Klare Hinweise zu Mischungen, auch mit den Medikamenten, die du schon nimmst."),
        ("bell", "tint-amber", "Erinnerungen, die passen",
         "Check-in-Timer, ein PEP-Countdown und Test-Erinnerungen, auf Wunsch diskret formuliert."),
        ("watch", "tint-blue", "An deinem Handgelenk",
         "Timer, Check-ins und eine Notrufnummer auf der Apple Watch, ohne zum Handy zu greifen."),
    ],

    # ---------- home: is this for you ----------
    "foryou_eyebrow": "Kennst du das",
    "foryou_h2": "Wenn eins davon passt, ist es für dich.",
    "foryou": [
        "Du willst dich richtig an letzte Nacht erinnern. Du, und sonst niemand.",
        "Du nimmst PrEP, die tägliche Tablette, die dich vor HIV schützt. Auf deinem Sperrbildschirm soll das lieber nicht stehen.",
        "Du willst dich bei jemandem melden können, ohne dass daraus ein ganzes Gespräch wird.",
        "Du hast dich mitten in der Woche schon gefragt, ob es öfter ist als früher.",
        "Du willst die Notrufnummer für den Ort, an dem du gerade bist, ohne einen Browser zu öffnen.",
    ],
    "foryou_not": "Was dich erwartet, damit dich nichts überrascht. ChillMate bewertet keine Nacht, benotet dich nicht als Person und nennt keine Mischung sicher. Es sagt dir, was bekannt ist. Den Rest traut es dir zu.",

    # ---------- home: privacy ----------
    "privacy_eyebrow": "Von Grund auf privat",
    "privacy_h2": "Dein Handy, und sonst nirgends",
    "privacy_intro": 'Nichts von dem, was du hier schreibst, geht irgendwohin. Nicht zu mir, nicht zu einer Firma, nicht zu einem Werbenetz. Es bleibt auf deinem Handy.',
    "privacy_checks": [
        'Sperr die App mit Face ID oder einer PIN. Alles auf dem Handy ist verschlüsselt, niemand sonst kann es lesen.',
        'Backups sind freiwillig und ebenfalls verschlüsselt. Sie gehen in dein eigenes iCloud Drive.',
        'Mitteilungen kannst du so formulieren, dass dein Sperrbildschirm nichts verrät.',
    ],
    "privacy_link": "Die ganze Datenschutzerklärung lesen",

    # ---------- home: proof ----------
    "proof_eyebrow": "Prüf es selbst",
    "proof_h2": "Du kannst hier jedes Wort nachprüfen",
    "proof_p": 'ChillMate ist Open Source. Jede Zeile, die mit deinen Daten zu tun hat, ist öffentlich. Du kannst das also nachsehen, statt mir glauben zu müssen.',
    "proof_fact": "Der Code der App baut überhaupt keine Internetverbindung auf. Kein Analytics, kein Crash-Reporter, nirgends eine <code>URLSession</code>. Dein Handy verlässt nur, was du selbst antippst.",
    "proof_cta_repo": "Den Code lesen",
    "proof_cta_store": "Wo deine Daten liegen",
    "proof_caption": "Geprüft an ChillMate 4.2.1 (Build 422).",

    "diagram_title": "Wohin deine Daten gehen",
    "diagram_you": "Du",
    "diagram_phone": "Dein iPhone",
    "diagram_icloud": "Deine iCloud",
    "diagram_optional": "optional, verschlüsselt",
    "diagram_server": "Meine Server",
    "diagram_none": "gibt es nicht",

    # ---------- home: the promises ----------
    "refuse_eyebrow": "Versprechen",
    "refuse_h2": "Worauf du dich verlassen kannst",
    "refuse": [
        ("Du bekommst Fakten, nie ein Urteil.", "Es zeigt, was zu einer Mischung bekannt ist, und lässt dir die Entscheidung. Es kennt deinen Körper nicht, deine Dosis nicht und deine Nacht nicht."),
        ("Du wirst nie als Person benotet.", "Es gibt eine Zahl für den Tag. Sie bleibt auf deinem Handy. Nichts wird deswegen gesperrt, vorenthalten oder bewertet."),
        ("Jede Erinnerung schaltest du selbst ein.", "Am Anfang ist alles aus. Schalt an, was du willst, und formulier es so, dass ein Sperrbildschirm nichts verrät."),
        ("Nach einem Konto wirst du nie gefragt.", "Ein Konto braucht einen Server. Ein Server heißt: eine Kopie von dir, an einem Ort, an den du nicht kommst. Also gibt es keines von beidem."),
        ("Es ist kostenlos und bleibt kostenlos.", "Jede Funktion, für alle. Das freiwillige Trinkgeld schaltet nichts frei, denn ein Sicherheitswerkzeug hinter einer Bezahlschranke hilft den Falschen."),
    ],
    "refuse_p": "Fünf Versprechen. Deshalb kannst du hier alles hineinschreiben, ohne dich zu fragen, wer mitliest.",

    # ---------- home: watch and languages ----------
    "watch_h3": "Es funktioniert, während dein Handy in der Tasche bleibt",
    "watch_p": "Dosis-Timer, Erinnerungen ans Trinken, stille Check-ins und eine Atemübung. Einmal tippen, und du erreichst deine Vertrauensperson oder den örtlichen Notruf. Alles auf der Uhr, dazu eine Verknüpfung für dein Zifferblatt.",
    "watch_quote": "Wenn sich etwas falsch anfühlt, hol dir Hilfe. Du bist nicht in Schwierigkeiten.",
    "watch_quote_note": "Das ist der komplette Sicherheits-Screen der Uhr, Wortlaut inklusive.",
    "langs_h3": "Es funktioniert in deiner Sprache",
    "langs_p": "Die App und diese Seite gibt es auf Englisch, Niederländisch, Deutsch, Französisch und Spanisch. Die Hilfsangebote richten sich nach dem Land, das du einstellst, nicht nach deiner Lesesprache. Das sind zwei verschiedene Fragen.",

    # ---------- home: questions ----------
    "faq_teaser_eyebrow": "Bevor du fragst",
    "faq_teaser_h2": "Die drei Fragen, die alle stellen.",
    "faq_teaser_link": "Die übrigen Fragen, und echte Anlaufstellen",

    # ---------- home: the closing ask ----------
    "close_eyebrow": "Noch eine Sache",
    "close_h2": "Es ist kostenlos und bleibt kostenlos.",
    "close_p": "Schick eine leere Mail. Du hörst genau einmal von mir, an dem Tag, an dem ChillMate im App Store landet. Danach lösche ich deine Adresse. Bis dahin läuft der Risikocheck hier oben schon jetzt, und jede Nummer auf der Hilfeseite funktioniert ohne Empfang.",

    # ---------- support page ----------
    "support_title": "ChillMate · Hilfe und Unterstützung",
    "support_desc": "Krisentelefone und Gesundheitsangebote für dein Land. Funktioniert ohne Empfang, passt auf eine gedruckte Seite, und beantwortet die häufigsten Fragen.",
    "support_h1": "Hilfe, und wie du mich erreichst",
    "support_lede": "Zuerst echte Anlaufstellen, denn dafür ist diese Seite am nützlichsten. Fragen zur App stehen weiter unten. Jede Nachricht liest ein Mensch.",
    "support_urgent": "<strong>Warte im Notfall nicht auf die App.</strong> Wenn du oder jemand anderes in akuter Gefahr sein könnte, ruf jetzt den örtlichen Notruf.",
    "support_contact_eyebrow": "Melde dich",
    "support_contact_h2": "Kontakt",
    "support_contact_p": "Schreib an {email}. Eine Antwort dauert meist ein paar Tage. Es hilft sehr, wenn du dazuschreibst, welche iOS-Version du hast und was du gerade gemacht hast.",
    "support_email_btn": "Schreib mir",
    "support_issue_btn": "Problem melden",
    "support_faq_eyebrow": "Häufige Fragen",
    "support_help_eyebrow": "Echte Anlaufstellen",
    "support_help_h2": "Hilfe von Menschen, nicht von einer App",
    "support_help_p": "ChillMate ist kein Krisendienst. Wähl aus, wo du bist, dann helfen dir diese Stellen direkt. Diese Seite lässt sich drucken und funktioniert ohne Empfang. Genau dann zählen diese Nummern.",
    "support_country_label": "Wo bist du?",
    "support_emergency_is": "Notruf hier:",
    "support_emergency_local": "dein örtlicher Notruf",
    "support_print": "Diese Seite drucken",

    "faq": [
        ("Sind meine Daten privat?",
         "Ja, und du musst mir nicht einfach glauben. ChillMate lässt alles auf deinem iPhone. Es gibt kein Konto und keinen Server, keine Werbung, keine Analyse, keine Tracker. Die App ist Open Source, du kannst also genau nachlesen, was mit deinen Eingaben passiert."),
        ("Was kostet es?",
         "Nichts, und es gibt keine bezahlte Version. Ein freiwilliges Trinkgeld läuft über Apple und schaltet gar nichts frei. Alle bekommen jede Funktion, denn ein Sicherheitswerkzeug hinter einer Bezahlschranke hilft den Falschen."),
        ("Sagt es mir, ob etwas sicher ist?",
         "Nein, und das ist Absicht. Der Risikocheck zeigt, was zu einer Mischung bekannt ist, auch mit Medikamenten, die du schon nimmst. Danach liegt die Entscheidung bei dir. Wenn es wirklich darauf ankommt, frag in einer Arztpraxis oder Apotheke nach."),
        ("Wie mache ich ein Backup, oder wechsle auf ein neues Handy?",
         "Schalt in den Einstellungen das iCloud-Backup ein, dann geht ein verschlüsseltes Backup in deine eigene iCloud Drive. Du kannst auch selbst eine Backup-Datei exportieren. Auf einem neuen Handy stellst du beim Einrichten aus iCloud wieder her oder importierst diese Datei."),
        ("Wie sperre oder verstecke ich die App?",
         "Geh in die Einstellungen, dann Datenschutz und Sperre, und schalt Face ID ein oder setz eine PIN. Du kannst auch diskrete Mitteilungen einschalten, damit dein Sperrbildschirm nichts verrät. ChillMate verbirgt den Inhalt, sobald du die App wechselst, und während dein Bildschirm aufgenommen oder gespiegelt wird. Einmal tippen, und es bleibt nur ein Mond."),
        ("Wie lösche ich meine Daten?",
         "Einzeln oder alles auf einmal, direkt in der App. Die App zu löschen entfernt alles, was auf deinem Handy liegt. iCloud-Daten löschst du in den Backup-Einstellungen oder in iCloud selbst. Anderswo gibt es keine Kopie, nach der du fragen müsstest."),
        ("In welchen Ländern funktioniert es?",
         "Überall. Die Hilfsangebote richten sich nach dem Land, das du beim Einrichten wählst. Eingebaut sind: die Niederlande, Belgien, Deutschland, das Vereinigte Königreich, Irland, Frankreich, Spanien, die USA und Australien. Überall sonst bekommst du internationale Angebote."),
        ("Welche Sprachen spricht es?",
         "Englisch, Niederländisch, Deutsch, Französisch und Spanisch, auf dem Handy und auf der Uhr. Stell es in der App ein oder in den iOS-Einstellungen. Es gilt, was du zuletzt geändert hast."),
    ],
    "footnotes": [
        'Die App baut keine Internetverbindung auf.',
        'Sync geht in deine eigene private Datenbank.',
        'Die PIN: 200.000 PBKDF2-Runden, im Schlüsselbund.',
        'Verborgen, wenn du die App wechselst, und bei Bildschirmaufnahme.',
        'Backups mit AES-GCM versiegelt.',
        'Mitteilungstexte, die nichts verraten.',
        'Zusammenfassungen laufen auf Apples Modell im Gerät.',
        'Die 30 Kombinationen oben.',
        'Das Hilfeverzeichnis für 10 Regionen.',
    ],
    "statement2_big": 'Es sagt dir, was bekannt ist. Die Wahl bleibt bei dir.',
    "statement2_note": 'Der Risikocheck nennt nichts sicher. Die Zusammenfassungen auch nicht. Nirgends in der App wird dir gesagt, dass etwas in Ordnung ist. Du bekommst, was bekannt ist, in klaren Worten, und entscheidest selbst.',
    "nav_howto": 'So funktioniert es',
    "howto_title": 'ChillMate · So funktioniert es',
    "howto_desc": 'Eine Nacht vom ersten Plan bis zum Morgen danach. Dazu die Versprechen der App, alles, was drin ist, und die Apple Watch.',
    "howto_h1": 'So funktioniert es',
    "howto_lede": 'Eine Nacht vom ersten Plan bis zum Morgen danach, die Versprechen der App, und alles, was wirklich drin ist.',
    "howto_back": 'Zurück zur Startseite',
    "demo_meds_label": 'Was du ohnehin nimmst',
    "demo_meds_ph": 'Name des Medikaments, optional',
    "demo_timing_label": 'Wie dicht beieinander',
    "demo_assess_label": 'Ständige Checks',
    "demo_share": 'Link dazu kopieren',
    "demo_shared": 'Link kopiert',
    "demo_print": 'Das drucken',
    "demo_meds_hit": 'Erkannt',
    "demo_meds_none": 'Das steht nicht auf der Liste.',
    "faq_teaser_indices": [0, 1, 2],

    # ---------- chapter navigation ----------
    "nav_chapters": [("who", "Für wen"), ("inside", "Blick hinein"),
                     ("try", "Ausprobieren"), ("privacy", "Datenschutz"), ("specs", "Technik")],
    "scroll_cue": "Scrollen",


    # ---------- the playable risk checker ----------
    "demo_eyebrow": "Ausprobieren",
    "demo_h2": "Das ist der echte Risikocheck.",
    "demo_p": 'Kein Bild davon. Dieselben 30 Kombinationen und derselbe Wortlaut wie in der App, hier direkt auf der Seite. Du musst nichts installieren.',
    "demo_pick": "Wähl, was im Spiel ist",
    "demo_none_title": "Zu dieser Mischung ist nichts bekannt",
    "demo_none_body": "Das heißt nicht, dass sie sicher ist. Es heißt nur: Hier steht nichts dazu. Diese Liste ist nicht das letzte Wort, und eine Apotheke kann dir mehr sagen.",
    "demo_empty": 'Wähl etwas aus oder tipp ein Medikament ein, dann siehst du, was die App sagen würde.',
    "demo_reset": "Zurücksetzen",
    "demo_note": "Das läuft in dieser Seite. Nichts von dem, was du antippst, geht irgendwohin, genau wie in der App.",
    "demo_try": "Beispiel: GHB und Alkohol",

    # ---------- tech specs ----------
    "specs_eyebrow": "Die Details",
    "specs_h2": "Technische Daten",
    "specs": [
        ("Voraussetzung", "iPhone mit iOS 26 oder neuer"),
        ("Apple Watch", "Eigene App, watchOS 26 oder neuer"),
        ("Preis", "Kostenlos. Keine bezahlte Version, kein Abo, keine Werbung."),
        ("Konto", "Keins. Es gibt nichts zu registrieren."),
        ("Erhobene Daten", "Keine"),
        ("Sprachen", "English, Nederlands, Deutsch, Français, Español"),
        ("Hilfsangebote", "10 Regionen, auf dem Handy, funktioniert offline"),
        ("Geprüfte Kombinationen", "30 bekannte Wechselwirkungen, auf dem Handy"),
        ("Geschriebene Zusammenfassungen", "Auf dem Handy, Apple Foundation Models"),
        ("Sync und Backup", "Optional, verschlüsselt, deine eigene iCloud"),
        ("Sperre", "Face ID, oder eine PIN mit 200.000 PBKDF2-Runden"),
        ("Quellcode", "Offen, MIT-Lizenz"),
        ("Version", "4.2.1 (Build 422)"),
    ],

    # ---------- footnotes ----------
    "footnotes_title": "Jede Behauptung auf dieser Seite, und wo du sie prüfst",
    "footnotes_intro": "Jede Behauptung auf dieser Seite verlinkt auf den Code dahinter. Du kannst jede einzelne in etwa einer Minute nachprüfen.",
}
