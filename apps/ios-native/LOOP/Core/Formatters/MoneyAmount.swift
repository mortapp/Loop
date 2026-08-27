import Foundation

/// A precise currency value. LOOP never uses binary floating point for money.
nonisolated struct MoneyAmount: Codable, Hashable, Sendable, Comparable {
    var value: Decimal
    var currencyCode: String

    init(_ value: Decimal, currencyCode: String = "USD") {
        self.value = value
        self.currencyCode = currencyCode
    }

    static func usd(_ value: Decimal) -> MoneyAmount { MoneyAmount(value, currencyCode: "USD") }
    static let zero = MoneyAmount(0)

    var isZero: Bool { value == 0 }
    var isNegative: Bool { value < 0 }
    var isPositive: Bool { value > 0 }
    var absolute: MoneyAmount { MoneyAmount(abs(value), currencyCode: currencyCode) }
    var negated: MoneyAmount { MoneyAmount(-value, currencyCode: currencyCode) }

    static func < (lhs: MoneyAmount, rhs: MoneyAmount) -> Bool { lhs.value < rhs.value }

    static func + (lhs: MoneyAmount, rhs: MoneyAmount) -> MoneyAmount {
        MoneyAmount(lhs.value + rhs.value, currencyCode: lhs.currencyCode)
    }

    static func - (lhs: MoneyAmount, rhs: MoneyAmount) -> MoneyAmount {
        MoneyAmount(lhs.value - rhs.value, currencyCode: lhs.currencyCode)
    }

    static func * (lhs: MoneyAmount, rhs: Decimal) -> MoneyAmount {
        MoneyAmount(lhs.value * rhs, currencyCode: lhs.currencyCode)
    }

    static func sum(_ amounts: [MoneyAmount], currencyCode: String = "USD") -> MoneyAmount {
        amounts.reduce(MoneyAmount(0, currencyCode: currencyCode)) { partial, next in
            MoneyAmount(partial.value + next.value, currencyCode: currencyCode)
        }
    }
}

/// Centralized currency + number formatting. One shared set of formatters.
nonisolated enum MoneyFormatter {
    /// "$349.99" — full precision.
    static func string(_ amount: MoneyAmount) -> String {
        amount.value.formatted(.currency(code: amount.currencyCode))
    }

    /// "$350" — no cents, for large summary metrics.
    static func compactString(_ amount: MoneyAmount) -> String {
        amount.value.formatted(
            .currency(code: amount.currencyCode).precision(.fractionLength(0))
        )
    }

    /// "+$86.42" / "−$349.99" — signed, using a true minus sign.
    static func signedString(_ amount: MoneyAmount, showsPlus: Bool = true) -> String {
        let base = string(amount.absolute)
        if amount.isNegative { return "\u{2212}" + base }
        if showsPlus && amount.isPositive { return "+" + base }
        return base
    }

    /// Spoken form for VoiceOver: "plus 86 dollars and 42 cents" style, localized.
    static func accessibleString(_ amount: MoneyAmount, showsSign: Bool = true) -> String {
        let base = amount.absolute.value.formatted(
            .currency(code: amount.currencyCode).presentation(.fullName)
        )
        guard showsSign else { return base }
        if amount.isNegative { return "minus \(base)" }
        if amount.isPositive { return "plus \(base)" }
        return base
    }

    /// Parses free user input ("1,299.50", "$1299.5") into a Decimal.
    static func parse(_ input: String) -> Decimal? {
        let cleaned = input
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Rounds to currency precision (2 fraction digits, bankers-safe plain rounding).
    static func rounded(_ value: Decimal, scale: Int = 2) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
    }
}
