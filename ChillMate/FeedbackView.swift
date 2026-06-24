import MessageUI
import SwiftUI
import UIKit

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    let showsBackButton: Bool

    init(showsBackButton: Bool = false) {
        self.showsBackButton = showsBackButton
    }

    @State private var topic: FeedbackTopic = .bug
    @State private var message = ""
    @State private var replyEmail = ""
    @State private var isShowingMailComposer = false
    @State private var statusMessage: String?
    @State private var isShowingNoMailAlert = false

    private let recipient = "chillmate@icloud.com"

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool { !trimmedMessage.isEmpty }

    // Subject and body are intentionally in English: they land in the developer's inbox.
    private var emailSubject: String { "ChillMate feedback (\(topic.rawValue))" }

    private var emailBody: String {
        var lines = [trimmedMessage, "", "", "----------"]
        lines.append("Topic: \(topic.rawValue)")
        let trimmedReply = replyEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedReply.isEmpty {
            lines.append("Reply to: \(trimmedReply)")
        }
        lines.append("App: ChillMate \(appVersion) (\(appBuild))")
        lines.append("iOS: \(UIDevice.current.systemVersion)")
        lines.append("Device: \(UIDevice.current.model)")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ZStack {
            DashboardBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(
                        title: String(localized: "Feedback"),
                        subtitle: String(localized: "Report a bug, share an idea, or ask a question. Your app version is added automatically."),
                        symbol: "envelope.fill",
                        tint: Color.chillIconTeal
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("What's it about?")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.chillText)

                        Picker("What's it about?", selection: $topic) {
                            ForEach(FeedbackTopic.allCases) { topic in
                                Text(topic.title).tag(topic)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassSurface(radius: 24, tint: .black.opacity(0.04))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your message")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.chillText)

                        TextField("Share as much detail as you like", text: $message, axis: .vertical)
                            .lineLimit(5...)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Color.chillText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassSurface(radius: 24, tint: .black.opacity(0.04))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your email (optional)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.chillText)

                        TextField("So I can reply to you", text: $replyEmail)
                            .textFieldStyle(.plain)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(Color.chillText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassSurface(radius: 24, tint: .black.opacity(0.04))

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: submit) {
                        Text("Send feedback")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                (canSubmit ? Color.chillPrimary : Color.chillSecondary.opacity(0.6)),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                    }
                    .buttonStyle(ChillPlainButtonStyle())
                    .disabled(!canSubmit)

                    Text("Tapping send opens an email with your message and your app version already filled in, ready for you to send.")
                        .font(.caption)
                        .foregroundStyle(Color.chillTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if showsBackButton {
                ToolbarItem(placement: .topBarLeading) {
                    BackChevronButton { dismiss() }
                }
            }
        }
        .sheet(isPresented: $isShowingMailComposer) {
            MailComposeView(recipient: recipient, subject: emailSubject, body: emailBody) { result in
                switch result {
                case .sent:
                    statusMessage = String(localized: "Thanks, your feedback was sent.")
                    message = ""
                    replyEmail = ""
                case .failed:
                    statusMessage = String(localized: "That didn't send. Please try again.")
                default:
                    break
                }
            }
        }
        .alert(String(localized: "No mail account found"), isPresented: $isShowingNoMailAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("No email account is set up on this device. You can email chillmate@icloud.com directly.")
        }
    }

    private func submit() {
        guard canSubmit else { return }

        if MFMailComposeViewController.canSendMail() {
            isShowingMailComposer = true
        } else if let url = mailtoURL() {
            UIApplication.shared.open(url)
        } else {
            isShowingNoMailAlert = true
        }
    }

    private func mailtoURL() -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: emailSubject),
            URLQueryItem(name: "body", value: emailBody)
        ]
        return components.url
    }
}

enum FeedbackTopic: String, CaseIterable, Identifiable {
    case bug
    case idea
    case question
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bug:
            String(localized: "Bug")
        case .idea:
            String(localized: "Idea")
        case .question:
            String(localized: "Question")
        case .other:
            String(localized: "Other")
        }
    }
}

/// Wraps the system mail composer so feedback can be sent in-app with everything pre-filled.
/// iOS does not allow sending mail without the user's explicit tap, so this presents the
/// composer (recipient, subject, and body already populated) and reports the result back.
struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let onFinish: (MFMailComposeResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([recipient])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void

        init(onFinish: @escaping (MFMailComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish(result)
            controller.dismiss(animated: true)
        }
    }
}
