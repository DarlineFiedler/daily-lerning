import Foundation

/// Kleine Testhilfe: erzeugt ein Datum, das `self` Kalendertage in der Zukunft liegt.
/// Wird genutzt, um den „nur +1 pro Tag"-Tageswechsel in Lern-Tests zu simulieren.
extension Int {
    var daysFromNow: Date {
        Calendar.current.date(byAdding: .day, value: self, to: .now) ?? .now
    }
}
