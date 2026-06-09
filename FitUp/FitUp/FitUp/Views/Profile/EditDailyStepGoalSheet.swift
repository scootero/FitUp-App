//
//  EditDailyStepGoalSheet.swift
//  FitUp
//
//  Shared daily step goal editor (Profile, Stats hero card, etc.).
//

import SwiftUI

struct EditDailyStepGoalSheet: View {
    let initialGoal: Int
    var onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @State private var saveError: String?
    @FocusState private var fieldFocused: Bool

    init(initialGoal: Int, onSave: @escaping (Int) -> Void) {
        self.initialGoal = initialGoal
        self.onSave = onSave
        _draft = State(initialValue: "\(initialGoal)")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Used for Home and Stats goal lines and readiness. Stored on this device only.")
                    .font(FitUpFont.body(13))
                    .foregroundStyle(FitUpColors.Text.secondary)

                TextField("Daily steps", text: $draft)
                    .keyboardType(.numberPad)
                    .focused($fieldFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .foregroundStyle(FitUpColors.Text.primary)
                    .background(
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .fill(FitUpColors.Bg.base.opacity(0.55))
                            .overlay(
                                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )

                if let saveError, !saveError.isEmpty {
                    Text(saveError)
                        .font(FitUpFont.body(13, weight: .medium))
                        .foregroundStyle(FitUpColors.Neon.pink)
                }

                Spacer()
            }
            .padding(20)
            .background(BackgroundGradientView())
            .navigationTitle("Daily Step Goal")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .fitUpKeyboardDoneToolbar { fieldFocused = false }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        fieldFocused = false
                        saveError = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        fieldFocused = false
                        let normalized = draft
                            .replacingOccurrences(of: ",", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        guard let goal = Int(normalized), goal >= 1_000, goal <= 200_000 else {
                            saveError = "Enter a value between 1,000 and 200,000."
                            return
                        }
                        ReadinessGoals.saveStepsGoal(goal)
                        onSave(goal)
                        saveError = nil
                        dismiss()
                    }
                }
            }
        }
    }
}
