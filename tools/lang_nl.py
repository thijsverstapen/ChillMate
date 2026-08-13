# -*- coding: utf-8 -*-
"""Dutch copy. Translated from lang_en, in the tone the app itself uses.

Two decisions shape this file.

**Register.** It says "je", never "u". The app does, and a safety tool that
addresses you formally at four in the morning has picked the wrong register.
Dutch is the primary audience, so this file gets the closest reading of all of
them. It has to read like it was written in Dutch, not translated into it,
which means headlines are rewritten rather than carried across word for word.

**Plain words.** The English source was made deliberately plain, and plainness
is the part of a text that a literal translation loses first. It does not
arrive in Dutch the way it arrives in English. Written Dutch stays written, so
none of the spoken elisions ("d’r is", "da’s") are here. What costs a Dutch
reader is the long subordinate clause: the sentence that opens with "waarbij",
stacks "hetgeen" on "waarvan", and parks its verb at the very end. Those are
broken into short main clauses with the verb early. Someone reading this is
tired, anxious, worried about a test result, or halfway into a language they
learned late. Every one of those states costs comprehension, and the page that
loses them is the page that was supposed to help.
"""

S = {
    # ---------- chrome ----------
    "skip": "Naar de inhoud",
    "nav_home": "Home",
    "nav_privacy": "Privacy",
    "nav_support": "Hulp",
    "nav_github": "GitHub",
    "lang_label": "Taal",
    "to_top": "Terug naar boven",
    "made": "gemaakt door één persoon in Nederland",
    "copy": "Kopiëren",
    "copied": "Gekopieerd",
    "call": "Bel",
    "open": "Open",
    "policy_en_note": "Er is een Nederlandse vertaling van het privacybeleid. De Engelse tekst is de officiële versie: als de twee ooit verschillen, geldt het Engels.",

    # The one disclaimer, worded once and used everywhere.
    "disclaimer": "ChillMate helpt je nadenken, vooruit plannen en goed voor jezelf zorgen. Hij vervangt geen arts, en hij bepaalt nooit of iets veilig is. Kan iemand in direct gevaar zijn? Bel dan je lokale alarmnummer.",

    # ---------- help categories ----------
    "cat_emergency": "Hulpdiensten",
    "cat_crisis": "Crisis en zelfmoordpreventie",
    "cat_sexual_health": "Seksuele gezondheid en soa-tests",
    "cat_gp": "Je huisarts",
    "cat_drugs": "Drugsinformatie en harm reduction",
    "cat_assault": "Na seksueel geweld",
    "cat_lgbtq": "LHBTIQ+ steun",
    "cat_emergency_d": "Direct gevaar, bewusteloosheid, of iemand die niet wakker te krijgen is.",
    "cat_crisis_d": "Gratis en vertrouwelijk, als je jezelf iets zou kunnen aandoen of als je je niet veilig voelt.",
    "cat_sexual_health_d": "Soa-tests, PrEP, PEP, vaccinatie en hulp bij seksuele gezondheid.",
    "cat_gp_d": "Wisselwerking van medicijnen, slaap, mentale gezondheid, middelengebruik en doorverwijzing.",
    "cat_drugs_d": "Eerlijke drugsinformatie zonder oordeel, en advies om het veiliger te doen.",
    "cat_assault_d": "Steun na geweld, dwang of twijfel over toestemming.",
    "cat_lgbtq_d": "Een luisterend oor, informatie en doorverwijzing.",
    "cat_generic_local": "Vraag het bij je lokale zorginstelling.",

    # ---------- home: head ----------
    "home_title": "ChillMate · Een rustige, privéplek om voor jezelf te zorgen",
    "home_desc": "Zorg goed voor jezelf rond je avonden uit. Leg vast hoe je je voelde, zie wat slecht samengaat, en laat een vriend weten dat je thuis bent. Privé, en gratis.",

    # ---------- home: hero ----------
    "h1": "Een rustige, privéplek om voor jezelf te zorgen.",
    # Short enough to survive a 1200x630 share card.
    "og_sub": "Gratis. Geen account. Alles blijft op je iPhone.",
    "og_foot": "Open source · iPhone en Apple Watch",
    "lede": "Geniet van je nacht, en word wakker met het gevoel dat je goed voor jezelf gezorgd hebt. ChillMate houdt bij wat je nam en hoe je je voelde, vertelt wat slecht samengaat, en laat een vriend rustig weten dat je thuis bent. Allemaal privé. Allemaal gratis.",
    "cta_notify": "Laat het me weten als hij er is",
    "cta_see": "Kijk hoe het werkt",
    "status_note": "Hij staat nog niet in de App Store. Laat je mailadres achter, dan hoor je één keer van me, op de dag dat hij er is. Verder nooit iets.",
    "notify_subject": "Laat het me weten als ChillMate er is",
    "notify_body": "Je hoeft niets te schrijven. Ik mail je één keer, op de dag van de lancering. Daarna verwijder ik je adres.",

    # ---------- home: who it is for ----------
    "audience_eyebrow": "Voor wie het is",
    "audience_h2": "Gemaakt voor de nachten die andere apps overslaan",
    "audience_p": "Chems, hookups, of allebei. ChillMate neemt je nacht zoals hij was. Uitleggen hoeft niet.",
    "audience_points": [
        "Een risicocheck die weet welke medicijnen je slikt, dus het antwoord past bij jou.",
        "Een check-intimer, zodat een vriend weet dat je thuis bent. Appen hoeft niet.",
        "Een aftelklok voor PEP, de medicijnen die je slikt na mogelijk contact met hiv. Die werken alleen als je snel begint, dus het aftellen start meteen.",
        "Testherinneringen die op tijd komen en op je vergrendelscherm nooit zeggen waarvoor.",
    ],
    "audience_chill": "De app noemt een nacht een <strong>Chill</strong>. De jouwe is van jou, wat het ook werd.",

    # ---------- home: the walk ----------
    "walk_eyebrow": "Een kijkje binnen",
    "walk_h2": "Vijf schermen, en wat je aan elk hebt.",
    "walk": [
        ("Hij schikt zichzelf", "Wat je nodig hebt, staat al bovenaan", "Leg een nacht vast en het beginscherm schikt zich eromheen. Hier ziet de app dat een gesprek over PEP zinvol kan zijn. Die aftelklok staat dus meteen bovenaan."),
        ("Eerlijke antwoorden", "Wat bekend is, in gewone taal", "Kies wat er speelt, ook je eigen medicijnen. Je krijgt te horen wat er over die mix bekend is, in woorden die je om vier uur ’s nachts nog snapt. De keuze blijft van jou."),
        ("Als het al zwaar is", "Eén rustig ding tegelijk", "Gedimd scherm, niets dat knippert, stap voor stap. Adem, loop de groundingstappen door, en bel iemand zodra je dat wilt."),
        ("Echte hulp, ook offline", "Mensen, één tik verderop", "Crisislijnen, seksuele gezondheid, drugsinformatie en LHBTIQ+ steun voor jouw land. De lijst staat op je telefoon, dus hij werkt ook zonder bereik."),
        ("Je gegevens, op één scherm", "In de app, niet in de kleine lettertjes", "Wat er op je telefoon staat, wat er in een back-up zou zitten, en wat ChillMate nooit verstuurt. Eén scherm laat het allemaal zien. Geen juridische tekst om door te ploegen."),
    ],

    # ---------- home: one night ----------
    "night_eyebrow": "Hoe het past",
    "night_h2": "Eén nacht, in drie momenten.",
    "night": [
        ("Voordat je gaat", "Beslis nu het nog makkelijk is", "Leg de mix langs de risicocheck. Zet vast waar je wel en geen zin in hebt. Start een check-intimer. Vijf minuten, nu je nog helder bent."),
        ("Als je op stap bent", "Eén tik, niets typen", "De timer vraagt of het goed gaat. De knop Hulp zoeken kent je vertrouwenscontact al, en het alarmnummer van waar je bent. Je horloge kan voor je antwoorden."),
        ("De ochtend erna", "Leg het vast nu het vers is", "Slaap, hoe je je voelt, wat echt hielp. Eén minuut nu, daar ben je over drie maanden blij mee."),
    ],

    # ---------- home: features ----------
    "features_eyebrow": "Wat erin zit",
    "features": [
        ("book", "tint-blue", "Privélogboek",
         "Schrijf een nacht op zoals jij hem wilt onthouden: slaap, hoe je je voelde, wat daarna hielp."),
        ("chart", "tint-mint", "Jouw patronen",
         "Zie wat er bij jou echt verandert over 30 en 90 dagen, plus een dagscore die niemand anders ooit ziet."),
        ("life", "tint-purple", "Zorgtools",
         "Ademhaling, een pauze als de drang komt, een plan voor een veiligere sessie, en een route naar huis als je die wilt."),
        ("flask", "tint-pink", "Risicocheck",
         "Duidelijke waarschuwingen over mixen, ook met de medicijnen die je al slikt."),
        ("bell", "tint-amber", "Herinneringen die passen",
         "Check-intimers, een PEP-aftelklok en testherinneringen, discreet geformuleerd als je dat wilt."),
        ("watch", "tint-blue", "Op je pols",
         "Timers, check-ins en een alarmnummer op Apple Watch, zonder je telefoon te pakken."),
    ],

    # ---------- home: is this for you ----------
    "foryou_eyebrow": "Klinkt dit bekend",
    "foryou_h2": "Herken je hier iets? Dan is hij voor jou.",
    "foryou": [
        "Je wilt gisternacht goed onthouden, door jou en door niemand anders.",
        "Je slikt PrEP, de dagelijkse pil die hiv voorkomt, en je hebt liever niet dat dat op je vergrendelscherm staat.",
        "Je wilt bij iemand kunnen inchecken zonder dat het een heel gesprek wordt.",
        "Je hebt je doordeweeks weleens afgevraagd of het vaker is dan vroeger.",
        "Je wilt het alarmnummer van waar je bent, zonder een browser te openen.",
    ],
    "foryou_not": "Wat je kunt verwachten, zodat niets je verrast. ChillMate oordeelt nooit over een nacht, geeft jou als persoon nooit een cijfer, en noemt een mix nooit veilig. Hij vertelt wat bekend is en laat de rest aan jou.",

    # ---------- home: privacy ----------
    "privacy_eyebrow": "Standaard privé",
    "privacy_h2": "Je telefoon, en nergens anders",
    "privacy_intro": "Niets van wat je hier schrijft gaat ergens heen. Niet naar mij, niet naar een bedrijf, niet naar een adverteerder. Het blijft op je telefoon.",
    "privacy_checks": [
        "Zet er Face ID of een pincode op. Alles op je telefoon is versleuteld, dus niemand anders leest het.",
        "Back-ups zijn optioneel en ook versleuteld, en ze gaan naar je eigen iCloud Drive.",
        "Meldingen kun je zo laten formuleren dat je vergrendelscherm niets prijsgeeft.",
    ],
    "privacy_link": "Lees het volledige privacybeleid",

    # ---------- home: proof ----------
    "proof_eyebrow": "Controleer het zelf",
    "proof_h2": "Je kunt elk woord hiervan nakijken",
    "proof_p": "ChillMate is open source. Elke regel code die iets met je gegevens doet, is openbaar. Je kunt dit dus zelf nakijken, in plaats van mij te moeten geloven.",
    "proof_fact": "De code van de app maakt geen enkele internetverbinding. Geen analytics, geen crashrapportage, nergens een <code>URLSession</code>. Het enige dat je telefoon verlaat, is wat jij zelf aantikt.",
    "proof_cta_repo": "Lees de code",
    "proof_cta_store": "Waar je gegevens staan",
    "proof_caption": "Gecontroleerd op ChillMate 4.2.1 (build 422).",

    "diagram_title": "Waar je gegevens heen gaan",
    "diagram_you": "Jij",
    "diagram_phone": "Je iPhone",
    "diagram_icloud": "Jouw iCloud",
    "diagram_optional": "optioneel, versleuteld",
    "diagram_server": "Mijn servers",
    "diagram_none": "die zijn er niet",

    # ---------- home: the promises ----------
    "refuse_eyebrow": "Beloftes",
    "refuse_h2": "Waar je op kunt rekenen",
    "refuse": [
        ("Je krijgt de feiten, nooit een oordeel.", "Je ziet wat er over een mix bekend is, en de keuze blijft van jou. De app kent jouw lichaam niet, jouw dosis niet, en jouw nacht niet."),
        ("Jij krijgt als persoon geen cijfer.", "Er is een getal voor die dag. Dat blijft op je telefoon. Er gaat niets op slot, je mist er niets door, en er wordt niets van gevonden."),
        ("Elke herinnering zet jij zelf aan.", "Ze staan allemaal uit. Zet aan wat je wilt, en formuleer het zo dat je vergrendelscherm niets prijsgeeft."),
        ("Er wordt nooit om een account gevraagd.", "Een account heeft een server nodig. Een server is een kopie van jou, op een plek waar jij niet bij kunt. Dus is er geen van beide."),
        ("Hij is gratis, en dat blijft zo.", "Elke functie, voor iedereen. De fooi is vrijwillig en ontgrendelt niets, want een veiligheidstool achter een betaalmuur helpt de verkeerde mensen."),
    ],
    "refuse_p": "Vijf beloftes. Daardoor kun je hier alles in kwijt zonder je af te vragen wie er meeleest.",

    # ---------- home: watch and languages ----------
    "watch_h3": "Hij werkt terwijl je telefoon in je zak blijft",
    "watch_p": "Dosistimers, drinkherinneringen, discrete check-ins, een ademhalingsoefening, en met één tik je vertrouwenscontact of het lokale alarmnummer. Allemaal op het horloge, plus een knop die je op je wijzerplaat kunt zetten.",
    "langs_h3": "Hij werkt in jouw taal",
    "langs_p": "De app en deze site zijn er in het Engels, Nederlands, Duits, Frans en Spaans. De hulpdiensten volgen het land dat je instelt, niet de taal die je leest. Dat zijn twee verschillende vragen.",

    # ---------- home: questions ----------
    "faq_teaser_eyebrow": "Voordat je het vraagt",
    "faq_teaser_h2": "De drie vragen die iedereen stelt.",
    "faq_teaser_link": "De rest van de vragen, en echte hulpdiensten",

    # ---------- home: the closing ask ----------
    "close_eyebrow": "Nog één ding",
    "close_h2": "Hij is gratis, en dat blijft zo.",
    "close_p": "Laat je mailadres achter, dan hoor je één keer van me: op de dag dat ChillMate in de App Store staat. Daarna verwijder ik je adres. Ondertussen werkt de risicocheck hierboven nu al, en werkt elk nummer op de hulppagina ook zonder bereik.",

    # ---------- support page ----------
    "support_title": "ChillMate · Hulp en ondersteuning",
    "support_desc": "Crisislijnen en zorgdiensten voor jouw land. Werkt offline, is goed te printen, en beantwoordt de vragen die het vaakst komen.",
    "support_h1": "Hulp, en hoe je mij bereikt",
    "support_lede": "Eerst echte hulpverlening, want daar is deze pagina het nuttigst voor. Vragen over de app staan verderop. Elk bericht wordt door een mens gelezen.",
    "support_urgent": "<strong>Wacht in een noodgeval niet op de app.</strong> Als jij of iemand anders in direct gevaar kan zijn, bel dan nu je lokale alarmnummer.",
    "support_contact_eyebrow": "Neem contact op",
    "support_contact_h2": "Contact",
    "support_contact_p": "Mail naar {email}. Een antwoord duurt meestal een paar dagen. Het helpt enorm als je erbij zet welke iOS-versie je hebt en wat je deed toen het misging.",
    "support_email_btn": "Mail mij",
    "support_issue_btn": "Meld een probleem",
    "support_faq_eyebrow": "Veelgestelde vragen",
    "support_help_eyebrow": "Echte hulpverlening",
    "support_help_h2": "Hulp van mensen, niet van een app",
    "support_help_p": "ChillMate is geen crisisdienst. Kies waar je bent, dan helpen deze organisaties je direct. Je kunt deze pagina printen, en hij werkt zonder bereik, want juist dan doen deze nummers ertoe.",
    "support_country_label": "Waar ben je?",
    "support_emergency_is": "Alarmnummer hier:",
    "support_emergency_local": "je lokale alarmnummer",
    "support_print": "Print deze pagina",

    "faq": [
        ("Zijn mijn gegevens privé?",
         "Ja, en je hoeft me niet op mijn woord te geloven. ChillMate houdt alles op je iPhone. Er is geen account en geen server, en er zijn geen advertenties, analytics of trackers. De app is open source, dus je kunt precies nalezen wat er gebeurt met wat je invult."),
        ("Wat kost het?",
         "Niets, en er is geen betaalde versie. Je kunt een fooi geven via Apple, maar die ontgrendelt helemaal niets. Iedereen krijgt elke functie, want een veiligheidstool achter een betaalmuur helpt de verkeerde mensen."),
        ("Zegt hij of iets veilig is?",
         "Nee, en dat is met opzet. De risicocheck laat zien wat er over een mix bekend is, ook met medicijnen die je al slikt. De beslissing blijft daarna aan jou. Gaat het ergens echt om? Vraag het dan aan een arts of apotheker."),
        ("Hoe maak ik een back-up, of stap ik over naar een nieuwe telefoon?",
         "Zet iCloud-back-up aan in Instellingen, dan gaat er een versleutelde back-up naar je eigen iCloud Drive. Je kunt ook zelf een back-upbestand exporteren. Op een nieuwe telefoon herstel je vanuit iCloud, of importeer je dat bestand tijdens het instellen."),
        ("Hoe vergrendel of verberg ik de app?",
         "Ga naar Instellingen, dan Privacy en vergrendeling, en zet Face ID aan of stel een pincode in. Je kunt ook discrete meldingen aanzetten, zodat je vergrendelscherm niets prijsgeeft. ChillMate verbergt het scherm als je van app wisselt, en tijdens schermopname of spiegelen. Eén tik maakt het leeg, op een maantje na."),
        ("Hoe verwijder ik mijn gegevens?",
         "Per item, of alles in één keer, in de app zelf. De app verwijderen wist wat er op je telefoon staat. iCloud-gegevens haal je weg bij de back-upinstellingen, of via iCloud zelf. Ergens anders ligt geen kopie waar je naar zou moeten vragen."),
        ("In welke landen werkt hij?",
         "Overal. De hulpdiensten volgen het land dat je bij het instellen kiest. Ingebouwd: Nederland, België, Duitsland, het Verenigd Koninkrijk, Ierland, Frankrijk, Spanje, de Verenigde Staten en Australië. Voor de rest van de wereld staan er internationale diensten in."),
        ("Welke talen spreekt hij?",
         "Engels, Nederlands, Duits, Frans en Spaans, op de telefoon en op het horloge. Stel het in de app in, of in iOS-instellingen. De laatste die je wijzigde is degene die telt."),
    ],
    "footnotes": [
        "De app maakt geen internetverbindingen.",
        "Synchronisatie gaat naar je eigen privédatabase.",
        "De pincode: 200.000 PBKDF2-rondes, bewaard in de Keychain.",
        "Verborgen als je van app wisselt, en tijdens schermopname.",
        "Back-ups verzegeld met AES-GCM.",
        "Meldingen die op je vergrendelscherm niets prijsgeven.",
        "Samenvattingen draaien op Apple’s model op het toestel.",
        "De 30 combinaties hierboven.",
        "De hulpgids voor 10 regio’s.",
    ],
    "statement2_big": "Hij vertelt wat bekend is, en laat de keuze aan jou.",
    "statement2_note": "De risicocheck noemt niets veilig. De samenvattingen ook niet. Nergens in de app krijg je te horen dat iets wel goed zit. Je krijgt wat er bekend is, in gewone taal, en jij beslist.",
    "nav_howto": "Hoe het werkt",
    "howto_title": "ChillMate · Hoe het werkt",
    "howto_desc": "Een nacht van het eerste plan tot de ochtend erna, de beloftes van de app, alles wat erin zit, en de Apple Watch.",
    "howto_h1": "Hoe het werkt",
    "howto_lede": "Een nacht van het eerste plan tot de ochtend erna, de beloftes die de app nakomt, en alles wat erin zit.",
    "howto_back": "Terug naar de voorpagina",
    "demo_meds_label": "Wat je al slikt",
    "demo_meds_ph": "Naam van medicijn, optioneel",
    "demo_timing_label": "Hoe kort op elkaar",
    "demo_assess_label": "Vaste checks",
    "demo_share": "Kopieer een link hiernaartoe",
    "demo_shared": "Link gekopieerd",
    "demo_print": "Print dit",
    "demo_meds_hit": "Herkend",
    "demo_meds_none": "Dat staat niet op de lijst.",
    "faq_teaser_indices": [0, 1, 2],

    # ---------- chapter navigation ----------
    "nav_chapters": [("who", "Voor wie"), ("inside", "Binnenkijken"),
                     ("try", "Probeer het"), ("privacy", "Privacy"), ("specs", "Specs")],
    "scroll_cue": "Scroll",


    # ---------- the playable risk checker ----------
    "demo_eyebrow": "Probeer het",
    "demo_h2": "Dit is de echte risicocheck.",
    "demo_p": "Geen plaatje ervan. Dezelfde 30 combinaties en dezelfde woorden als in de app, hier draaiend. Je hoeft niets te installeren.",
    "demo_pick": "Kies wat er speelt",
    "demo_none_title": "Niets bekend over deze mix",
    "demo_none_body": "Dat betekent niet dat het veilig is. Het betekent dat er hier niets over vastligt. Deze lijst is over niets het laatste woord, en een apotheker weet meer.",
    "demo_empty": "Kies iets, of typ een medicijn, om te zien wat de app zou zeggen.",
    "demo_reset": "Wissen",
    "demo_note": "Dit draait in de pagina zelf. Wat je aantikt gaat nergens heen, precies zoals in de app.",
    "combos_h2": "Alle 30 combinaties, in één lijst",
    "combos_meds_h2": "De medicijngroepen die hij herkent",
    "demo_try": "Probeer GHB en alcohol",

    # ---------- tech specs ----------
    "specs_eyebrow": "De details",
    "specs_h2": "Specificaties",
    "specs": [
        ("Vereist", "iPhone met iOS 26 of nieuwer"),
        ("Apple Watch", "Eigen app, watchOS 26 of nieuwer"),
        ("Prijs", "Gratis. Geen betaalde versie, geen abonnement, geen advertenties."),
        ("Account", "Geen. Er valt niets aan te melden."),
        ("Verzamelde gegevens", "Geen"),
        ("Talen", "English, Nederlands, Deutsch, Français, Español"),
        ("Hulpdiensten", "10 regio’s, op je telefoon, werkt offline"),
        ("Gecheckte combinaties", "30 bekende interacties, op je telefoon"),
        ("Geschreven samenvattingen", "Op je telefoon, Apple Foundation Models"),
        ("Synchronisatie en back-up", "Optioneel, versleuteld, je eigen iCloud"),
        ("Vergrendeling", "Face ID, of een pincode beschermd met 200.000 PBKDF2-rondes"),
        ("Broncode", "Open, MIT-licentie"),
        ("Versie", "4.2.1 (build 422)"),
    ],

    # ---------- footnotes ----------
    "footnotes_title": "Elke bewering op deze pagina, en waar je hem nakijkt",
    "footnotes_intro": "Elke bewering op deze pagina verwijst naar de code erachter. Je controleert er eentje in ongeveer een minuut.",
}
