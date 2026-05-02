import Foundation

// MARK: - Candidate Sanitizer

/// サーバーから返ってきた `ExtractionCandidate` をカレンダーに渡す前にサニタイズする。
/// 制御文字除去・長さ制限・日付/時刻フォーマット検証・timezone 検証を行う。
enum CandidateSanitizer {

    // MARK: - Limits

    private static let maxTitleLength = 200
    private static let maxLocationLength = 300
    private static let maxDescriptionLength = 2000

    // MARK: - Public API

    /// 候補を安全な状態に整える。不正な日付/時刻は nil 化する。
    /// title はサニタイズ後に空になる場合があるので最低限のフォールバックを与える。
    static func sanitize(_ candidate: ExtractionCandidate) -> ExtractionCandidate {
        let title = clean(candidate.title, max: maxTitleLength)
            ?? String(localized: "(無題)")
        let location = clean(candidate.location, max: maxLocationLength)
        let description = clean(candidate.description, max: maxDescriptionLength)

        let validatedDate = validateDate(candidate.date)
        // 日付が不正なら時刻も無効化(終日にもできないため)
        let validatedStart: String? = validatedDate == nil ? nil : validateTime(candidate.start_time)
        let validatedEnd: String? = validatedStart == nil ? nil : validateTime(candidate.end_time)

        let resolvedTimezone = validateTimezone(candidate.timezone)

        return ExtractionCandidate(
            candidate_id: candidate.candidate_id,
            note_id: candidate.note_id,
            type: candidate.type,
            title: title,
            date: validatedDate,
            start_time: validatedStart,
            end_time: validatedEnd,
            timezone: resolvedTimezone,
            location: location,
            description: description,
            confidence: candidate.confidence,
            needs_confirmation: candidate.needs_confirmation,
            status: candidate.status
        )
    }

    // MARK: - String Cleaning

    /// 制御文字を除去 (`\n` `\r` `\t` のみ許可)、両端 trim、空なら nil、最大長で truncate。
    private static func clean(_ input: String?, max: Int) -> String? {
        guard let input else { return nil }
        let allowed: Set<Unicode.Scalar.Value> = [0x0A, 0x0D, 0x09]  // LF, CR, TAB
        let filteredScalars = input.unicodeScalars.filter { scalar in
            if allowed.contains(scalar.value) { return true }
            return !CharacterSet.controlCharacters.contains(scalar)
        }
        let cleaned = String(String.UnicodeScalarView(filteredScalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return nil }
        if cleaned.count <= max { return cleaned }
        return String(cleaned.prefix(max))
    }

    // MARK: - Date / Time Validation

    /// `yyyy-MM-dd` フォーマット + 実在日チェック。
    private static func validateDate(_ input: String?) -> String? {
        guard let input, input.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
            return nil
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.isLenient = false
        guard let date = fmt.date(from: input) else { return nil }
        // 往復一致チェックで 2025-02-30 のような無効日付を除外
        guard fmt.string(from: date) == input else { return nil }
        return input
    }

    /// `HH:mm` または `HH:mm:ss` を許容。範囲外は nil。
    private static func validateTime(_ input: String?) -> String? {
        guard let input else { return nil }
        let pattern = #"^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$"#
        guard input.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }
        return input
    }

    /// `TimeZone(identifier:)` で解決可能なものに限定。解決不能なら "Asia/Tokyo" にフォールバック。
    private static func validateTimezone(_ input: String?) -> String {
        if let input, TimeZone(identifier: input) != nil {
            return input
        }
        return "Asia/Tokyo"
    }
}
