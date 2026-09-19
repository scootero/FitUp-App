import SwiftUI

struct ModerationReasonSheet: View {
    let title: String
    let onSubmit: (ModerationReason) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: ModerationReason?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List(ModerationReason.allCases) { reason in
                Button { selectedReason = reason } label: {
                    HStack { Text(reason.title); Spacer(); if selectedReason == reason { Image(systemName: "checkmark") } }
                }
                .disabled(isSubmitting)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSubmitting) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Sending…" : "Submit") { Task { await submit() } }
                        .disabled(selectedReason == nil || isSubmitting)
                }
            }
            .alert("Report Not Sent", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "Please try again.") }
        }
    }

    @MainActor private func submit() async {
        guard let selectedReason else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do { try await onSubmit(selectedReason); dismiss() }
        catch { errorMessage = "The report could not be sent. Please try again." }
    }
}

