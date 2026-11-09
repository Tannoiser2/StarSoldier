# StarSoldier, versione digitale

Versione digitale di **StarSoldier: Tactical Warfare in the 25th Century** (SPI, 1977, di Tom Walczyk con la
grafica di Redmond A. Simonsen), il gioco tattico della trilogia di *StarForce* e *Outreach*: pochi
StarSoldier in tuta da battaglia attiva, piani segreti e simultanei con i punti di compito.

Si gioca nel browser: https://tannoiser2.github.io/StarSoldier/ (e dalla ludoteca https://tannoiser2.github.io).

## Cosa c'è

- **Gioco base**: il Primo contatto con i L'Chal Dah (2451), con i dieci segnalini di civili, la ricerca, il
  trasporto e i rinforzi umani.
- **Gioco standard**: turno in due stadi, comunicazioni di comando, livelli di preservazione, granate
  opacizzanti, missili cercatori (anche nascosti come mine), supporto orbitale (bombardamento, raffica laser,
  bombe opacizzanti), piattaforme di supporto con il cannone laser e la registrazione, androidi, Rame con gli
  sciami killer, Xenofobi con le bombe al neutrone, basi e civili.
- **Tutti gli scenari** del regolamento: le situazioni di Pattuglia, Ricognizione e Assalto per ogni
  guerra dal 2405 al 2487 (scegliendo le fazioni e chi fa Alpha o Bravo), la sconfitta degli Xenofobi (2785),
  il Dinkblog di Delta Pavonis e l'assalto alla Stazione Zulu (bordi uniti, niente atmosfera).
- **Mappa 3D** con la mappa originale del modulo TTS: i soldati alle tre quote (a terra, volo radente su uno
  stelo, alta quota), percorsi e colpi dei piani disegnati sulla mappa, raggio delle esplosioni. Due grafiche:
  **originale** (le pedine SPI, fronte a terra e retro in volo, e la plancia dei punti di compito) e **Reborn**
  (miniature 3D per ogni specie, alberi, rocce ed edifici, effetti di luce per fuoco ed esplosioni).
- Comandi della mappa con mouse e **tocco su iPad**: un dito trascina, due dita pizzicano per lo zoom e
  ruotano; rotella e tasto destro con il mouse.
- **IA** per qualsiasi lato, **gioco a turno** sullo stesso dispositivo con piani segreti, **online** con
  piani simultanei (Firebase), **salvataggi** su Firebase con un codice di sei lettere, **replay** finale.
- Regolamento in italiano e tabelle dentro il gioco (`assets/regole.md`).

## Struttura

- `scripts/data/ss_data.gd`: terreno della mappa (letto dai colori della mappa del modulo TTS), specie,
  organizzazione delle unità, tabelle.
- `scripts/data/scenari.gd`: gli scenari con le forze, i livelli di preservazione, basi, mine e supporto orbitale.
- `scripts/core/hex.gd`: geometria della mappa (numerazione XXYY, distanze, linee di fuoco, diagramma di dispersione).
- `scripts/core/engine.gd`: la sequenza di gioco e tutte le regole.
- `scripts/core/ai.gd`: avversario automatico.
- `scripts/ui/`: menu, schermata di gioco, scena 3D (`board3d.gd`), miniature Reborn (`models.gd`), regole e tabelle.
- `scripts/net/`: Firebase (stanze `starsoldier/rooms`, salvataggi `starsoldier/partite`) e partita online in
  lockstep. Usa le strutture comuni della ludoteca, quindi non servono regole nuove nel database.

## Note

- L'organizzazione delle unità (25.1) non è leggibile nella scansione del regolamento: è ricostruita dal gioco
  base e dal numero di pedine (vedi le note in fondo alle regole del gioco).
- Il gioco collegato con *StarForce* (41.0) non è incluso.

## Prove

```
godot --headless --path . -s tests/autoplay.gd                 # tutti gli scenari, IA contro IA
godot --headless --path . -s tests/autoplay.gd -- 30 P 5       # uno scenario, una situazione, più partite
godot --headless --path . -s tests/salva_carica.gd             # un salvataggio rigioca la stessa partita
xvfb-run godot --path . -s tests/shot.gd -- 30 R originale 4 /tmp/foto.png 1 auto
python3 tests/firebase_mock.py 8765                            # e tests/online_play.gd: partita online
python3 tools/controlla_glifi.py                               # ogni carattere esiste nei font
xvfb-run godot --path . -s tests/tocco.gd                     # tocco su iPad e mouse sulla mappa
```

## Pubblicazione

Il workflow `Pubblica` parte a mano (Actions, Pubblica, Run workflow) oppure con un commit su `main` il cui
messaggio contiene `[pubblica]`: costruisce la versione web con Godot 4.7 e la mette su GitHub Pages (e sulla
ludoteca privata Cloudflare se ci sono i segreti).
