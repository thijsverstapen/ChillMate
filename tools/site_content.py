# -*- coding: utf-8 -*-
"""Content for the ChillMate site, in every language the app itself ships.

The app speaks English, Dutch, German, French and Spanish. A site that only
speaks English sends most of its readers to a page they have to translate
themselves, which is the wrong first impression for an app whose whole promise
is that it is easy to reach when you are not at your best.

The privacy policy is deliberately English only. It is the document that says
what happens to someone's data, and five translations of it would be five
documents to keep in step. One authoritative text is safer than five drifting
ones, and every localised page links to it plainly.
"""

# Order matters: this is the order of the language menu.
LANGS = ["en", "nl", "de", "fr", "es"]

LANG_NAMES = {
    "en": "English",
    "nl": "Nederlands",
    "de": "Deutsch",
    "fr": "Français",
    "es": "Español",
}

# BCP-47 tags for <html lang> and hreflang.
LANG_TAGS = {
    "en": "en",
    "nl": "nl",
    "de": "de",
    "fr": "fr",
    "es": "es",
}


# --------------------------------------------------------------------------
# Help services, mirroring ChillMate/SupportDirectoryViews.swift
# --------------------------------------------------------------------------
#
# One list per country, each entry a (category, name, url) triple. The action
# label is derived from the url rather than written out, so adding a country
# adds no new strings to translate.

CATEGORIES = ["emergency", "crisis", "sexual_health", "gp", "drugs", "assault", "lgbtq"]

COUNTRIES = {
    "NL": {
        "emergency": "112",
        "items": [
            ("emergency", "112", "tel:112"),
            ("crisis", "113 Zelfmoordpreventie", "https://www.113.nl"),
            ("sexual_health", "GGD", "https://www.ggd.nl"),
            ("gp", "Huisarts", None),
            ("drugs", "Drugs Infolijn", "https://www.drugsinfo.nl"),
            ("assault", "Centrum Seksueel Geweld", "https://centrumseksueelgeweld.nl"),
            ("lgbtq", "Switchboard LGBT+", "https://switchboard.nl"),
        ],
    },
    "BE": {
        "emergency": "112",
        "items": [
            ("emergency", "112", "tel:112"),
            ("crisis", "Zelfmoordlijn 1813", "tel:1813"),
            ("sexual_health", "Sensoa", "https://www.sensoa.be"),
            ("gp", "Huisarts", None),
            ("drugs", "De DrugLijn", "https://www.druglijn.be"),
            ("assault", "Zorgcentra na Seksueel Geweld", "https://www.seksueelgeweld.be"),
            ("lgbtq", "Lumi", "https://lumi.be"),
        ],
    },
    "DE": {
        "emergency": "112",
        "items": [
            ("emergency", "112", "tel:112"),
            ("crisis", "TelefonSeelsorge", "tel:08001110111"),
            ("sexual_health", "Deutsche Aidshilfe", "https://www.aidshilfe.de"),
            ("gp", "Hausarzt", None),
            ("drugs", "drugcom.de", "https://www.drugcom.de"),
            ("assault", "Hilfetelefon", "tel:116016"),
            ("lgbtq", "LSVD+", "https://www.lsvd.de"),
        ],
    },
    "GB": {
        "emergency": "999",
        "items": [
            ("emergency", "999", "tel:999"),
            ("crisis", "Samaritans", "tel:116123"),
            ("sexual_health", "NHS sexual health", "https://www.nhs.uk/live-well/sexual-health/"),
            ("gp", "GP", None),
            ("drugs", "FRANK", "https://www.talktofrank.com"),
            ("assault", "Rape Crisis", "https://rapecrisis.org.uk"),
            ("lgbtq", "Switchboard LGBTQ+", "https://switchboard.lgbt"),
        ],
    },
    "FR": {
        "emergency": "112",
        "items": [
            ("emergency", "112", "tel:112"),
            ("crisis", "3114", "tel:3114"),
            ("sexual_health", "Sida Info Service", "https://www.sida-info-service.org"),
            ("gp", "Médecin traitant", None),
            ("drugs", "Drogues Info Service", "https://www.drogues-info-service.fr"),
            ("assault", "Viols Femmes Informations", "tel:0800059595"),
            ("lgbtq", "SOS homophobie", "https://www.sos-homophobie.org"),
        ],
    },
    "ES": {
        "emergency": "112",
        "items": [
            ("emergency", "112", "tel:112"),
            ("crisis", "024", "tel:024"),
            ("sexual_health", "Sanidad", "https://www.sanidad.gob.es"),
            ("gp", "Médico de cabecera", None),
            ("drugs", "Energy Control", "https://energycontrol.org"),
            ("assault", "016", "tel:016"),
            ("lgbtq", "FELGTBI+", "https://felgtbi.org"),
        ],
    },
    "US": {
        "emergency": "911",
        "items": [
            ("emergency", "911", "tel:911"),
            ("crisis", "988 Suicide & Crisis Lifeline", "tel:988"),
            ("sexual_health", "CDC GetTested", "https://gettested.cdc.gov"),
            ("gp", "Primary care doctor", None),
            ("drugs", "DanceSafe", "https://dancesafe.org"),
            ("assault", "RAINN", "https://www.rainn.org"),
            ("lgbtq", "The Trevor Project", "https://www.thetrevorproject.org"),
        ],
    },
    "IE": {
        "emergency": "112",
        "items": [
            ("emergency", "112", "tel:112"),
            ("crisis", "Samaritans", "tel:116123"),
            ("sexual_health", "Sexual Wellbeing (HSE)", "https://www.sexualwellbeing.ie"),
            ("gp", "GP", None),
            ("drugs", "Drugs.ie", "https://www.drugs.ie"),
            ("assault", "Dublin Rape Crisis Centre", "https://www.drcc.ie"),
            ("lgbtq", "LGBT Ireland", "https://lgbt.ie"),
        ],
    },
    "AU": {
        "emergency": "000",
        "items": [
            ("emergency", "000", "tel:000"),
            ("crisis", "Lifeline", "tel:131114"),
            ("sexual_health", "Healthdirect", "https://www.healthdirect.gov.au/sexual-health"),
            ("gp", "GP", None),
            ("drugs", "Alcohol and Drug Foundation", "https://adf.org.au"),
            ("assault", "1800RESPECT", "tel:1800737732"),
            ("lgbtq", "QLife", "https://qlife.org.au"),
        ],
    },
    "XX": {
        "emergency": None,
        "items": [
            ("emergency", None, None),
            ("crisis", "Find a Helpline", "https://findahelpline.com"),
            ("sexual_health", None, None),
            ("gp", None, None),
            ("drugs", "TripSit", "https://tripsit.me"),
            ("assault", None, None),
            ("lgbtq", None, None),
        ],
    },
}

# The order countries appear in the picker. "XX" is the anywhere-else fallback
# and always sits last.
COUNTRY_ORDER = ["NL", "BE", "DE", "GB", "IE", "FR", "ES", "US", "AU", "XX"]

# The language each country's service names are actually written in. Used to tag
# them with `lang` when they appear on a page in a different language, so a
# screen reader pronounces "Zelfmoordpreventie" as Dutch rather than sounding it
# out in English. Belgium is listed as Dutch because the services carried here
# are the Flemish ones.
COUNTRY_LANG = {"NL": "nl", "BE": "nl", "DE": "de", "GB": "en", "IE": "en",
                "FR": "fr", "ES": "es", "US": "en", "AU": "en", "XX": "en"}


COUNTRY_NAMES = {
    "en": {"NL": "Netherlands", "BE": "Belgium", "DE": "Germany", "GB": "United Kingdom",
           "IE": "Ireland", "FR": "France", "ES": "Spain", "US": "United States",
           "AU": "Australia", "XX": "Somewhere else"},
    "nl": {"NL": "Nederland", "BE": "België", "DE": "Duitsland", "GB": "Verenigd Koninkrijk",
           "IE": "Ierland", "FR": "Frankrijk", "ES": "Spanje", "US": "Verenigde Staten",
           "AU": "Australië", "XX": "Ergens anders"},
    "de": {"NL": "Niederlande", "BE": "Belgien", "DE": "Deutschland", "GB": "Vereinigtes Königreich",
           "IE": "Irland", "FR": "Frankreich", "ES": "Spanien", "US": "Vereinigte Staaten",
           "AU": "Australien", "XX": "Anderswo"},
    "fr": {"NL": "Pays-Bas", "BE": "Belgique", "DE": "Allemagne", "GB": "Royaume-Uni",
           "IE": "Irlande", "FR": "France", "ES": "Espagne", "US": "États-Unis",
           "AU": "Australie", "XX": "Ailleurs"},
    "es": {"NL": "Países Bajos", "BE": "Bélgica", "DE": "Alemania", "GB": "Reino Unido",
           "IE": "Irlanda", "FR": "Francia", "ES": "España", "US": "Estados Unidos",
           "AU": "Australia", "XX": "En otro lugar"},
}


# --------------------------------------------------------------------------
# User-visible strings
# --------------------------------------------------------------------------
#
# One module per language, so a translation can be read and edited on its own
# instead of being hunted for inside a thousand-line dictionary. English is the
# source; every other file is translated from it and carries a note about the
# register it chose.

import lang_en
import lang_nl
import lang_de
import lang_fr
import lang_es

STRINGS = {
    "en": lang_en.S,
    "nl": lang_nl.S,
    "de": lang_de.S,
    "fr": lang_fr.S,
    "es": lang_es.S,
}


def missing_keys():
    """Keys English has that a translation does not. Used by the build."""
    reference = set(STRINGS["en"])
    return {lang: sorted(reference - set(STRINGS[lang]))
            for lang in LANGS if lang != "en" and reference - set(STRINGS[lang])}
