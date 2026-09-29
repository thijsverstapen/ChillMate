import Contacts
import ContactsUI
import SwiftUI
import UIKit
import ChillMateCore

// The system contact picker, for the trusted contact and for partners in a log.

struct PickedContact {
    let name: String
    let phoneNumber: String
}

struct ContactPicker: UIViewControllerRepresentable {
    let select: (PickedContact) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(select: select, dismiss: dismiss)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let select: (PickedContact) -> Void
        let dismiss: DismissAction

        init(select: @escaping (PickedContact) -> Void, dismiss: DismissAction) {
            self.select = select
            self.dismiss = dismiss
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let formattedName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            let phoneNumber = contact.phoneNumbers.first?.value.stringValue ?? ""
            select(PickedContact(name: formattedName, phoneNumber: phoneNumber))
            Task { @MainActor [dismiss] in
                dismiss()
            }
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            Task { @MainActor [dismiss] in
                dismiss()
            }
        }
    }
}
