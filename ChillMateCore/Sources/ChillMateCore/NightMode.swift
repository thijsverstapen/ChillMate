import Foundation

/// The small hours, as one decision instead of three scattered clock checks.
///
/// The app made this judgement in three places and made it differently in each:
/// Get Help escalated between midnight and five, the reality check used the same
/// window, and the tool ordering treated everything before four in the morning as
/// *before* a night out. That last one is the app misreading the room — somebody
/// reading this screen at 2am is out, not planning to go out, and "Heading out?
/// Set up first" is the wrong sentence to put in front of them.
///
/// Pure and testable so the window is stated once and can be argued with.
public enum NightMode {

    /// Midnight to five. The hours when the tools that matter are the ones for
    /// being out, and when a crisis is likeliest.
    public static let smallHours = 0..<5

    /// Six in the evening to midnight: the hours people actually plan in.
    public static let preNightHours = 18..<24

    /// Whether it is the middle of the night.
    public static func isActive(at date: Date = .now, calendar: Calendar = .current) -> Bool {
        smallHours.contains(calendar.component(.hour, from: date))
    }

    /// Whether the clock alone suggests somebody is getting ready rather than
    /// already out.
    public static func isPreNight(at date: Date = .now, calendar: Calendar = .current) -> Bool {
        preNightHours.contains(calendar.component(.hour, from: date))
    }
}
