import SwiftUI

/// Labelled text field with validation messaging and correct keyboard behaviour.
struct LoopTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var contentType: UITextContentType?
    var errorMessage: String?
    var isRequired: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.xs) {
            HStack(spacing: 3) {
                LoopEyebrow(text: label)
                if isRequired {
                    Text("*")
                        .font(LoopFont.eyebrow)
                        .foregroundStyle(LoopColor.accent)
                        .accessibilityHidden(true)
                }
            }
            TextField(placeholder, text: $text)
                .font(LoopFont.body)
                .foregroundStyle(LoopColor.ink)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .textContentType(contentType)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .padding(.horizontal, LoopSpacing.md)
                .frame(minHeight: 46)
                .background(LoopColor.surfaceSunken, in: .rect(cornerRadius: LoopRadius.sm))
                .overlay {
                    RoundedRectangle(cornerRadius: LoopRadius.sm)
                        .strokeBorder(
                            errorMessage == nil ? LoopColor.hairline : LoopColor.critical,
                            lineWidth: 1
                        )
                }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(LoopFont.caption)
                    .foregroundStyle(LoopColor.critical)
                    .accessibilityLabel("\(label) error: \(errorMessage)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label + (isRequired ? ", required" : ""))
    }
}

/// Currency field bound to a `Decimal`, with parsing on commit.
struct LoopCurrencyField: View {
    let label: String
    @Binding var value: Decimal
    var currencyCode: String = "USD"
    var isRequired: Bool = false

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.xs) {
            LoopEyebrow(text: label)
            HStack(spacing: LoopSpacing.xs) {
                Text(currencySymbol)
                    .font(LoopFont.amount(17, weight: .medium))
                    .foregroundStyle(LoopColor.inkTertiary)
                TextField("0.00", text: $text)
                    .font(LoopFont.amount(17, weight: .medium))
                    .foregroundStyle(LoopColor.ink)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .onChange(of: text) { _, newValue in
                        value = MoneyFormatter.parse(newValue) ?? 0
                    }
            }
            .padding(.horizontal, LoopSpacing.md)
            .frame(minHeight: 46)
            .background(LoopColor.surfaceSunken, in: .rect(cornerRadius: LoopRadius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: LoopRadius.sm)
                    .strokeBorder(LoopColor.hairline, lineWidth: 1)
            }
        }
        .onAppear {
            if value != 0 { text = "\(MoneyFormatter.rounded(value))" }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label + (isRequired ? ", required" : ""))
    }

    private var currencySymbol: String {
        Locale.current.localizedCurrencySymbol(forCurrencyCode: currencyCode) ?? "$"
    }
}

/// Multiline notes editor.
struct LoopTextEditor: View {
    let label: String
    @Binding var text: String
    var minHeight: CGFloat = 110
    var placeholder: String = "Add notes…"

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.xs) {
            LoopEyebrow(text: label)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(LoopFont.body)
                        .foregroundStyle(LoopColor.inkTertiary)
                        .padding(.horizontal, LoopSpacing.md + 4)
                        .padding(.vertical, LoopSpacing.md)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $text)
                    .font(LoopFont.body)
                    .foregroundStyle(LoopColor.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, LoopSpacing.md)
                    .padding(.vertical, LoopSpacing.sm)
            }
            .frame(minHeight: minHeight)
            .background(LoopColor.surfaceSunken, in: .rect(cornerRadius: LoopRadius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: LoopRadius.sm)
                    .strokeBorder(LoopColor.hairline, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// Horizontal filter chips.
struct LoopFilterChips<Value: Hashable & Identifiable>: View {
    let values: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LoopSpacing.sm) {
                ForEach(values) { value in
                    let isSelected = value == selection
                    Button {
                        LoopHaptics.selection()
                        withAnimation(LoopMotion.quick) { selection = value }
                    } label: {
                        Text(title(value))
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : LoopColor.inkSecondary)
                            .padding(.horizontal, LoopSpacing.md)
                            .padding(.vertical, LoopSpacing.sm)
                            .frame(minHeight: 36)
                            .background(
                                isSelected ? LoopColor.ink : LoopColor.surface,
                                in: .capsule
                            )
                            .overlay {
                                Capsule().strokeBorder(
                                    isSelected ? Color.clear : LoopColor.hairline,
                                    lineWidth: 1
                                )
                            }
                    }
                    .buttonStyle(LoopPressStyle())
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
        .contentMargins(.horizontal, LoopSpacing.gutter, for: .scrollContent)
    }
}

extension Locale {
    func localizedCurrencySymbol(forCurrencyCode code: String) -> String? {
        guard let symbol = Locale.current.currencySymbol,
              Locale.current.currency?.identifier == code else {
            return code == "USD" ? "$" : code
        }
        return symbol
    }
}
