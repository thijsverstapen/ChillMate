# The strings a complete translation file was hiding

*An engineering note from ChillMate, September 2026.*

ChillMate ships in five languages. Its String Catalog reports 2,594 keys, zero
incomplete, zero mismatched, and has done for months. A continuous integration
job checks that on every push and has never gone red for it.

Strings were still reaching people in English. Among them: the notification
telling somebody their PEP window was still open, with the hours remaining in it.
The message that carries your location to a trusted contact. Three medication
reminders for PrEP. The default text of the message you send when you need
someone to come and get you.

None of those were missing translations. Most of them had never been extracted
into the catalog at all, so the completeness check — which reads the catalog and
reports on its contents — had nothing to be incomplete about. A catalog that is
100% translated tells you about the strings that reached it. It tells you nothing
about the ones that did not.

## The checker could only see certain shapes

The gate was a list of regular expressions over the Swift sources, each matching
a shape that localizes a literal:

```python
re.compile(r'String\(\s*localized:\s*"((?:[^"\\]|\\.)*)"'),
re.compile(r'\bText\(\s*"((?:[^"\\]|\\.)*)"\s*\)'),
re.compile(r'\bLabel\(\s*"((?:[^"\\]|\\.)*)"\s*,'),
re.compile(r'\bButton\(\s*"((?:[^"\\]|\\.)*)"\s*\)'),
```

Each literal it found had to exist as a catalog key. That is a real check and it
caught real bugs. What it could not do was notice a string it had no pattern for,
and every gap is silent by construction: an ungated string is not reported as
ungated, it is simply absent from the count.

Six gaps, in the order they were found.

**Interpolation.** The original code skipped any literal containing `\(`, with a
comment explaining that the extracted key could not be derived from the source —
`"Started a \(hours) hour timer"` becomes `"Started a %lld hour timer"` and the
source cannot say whether the placeholder is `%lld` or `%@`. True, and beside the
point: the key does not have to be derived, because both sides reduce to the same
thing once placeholders are blanked. That covered 293 strings. Twenty-one of them
had never been extracted and were shipping in English.

Doing that needs bracket counting rather than a regex, because interpolations
nest:

```swift
"\(hours.formatted(.number.precision(.fractionLength(0...1)))) h"
```

**Ternaries.** `Text("Home")` was checked. `Text(arrived ? "Home" : "Getting
home")` was not, because the pattern wanted a quote immediately after the
bracket. A literal only had to sit inside a conditional to leave the gate behind.

The fix was to stop matching shapes and start reading the language: find the
call, extract its first argument by counting brackets, and check every literal
inside it. Only the first argument, so `Label("Log water", systemImage:
"drop.fill")` does not put an SF Symbol name under translation.

**Controls nobody had listed.** `Picker`, `Toggle`, `TextField` and `Stepper` all
take a label as their first argument and all localize it. None were in the
pattern list. VoiceOver reads every one of them.

**Whole targets.** The Live Activity extension's catalog was checked for
completeness and its sources were checked against nothing at all. That extension
draws the Lock Screen and the Dynamic Island — the most-read surface in the app,
and the one somebody looks at when they are least able to translate in their
head.

**App Intents and widget metadata.** Every `IntentDescription`, every
`LocalizedStringResource` title, every `shortTitle`, every widget's name and
blurb in the gallery. These are read aloud by Siri and shown in the Shortcuts
app. They happened to be translated, because somebody had added them by hand, and
nothing would have noticed when that stopped being true. The one live finding
here was the Focus filter's description and its switch, which appear in iOS
Settings and were in English for everybody.

**A regex cannot read a Swift string.** This one is quieter than the rest. An
interpolation may contain string literals of its own:

```swift
String(localized: "\(count) picture\(count == 1 ? "" : "s") attached")
```

A pattern that stops at the first unescaped quote captures a fragment, then
checks the fragment against the catalog, then reports whatever it finds. It is
not that such strings were unchecked. It is that they were checked against the
wrong text, which is worse, because the check passed.

## Then two shapes no call-site pattern can see

The gate above looks at call sites. Two classes of bug never reach one.

**A literal in a data structure.** ChillMate's PrEP reminders were built like
this:

```swift
let reminders: [(Date, String, String)] = [
    (firstDoseDate, "PrEP reminder", "If around-sex PrEP is prescribed for you, ..."),
    ...
]
```

The strings are passed to a content builder several lines later. They never
appear at a localizing call site, so no pattern over call sites could see them,
and a medication reminder arrived in English in all five languages.

The adjacent case was worse for being half right. The safer-session-plan reminder
reads:

```swift
body: String(localized: "Your safer session plan ends in \(label). ...")
```

The sentence is translated. `label` was `"1 hour"`, `"30 minutes"`, `"10
minutes"`, spelled in English in an array — and used as part of the notification
identifier, so localizing it in place would have produced identifiers that
changed with the reader's language, leaving scheduled reminders nothing could
cancel. It is formatted by Foundation now, and the identifier is built from the
number of seconds.

**A literal assigned to state.** Sixteen strings were put into `@State` variables
and rendered somewhere else entirely:

```swift
permissionMessage = "Face ID lock is enabled."
alertMessage = "Your tip means the world and helps keep ChillMate free and updated."
errorMessage = "Deletion did not finish. Please try again."
```

Four of those are confirmations during first-run setup. One is what the app says
when deleting your account does not finish. And the default text of the message
that goes to a trusted contact was an English literal repeated as the
`@AppStorage` default in three separate files, so a request for help left a Dutch
phone in English, to a Dutch contact.

Both classes are now gated by rules that match the *name being assigned to*
rather than the call: nothing named like something a person reads may take a bare
literal, and no English sentence may appear in the notification service outside
`String(localized:)`, where every user-facing string funnels through one builder.

## And one that was not a literal at all

ChillMate has a helper for rendering String-backed enums:

```swift
extension RawRepresentable where RawValue == String {
    var localizedDisplayName: String {
        Bundle.main.localizedString(forKey: rawValue, value: rawValue, table: nil)
    }
}
```

Six places passed `.rawValue` instead. Every translation was sitting in the
catalog, complete and correct, and nothing was reading it. Dutch users saw
"Horny", "Lonely", "Privacy & lock" — words that had been translated all along.

No literal check could ever have found this, because there is no literal. It
needed its own rule, looking for a `.rawValue` in a position where a person will
read the result.

## What the numbers did

The gate checked 1,963 literals in the app target when this started. It checks
2,594 now, along with 109 across the watch app, the complication and the Live
Activity extension, which were previously checked at 41, 13 and zero.

The catalog was 100% complete the entire time.

## What I would take from it

A completeness check on a translation file is a check on the file. It is not a
check on the code, and the two can disagree indefinitely without anything going
red.

The bugs were not distributed evenly. Every single one was in a shape the checker
could not see — which sounds tautological and is actually the useful part. The
strings inside `Text("...")` were fine, because they were checked. The strings
inside `Text(cond ? "..." : "...")` were not. Coverage is not a percentage of
your code, it is a list of the shapes you thought of, and the interesting
question is not "how much is covered" but "what does my checker not have a
pattern for".

The severity was not distributed evenly either, and not in a comforting
direction. What shipped in English was the PEP window, the location message, the
PrEP reminders, the first-run confirmations and the text somebody sends when they
need collecting. Those strings are written last, live in odd places, and carry
the most weight. That is not a coincidence: the ordinary copy is in the ordinary
place where the ordinary pattern finds it, and the exceptional copy is
exceptional in its construction too.

---

*ChillMate is a private harm-reduction companion for adults who use substances.
No account, no cloud, no network. The checker described here is
`scripts/check_localization.py` in the repository, and it runs on every push.*
