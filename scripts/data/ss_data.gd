class_name SSData
extends RefCounted
## Dati di StarSoldier (SPI, 1977): terreno della mappa, caratteristiche delle specie, tabelle e scenari.

# ---------------------------------------------------------------- terreno
## Una riga per ogni riga XX della mappa (01 in basso, 39 in alto), un carattere per colonna YY:
## . sereno, b accidentato, o copertura organica, m montagna, u urbano, l lago.
## Ricavato dai colori della mappa del modulo TTS (gli edifici dai simboli stampati).
const TERRAIN := [
	".........bbb.............................bmmmmmmmm....",  # 01
	".........bbb...................u........bmmmmmmmm.... ",  # 02
	"..........bb...................b........bbmmmmmmm.....",  # 03
	"..........b...bb...........u..bb........bbmmmmm...... ",  # 04
	"...............bb.............bbu.......bbbmmmb.......",  # 05
	"...............bb.....oo....mbbb.......lllbbbb....b.. ",  # 06
	".......................oo....mbmb......llllbbb....bb..",  # 07
	"..oo...................o.....mbmb.....lllll.......... ",  # 08
	".......................uu.....mbmb....llllll..........",  # 09
	".........u.....oo.....uuu.....mbbb....llllll......... ",  # 10
	".........uu...oooo...uuuuu.....mbb.....lllll..........",  # 11
	".............obboo...uuuu..............llll.....uu... ",  # 12
	".............obmboo....uu................ll...........",  # 13
	".............obboo...........u..ooo.................. ",  # 14
	"...............oo................ooo..................",  # 15
	"....bb..........u..............moooo...bbb........... ",  # 16
	"....bb......ll.................mmooo...bbbb.......b...",  # 17
	"...bbb.....ll.................mmmoo....bbb.......bbbb ",  # 18
	"....bb......ll..b..............bmooo...mbb.......bbbbb",  # 19
	"..................u..........bbboooooomm........bbbbb ",  # 20
	"..........b.oo.....u.........bbbbboooomm..........bbbb",  # 21
	".........bbmooo....u........bbbbbbooooo...u.......bbb ",  # 22
	"..........bmmooo.............bbbbbboooo...............",  # 23
	"..........mmmoo..............bbbbbooo.........u...... ",  # 24
	"............mmobbbb...........bbbbooo.................",  # 25
	"...u.......mmobbbbb.........u.bbbbooo........oooooo.. ",  # 26
	".............obbbbbb...........bbb.ooo........oooooo..",  # 27
	"........b....bbbbbb...............ooooo.......ooooo.. ",  # 28
	"........b.....bbbbbbb.....o.......ooooooo....u.oooo...",  # 29
	"...............bbb.......oooo.........oo........oo... ",  # 30
	"..oooo...................mooo.........................",  # 31
	"oooooo.........................................b..... ",  # 32
	"ooooooooo...u.......u..........................b......",  # 33
	"ooooooooo...u...o......................bb............ ",  # 34
	"oooooooooo......ooooo...........u.......b.............",  # 35
	"ooooooooo..............................b......u...... ",  # 36
	"ooooooooo..............................b..............",  # 37
	"ooooooooo................ooo......................... ",  # 38
	"ooooooooo................oooo.........................",  # 39
]

const T_NAME := {".": "sereno", "b": "accidentato", "o": "copertura organica", "m": "montagna", "u": "urbano", "l": "lago", "c": "cratere"}
const T_VALUE := {".": 1, "b": 2, "o": 3, "m": 6, "u": 6, "l": 2, "c": 2}


static func terrain(h: int) -> String:
	var r := h / 100
	var c := h % 100
	if r < 1 or r > 39 or c < 1 or c > 54:
		return "."
	var s: String = TERRAIN[r - 1]
	return s[c - 1]


# ---------------------------------------------------------------- specie
## [TPA, efficienza, recupero] (6.41 gioco base, 6.42 gioco standard)
const BASIC := {"h": [5, 2, 1], "l": [6, 2, 1]}
const STANDARD := {"h": [9, 2, 3], "l": [12, 2, 1], "r": [6, 4, 2], "x": [9, 1, 1]}
const SPECIES_NAME := {"h": "Umani", "l": "L'Chal Dah", "r": "Rame", "x": "Xenofobi"}
const KIND_NAME := {"ss": "StarSoldier", "hw": "Armi pesanti", "an": "Androide", "pl": "Piattaforma di supporto", "base": "Base", "dink": "Dinkblog"}
const KIND_PREFIX := {"ss": "Ss", "hw": "Hw", "an": "An"}
## numeri delle pedine disponibili per serie di pedine e tipo
const COUNTER_NUMS := {
	"h": {"ss": [101, 102, 103, 104, 105, 106, 107, 108, 109, 111, 112, 113, 114, 115, 116, 117], "hw": [121, 122, 123, 124, 125], "an": [131, 132, 133, 134, 135, 136, 137, 138]},
	"l": {"ss": [201, 202, 203, 204, 205, 206, 207, 208, 209, 211, 212, 213, 214], "hw": [221, 222, 223, 224], "an": [231, 232, 233, 234, 235, 236, 237, 238]},
	"r": {"ss": [301, 302, 303, 304, 305, 306, 307, 308, 309, 311, 312, 313], "hw": [], "an": [331, 332, 333, 334, 335, 336, 337, 338]},
	"x": {"ss": [401, 402, 403, 404, 405, 406, 407, 408, 409, 411, 412, 413], "hw": [], "an": []},
}

## Organizzazione delle unità (25.1). La tabella non è leggibile nella scansione del regolamento: la
## composizione è ricostruita dal gioco base (Squadra L'Chal Dah di 7 con 2 armi pesanti, Squadra di fuoco
## umana di 5 con un'arma pesante) e dal numero di pedine. Il primo soldato di ogni gruppo è il capo.
const ORG := {
	"FT": {"nome": "Squadra di fuoco", "h": ["ss", "ss", "ss", "ss", "hw"], "l": ["ss", "ss", "ss", "hw"]},
	"S": {"nome": "Squadra", "h": ["ss", "ss", "ss", "ss", "ss", "ss", "ss", "ss", "hw", "hw"], "l": ["ss", "ss", "ss", "ss", "ss", "hw", "hw"], "r": ["ss", "ss", "ss", "ss", "ss", "ss"], "x": ["ss", "ss", "ss", "ss", "ss", "ss", "ss", "ss", "ss", "ss", "ss", "ss"]},
	"HV": {"nome": "Sezione armi pesanti", "h": ["hw", "hw"], "l": ["hw", "hw"]},
	"AD": {"nome": "Squadra di androidi", "h": ["an", "an", "an", "an"], "l": ["an", "an", "an", "an"], "r": ["an", "an", "an", "an"]},
	"SW": {"nome": "Sciame killer", "r": ["ss", "ss", "ss"]},
	"PL": {"nome": "Piattaforma di supporto", "h": ["pl"], "l": ["pl"], "r": ["pl"]},
}

# ---------------------------------------------------------------- tabelle
## 9.8 Fuoco, gioco base: righe 2-12, colonne +1..+6
const FIRE_BASIC := [
	[4, 5, 6, 6, 6, 6], [3, 4, 5, 6, 6, 6], [2, 3, 4, 5, 5, 6], [1, 2, 3, 3, 4, 4], [0, 1, 2, 3, 3, 4],
	[0, 1, 2, 2, 3, 3], [0, 0, 1, 2, 2, 3], [0, 0, 1, 1, 2, 2], [0, 0, 0, 1, 1, 2], [0, 0, 0, 0, 1, 1], [0, 0, 0, 0, 0, 0],
]
## 26.1 Fuoco, gioco standard: righe 2-12, colonne +1..+9
const FIRE_STD := [
	[8, 10, 12, 12, 12, 12, 12, 12, 12], [6, 8, 10, 12, 12, 12, 12, 12, 12], [4, 6, 8, 10, 11, 12, 12, 12, 12],
	[2, 4, 6, 7, 8, 9, 10, 11, 12], [1, 3, 5, 6, 7, 8, 9, 10, 11], [0, 2, 4, 5, 6, 7, 8, 9, 10],
	[0, 1, 3, 4, 5, 6, 7, 8, 9], [0, 0, 2, 3, 4, 5, 6, 7, 8], [0, 0, 1, 2, 3, 4, 5, 6, 7], [0, 0, 0, 1, 2, 2, 3, 3, 3], [0, 0, 0, 0, 0, 0, 0, 0, 0],
]
## Armi lanciate (10.5 base, 26.2 standard): colonne 1-5, 6-10, 11-15, 16-20, 21-25, 26+; -1 = stordito
const LW_BASIC := [
	[3, 4, 5, 6, 6, 6], [2, 3, 4, 5, 6, 6], [1, 2, 3, 4, 5, 6], [-1, 2, 2, 3, 4, 5], [-1, 1, 2, 3, 4, 5],
	[-1, -1, 1, 2, 3, 4], [0, -1, 1, 2, 3, 4], [0, -1, -1, 1, 2, 3], [0, 0, -1, 1, 1, 1], [0, 0, 0, -1, -1, -1], [0, 0, 0, 0, 0, 0],
]
const LW_STD := [
	[6, 8, 10, 12, 12, 12], [4, 6, 8, 11, 12, 12], [2, 4, 6, 8, 10, 12], [1, 3, 5, 7, 9, 11], [-1, 2, 4, 6, 8, 10],
	[-1, 1, 3, 5, 7, 9], [0, -1, 2, 4, 6, 8], [0, -1, 1, 3, 5, 7], [0, 0, -1, 2, 3, 3], [0, 0, 0, -1, -1, -1], [0, 0, 0, 0, 0, 0],
]
## 10.4 Dispersione: righe dado 1-6, colonne differenziale -1..-6 (o meno); 0 = colpisce, n = esagoni
const SCATTER := [
	[0, 0, 0, 0, 0, 1], [0, 0, 0, 0, 1, 1], [0, 0, 1, 1, 1, 2], [0, 1, 1, 1, 2, 2], [1, 1, 1, 2, 2, 3], [1, 2, 2, 2, 3, 3],
]
## 10.24 Intercettazione dei missili a volo libero: righe dado 1-6, colonne 1-10, 11-15, 16-20, 21+
const INTERCEPT := [
	[true, true, true, true], [false, true, true, true], [false, false, true, true], [false, false, false, true], [false, false, false, false], [false, false, false, false],
]
## 21.5 Danni alle piattaforme: 2-7 nessuno, 8-9 TPA dimezzato, 10-11 cannone laser distrutto, 12 distrutta
static func platform_damage(roll: int) -> String:
	if roll <= 7:
		return "nulla"
	if roll <= 9:
		return "dimezza"
	if roll <= 11:
		return "laser"
	return "distrutta"


static func fire_result(diff: int, roll2: int, std: bool) -> int:
	if diff < 1:
		return 0
	var t: Array = FIRE_STD if std else FIRE_BASIC
	var cols: int = 9 if std else 6
	return t[roll2 - 2][mini(diff, cols) - 1]


static func lw_column(ratio: float) -> int:
	var r := int(floor(ratio + 1e-6))
	if r < 1:
		return -1
	return clampi((r - 1) / 5, 0, 5)


static func lw_result(ratio: float, roll2: int, std: bool) -> int:
	var c := lw_column(ratio)
	if c < 0:
		return 0
	var t: Array = LW_STD if std else LW_BASIC
	return t[roll2 - 2][c]


static func scatter(diff: int, die: int) -> int:
	if diff >= 0:
		return 0
	return SCATTER[die - 1][clampi(-diff, 1, 6) - 1]


static func intercepted(value: int, die: int) -> bool:
	if value <= 0:
		return false
	var c := 0 if value <= 10 else (1 if value <= 15 else (2 if value <= 20 else 3))
	return INTERCEPT[die - 1][c]
