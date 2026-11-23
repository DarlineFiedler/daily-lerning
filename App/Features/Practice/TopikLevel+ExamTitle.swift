import Foundation

extension Optional where Wrapped == TopikLevel {
    /// Anzeigetitel für die Prüfungs-Ansicht: der lokalisierte TOPIK-Name der Stufe,
    /// oder das generische „TOPIK", wenn keine Stufe gewählt ist. Vorher byte-identisch
    /// als `levelText` in drei View-Structs von `ExamContainerView`.
    var examTitle: String {
        map { L($0.titleKey) } ?? "TOPIK"
    }
}
