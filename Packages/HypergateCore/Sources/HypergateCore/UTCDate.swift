import Foundation

public enum UTCDate {
    public static func parse(_ text: String) throws -> Date {
        let pattern = #"^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
            throw CoreError.invalidArgument("Use an ISO 8601 date with seconds and an explicit offset or Z.")
        }
        func group(_ index: Int) -> String {
            let range = match.range(at: index)
            return range.location == NSNotFound ? "" : ns.substring(with: range)
        }
        guard let year = Int(group(1)), let month = Int(group(2)), let day = Int(group(3)),
            let hour = Int(group(4)), let minute = Int(group(5)), let second = Int(group(6)),
            (1...12).contains(month), (1...31).contains(day), (0...23).contains(hour),
            (0...59).contains(minute), (0...59).contains(second) else {
            throw CoreError.invalidArgument("Invalid civil date or unsupported leap-second spelling.")
        }
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(secondsFromGMT: 0) else { throw CoreError.invalidArgument("UTC unavailable.") }
        calendar.timeZone = utc
        let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard let civil = calendar.date(from: parts),
            calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: civil) == parts else {
            throw CoreError.invalidArgument("Invalid calendar date.")
        }
        let zone = group(8)
        var offset = 0
        if zone != "Z" {
            let numbers = zone.dropFirst().split(separator: ":")
            guard numbers.count == 2, let hours = Int(numbers[0]), let minutes = Int(numbers[1]),
                hours <= 14, minutes < 60, hours < 14 || minutes == 0 else {
                throw CoreError.invalidArgument("Invalid UTC offset.")
            }
            offset = (hours * 3600 + minutes * 60) * (zone.first == "-" ? -1 : 1)
        }
        let fraction = group(7).isEmpty ? 0 : (Double("0." + group(7)) ?? 0)
        return civil.addingTimeInterval(fraction - Double(offset))
    }
    public static func string(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(string(date))
        }
        return encoder
    }
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try parse(decoder.singleValueContainer().decode(String.self))
        }
        return decoder
    }
}
