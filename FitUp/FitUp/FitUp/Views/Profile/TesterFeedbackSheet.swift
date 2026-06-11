//
//  TesterFeedbackSheet.swift
//  FitUp
//

import SwiftUI

enum TesterFeedbackCategory: String, CaseIterable, Identifiable {
    case bug
    case confusingUx = "confusing_ux"
    case featureRequest = "feature_request"
    case positive
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bug: return "Bug"
        case .confusingUx: return "Confusing UX"
        case .featureRequest: return "Feature request"
        case .positive: return "Positive feedback"
        case .other: return "Other"
        }
    }
}

struct TesterFeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var category: TesterFeedbackCategory = .other
    @State private var isSubmitting = false
    @State private var errorText: String?

    let userId: UUID
    var screenName: String?
    var promptHints: [String]?
    var feedbackSource: String = "testflight_sheet"
    var onSuccess: (() -> Void)?

    private var usesPromptHints: Bool {
        guard let promptHints else { return false }
        return !promptHints.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradientView()
                VStack(alignment: .leading, spacing: 16) {
                    if usesPromptHints {
                        Text("Share anything that comes to mind — a few ideas to get you started:")
                            .font(FitUpFont.body(14, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(promptHints ?? [], id: \.self) { hint in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(FitUpFont.body(13, weight: .semibold))
                                        .foregroundStyle(FitUpColors.Neon.cyan.opacity(0.85))
                                    Text(hint)
                                        .font(FitUpFont.body(13, weight: .medium))
                                        .foregroundStyle(FitUpColors.Text.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    } else {
                        Text("What should we know? Bugs, ideas, and rough edges are all welcome.")
                            .font(FitUpFont.body(14, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Picker("Category", selection: $category) {
                            ForEach(TesterFeedbackCategory.allCases) { c in
                                Text(c.label).tag(c)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(FitUpColors.Neon.cyan)
                    }

                    TextEditor(text: $message)
                        .font(FitUpFont.body(15, weight: .regular))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 160)
                        .padding(12)
                        .glassCard(.base)

                    if let errorText {
                        Text(errorText)
                            .font(FitUpFont.body(13, weight: .medium))
                            .foregroundStyle(FitUpColors.Neon.pink)
                    }

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Send feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Send") { Task { await submit() } }
                            .disabled(truncatedMessage.isEmpty)
                    }
                }
            }
        }
    }

    private var truncatedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() async {
        let text = truncatedMessage
        guard !text.isEmpty else { return }
        isSubmitting = true
        errorText = nil
        do {
            let resolvedCategory = usesPromptHints ? "testflight_prompt" : category.rawValue
            var ctx: [String: String] = ["source": feedbackSource]
            if let screenName, !screenName.isEmpty {
                ctx["screen"] = String(screenName.prefix(200))
            }
            try await TesterFeedbackRepository().submit(
                message: String(text.prefix(4000)),
                userId: userId,
                category: resolvedCategory,
                screenName: screenName.map { String($0.prefix(200)) },
                context: ctx
            )
            isSubmitting = false
            ProductAnalytics.track(
                ProductAnalytics.Event.feedbackSubmitted,
                userId: userId,
                properties: ["category": resolvedCategory]
            )
            onSuccess?()
            dismiss()
        } catch {
            isSubmitting = false
            errorText = "Couldn’t send. Check your connection and try again."
            AppLogger.log(
                category: "network",
                level: .warning,
                message: "tester_feedback insert failed",
                userId: userId,
                metadata: ["error": error.localizedDescription]
            )
        }
    }
}
