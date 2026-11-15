# Calendar Lock

Deine heutigen Termine und Erinnerungen auf dem iPhone-Sperrbildschirm.

Die App zeichnet die Termine aus allen Kalendern auf dem iPhone (iCloud, Google, Outlook …) und deine offenen Erinnerungen in ein Hintergrundbild. Eine Kurzbefehle-Automation setzt das Bild jeden Morgen als Sperrbildschirm. iOS erlaubt Apps nicht, das Hintergrundbild selbst zu wechseln. Alles bleibt auf dem Gerät, es gibt kein Konto und keinen Server.

## Projekt öffnen

Voraussetzungen: ein Mac mit Xcode 16 oder neuer und ein iPhone mit iOS 17 oder neuer.

Das Xcode-Projekt wird mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml` erzeugt und deshalb nicht eingecheckt.

```sh
brew install xcodegen
xcodegen
open CalendarLock.xcodeproj
```

Team (`DEVELOPMENT_TEAM`) und Bundle-ID (`de.joerg.calendarlock`) stehen in `project.yml`, die Signierung läuft automatisch. Wer mit einem anderen Apple-Konto baut, ändert beides dort und führt `xcodegen` erneut aus. Dann in Xcode das iPhone wählen und starten.

Die Tests laufen mit ⌘U oder:

```sh
xcodebuild test -scheme CalendarLock -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Einrichtung auf dem iPhone

1. App öffnen und Zugriff auf Kalender und Erinnerungen erlauben.
2. Kurzbefehle-App › *Automation* › *+* › *Tageszeit*, z. B. 6:00 Uhr täglich, *Sofort ausführen*.
3. Aktion *Kalender-Hintergrund erstellen* (Calendar Lock) hinzufügen.
4. Danach *Hintergrundbild festlegen* hinzufügen, Sperrbildschirm wählen und *Vorschau zeigen* ausschalten.

## Aufbau

| Ordner | Inhalt |
| --- | --- |
| `CalendarLock/Model` | Datenmodell, Sortier- und Platzlogik, Einstellungen |
| `CalendarLock/Services` | Kalender und Erinnerungen (EventKit), Wetter (Open-Meteo), eigenes Foto |
| `CalendarLock/Rendering` | Hintergrundbild als SwiftUI-View, gezeichnete Motive, Wetterleiste, Monatsübersicht |
| `CalendarLock/Intents` | Aktion für die Kurzbefehle-App (App Intents) |
| `CalendarLock/Views` | Oberfläche: Vorschau, Einstellungen, Einrichtungshilfe |
| `CalendarLockTests` | Unit-Tests für die Logik |

## Funktionen

- Termine und Erinnerungen von heute, auf Wunsch auch von morgen
- Kalenderwoche (ISO, „KW 46“) neben dem Datum und eine Monatsübersicht mit KW-Spalte; Tage mit Terminen haben einen Punkt
- Hintergründe: Verlauf, Polarlicht, Dünen, Sterne, Wellen und Lichter, in sechs Farbthemen gezeichnet und jeden Tag leicht verändert, oder ein eigenes Foto
- Wetter für 5 Tage direkt unter der Uhr, Ort per Suche. Die Vorhersage wird zwischengespeichert, damit die Automation am Morgen auch ohne Netz etwas anzeigt.
- Vorschau in der App und die Kurzbefehle-Aktion

Wetterdaten: [Open-Meteo.com](https://open-meteo.com) (CC BY 4.0). Die kostenlose Schnittstelle ist nur für nicht-kommerzielle Nutzung gedacht. Für eine kostenpflichtige App im App Store sollte das Wetter auf Apples WeatherKit oder einen Open-Meteo-Tarif umgestellt werden.

Noch offen: App-Icon, Countdowns, Lokalisierung (Englisch) und der App-Store-Auftritt.
