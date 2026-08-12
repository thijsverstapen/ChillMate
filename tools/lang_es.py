# -*- coding: utf-8 -*-
"""Spanish copy. Translated from lang_en.

Two decisions shape this file, and both of them are about the person reading it.

**Register.** "tú", never "usted". That is how the app speaks, and it is how
Spanish harm-reduction material speaks to this audience. Peninsular Spanish,
because the built-in services (Energy Control, FELGTBI+, 016, 024) are Spanish
ones, but written so a reader in Bogotá or Buenos Aires never trips over a
word: no regionalisms, no "vosotros" where a rewrite avoids it.

**Plain words.** This is the one that matters, and it is a product requirement
rather than a style preference. Somebody reads this page tired, anxious, coming
down, worried about a test result, or in their third or fourth language, and
every one of those states costs comprehension. Spanish makes that harder than
English does: the language likes long sentences, "se" constructions and nouns
where a verb would do, and all three of those quietly move the reading level
up. So the sentences here are short and carry one idea each, the verbs are
active and concrete, the everyday word wins over the careful one ("saber"
instead of "tener conocimiento de"), and the two pieces of jargon a newcomer
will not know, PEP and PrEP, are explained in the same breath they appear.
"""

S = {
    # ---------- chrome ----------
    "skip": "Saltar al contenido",
    "nav_home": "Inicio",
    "nav_privacy": "Privacidad",
    "nav_support": "Ayuda",
    "nav_about": "Acerca de",
    "nav_github": "GitHub",
    "lang_label": "Idioma",
    "to_top": "Volver arriba",
    "made": "hecho por una sola persona en los Países Bajos",
    "copy": "Copiar",
    "copied": "Copiado",
    "call": "Llamar",
    "open": "Abrir",
    "policy_en_note": "La política de privacidad solo está en inglés. Así hay un único texto oficial, en vez de cinco que poco a poco dejarían de coincidir.",

    # The one disclaimer, worded once and used everywhere.
    "disclaimer": "ChillMate te ayuda a pensar las cosas, a planear con tiempo y a cuidarte. No sustituye a un médico y nunca decide si algo es seguro. Si alguien puede estar en peligro inmediato, llama a tu número de emergencias local.",

    # ---------- help categories ----------
    "cat_emergency": "Emergencias",
    "cat_crisis": "Crisis y prevención del suicidio",
    "cat_sexual_health": "Salud sexual y pruebas de ITS",
    "cat_gp": "Tu médico",
    "cat_drugs": "Información sobre drogas y reducción de daños",
    "cat_assault": "Tras una agresión sexual",
    "cat_lgbtq": "Apoyo LGTBIQ+",
    "cat_emergency_d": "Peligro inmediato, alguien inconsciente, o alguien a quien no consigues despertar.",
    "cat_crisis_d": "Gratis y confidencial, si crees que podrías hacerte daño o no te sientes a salvo.",
    "cat_sexual_health_d": "Pruebas, PrEP, PEP, vacunas y apoyo en salud sexual.",
    "cat_gp_d": "Interacciones entre medicamentos, sueño, salud mental, consumo y derivaciones.",
    "cat_drugs_d": "Información clara sobre drogas, sin juicios, y consejos para consumir con menos riesgo.",
    "cat_assault_d": "Apoyo tras una agresión, una coacción o una duda sobre el consentimiento.",
    "cat_lgbtq_d": "Alguien con quien hablar, información y una derivación.",
    "cat_generic_local": "Pregunta en tu servicio de salud local.",

    # ---------- home: head ----------
    "home_title": "ChillMate · Un lugar tranquilo y privado para cuidarte",
    "home_desc": "Cuídate alrededor de tus noches. Apunta cómo te sentiste, mira qué se mezcla mal y avisa a alguien de que has llegado a casa. Privado y gratis.",

    # ---------- home: hero ----------
    "h1": "Un lugar tranquilo y privado para cuidarte.",
    # Short enough to survive a 1200x630 share card.
    "og_sub": "Gratis. Sin cuenta. Todo se queda en tu iPhone.",
    "og_foot": "Código abierto · iPhone y Apple Watch",
    "lede": 'Disfruta de la noche y despierta contento de haberte cuidado. ChillMate apunta qué tomaste y cómo te sentiste, te dice qué se mezcla mal, y puede avisar sin ruido a alguien de que has llegado a casa. Todo privado. Todo gratis.',
    "cta_notify": "Avísame cuando salga",
    "cta_see": "Ver cómo funciona",
    "status_note": "Todavía no está en la App Store. Déjame tu correo y sabrás de mí una sola vez, el día que salga. Nada más, nunca.",
    "notify_subject": "Avísame cuando salga ChillMate",
    "notify_body": "No hace falta que escribas nada. Te contesto una vez, el día del lanzamiento, y después borro tu dirección.",

    # ---------- home: who it is for ----------
    "audience_eyebrow": "Para quién es",
    "audience_h2": "Hecho para las noches que otras apps se saltan",
    "audience_p": 'Chems, ligues o las dos cosas. ChillMate acepta la noche tal como fue. No te va a pedir explicaciones.',
    "audience_points": [
        "Un comprobador de riesgos que ya sabe qué medicación tomas, así que la respuesta encaja contigo.",
        "Un temporizador de check-in, para que alguien sepa que has llegado sin que tengas que mandar un mensaje.",
        "Una cuenta atrás para la PEP, la medicación que tomas después de una posible exposición al VIH. Solo funciona si empiezas rápido, y aquí la cuenta arranca al momento.",
        "Recordatorios de pruebas que llegan a tiempo y nunca dicen por qué en tu pantalla de bloqueo.",
    ],
    "audience_chill": "La app llama <strong>Chill</strong> a una noche. Tu Chill es tuyo, acabara como acabara.",

    # ---------- home: the walk ----------
    "walk_eyebrow": "Un vistazo por dentro",
    "walk_h2": "Cinco pantallas, y qué hace cada una por ti.",
    "walk": [
        ('Se ordena solo', 'Lo que necesitas, ya arriba del todo', 'Apunta una noche y la pantalla de inicio se recoloca a su alrededor. Aquí ha visto que quizá merezca la pena hablar de la PEP. Así que ha puesto esa cuenta atrás arriba del todo.'),
        ('Respuestas claras', 'Lo que se sabe, en palabras sencillas', 'Marca qué hay en juego, incluida tu propia medicación. Te dice qué se sabe de esa mezcla, en palabras que se entienden a las cuatro de la mañana. La decisión sigue siendo tuya.'),
        ('Cuando ya cuesta', 'Una cosa cada vez, con calma', 'Pantalla en penumbra, nada que parpadee, un paso cada vez. Respira, sigue los pasos para volver al aquí y ahora, y llama a alguien en cuanto quieras.'),
        ('Ayuda real, sin conexión', 'Personas, a un toque', 'Líneas de crisis, salud sexual, información sobre drogas y apoyo LGTBIQ+ de tu país. La lista está en tu teléfono, así que funciona aunque no tengas cobertura.'),
        ('Tus datos, en una pantalla', 'En la app, no en la letra pequeña', 'Qué hay en tu teléfono, qué guardaría una copia de seguridad y qué no envía nunca ChillMate. Una sola pantalla te lo enseña todo. Sin textos legales que tragarte.'),
    ],

    # ---------- home: one night ----------
    "night_eyebrow": "Cómo encaja",
    "night_h2": "Una noche, en tres momentos.",
    "night": [
        ('Antes de salir', 'Decide mientras es fácil', 'Pasa la mezcla por el comprobador de riesgos. Deja claro qué te apetece y qué no. Pon un temporizador de check-in. Cinco minutos, mientras tienes la cabeza clara.'),
        ('Mientras estás fuera', 'Un toque, sin escribir nada', 'El temporizador pregunta si estás bien. «Pedir ayuda» ya conoce a tu contacto de confianza. Y sabe el número de emergencias de donde estés. Tu reloj puede contestar por ti.'),
        ('La mañana siguiente', 'Apúntalo mientras lo tienes fresco', 'Sueño, cómo estás, qué ayudó de verdad. Un minuto ahora es lo que agradecerás dentro de tres meses.'),
    ],

    # ---------- home: features ----------
    "features_eyebrow": "Qué lleva dentro",
    "features": [
        ("book", "tint-blue", "Registro privado",
         "Apunta una noche como quieras recordarla: el sueño, cómo te sentiste y qué te ayudó después."),
        ("chart", "tint-mint", "Tus patrones",
         "Mira qué cambia de verdad a 30 y a 90 días, más una puntuación diaria que no verá nadie más."),
        ("life", "tint-purple", "Herramientas de cuidado",
         "Respiración, una pausa cuando llega el impulso, un plan para una sesión más segura y una ruta a casa cuando la quieras."),
        ("flask", "tint-pink", "Comprobador de riesgos",
         "Avisos claros sobre mezclas, incluida la medicación que ya tomas."),
        ("bell", "tint-amber", "Recordatorios que encajan",
         "Temporizadores de check-in, una cuenta atrás para la PEP y recordatorios de pruebas, con palabras discretas si quieres."),
        ("watch", "tint-blue", "En tu muñeca",
         "Temporizadores, check-ins y un número de emergencias en el Apple Watch, sin sacar el teléfono."),
    ],

    # ---------- home: is this for you ----------
    "foryou_eyebrow": "¿Te suena?",
    "foryou_h2": "Si te ves en alguna de estas, es para ti.",
    "foryou": [
        "Quieres recordar bien lo de anoche, tú y nadie más.",
        "Tomas PrEP, la pastilla diaria que evita que contraigas el VIH. Y prefieres que tu pantalla de bloqueo no lo diga.",
        "Quieres dar señales de vida a alguien sin montar una conversación entera.",
        "Te has preguntado, entre semana, si es más a menudo que antes.",
        "Quieres el número de emergencias de donde estés, sin abrir el navegador.",
    ],
    "foryou_not": "Qué puedes esperar, para que nada te sorprenda. ChillMate no juzga una noche, no te pone nota como persona y nunca dice que una mezcla sea segura. Te cuenta lo que se sabe y confía en ti para el resto.",

    # ---------- home: privacy ----------
    "privacy_eyebrow": "Privado por diseño",
    "privacy_h2": "Tu teléfono, y ningún otro sitio",
    "privacy_intro": 'Nada de lo que escribes aquí va a ningún sitio. Ni a mí, ni a una empresa, ni a un anunciante. Se queda en tu teléfono.',
    "privacy_checks": [
        'Bloquéala con Face ID o con un PIN. Todo lo que hay en el teléfono está cifrado, así que nadie más puede leerlo.',
        'Las copias de seguridad son opcionales, también van cifradas, y se guardan en tu propio iCloud Drive.',
        'Puedes redactar las notificaciones para que tu pantalla de bloqueo no delate nada.',
    ],
    "privacy_link": "Leer la política de privacidad completa",

    # ---------- home: proof ----------
    "proof_eyebrow": "Compruébalo tú",
    "proof_h2": "Puedes comprobar cada palabra de esto",
    "proof_p": 'ChillMate es de código abierto. Cada línea que toca tus datos es pública. Así que puedes comprobarlo, en vez de tener que fiarte de mí.',
    "proof_fact": 'El código de la app no hace ninguna conexión a internet. Nada de analítica, nada de informes de fallos, ninguna <code>URLSession</code> por ningún lado. De tu teléfono solo sale lo que tú tocas.',
    "proof_cta_repo": "Leer el código",
    "proof_cta_store": "Dónde viven tus datos",
    "proof_caption": "Comprobado en ChillMate 4.2.1 (build 422).",

    "diagram_title": "Adónde van tus datos",
    "diagram_you": "Tú",
    "diagram_phone": "Tu iPhone",
    "diagram_icloud": "Tu iCloud",
    "diagram_optional": "opcional, cifrado",
    "diagram_server": "Mis servidores",
    "diagram_none": "no existen",

    # ---------- home: the promises ----------
    "refuse_eyebrow": "Promesas",
    "refuse_h2": "Con lo que puedes contar",
    "refuse": [
        ("Los hechos, nunca un veredicto.", "Te enseña qué se sabe de una mezcla y te deja a ti la decisión. No conoce tu cuerpo, ni tu dosis, ni tu noche."),
        ("Nunca te pone nota como persona.", "Hay un número para el día. Se queda en tu teléfono. No bloquea nada, no te quita nada y no te juzga."),
        ("Cada recordatorio lo enciendes tú.", "Todos empiezan apagados. Enciende los que quieras y redáctalos para que la pantalla de bloqueo no delate nada."),
        ("Nunca tendrás que crearte una cuenta.", "Una cuenta necesita un servidor. Un servidor es una copia de ti en un sitio al que tú no llegas. Así que no hay ninguna de las dos cosas."),
        ("Es gratis, y seguirá siendo gratis.", "Todas las funciones, para todo el mundo. La propina opcional no desbloquea nada, porque una herramienta de seguridad tras un muro de pago ayuda a quien menos la necesita."),
    ],
    "refuse_p": "Cinco promesas. Por eso puedes escribir aquí lo que sea sin preguntarte quién más lo está leyendo.",

    # ---------- home: watch and languages ----------
    "watch_h3": "Funciona con el teléfono en el bolsillo",
    "watch_p": "Temporizadores de dosis, avisos para beber agua, check-ins discretos y un ejercicio de respiración. Un toque llama a tu contacto de confianza o al número de emergencias local. Todo en el reloj, y además un acceso directo que puedes poner en la esfera.",
    "watch_quote": "Si algo no va bien, busca ayuda. No estás en problemas.",
    "watch_quote_note": "La pantalla de Seguridad del reloj entera, con esas mismas palabras.",
    "langs_h3": "Funciona en tu idioma",
    "langs_p": "La app y esta web están en inglés, neerlandés, alemán, francés y español. Los servicios de ayuda siguen al país que elijas, no al idioma en que lees. Son dos preguntas distintas.",

    # ---------- home: questions ----------
    "faq_teaser_eyebrow": "Antes de que preguntes",
    "faq_teaser_h2": "Las tres preguntas que hace todo el mundo.",
    "faq_teaser_link": "El resto de preguntas, y servicios de ayuda reales",

    # ---------- home: the closing ask ----------
    "close_eyebrow": "Una última cosa",
    "close_h2": "Es gratis, y seguirá siendo gratis.",
    "close_p": "Déjame tu correo y te escribo una sola vez, el día que ChillMate llegue a la App Store. Después borro tu dirección. Mientras tanto, el comprobador de riesgos de arriba ya funciona. Y todos los números de la página de ayuda funcionan sin cobertura.",

    # ---------- support page ----------
    "support_title": "ChillMate · Ayuda y apoyo",
    "support_desc": "Líneas de crisis y servicios de salud de tu país. Funciona sin conexión, se imprime en una hoja y responde a las preguntas más frecuentes.",
    "support_h1": "Ayuda, y cómo localizarme",
    "support_lede": "Primero los servicios reales, porque para eso sirve esta página. Las preguntas sobre la app están más abajo. Cada mensaje lo lee una persona.",
    "support_urgent": "<strong>En una emergencia, no esperes a la app.</strong> Si hay peligro inmediato para ti o para otra persona, llama ya a tu número de emergencias local.",
    "support_contact_eyebrow": "Ponte en contacto",
    "support_contact_h2": "Contacto",
    "support_contact_p": "Escribe a {email}. Suelo tardar unos días en contestar. Ayuda mucho que digas qué versión de iOS tienes y qué estabas haciendo cuando falló.",
    "support_email_btn": "Escríbeme",
    "support_issue_btn": "Informar de un problema",
    "support_faq_eyebrow": "Preguntas frecuentes",
    "support_help_eyebrow": "Servicios reales",
    "support_help_h2": "Ayuda de personas, no de una app",
    "support_help_p": "ChillMate no es un servicio de crisis. Elige dónde estás y estas organizaciones pueden ayudarte directamente. Puedes imprimir esta página, y funciona sin cobertura, porque es justo entonces cuando estos números importan.",
    "support_country_label": "¿Dónde estás?",
    "support_emergency_is": "Número de emergencias aquí:",
    "support_emergency_local": "tu número de emergencias local",
    "support_print": "Imprimir esta página",

    "faq": [
        ("¿Mis datos son privados?",
         "Sí, y no hace falta que te fíes de mi palabra. ChillMate lo guarda todo en tu iPhone. No hay cuenta ni servidor, y no hay anuncios, analítica ni rastreadores. La app es de código abierto, así que puedes leer qué hace exactamente con lo que escribes."),
        ("¿Cuánto cuesta?",
         "Nada, y no hay versión de pago. Hay una propina opcional, que gestiona Apple, y no desbloquea absolutamente nada. Todas las funciones son para todo el mundo. Una herramienta de seguridad tras un muro de pago ayuda a quien menos la necesita."),
        ("¿Me dice si algo es seguro?",
         "No, y es a propósito. El comprobador de riesgos enseña qué se sabe de una mezcla, también con la medicación que ya tomas. La decisión te la deja a ti. Para lo que de verdad importa, pregunta a un médico o a un farmacéutico."),
        ("¿Cómo hago una copia de seguridad o cambio de teléfono?",
         "Activa la copia en iCloud desde Ajustes y se guardará cifrada en tu propio iCloud Drive. También puedes exportar el archivo de copia por tu cuenta. En un teléfono nuevo, restaura desde iCloud o importa ese archivo mientras lo configuras."),
        ("¿Cómo bloqueo la app, o la escondo?",
         "Ve a Ajustes, luego a Privacidad y bloqueo, y activa Face ID o pon un PIN. También puedes encender las notificaciones discretas, para que la pantalla de bloqueo no delate nada. ChillMate esconde lo que hay en pantalla cuando cambias de app, y mientras grabas o duplicas la pantalla. Con un toque, la pantalla se queda en una luna."),
        ("¿Cómo borro mis datos?",
         "Entrada a entrada, o todo de golpe, dentro de la app. Si borras la app, se va lo que hay en tu teléfono. Lo de iCloud se quita desde los ajustes de copia, o desde el propio iCloud. No hay ninguna copia en otro sitio por la que preguntar."),
        ("¿En qué países funciona?",
         "En cualquiera. Los servicios de ayuda siguen al país que elijas al configurarla. Vienen incluidos los Países Bajos, Bélgica, Alemania, el Reino Unido, Irlanda, Francia, España, Estados Unidos y Australia. En el resto salen servicios internacionales."),
        ("¿Qué idiomas habla?",
         "Inglés, neerlandés, alemán, francés y español, en el teléfono y en el reloj. Elígelo en la app o en los Ajustes de iOS. Vale el último que hayas cambiado."),
    ],
    "footnotes": [
        'La app no hace ninguna conexión a internet.',
        'La sincronización va a tu propia base de datos privada.',
        'El PIN: 200.000 rondas PBKDF2, guardado en el Llavero.',
        'Se oculta al cambiar de app y durante las grabaciones de pantalla.',
        'Copias selladas con AES-GCM.',
        'Textos de la pantalla de bloqueo que no delatan nada.',
        'Los resúmenes se hacen con el modelo de Apple en el propio teléfono.',
        'Las 30 combinaciones de arriba.',
        'El directorio de ayuda de 10 regiones.',
    ],
    "statement2_big": 'Te dice lo que se sabe, y la decisión te la deja a ti.',
    "statement2_note": 'El comprobador de riesgos nunca dirá que algo es seguro. Los resúmenes tampoco. En ningún sitio de la app te van a decir que no pasa nada. Te enseña lo que se sabe, en palabras sencillas, y decides tú.',
    "nav_howto": 'Cómo funciona',
    "howto_title": 'ChillMate · Cómo funciona',
    "howto_desc": 'Una noche entera, del primer plan a la mañana siguiente. Las promesas que cumple la app, todo lo que lleva dentro y el Apple Watch.',
    "howto_h1": 'Cómo funciona',
    "howto_lede": 'Una noche entera, del primer plan a la mañana siguiente. Las promesas que cumple la app, y todo lo que lleva dentro de verdad.',
    "howto_back": 'Volver a la portada',
    "demo_meds_label": 'Lo que ya tomas',
    "demo_meds_ph": 'Nombre del medicamento, opcional',
    "demo_timing_label": 'Con cuánta separación',
    "demo_assess_label": 'Comprobaciones fijas',
    "demo_share": 'Copiar un enlace a esto',
    "demo_shared": 'Enlace copiado',
    "demo_print": 'Imprimir esto',
    "demo_meds_hit": 'Reconocido',
    "demo_meds_none": 'Eso no está en la lista.',
    "faq_teaser_indices": [0, 1, 2],

    # ---------- chapter navigation ----------
    "nav_chapters": [("who", "Para quién"), ("inside", "Por dentro"),
                     ("try", "Pruébalo"), ("privacy", "Privacidad"), ("specs", "Ficha técnica")],
    "scroll_cue": "Desplázate",


    # ---------- the playable risk checker ----------
    "demo_eyebrow": "Pruébalo",
    "demo_h2": "Este es el comprobador de riesgos de verdad.",
    "demo_p": 'No es una captura. Son las mismas 30 combinaciones y las mismas palabras que la app, funcionando aquí mismo. No hay nada que instalar.',
    "demo_pick": "Elige qué hay en juego",
    "demo_none_title": "No hay nada registrado sobre esta mezcla",
    "demo_none_body": "Eso no quiere decir que sea segura. Quiere decir que aquí no hay nada anotado. Esta lista no es la última palabra, y un farmacéutico puede contarte más.",
    "demo_empty": 'Elige algo, o escribe un medicamento, para ver qué diría la app.',
    "demo_reset": "Borrar",
    "demo_note": "Esto funciona dentro de la página. Nada de lo que toques se envía a ningún sitio, igual que en la app.",
    "demo_try": "Probar GHB y alcohol",

    # ---------- tech specs ----------
    "specs_eyebrow": "Los detalles",
    "specs_h2": "Ficha técnica",
    "specs": [
        ("Requiere", "iPhone con iOS 26 o posterior"),
        ("Apple Watch", "App propia, watchOS 26 o posterior"),
        ("Precio", "Gratis. Sin versión de pago, sin suscripción, sin anuncios."),
        ("Cuenta", "Ninguna. No tienes que registrarte."),
        ("Datos recogidos", "Ninguno"),
        ("Idiomas", "English, Nederlands, Deutsch, Français, Español"),
        ("Servicios de ayuda", "10 regiones, en el teléfono, funciona sin conexión"),
        ("Combinaciones comprobadas", "30 interacciones conocidas, en el teléfono"),
        ("Resúmenes escritos", "En el teléfono, Apple Foundation Models"),
        ("Sync y copia", "Opcional, cifrado, tu propio iCloud"),
        ("Bloqueo", "Face ID, o un PIN protegido con 200.000 rondas PBKDF2"),
        ("Código", "Abierto, licencia MIT"),
        ("Versión", "4.2.1 (build 422)"),
    ],

    # ---------- footnotes ----------
    "footnotes_title": "Cada afirmación de esta página, y dónde comprobarla",
    "footnotes_intro": "Cada afirmación de esta página enlaza con el código que hay detrás. Puedes comprobar cualquiera en un minuto.",
}
