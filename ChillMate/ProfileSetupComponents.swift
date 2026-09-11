import SwiftUI

/// The form rows the profile wizard and the intro are both built from.
///
/// Split out of `ProfileSetupView.swift` unchanged. They were already internal
/// rather than private, which is what made them the obvious seam.

struct ProfileSetupHeroCard: View {
    let contentWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 64, height: 64)

                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text("Private")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.14), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Let’s make it yours")
                    .chillScaledFont(size: 36, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Add the details that help ChillMate feel personal, useful, and clear. Nothing has to be perfect right away.")
                    .font(.callout)
                    .lineSpacing(2)
                    .foregroundStyle(.white.opacity(0.80))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(width: contentWidth, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            Color.chillPrimary.opacity(0.20),
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.26), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 24, y: 14)
    }
}

struct ProfileSetupSectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(Color.chillSecondary)

            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color.chillText)

            Text(subtitle)
                .font(.footnote)
                .lineSpacing(2)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A hairline separator between flat rows inside a setup card, inset to line up
/// under the row text (past the leading icon) the way iOS grouped lists do.
struct ProfileSetupRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
            .padding(.leading, 50)
    }
}

struct ProfileSetupTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String
    var axis: Axis = .horizontal

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillMint)

                TextField(placeholder, text: $text, axis: axis)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                    .tint(Color.chillPrimary)
                    .lineLimit(axis == .vertical ? 1...4 : 1...1)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            Stepper(value: $value, in: range) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillMint)

                    Text("\(value) years old")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                }
            }
            .tint(.chillPrimary)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupMeasurementRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            Stepper(value: $value, in: range, step: 1) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillMint)

                    Text("\(Int(value.rounded())) \(unit)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                }
            }
            .tint(.chillPrimary)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupPickerRow<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillMint)

                content
                    .pickerStyle(.menu)
                    .tint(Color.chillText)
                    .font(.body.weight(.semibold))
                    .fixedSize()
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(.chillPrimary)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupDateRow: View {
    let title: String
    @Binding var date: Date
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            DatePicker(title, selection: $date, displayedComponents: [.date])
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .tint(.chillPrimary)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.chillMint)
            .frame(width: 38, height: 38)
            .background(Color.chillMint.opacity(0.16), in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.chillMint.opacity(0.34), lineWidth: 1)
            }
    }
}
