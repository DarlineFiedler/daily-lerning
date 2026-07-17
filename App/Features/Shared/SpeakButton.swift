import SwiftUI

/// Kleiner Lautsprecher-Button, der einen Text vorliest (Standard: Koreanisch).
/// Blendet sich aus, wenn für die Sprache keine Stimme installiert ist.
struct SpeakButton: View {
    let text: String
    var language: String = "ko-KR"
    var font: Font = .appTitle3
    var tint: Color = Theme.brandStart

    var body: some View {
        if SpeechService.isAvailable(language: language) {
            Button {
                SpeechService.shared.speak(text, language: language)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(font)
            }
            .buttonStyle(.plain)
            .foregroundStyle(tint)
            .accessibilityLabel(L("speak.label"))
        }
    }
}
