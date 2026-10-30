# Token Overdrive · 0.9.8

A playful, local-first macOS dashboard for Codex token activity, RSS headlines,
pixel galleries and tiny arcade breaks. It turns the wait between prompt and
answer into a small desktop escape.

## What works today

- Reads **local Codex JSONL session logs** from `~/.codex` and displays TOTAL
  and TRIP token counters. No API key, account credential, prompt or response
  content is read, uploaded or stored by Token Overdrive.
- The simulated engine, speedometer and optional local microphone response are
  driven by the observed local activity. They are playful visualisations, not
  billing or quota instruments.
- RSS feeds are fetched only after the user explicitly selects a source. Games
  and pixel galleries are fully local.

## Important limitation

Token Overdrive does **not** read normal ChatGPT conversations, prompts or
responses. Those are not exposed as local logs. A future optional OpenAI sign-in
may show only activity that the app is officially authorised to access; it will
never imply access to a person's ChatGPT history.

## Build locally

Run `./build.sh` in the repository root. It compiles the app, ad-hoc signs the
local build and runs the integrated regression suite. The resulting app is for
local testing; it is not yet notarized or App Store distributed.

## Assets and licence

The code is released under the [MIT License](LICENSE). The included Token
Overdrive branding and local pixel-art resources are part of this repository and
may be used under the same licence when redistributing the project. No remote
image service is used by the galleries.

## Release notes

## 0.43.0

Neu im Glasmenü ist **BILDER** mit drei vollständig lokalen Pixel-Galerien: **California Girls**, **Beach Boys** und **Ugly Monsters**, jeweils mit zwölf originalen 16-Bit-inspirierten Illustrationen. Die Galerie braucht weder RSS noch eine Netzwerkverbindung. Beim automatischen Wechsel sowie beim Blättern schließt sich erst ein grobes Pixelraster über die Karte und gibt anschließend das nächste Motiv wieder frei. Die Motive liegen als mitgelieferte Ressourcen in der App; es werden dabei keine externen Bilder geladen.

## 0.44.0

Die Bildfolge wechselt nun automatisch und gleichmäßig alle sechs Sekunden. Es gibt keine Vor-/Zurück-Navigation mehr; die drei kleinen farbigen Punkte wählen weiterhin direkt zwischen den drei Galerien. Der rechenintensive Pixelvorhang wurde durch eine weichere, vorab geladene Überblendung ersetzt. Die Karten zeigen die hochformatigen Motive jetzt vollständig ohne Beschnitt. Das Drei-Punkte-Menü hat eine deutlich größere unsichtbare Klickfläche; doppelte Spielnamen in der linken Navigation wurden entfernt.

## 0.90.0 · Release Candidate

Die sichtbare App-Oberfläche ist vollständig auf Englisch umgestellt. Das Glasmenü sitzt optisch höher, das Cockpit-Menü ist auf die eigentlichen MVP-Bedienelemente reduziert und der auswählbare Datenordner sowie Verbrauchsdetails sind aus dem Menü entfernt. RSS-Karten sind jetzt reine, größere Textkarten ohne Bildfläche. Der neue kleine **R**-Knopf rechts oben an der Mitte zeigt zufällig eine RSS-Überschrift, eine Galerie oder eines der drei Spiele.

## 0.91.0

Feinschliff für den Release Candidate: Der feste Random-Knopf sitzt jetzt unabhängig vom jeweiligen Karteninhalt an derselben Stelle und nutzt eine dezente plastische Oberfläche. Galerie-Karten sind vollständig typofrei und ohne Farbrahmen. Spiele-, Galerie- und Cockpit-Menü zeigen nur noch die notwendigen Bedienelemente. Das Cockpit wurde als Ganzes leicht höher ausgerichtet, die Drei-Punkte-Fläche weiter vergrößert.

## 0.92.0

Der Random-Knopf orientiert sich nun an der weichen, erhöhten quadratischen Buttonform des Referenzdesigns. Eine RSS-Quelle im Menü beendet zuverlässig jede offene Spiel- oder Galerieansicht und zeigt wieder die zentrale RSS-Karte. Das Cockpitfenster ist 390 px hoch und lässt den zusätzlichen Bereich unten bewusst weiß und ruhig auslaufen.

## 0.93.0

Der sichtbare R-Button ist nochmals um etwa 15 % kleiner und höher an einer festen Position angeordnet. Der Drei-Punkte-Auslöser besitzt nun eine weit größere, unsichtbare Klickfläche im oberen linken Bereich, ohne das Cockpitlayout zu verschieben.

## 0.94.0

Die sichtbaren drei Punkte sitzen wieder oben links, während die großzügige Klickfläche bestehen bleibt. Der R-Button verwendet nun eine absolute Position im festen Cockpitrahmen; ein Wechsel zwischen RSS, Galerie und Spielen kann seine Lage nicht mehr beeinflussen.

## 0.96.0

Das Cockpit-Menü trägt jetzt die neue Marke **Token Overdrive**: links unten als leichte Kapitälchen-Navigation am Einstellungs-Icon und rechts als kompakte TO-Wortmarke. Die Bedienung darunter beginnt bewusst etwas tiefer. Schalter, Checkboxen und der Lautstärke-Regler nutzen ein dunkles Grau statt macOS-Blau.

## 0.97.0

Beim Start erscheint für eine Sekunde ein Token-Overdrive-Splash mit Version 0.9 unten rechts. Die App verwendet jetzt außerdem das flache TO-Zeichen als vollständiges macOS-App-Icon in allen notwendigen Auflösungen.

## 0.9.0

Die Anwendung, das Fenster und die Menüleiste heißen nun durchgängig **Token Overdrive**. Das Cockpit-Menü rendert die freigegebene TO-Wortmarke direkt aus der Vektorquelle; sie kann nicht mehr in Einzelteile auseinanderfallen. Eine dezente Versionszeile im Menü zeigt `VERSION 0.9` und spielt den Start-Splash bei Klick erneut ab.

## Open source

Token Overdrive is released under the [MIT License](LICENSE). Local Codex logs
remain local. Future optional ChatGPT sign-in will be used only for activity
that Token Overdrive itself is allowed to access; it does not grant access to a
person's ChatGPT conversations or prompts.

## 0.9.8 · Stability & documentation

The public documentation now names the product and its current release
correctly, makes the local Codex-only scope explicit and documents the status
panel in Cockpit settings. The status reports the selected local source, log
count, latest observed event and last scan time. `Check Source` performs an
immediate scan without sending anything to a network service. Branding and
public links use **Ollifolio** consistently.

## 0.9.7 · Microphone response

Microphone mode now owns the engine response even while Codex is working: synthesized engine playback remains stopped, so the mic can safely drive the RPM needle without a feedback loop. The speech range is expanded and the settings menu shows the live input percentage for an immediate signal check.

## 0.9.6 · Input repair and connection notice

The Version action now opens the splash in its own stable three-second presentation rather than compositing it over the closing menu. When microphone mode is on and Codex is idle, microphone input takes priority over a coasting motor, restoring voice-driven RPM. On first launch, an English information dialog explains the future optional ChatGPT account connection and its privacy boundary; it does not claim to connect an account before a reliable integration exists.

## 0.9.5 · Calm replay and ChatGPT account placeholder

Replaying the splash from the Version control now fades in and out without a flash. Cockpit settings also reserve a transparent, optional ChatGPT-account area. It clearly states that no chat content will be read or stored; the account connection itself waits for a reliable App Store-compatible integration.

## 0.9.4 · Automatic local connection

The local build again discovers `~/.codex` automatically, exactly like the last known-working release. **Codex Folder** remains available only when a different local folder needs to be selected.

## 0.9.3 · Working build

The Version control now replays the Token Overdrive splash for three seconds. This build preserves the verified local Codex connection and its local-source diagnostics.

## 0.9.2 · Local source diagnostics

The Cockpit settings now show a clear local-source status: whether a `.codex` folder was selected, whether readable session logs were found, and the time of the latest observed event. **Check Source** runs an immediate local scan. This makes a missing local-data connection visible without guessing.

## 0.9.1 · App Store candidate

Die finalen Markenquellen sind `Resources/TokenOverdrive-Wordmark.svg` und `Resources/TokenOverdrive-AppIcon.svg`. Das Menü enthält nun einen Privacy-&-Legal-Bereich mit den geplanten Ollifolio-Links. Tokenwerte werden erst nach einer bewussten Auswahl des lokalen `.codex`-Ordners gelesen; die vorbereiteten Sandbox-Entitlements erlauben dafür ausschließlich einen nutzergewählten Lesezugriff und Netzwerkzugriff für ausdrücklich gewählte RSS-Feeds.

## 0.95.0

Eine erfolgreich geprüfte benutzerdefinierte RSS-Adresse wird nun dauerhaft als oberster Quellen-Eintrag gespeichert. Die Quellenliste lässt sich bei vielen eigenen Feeds scrollen. Der Mittelbereich erhält eine feste Höhe, damit ein Random-Wechsel zwischen Feed, Galerie und Spielen die beiden großen Instrumente nicht mehr vertikal verschiebt. Die Feed-Statuszeile ist vollständig englisch.

## Cockpit

- **Links: Drehzahlmesser**, rechts: **Geschwindigkeitsmesser**. U/min, km/h und Gänge sind eine spielerische Simulation nach Aufgabenstatus und Token-Last, keine physikalische Token-Umrechnung.
- Normale Aufgaben beschleunigen grob auf 90 km/h. Höhere Last erhöht das Ziel. Beim Schalten fällt die Drehzahl kurz; nach Aufgabenende rollt das Auto aus.
- **TOTAL** zählt echte lokale Eingabe- und Ausgabe-Tokens einschließlich Cache. Cache ist bereits Teil der Eingabe und wird nicht doppelt addiert; Reasoning ist bereits in der Ausgabe enthalten.
- **TRIP** zählt echte Tokens seit dem manuellen Reset über alle lokalen Chats hinweg. Stand und Baseline bleiben bei App-Neustarts erhalten. Reset löscht keine Protokolle und verändert TOTAL nicht. Gelöschte historische Logs oder ein geänderter Datenordner können den lokalen Stand verändern.
- Mitte: simulierter Gang, km/h und echte Tokens/Sekunde (10-Sekunden-Mittelwert).
- Das Fenster lässt sich am Hintergrund ziehen. Einstellungen oben rechts: im Vordergrund halten, oben/unten andocken, Details und CSV-Export.

## Mikrofon und Sound

Mikrofon ist beim Start aus. Über **Mikrofon** aktivieren und den macOS-Mikrofonzugriff erlauben. Ohne laufende Aufgabe lässt die Stimme den Motor im Stand hochdrehen. Nur der momentane Lautstärkepegel wird im Speicher ausgewertet. Keine Aufnahme, Spracherkennung, Audiodateien oder Netzwerkübertragung. Die App kann nicht zwischen eigener Stimme und anderen Geräuschen unterscheiden. Gleichzeitige Mikrofonverwendung durch die ChatGPT-Sprachfunktion ist geräteabhängig und muss praktisch getestet werden.

**Ton** schaltet einen lokal synthetisierten Motorsound ein. Tonhöhe folgt der simulierten Drehzahl. Standardmäßig aus; Ton-Einstellung und Lautstärke werden gespeichert. Bei aktivem Mikrofon läuft der Sound während Aufgaben und beim anschließenden Ausrollen. Die Mikrofon-Pegelmessung ist während dieser Wiedergabe angehalten und wird danach automatisch wieder aktiviert. Im Stand wird die Stimme somit ohne Eigenanregung durch den Motorsound ausgewertet. Keine Tastaturüberwachung.

## Daten und Grenzen

Quelle: `~/.codex/sessions` und `archived_sessions`, Protokolle als unkomprimierte JSONL. Aktualisierung einmal pro Sekunde, nach dem ersten Einlesen inkrementell. Chat-Titel optional aus `session_index.jsonl`. Kein API-Schlüssel, kein lokaler Webserver, keine zusätzlichen API-Aufrufe. `auth.json` wird nicht gelesen. Die App verändert keine Codex-Dateien und speichert keine Chat-Inhalte.

Kumulative Nutzungsstände werden als positive Differenzen gezählt. Wiederholte oder rückläufige Snapshots werden nicht doppelt gezählt; letztere führen zu einer Warnung in den Details. Aktive und archivierte Kopien derselben Sitzungs-ID werden dedupliziert. Der erste Stand bei Fork-Metadaten dient als Baseline. Komplexe Replay-Formate, zusätzliche Compaction-Records, komprimierte `.zst`-Logs und fehlende Cloud-Chats werden nicht rekonstruiert. Der erste historische kumulative Stand wird zeitlich dem ersten Ereignis zugerechnet. Keine vollständige Kontostatistik, Rechnung oder Aboauslastung.

## Bauen / Tests

Quelle: `native/TokenTacho.swift`. `./build.sh` kompiliert, signiert und führt die integrierten Tests aus. `"Token Tacho.app/Contents/MacOS/TokenTacho" --diagnose` prüft reale lokale Daten und gibt ausschließlich Summen aus. Die Tests prüfen Deduplizierung, Cache, Fork-Baseline, unvollständige Zeilen, inkrementelles Lesen, Neustart, Dateikürzung, Aufgabenstart/-ende, Beschleunigung, Schaltabfall, Ausrollen und TRIP-Isolation.

Mikrofonberechtigung und reale Audioausgabe sind interaktive Funktionen; die Berechtigung wird erst bei Klick angefragt. Ein Test ohne Audiohardware kann die Klangqualität oder die gleichzeitige Nutzung mit ChatGPT nicht bestätigen.

## 0.4.1

Mikrofon und Ton: grün bei eingeschalteter Funktion; grau mit durchgestrichenem Icon bei ausgeschalteter Funktion. Die Beschriftung zeigt keine Pause mehr. Mikrofon-Grün bedeutet aktiviert, nicht durchgehend abhörend: während des Motorsounds ruht die Pegelmessung. Motorsound folgt der simulierten Drehzahl bei Aufgabenbearbeitung, Gangwechsel und Ausrollen.

## 0.4.2

Optische Überarbeitung: schlankere Instrumentenringe, weniger Nebenstriche, ruhige Regular-Ziffern und dezente Graphit-Tiefe. Die rote Lichtsignatur bleibt. TOTAL-Beschriftung kleiner und Regular; rechter Zähler „TRIP TOKENS“. Reset-Knopf mit plastischer Oberfläche und gedrücktem Zustand. Keine Änderung an Daten, Audio oder Fahrlogik.

## 0.4.3

Stärker leuchtender roter Grenzbereich. Titel, Versionsnummer, Aufgabenstatus und Erklärungstext sind aus dem Cockpit ausgeblendet; Version und Einstellungen bleiben im Menü. Mikrofon und Ton unten links nur noch als beschriftete zugängliche Icons mit Tooltips. Fahrlogik und Sound unverändert; km/h und Drehzahl bleiben Simulationen.

## 0.4.4

Zählerbeschriftung auf „TOKENS INKL. CACHE“ gekürzt. Reset-Button mit glänzender oberer Reflexion und stärkerer Lichtkante. Keine Änderung an Fahrt oder Sound.

## 0.5.0

Animierte kurvige Nachtstraße zwischen den Instrumenten, Bewegung abhängig von der simulierten Geschwindigkeit. Die Straßenkrümmung beeinflusst Zieltempo und Gangwahl; Gaswechsel verändern Drehzahl und Sound gemeinsam. Es ist eine visuelle Simulation ohne echte Karte oder GPS.

Die Zähler im Cockpit interpolieren ganzzahlig zwischen gemeldeten Ständen über höchstens 2,4 Sekunden. Bei hohen Raten können pro Bild mehrere Tokens weitergezählt werden; sie laufen nicht um erfundene zukünftige Tokens voraus. Nach der letzten Meldung entspricht der angezeigte Stand exakt den lokalen Messdaten. TOTAL und TRIP nutzen dieselbe animierte Basis; Reset-Baseline und CSV-Export bleiben exakt und ungerundet. Die Detailansicht zeigt die gemessenen Stände ohne Animation.

## 0.6.0

Helles, um rund 20 % kompakteres Cockpit in Schwarz, Weiß und Grautönen. Die beiden großen Instrumente behalten rote Zeiger mit schwarzer Nabe; Rot erscheint darüber hinaus nur als kurzer Akzent am Horizont der animierten Pixel-Landschaft. Die mittlere Straße ist nun eine gleichmäßig gerasterte, abstrakte Schwarz-Weiß-Landschaft mit stärkeren Kurven.

TRIP RESET sitzt klein direkt unter dem TRIP-Zähler. Beim Reset läuft der TRIP-Zähler bis zum nächsten vollen 100.000er-Stand weiter und rollt damit sichtbar auf `00000`; die gespeicherte Baseline wird erst am Ende dieser Animation gesetzt.

Neu ist ein kleines Tankinstrument oberhalb links am Geschwindigkeitsmesser. Es zeigt bewusst `—`, solange keine unterstützte Quelle für die verbleibende Codex-/ChatGPT-Nutzungsquote verbunden ist. Lokale Protokolle enthalten ausschließlich bereits verarbeitete Tokens; die App schätzt keinen verbleibenden Kontostand.

## 0.7.0

Die großen Instrumente sind wieder klarer als Tacho und Drehzahlmesser lesbar: numerische Skalen, rote Zeiger, schwarzer Nabenkreis und ein roter Grenzbereich. Der Geschwindigkeitsmesser beschriftet die Skala von 0 bis 300 ohne zusätzliche Einheit. TOTAL und TRIP liegen als kleinere, überlappende, sanft gewölbte Zählerfelder auf den unteren Instrumentenrändern.

Die Mitte ist nun eine hochformatige Pause-Feed-Karte mit monochromer, abstrahierter Bildfläche, Headline und Quellenzeile; die Netzwerk-Anbindung von RSS-Feeds folgt separat. Das Menü verwendet oben rechts drei Punkte. Dosis wird als Schriftdatei mit der App ausgeliefert und beim Start registriert.

## 0.8.0

Die Feed-Karte lädt beim Start den öffentlichen RSS-Feed des Postillon. Sie zeigt nur die Überschrift, Quellenzeile, direkte Artikeladresse und ein im Feed angegebenes Vorschaubild; per Klick wird der Originalartikel im Browser geöffnet. In den drei Punkten kann eine andere RSS-Adresse eingetragen und aktualisiert werden. Die App übermittelt dabei keine lokalen Codex-Daten an Feed-Anbieter.

TOTAL und TRIP haben keine weißen Hintergrundflächen mehr und liegen frei auf den Instrumenten. Die Zähleranimation hat mindestens 0,9 Sekunden Laufzeit und bleibt nach spätestens 2,4 Sekunden auf dem gemessenen Stand. Tankanzeige oben rechts, Drei-Punkte-Menü oben links, größere Feed-Karte und größere Abstände vervollständigen das Layout.

## 0.9.0

Die Card zeigt nur noch das im RSS-Feed angegebene Vorschaubild. Während es lädt oder wenn ein Feed kein Bild liefert, bleibt die Bildfläche neutral; eine künstliche Pixel-Ersatzgrafik wird nicht mehr gezeigt.

Die Tankanzeige ist nun eine lokale Verbrauchsprognose: Ein konfigurierbares Arbeitsbudget (Standard: 50.000 Tokens) wird anhand der gemessenen Zehn-Sekunden-Tokenrate in eine geschätzte Restzeit übersetzt. Der kleine Zeiger fällt mit dem lokalen Budget und erreicht einen roten Reservebereich. Budget und Baseline lassen sich im Menü zurücksetzen. Das ist ausdrücklich keine ChatGPT-/Codex-Kontolimit-Anzeige. Der lokale Protokollabgleich läuft viermal pro Sekunde; Zählerstände werden weiterhin ausschließlich aus echten Token-Snapshots gebildet und nach spätestens 2,4 Sekunden exakt erreicht.

## 0.10.0

Breiteres 800-Pixel-Fenster mit größeren Zwischen- und Außenabständen. TRIP RESET steht wieder unterhalb des rechten Instruments. Das Postillon-Vorschaubild wird explizit heruntergeladen, geprüft und dargestellt; bei einem Fehler zeigt die Card ein kleines Bildsymbol statt einer stillen leeren Fläche. Der FUEL-Startwert wird bei diesem Update einmalig auf den aktuellen echten Verbrauchsstand zurückgesetzt, damit ein alter lokaler Tank nicht sofort im roten Bereich startet.

## 0.11.0

Die Feed-Verarbeitung liest mehrere RSS-Beiträge, lädt das zugehörige Vorschaubild vorab und wechselt alle 2,5 Sekunden zum nächsten Beitrag. Kleine Punkte unter der Card zeigen die verfügbaren Beiträge und erlauben die Rückkehr zu einem vorherigen Post. Die Card sitzt 16 px höher; TRIP RESET liegt 8 px höher unterhalb des rechten Instruments.

## 0.12.0

Neue echte Tokenstände unterbrechen die laufende TOTAL-Animation nicht mehr: Das Ziel wird fortgeschrieben, während die sichtbare Zahl kontinuierlich nachläuft. TRIP verwendet nun denselben fortlaufenden Rollmechanismus relativ zur gespeicherten Reset-Baseline. Beide Anzeigen basieren weiterhin ausschließlich auf lokalen Token-Snapshots; sie zeigen keine vorausberechneten Tokens an.

## 0.15.0

Der Zählerkern verarbeitet schnell aufeinanderfolgende echte Snapshots als ein fortlaufendes Ziel statt als neu gestartete Animationen. TOTAL und TRIP wachsen während des Nachlaufs sichtbar weiter und werden nach dem letzten Snapshot exakt auf den gemessenen Stand gesetzt. Integrierte Tests simulieren mehrere neue Stände im Viertelsekundentakt und prüfen sichtbares Zwischenwachstum sowie den exakten Endstand.

## 0.16.0

Während eine lokale Codex-Aufgabe aktiv ist, ergänzen TOTAL und TRIP einen kleinen, begrenzten visuellen Nachlauf zwischen gebündelten Protokoll-Snapshots. Echte Stände bleiben stets die Autorität. Sobald die Aufgabe endet, gleichen sich beide Anzeigen innerhalb kurzer Zeit an den exakt gemessenen Stand an. Ein Regressionstest prüft explizit diesen aktiven Nachlauf sowie die exakte Rückkehr auf TOTAL und TRIP.

## 0.17.0

TRIP ist nun ein strikt monotoner Kilometerzähler: Nur bestätigte lokale Token-Snapshots erhöhen seinen Zahlenwert. Ein geringerer oder verspäteter Stand darf ihn nicht absenken. Der visuelle Vorlauf zwischen Snapshots bleibt ausschließlich bei TOTAL; TRIP kann nur durch den manuellen Reset auf `00000` zurückrollen.

## 0.19.0

TRIP verarbeitet bestätigte lokale Tokenstände jetzt als mechanische Warteschlange: keine künstlichen Vorlauf-Tokens, keine Pause bei einem kleinen Cap und keine Sprünge bei großen, verzögert gelesenen Log-Blöcken. Große Deltas rollen mit fester Odometer-Geschwindigkeit durch; weitere bestätigte Deltas werden hinten angehängt. Rückwärts läuft TRIP ausschließlich beim manuellen Reset auf `00000`.

## 0.19.1

Beim Start übernimmt TRIP seinen bereits gespeicherten Iststand sofort und still. Historische Differenzen werden nicht mehr nachträglich wie neue Fahrt abgerollt. Erst Tokenstände, die nach dieser ersten lokalen Synchronisierung eintreffen, werden sichtbar durch die mechanische Warteschlange gezählt.

## 0.20.0

TRIP verwendet jetzt exakt denselben kontinuierlichen Animationskern wie TOTAL. Der einzige Unterschied ist die gespeicherte TRIP-RESET-Baseline: TOTAL zählt den Gesamtstand, TRIP zählt den Gesamtstand ab dieser Baseline. Ein Reset bei einem echten Stand von null löst keine Animation mehr aus.

## 0.21.0

Fahrstil, Tacho, Drehzahl und Sound bewerten nun ausschließlich neue Eingabe-Tokens sowie stärker gewichtete Ausgabe-/Reasoning-Tokens. Cache-Tokens bleiben korrekt in TOTAL und TRIP enthalten, lösen aber keine künstliche Volllast mehr aus. Die oberen Gänge werden erst durch hohe nachhaltige Arbeitsrate oder ungefähr 240.000 neue Arbeits-Tokens innerhalb einer aktiven Aufgabe erreicht.

## 0.22.0

Tacho- und Drehzahlnadel haben nun einen dezenten Trägheitsimpuls beim Beschleunigen und Schalten und pendeln danach weich ein. Der RSS-Bereich ist kein wiederholender Fünfer-Kreisel mehr: Er zeigt die aktuelle Nachricht plus höchstens zwei vorherige Beiträge als kleinen Verlauf. Nach fünf Minuten wird der Feed neu geladen; sobald die Quelle neue Beiträge veröffentlicht, rücken diese nach. Ohne neue RSS-Inhalte bleibt die aktuelle Card stehen.

## 0.23.0

Der Postillon-Startpool kann bis zu 50 aktuelle RSS-Beiträge laden und zeigt sie im Zehn-Sekunden-Takt einmalig vorwärts statt in einer kurzen Schleife. Die Punkte unter der Card erlauben weiterhin nur den Rückweg über die zwei unmittelbar vorherigen Beiträge. Bei frei eingetragenen RSS-Quellen verwendet die App die Anzahl Beiträge, die deren Feed liefert. Der FAHRSTIL-Zeiger reagiert bei leichter aktiver Fahrt dezent auf Drehzahl und Tempo, bleibt dabei im grünen Bereich und erreicht die höheren Zonen weiterhin nur durch gemessene neue Modellarbeit.

## 0.24.0

Der Postillon-Pool lädt nun drei paginierte Feed-Seiten à 20 Beiträge und kann damit bis zu 50 unterschiedliche Cards vorhalten; sichtbar bleibt weiterhin nur ein Rückweg über zwei Beiträge. Der Card-Wechsel ist als kurze räumliche Bewegung ausgeführt: die bisherige Card verschwindet leicht nach hinten, die nächste kommt aus der Tiefe weich nach vorn.

## 0.25.0

Der Card-Wechsel verwendet nun nur noch eine kurze Skalierungs- und Verschiebebewegung und vermeidet die rechenintensive 3D-Rotation. Das macht den Wechsel schneller und ruhiger. Die Bildsuche überspringt die Tracking-Pixel, die der Postillon vor den eigentlichen Artikelbildern einfügt, und übernimmt nur noch die echte Blogger-Vorschau. Späte Bild-Downloads dürfen außerdem keine inzwischen angezeigte Card mehr überschreiben.

## 0.26.0

Die erste Feedseite wird nun sofort angezeigt; die weiteren Postillon-Seiten werden parallel und nachträglich in den Pool ergänzt, sodass der Kaltstart nicht mehr auf alle 50 Beiträge warten muss. Die Navigation nutzt links/rechts-Pfeile und eine Positionsanzeige statt Dots. Zurückgehen ist auf zwei bereits gesehene Cards begrenzt, vorwärts läuft durch den gesamten Pool. Bilder werden URL-basiert gecacht, mit einem Bild-Accept-Header geladen und nur übernommen, solange ihre Card noch aktiv ist. Der Card-Wechsel verwendet eine einzelne, gerichtete 60/160-ms-Tiefenbewegung.

## 0.27.0

TOTAL und TRIP zeigen beim App-Start sofort den zuletzt lokal gemessenen Stand und werden anschließend durch den ersten Protokollscan abgeglichen. Der Feed ist ein echter Ring: Nach dem letzten Beitrag beginnt er wieder vorn; der Zurück-Pfeil hält nur die zwei tatsächlich zuvor gesehenen Cards vor. Artikelbilder verwenden nun eine auf Card-Größe passende Blogger-Variante, werden im Speicher gecacht und für den nächsten Feed vorab geladen. Das reduziert Download- und Decodierlast beim Wechsel.

## 0.28.0

Die Cockpit-Zähler besitzen zusätzlich einen direkten Anzeige-Fallback auf den letzten lokalen Stand, sodass sie auch während der ersten asynchronen Abfrage nicht mit null erscheinen. Artikelbilder werden mit ImageIO als kleine, vororientierte Vorschau decodiert statt als volles Originalbild. Der Card-Wechsel ist auf einen einzigen SwiftUI-Übergang (Opacity plus minimale Skalierung) reduziert; die früheren verzögerten Zwischenzustände entfallen.

## 0.29.0

Der Bildpfad kehrt für maximale Kompatibilität zur bewährten direkten `NSImage`-Dekodierung der originalen RSS-Bild-URL zurück; Cache und Schutz vor verspäteten Antworten bleiben erhalten. Der Feed wechselt nun alle 2,5 Sekunden. Die Vorschauoptimierung wird erst wieder eingeführt, wenn die Bilder im Cockpit erneut zuverlässig erscheinen.

## 0.30.0

Ein fertig geladenes Artikelbild wird jetzt immer im Cache behalten – auch wenn die Card inzwischen weitergeschaltet hat. Nur das direkte Einsetzen in die sichtbare Card ist an deren Artikel-ID gebunden. Die nächsten zwei Bilder werden unmittelbar vorgeladen. Der Feedwechsel startet in einer expliziten 320-ms-`easeInOut`-Transaktion; die Card-Transition nutzt dieselbe Dauer.

## 0.31.0

Der Bildlader bündelt nun alle parallelen Anforderungen je Artikelbild in genau einen Download. Sichtbare Card und Vorladen warten auf dasselbe Ergebnis; nach erfolgreichem Dekodieren erhalten alle Wartenden das Bild aus einem zentralen Cache. Damit können schnelle Feedwechsel keine konkurrierenden Mehrfach-Downloads oder verlorenen Antworten mehr erzeugen. Der integrierte Feed-Diagnosetest bestätigt für den aktuellen Postillon-Feed: 20 Beiträge, 20 Bild-URLs, HTTP 200 und erfolgreiche JPEG-Dekodierung.

## 0.32.0

Die sichtbare Feed-Card lädt und verwaltet ihr Vorschaubild nun selbst, unabhängig vom Hintergrund-Vorladen und vom Wechselzustand des Cockpits. Sie besitzt einen eigenen URL-basierten Speicher-Cache, übernimmt ein Bild ausschließlich für ihre aktuelle Artikel-URL und füllt die gesamte obere Kartenfläche beschnitten aus. Damit ist der letzte verbliebene Übergabepunkt zwischen Feed-Logik und Darstellung entfernt.

## 0.33.0

Die funktionierende Referenz-App 0.23.0 diente als Vergleich: Ihre Card zeichnet ein vom langlebigen Cockpit-Lader bereitgestelltes Bild. Dieses Modell ist wiederhergestellt. Zusätzlich nutzt der Postillon-Feed jetzt die echte, von Blogger gelieferte `480 × 270`-Variante desselben Artikelbilds statt des mehrmegabytegroßen Originals. So kann der Download vor dem 2,5-Sekunden-Wechsel fertig werden; Quelle, Artikelbild und Link bleiben unverändert.

## 0.34.0

Der langlebige Cockpit-Bildlader nutzt für den Bildabruf nun denselben zeitbegrenzt wartenden Hintergrundmechanismus wie die erfolgreiche integrierte Feed-Diagnose. Bildabruf, Dekodierung und Rückgabe in die sichtbare Card erfolgen damit nicht mehr über einen flüchtigen Callback während eines Card-Wechsels. Mehrere wartende Cards teilen weiter einen einzelnen Abruf pro Bild-URL.

## 0.35.0

Die automatische Card-Dauer beträgt nun 3,8 Sekunden. Das Einstellungsmenü zeigt temporär den Status des sichtbaren Feedbilds: geladen, kein Bild im Artikel oder Abruf-/Dekodierungsfehler. Der letzte Status und die zugehörige Bild-URL werden lokal gespeichert, damit ein Fehler nicht mehr unsichtbar bleibt.

## 0.36.0

Das Drei-Punkte-Menü ist jetzt ein halbtransparentes Glas-Flyout mit eigener **QUELLEN**-Spalte und einer getrennten Cockpit-Spalte. Quellen lassen sich über geprüfte Vorschläge (Der Postillon, TITANIC, Die Tagespresse, The Onion, NewsThump) oder durch Eingabe einer eigenen RSS-Adresse auswählen. Eine Quelle wird erst dauerhaft übernommen, wenn mindestens ein lesbarer RSS-Beitrag gefunden wurde; dabei werden nur öffentliche Feed-Daten abgerufen. Die bestehende Quelle bleibt bei einem fehlgeschlagenen Test aktiv.

## 0.37.0

Das Quellenmenü ist nun ein breites, helles Glas-Overlay innerhalb des Cockpits. Es dimmt und verwischt die Instrumente im Hintergrund leicht, schließt per Klick auf den Rand oder mit Escape und hat eine deutlich größere Klickfläche für die drei Punkte. Die linke Menüordnung lautet **RSS-FEEDS**, **SPIELE** und – unter einer Trennlinie – **COCKPIT**. Pong ist als erstes lokales Pausenspiel spielbar und ersetzt vorübergehend nur die mittlere News-Card; die Schlägersteuerung folgt dem Maus-/Trackpad-Zug. Tic-Tac-Toe ist als nächster Platzhalter sichtbar.

## 0.38.0

Pong ist nun ein echtes Mouse-over-Spiel: Der linke, kräftig gelbe Schläger folgt innerhalb der schwarzen Spielfläche dem Maus-/Trackpad-Zug; rechts spielt ein einfacher Gegner. Punktestand und Ballphysik laufen lokal. Tic-Tac-Toe ist ebenfalls spielbar: Du setzt gelbe X, der Computer antwortet mit O. Beide Spiele ersetzen nur temporär die mittlere Card und kehren über **NEWS** oder Escape zurück.

## 0.39.0

Pong bewertet nun jeden Treffer am gelben Spielerschläger sichtbar: zentraler Treffer grün, mittlerer Versatz orange, Randtreffer rot. Tic-Tac-Toe nutzt ein streng gleichmäßiges Raster; X und O werden als kurze, handgezeichnet wirkende Linien beziehungsweise Kreisbewegung eingeblendet. Der Spielstand bleibt als lokale Session-Zählung `X : O` über „Nochmal“ hinweg erhalten; der kleine Button startet nur die nächste Runde.

## 0.40.0

Tic-Tac-Toe zeichnet X und O nun zusätzlich sofort als sichtbare Grundlinie und animiert darüber die zeichnerische Bewegung; gesetzte Züge bleiben damit auch bei ausbleibender Animation sichtbar. **Star Run** ergänzt die Spielauswahl: Ein gelbes Raumschiff wird per Maus/Trackpad bewegt, Klick feuert. Bei Spielende speichert die lokale Arcade-Hall-of-Fame die fünf besten Namen, Punkte und Daten in den App-Einstellungen. Keine Daten werden übertragen.

## 0.41.0

Die Tic-Tac-Toe-Markierungen sind kontrastreicher; nach einem X wartet der Computer etwa 0,65 Sekunden sichtbar, bevor er O setzt. Star Run verschiebt das Spielerschiff höher und zeichnet beide Schiffe als reduzierte Raumschiffe statt als einfache Dreiecke. Nach einem Highscore-Eintrag verschwindet **SAVE** und wird durch eine Bestätigung ersetzt. Die Top-5-Liste ordnet Name, Score und kompaktes Datum (`TT.MM`) in festen Spalten an, damit nichts mehr abgeschnitten wird.

## 0.42.0

Tic-Tac-Toe zeichnet X und O noch heller. Eine abgeschlossene Runde zeigt oben `NEXT 3`, `NEXT 2`, `NEXT 1` und startet selbstständig neu. Star Run steigert die Schwierigkeit über die Laufzeit: ab rund zehn Sekunden erscheinen lilafarbene, anders geformte Gegner mit 20 % mehr Tempo; ab rund zwanzig Sekunden dunkelgrüne Gegner mit 60 % mehr Tempo. Bei Game Over wird das laufende Spielfeld weichgezeichnet und die Hall-of-Fame als großzügigeres Overlay angezeigt. Nach einem Highscore-Save zählt auch Star Run selbstständig `3–2–1` in die nächste Runde.
