# -*- coding: utf-8 -*-
"""The Dutch privacy policy, as a translation of the English one.

The English text governs. That is not a formality: if these two ever disagree,
the disagreement is a bug in this file, and the English version is what was
meant. The page says so at the top, in a box nobody can miss, and links back.

Kept as a separate module because it is the only page whose translation carries
legal weight, and mixing it into the marketing strings would make it too easy
to edit one without the other.
"""

# Section bodies are HTML fragments, so they can carry <strong> and <em>. The
# ids match the English page exactly, so /privacy/#watch and
# /nl/privacy/#watch land on the same section.

TITLE = "ChillMate · Privacybeleid"
DESC = ("Het privacybeleid van ChillMate in het Nederlands. Je gegevens blijven op je iPhone. "
        "Geen advertenties, geen tracking, niets wordt verkocht.")

H1 = "Privacy beleid"
LEDE = ("ChillMate is privacy-first gebouwd. Je gegevens staan op je iPhone, onder jouw beheer. "
        "Ik draai geen servers die je gegevens verzamelen, gebruik geen advertentie- of "
        "analysetrackers, en verkoop of deel je persoonlijke gegevens nooit.")
META = "Laatst bijgewerkt: {updated} · Geldt voor de ChillMate iOS-app en deze website."

GOVERNS_TITLE = "De Engelse tekst is leidend"
GOVERNS_BODY = (
    "Dit is een vertaling, gemaakt zodat je niet gedwongen wordt Engels te lezen om te "
    "weten wat er met je gegevens gebeurt. Bij een verschil tussen deze tekst en "
    "<a href=\"../../privacy/\">de Engelse versie</a> geldt de Engelse. Dat is geen "
    "juridisch trucje: één gezaghebbende tekst is veiliger dan twee die uit elkaar groeien, "
    "en als je hier iets tegenkomt dat afwijkt, is dat een fout die ik graag hoor."
)

SECTIONS = [
    ("short", "shield", "var(--primary)", "De korte versie", """
    <ul>
      <li><strong>Op je toestel.</strong> Je profiel, logboek, plannen en notities staan lokaal op je iPhone.</li>
      <li><strong>Geen trackers.</strong> Geen advertentie-, analyse- of trackingsoftware van derden.</li>
      <li><strong>Niets verkocht.</strong> Je persoonlijke of gezondheidsgegevens worden nooit verkocht of gedeeld.</li>
      <li><strong>Jij hebt de regie.</strong> Jij bepaalt wat je toevoegt, wat je synchroniseert, en je kunt alles op elk moment wissen.</li>
    </ul>
"""),

    ("network", "code", "var(--mint)", "Elke verbinding die de app maakt", """
    <p>Privacybeleid beschrijft meestal bedoelingen. Dit is de lijst van wat er werkelijk van het toestel af gaat, en dat is korter en beter te controleren.</p>
    <p>De code van ChillMate bevat <strong>helemaal geen netwerkcode</strong>: geen <code>URLSession</code>, geen analytics-SDK, geen crashrapportage, geen configuratie op afstand. Alles hieronder is óf een Apple-dienst die met jouw eigen account praat, óf iets waar jij op hebt getikt.</p>
    <div class="table-scroll">
      <table>
        <caption>Gecontroleerd op ChillMate {version} (build {build}), over alle 82 Swift-bestanden in de repository.</caption>
        <thead><tr><th scope="col">Wat</th><th scope="col">Gaat waarheen</th><th scope="col">Wanneer</th></tr></thead>
        <tbody>
          <tr><td>iCloud-synchronisatie (CloudKit)</td><td>Je eigen privé-iCloud-database</td><td>Alleen als je iCloud aanzet. Apple bewaart het, en ik kan er niet bij.</td></tr>
          <tr><td>Versleuteld back-upbestand</td><td>Je eigen iCloud Drive</td><td>Alleen als je back-ups aanzet, of zelf een bestand exporteert.</td></tr>
          <tr><td>Apple Watch-spiegeling</td><td>Je eigen horloge, rechtstreeks</td><td>Als je een horloge koppelt. Toestel naar toestel, via Watch Connectivity.</td></tr>
          <tr><td>Apple Gezondheid</td><td>Blijft op het toestel</td><td>Alleen de categorieën die jij toestaat. HealthKit is lokale opslag, geen dienst.</td></tr>
          <tr><td>Een optionele donatie</td><td>Apple In-App Purchase</td><td>Alleen als jij erop tikt. Apple verwerkt de betaling; ik zie nooit je kaartgegevens.</td></tr>
          <tr><td>Een link waar je op tikt</td><td>Safari, naar die site</td><td>Alleen op jouw tik. ChillMate haalt die pagina's niet zelf op.</td></tr>
          <tr><td>Een gesprek of bericht dat jij stuurt</td><td>Je telefoon-app, je berichten-app</td><td>Alleen op jouw tik, en je ziet het bericht voordat het weggaat.</td></tr>
          <tr><td><strong>Iets naar een ChillMate-server</strong></td><td><strong>Nergens heen</strong></td><td><strong>Nooit. Die server bestaat niet.</strong></td></tr>
        </tbody>
      </table>
    </div>
    <p><a href="{repo}">Lees de broncode</a> als je liever controleert dan gelooft.</p>
"""),

    ("collected", "doc", "var(--purple)", "Categorie voor categorie", """
    <p>Dit zijn de categorieën waar Apple elke ontwikkelaar naar vraagt. Het antwoord van ChillMate is overal hetzelfde.</p>
    <div class="table-scroll">
      <table>
        <thead><tr><th scope="col">Categorie</th><th scope="col">Verzameld door ChillMate</th><th scope="col">Gekoppeld aan jou</th><th scope="col">Gebruikt om je te volgen</th></tr></thead>
        <tbody>
          <tr><td>Gezondheid en fitness</td><td class="no">Nee</td><td class="no">Nee</td><td class="no">Nee</td></tr>
          <tr><td>Gevoelige informatie</td><td class="no">Nee</td><td class="no">Nee</td><td class="no">Nee</td></tr>
          <tr><td>Contactgegevens</td><td class="no">Nee</td><td class="no">Nee</td><td class="no">Nee</td></tr>
          <tr><td>Contacten</td><td class="no">Nee</td><td class="no">Nee</td><td class="no">Nee</td></tr>
          <tr><td>Locatie</td><td class="no">Nee</td><td class="no">Nee</td><td class="no">Nee</td></tr>
          <tr><td>Gebruikersinhoud</td><td class="no">Nee</td><td class="no">Nee</td><td class="no">Nee</td></tr>
          <tr><td>Identificatiegegevens</td><td class="no">Nee</td><td class="no">Nee</td><td class="no">Nee</td></tr>
          <tr><td>Gebruiksgegevens</td><td class="no">Nee</td><td class="no">Nee</td><td class="no">Nee</td></tr>
          <tr><td>Diagnostiek</td><td class="no">Nee</td><td class="no">Nee</td><td class="no">Nee</td></tr>
          <tr><td>Aankopen</td><td class="no">Nee</td><td class="no">Nee</td><td class="no">Nee</td></tr>
        </tbody>
      </table>
    </div>
    <p>Om precies te zijn over dat woord. ChillMate <em>bewaart</em> heel veel op je telefoon, ook gezondheidsgegevens en andere gevoelige dingen die je intypt. Het <em>verzamelt</em> er niets van. Verzamelen zou betekenen dat het van je toestel af gaat, naar een plek waar jij niet bij kunt.</p>
"""),

    ("compare", "hand", "var(--pink)", "Wat een welzijnsapp meestal van je weet", """
    <p>Geen aanklacht tegen iemand in het bijzonder. Dit is simpelweg wat de gewone, keurige versie van zo'n app bewaart, omdat dat bewaren nu eenmaal is hoe die versie werkt.</p>
    <div class="table-scroll">
      <table>
        <thead><tr><th scope="col">Vraag</th><th scope="col">Het gebruikelijke antwoord</th><th scope="col">ChillMate</th></tr></thead>
        <tbody>
          <tr><th scope="row">Wie kan je invoer lezen?</th><td>Jij, en wie de database beheert</td><td><span class="yes">Alleen jij</span></td></tr>
          <tr><th scope="row">Wat komt er vrij bij een datalek?</th><td>Alles wat op de server staat</td><td><span class="yes">Niets. Er is geen server.</span></td></tr>
          <tr><th scope="row">Wat kan er op verzoek worden afgegeven?</th><td>Je account en de inhoud ervan</td><td><span class="yes">Er wordt niets bewaard om af te geven</span></td></tr>
          <tr><th scope="row">Wat gebeurt er bij een overname?</th><td>De nieuwe eigenaar krijgt de gegevens</td><td><span class="yes">Er zijn geen gegevens om over te nemen</span></td></tr>
          <tr><th scope="row">Wat ontsluit een e-mailadres?</th><td>Je account</td><td><span class="yes">Er is geen account</span></td></tr>
          <tr><th scope="row">Wie ziet welke schermen je opent?</th><td>Een analytics-aanbieder</td><td><span class="yes">Niemand. Er is geen analytics.</span></td></tr>
          <tr><th scope="row">Kan het beleid later veranderen?</th><td>Ja, en de gegevens zijn al verzameld</td><td><span class="yes">Het kan veranderen, maar er is nog steeds niets verzameld</span></td></tr>
        </tbody>
      </table>
    </div>
    <p>De eerlijke prijs van de rechterkolom: raak je je telefoon kwijt zonder back-up, dan kan niemand het voor je terughalen. Dat is dezelfde eigenschap, van de andere kant bekeken.</p>
"""),

    ("threat", "hand", "var(--amber)", "Waar het echt tegen ontworpen is", """
    <p>De meeste privacypagina's gaan over datalekken en hackers. Voor een app als deze ligt het risico dichter bij huis: <strong>iemand die je ontgrendelde telefoon oppakt.</strong> Een partner, een huisgenoot, familie, een collega die naar een melding kijkt.</p>
    <p>Daarom heeft de app een eigen Face ID- of pinvergrendeling, bovenop die van je telefoon. Meldingen kun je zo laten formuleren dat je vergrendelscherm niets prijsgeeft. Eén tik maakt het scherm zwart. En ChillMate verbergt wat er op het scherm staat als je van app wisselt, en tijdens schermopname of spiegelen.</p>
    <p>Geen server hebben heeft een handig neveneffect. Word ik gehackt, dan komt er niets over jou naar buiten, want ik bewaar niets. De keerzijde zeg ik er eerlijk bij: raak je je telefoon kwijt en heb je geen back-up, dan zijn de gegevens weg. Dat is bewust, en daarom staat een versleutelde back-up één instelling verderop.</p>
"""),

    ("saves", "mail", "var(--mint)", "Wat ChillMate kan bewaren", """
    <ul>
      <li>Je profiel, foto, notities over medicijnen, vertrouwenscontact, thuisadres, instellingen en voorkeuren.</li>
      <li>Privélogboek, slaapnotities, gezondheidsgerelateerde invoer en testherinneringen, plannen, dagboekitems, check-ins en gegevens voor je noodkaart.</li>
      <li>Optionele informatie die je zelf toevoegt vanuit Apple Gezondheid, Contacten, Foto's of Locatievoorzieningen.</li>
    </ul>
    <p>Een deel van wat je toevoegt is gezondheidsgerelateerd en gevoelig. Het staat alleen op je toestel, onder jouw beheer.</p>
"""),

    ("use", "lock", "var(--purple)", "Hoe je gegevens gebruikt worden", """
    <ul>
      <li>Om je privéoverzicht, herinneringen, opvolging, noodsnelkoppelingen en reflecties te tonen.</li>
      <li>Om te synchroniseren met Apple Gezondheid, alleen voor de categorieën die je in iOS goedkeurt.</li>
      <li>Om versleutelde back-ups te maken, alleen als je back-upfuncties aanzet.</li>
    </ul>
    <p>Dit gebeurt allemaal op je toestel. ChillMate stuurt nooit iets van wat je schrijft naar mij.</p>
"""),

    ("never", "hand", "var(--pink)", "Wat ChillMate niet doet", """
    <ul>
      <li>Geen advertenties, geen verkoop van persoonlijke gegevens, en geen delen van je gezondheidsgegevens voor marketing.</li>
      <li>Geen medische diagnose, behandelbeslissingen of advies of iets veilig is.</li>
      <li>Er gaan geen berichten naar je contacten tenzij jij ervoor kiest ze te sturen.</li>
    </ul>
"""),

    ("where", "cloud", "var(--amber)", "Waar je gegevens worden bewaard", """
    <p><strong>Op je iPhone.</strong> In de privéopslag van de app, beschermd door de bestandsbeveiliging van iOS. Zet je het aan, dan komt daar een extra appvergrendeling bovenop, met Face ID of een pincode.</p>
    <p><strong>Optioneel iCloud.</strong> Als je iCloud-back-up of -synchronisatie aanzet, bewaart ChillMate je gegevens in <em>jouw eigen</em> privé-iCloud-account via CloudKit en iCloud Drive van Apple. Apple versleutelt het, en alleen jij kunt erbij. Ik heb er geen enkele toegang toe.</p>
    <p><strong>Geen servers van mij.</strong> Er bestaat nergens een ChillMate-server die je persoonlijke gegevens ontvangt of bewaart.</p>
"""),

    ("watch", "watch", "var(--mint)", "Apple Watch", """
    <p>Koppel je een Apple Watch, dan kopieert ChillMate een deel van je gegevens naar het horloge, zodat dat blijft werken als je telefoon buiten bereik is. Het gaat om je reeks en dagscore, lopende dosistimers, je horloge-instellingen, je alarmnummer, en de <strong>naam en het telefoonnummer van je vertrouwenscontact</strong>, zodat het horloge die persoon kan bellen zonder je telefoon.</p>
    <p>Dit gaat rechtstreeks tussen je telefoon en je horloge via Watch Connectivity van Apple, op je eigen toestellen. Het gaat niet via mijn servers, want die zijn er niet.</p>
    <p>Twee dingen om te weten. De gegevens van je vertrouwenscontact zijn van iemand anders en komen op een tweede toestel terecht, dus voeg alleen iemand toe die dat goed zou vinden. En de appvergrendeling van ChillMate beschermt de <em>telefoon</em>-app. De horloge-app wordt beschermd door de toegangscode en polsdetectie van je horloge zelf.</p>
    <p>Je vertrouwenscontact wissen in Instellingen, of het horloge ontkoppelen, verwijdert deze gespiegelde gegevens.</p>
"""),

    ("permissions", "shield", "var(--primary)", "Toestemmingen op je toestel", """
    <p>Elke toestemming is optioneel en wordt alleen gebruikt waarvoor je hem geeft:</p>
    <ul>
      <li><strong>Apple Gezondheid.</strong> Lezen en schrijven van alleen de categorieën die je toestaat (zoals slaap, hartslag, HRV en workouts).</li>
      <li><strong>Contacten.</strong> Alleen om een vertrouwenscontact te kunnen kiezen. Het opzoeken gebeurt op je toestel.</li>
      <li><strong>Foto's.</strong> Alleen om een profielfoto in te stellen die jij kiest.</li>
      <li><strong>Locatie.</strong> Alleen om een locatie aan een log te hangen of je huidige locatie mee te sturen in een noodbericht dat jij verstuurt.</li>
      <li><strong>Meldingen.</strong> Voor de herinneringen en check-ins die je aanzet. Discrete formulering kan aan, zodat de tekst op je vergrendelscherm vaag blijft.</li>
    </ul>
"""),

    ("payments", "tag", "var(--mint)", "Betalingen en donaties", """
    <p>ChillMate is gratis. Als je wilt doneren, wordt dat volledig afgehandeld door het In-App Purchase-systeem van Apple. Apple verwerkt de betaling; ik ontvang nooit je kaart- of accountgegevens. Donaties ontgrendelen geen functies en veranderen niets aan wat er wordt verzameld.</p>
"""),

    ("control", "lock", "var(--purple)", "Jouw beheer en verwijdering", """
    <ul>
      <li>Je kunt logboekitems, plannen, herinneringen, timers, dagboekitems en je hele account vanuit de app verwijderen.</li>
      <li>De app verwijderen wist de lokale gegevens van je iPhone. iCloud-gegevens kun je weghalen via iCloud-instellingen of via de back-upinstellingen in de app.</li>
      <li>De iOS-toestemmingen voor Gezondheid, Locatie, Meldingen, Contacten en Foto's blijven altijd beschikbaar in de Instellingen-app.</li>
    </ul>
    <p>ChillMate verzamelt je gegevens niet op een server. Er is dus geen profiel op afstand om op te vragen, te corrigeren of te laten wissen. Je hebt alles al zelf in handen. Woon je in de EU of EER, dan regel je je AVG-rechten (inzage, correctie, wissen, overdraagbaarheid, bezwaar) rechtstreeks met deze knoppen op je toestel.</p>
"""),

    ("children", "info", "var(--pink)", "Kinderen", """
    <p>ChillMate is alleen bedoeld voor volwassenen. Je moet 18 jaar of ouder zijn om een profiel te maken en de app te gebruiken.</p>
"""),

    ("changes", "doc", "var(--primary)", "Wijzigingen in dit beleid", """
    <p>Als dit beleid verandert, wordt de bijgewerkte versie op deze pagina geplaatst met een nieuwe datum bij "laatst bijgewerkt". Wezenlijke wijzigingen worden ook vermeld in de app of in de <a href="../../changelog/">changelog</a>.</p>
    <p>De volledige wijzigingsgeschiedenis van deze pagina staat, uit git gelezen, op <a href="../../privacy/#history">de Engelse versie</a>.</p>
"""),

    ("contact", "mail", "var(--mint)", "Contact", """
    <p>Vragen over privacy? Mail naar <a href="mailto:{email}">{email}</a>. Voor alles wat met beveiliging te maken heeft, zie de <a href="../../security/">beveiligingspagina</a>.</p>
"""),
]
