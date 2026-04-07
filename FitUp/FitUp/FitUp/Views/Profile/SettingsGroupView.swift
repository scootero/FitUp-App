//
//  SettingsGroupView.swift
//  FitUp
//
//  Slice 14 — Reusable settings section: section label + glassCard(.base) row group.
//  Matches JSX ProfileScreen groups layout exactly (icon square, label, action widget, dividers).
//

import SwiftUI

// MARK: - Row action

enum SettingsRowAction {
    /// Tappable row with a right-pointing chevron.
    case chevron(_ onTap: () -> Void = {})
    /// Toggle switch bound to external state.
    case toggle(Binding<Bool>)
    /// Right-side NeonBadge pill.
    case badge(String, Color)
}

// MARK: - Single row

/// One row inside a settings group. Matches JSX row layout: icon square → label → action.
struct SettingsRowView: View {
    let sfSymbol: String
    let label: String
    var isDanger: Bool = false
    var showSeparator: Bool = true
    var action: SettingsRowAction = .chevron()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                iconSquare
                Text(label)
                    .font(FitUpFont.body(14))
                    .foregroundStyle(isDanger ? FitUpColors.Neon.pink : FitUpColors.Text.primary)
                Spacer()
                actionWidget
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
            .onTapGesture {
                if case .chevron(let onTap) = action { onTap() }
            }

            if showSeparator {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)
                    .padding(.leading, 54)
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var iconSquare: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isDanger
                      ? FitUpColors.Neon.pink.opacity(0.08)
                      : Color.white.opacity(0.07))
                .frame(width: 28, height: 28)
            Image(systemName: sfSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isDanger ? FitUpColors.Neon.pink : FitUpColors.Text.secondary)
        }
    }

    @ViewBuilder
    private var actionWidget: some View {
        switch action {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.tertiary)

        case .toggle(let binding):
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(FitUpColors.Neon.cyan)

        case .badge(let label, let color):
            NeonBadge(label: label, color: color)
        }
    }
}

// MARK: - Group container

/// Settings group: section label above a glassCard(.base) containing a @ViewBuilder block of rows.
struct SettingsGroupView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(FitUpFont.body(11, weight: .bold))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .kerning(1.5)
                .padding(.bottom, 8)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: FitUpRadius.md)
                    .fill(GlassCardVariant.base.fillGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: FitUpRadius.md)
                            .strokeBorder(GlassCardVariant.base.borderColor, lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.md))
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        BackgroundGradientView()
        ScrollView {
            VStack(spacing: 20) {
                SettingsGroupView(title: "ACCOUNT") {
                    SettingsRowView(sfSymbol: "bell", label: "Notifications",
                                   showSeparator: true,
                                   action: .toggle(.constant(true)))
                    SettingsRowView(sfSymbol: "shield", label: "Privacy",
                                   showSeparator: true,
                                   action: .chevron())
                    SettingsRowView(sfSymbol: "gear", label: "Connected Apps",
                                   showSeparator: false,
                                   action: .chevron())
                }

                SettingsGroupView(title: "DEVELOPER") {
                    SettingsRowView(sfSymbol: "chevron.left.forwardslash.chevron.right",
                                   label: "Dev Mode",
                                   showSeparator: true,
                                   action: .toggle(.constant(false)))
                    SettingsRowView(sfSymbol: "rectangle.portrait.and.arrow.right",
                                   label: "Sign Out",
                                   isDanger: true,
                                   showSeparator: false,
                                   action: .chevron())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
}
