import Foundation

public enum InviteCode {
    public static let length = 6
    /// Letters and numbers that are hard to mix up out loud. No 0/O or 1/I.
    public static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    public static func generate() -> String {
        var generator = SystemRandomNumberGenerator()
        return generate(using: &generator)
    }

    public static func generate<R: RandomNumberGenerator>(using generator: inout R) -> String {
        String((0..<length).map { _ in
            alphabet[Int(generator.next(upperBound: UInt64(alphabet.count)))]
        })
    }

    /// Accepts lowercase and ignores spaces or dashes. Returns nil when the
    /// code isn't six characters from the alphabet above.
    public static func normalize(_ raw: String) -> String? {
        let cleaned = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard cleaned.count == length else { return nil }
        guard cleaned.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return cleaned
    }

    public static func spokenGroups(_ code: String) -> String {
        guard code.count == length else { return code }
        let mid = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<mid]) \(code[mid...])"
    }
}

private extension RandomNumberGenerator {
    mutating func next(upperBound: UInt64) -> UInt64 {
        precondition(upperBound > 0)
        return next() % upperBound
    }
}
