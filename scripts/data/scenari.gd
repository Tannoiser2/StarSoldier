class_name SSScenari
extends RefCounted
## Scenari di StarSoldier: il gioco base (13.0) e gli scenari del gioco standard (28.0-40.5).
## Ogni fazione ha, per ogni situazione generale (P pattuglia, R ricognizione, A assalto), le forze come
## Alpha e come Bravo: unità (FT squadra di fuoco, S squadra, HV sezione armi pesanti, AD squadra di
## androidi, SW sciame Rame, PL piattaforma di supporto), livello di preservazione, mine (missili
## cercatori nascosti) e basi.

const SIT_NAME := {"P": "Pattuglia", "R": "Ricognizione", "A": "Assalto"}
const SIT_TEXT := {
	"P": "La base di Bravo è oltre il bordo Est o Ovest (a caso). Le forze Alpha entrano dal bordo opposto e cercano di uscire dal bordo della base; Bravo entra dal lato della base per fermarle. Alpha prende 2 punti per ogni punto di compito perso da Bravo e 10 per ogni soldato uscito; Bravo prende 3 punti per ogni punto perso da Alpha.",
	"R": "Bravo schiera in segreto le sue forze e la base (o le basi). Alpha entra dal bordo Ovest e deve scoprirle tutte: una base si scopre passando entro quattro esagoni (a terra o in volo radente) o quando spende punti di compito. Se Alpha viene distrutta o non ci riesce entro il limite di turni vince Bravo.",
	"A": "Bravo schiera in segreto forze e basi; Alpha deve distruggere tutte le basi. Se Alpha ha il supporto orbitale attacca dallo spazio: dieci bombardamenti e tre bombe opacizzanti preparano l'assalto e le sue forze scendono in alta quota dove vuole. Altrimenti entra dal bordo Ovest.",
}

const O_FULL := {"b": 4, "l": 2, "o": 2}     # 28.32
const O_HALF := {"b": 2, "l": 1, "o": 1}     # 29.32


static func list() -> Array:
	return [
		{
			"id": 13, "nome": "Primo contatto", "anno": 2451, "base": true,
			"testo": "Gioco base. Una Squadra L'Chal Dah atterra su Eta Cassiopeiae II per catturare umani e ottenere informazioni, cercando di non spargere sangue. Una Squadra di fuoco umana difende i civili rimasti in città. I L'Chal Dah devono trovare un civile vero fra dieci segnalini e portarlo fuori dalla mappa; un civile ucciso da loro è una vittoria decisiva umana.",
			"fazioni": [
				{"nome": "Umani", "razza": "h", "pedine": "h"},
				{"nome": "L'Chal Dah", "razza": "l", "pedine": "l"},
			],
			"scontri": [[1, 0]],
			"situazioni": ["B"],
			"turni": 14,
		},
		{
			"id": 28, "nome": "Schermaglie su Epsilon Indi", "anno": 2405,
			"testo": "La campagna di Epsilon Eridani: la colonia ribelle cerca di prendersi Epsilon Indi e le truppe dell'Egemonia Solare resistono senza StarGate né StarForce. Le città valgono come copertura organica.",
			"fazioni": [
				{"nome": "Egemonia Solare", "razza": "h", "pedine": "h",
					"P": [{"u": "S", "pl": 54}, {"u": "S", "pl": 54}], "hm": "no"},
				{"nome": "Epsilon Eridani", "razza": "h", "pedine": "l", "orb": O_FULL,
					"P": [{"u": "S+HV", "pl": 63}, {"u": "FT+HV", "pl": 32}], "hm": "no"},
			],
			"scontri": [[0, 1]], "situazioni": ["P"], "urbano": "o",
		},
		{
			"id": 29, "nome": "L'ascesa della Lega Umana", "anno": 2415,
			"testo": "La Lega Umana, di frontiera, sfida l'Egemonia Pan-Umana occupando Epsilon Indi. Distrutta la StarForce della Lega, si combatte sulla superficie. Le città valgono come terreno sereno.",
			"fazioni": [
				{"nome": "Egemonia Pan-Umana", "razza": "h", "pedine": "h", "orb": O_HALF, "hm": "mine",
					"P": [{"u": "FT+HV", "pl": 32}, {"u": "FT", "pl": 23, "mine": 2}],
					"R": [{"u": "S", "pl": 54}, {"u": "FT", "pl": 23, "basi": 2, "mine": 3}],
					"A": [{"u": "S+HV", "pl": 63}, {"u": "FT+HV", "pl": 32, "basi": 2, "mine": 4}]},
				{"nome": "Lega Umana", "razza": "h", "pedine": "l", "hm": "no",
					"P": [{"u": "S", "pl": 54}, {"u": "FT+HV", "pl": 32}],
					"R": [{"u": "S", "pl": 54}, {"u": "FT+HV", "pl": 32, "basi": 1}],
					"A": [{"u": "S+HV", "pl": 63}, {"u": "S", "pl": 54, "basi": 1}]},
			],
			"scontri": [[0, 1]], "situazioni": ["P", "R", "A"], "urbano": ".",
		},
		{
			"id": 30, "nome": "Attacco a Tau Ceti", "anno": 2430,
			"testo": "La resa dei conti fra Egemonia Pan-Umana e Lega Umana: l'Egemonia porta la guerra su Tau Ceti, il sistema più popoloso della Lega. Sei segnalini di civili: chi causa più di cinque punti di vittime civili in più dell'avversario perde la partita.",
			"fazioni": [
				{"nome": "Egemonia Pan-Umana", "razza": "h", "pedine": "h", "orb": O_HALF, "hm": "si",
					"P": [{"u": "FT+HV", "pl": 32}, {"u": "FT", "pl": 23, "mine": 2}],
					"R": [{"u": "S", "pl": 54}, {"u": "FT", "pl": 23, "basi": 2, "mine": 4}],
					"A": [{"u": "S+HV", "pl": 63}, {"u": "FT+HV", "pl": 32, "basi": 2, "mine": 6}]},
				{"nome": "Lega Umana", "razza": "h", "pedine": "l", "hm": "si",
					"P": [{"u": "S", "pl": 54}, {"u": "FT+HV", "pl": 32, "mine": 2}],
					"R": [{"u": "S", "pl": 54}, {"u": "FT+HV", "pl": 32, "basi": 1, "mine": 4}],
					"A": [{"u": "S+HV", "pl": 63}, {"u": "S", "pl": 54, "basi": 1, "mine": 6}]},
			],
			"scontri": [[0, 1]], "situazioni": ["P", "R", "A"], "civili": 6,
		},
		{
			"id": 31, "nome": "Il contatto con i L'Chal Dah", "anno": 2451,
			"testo": "Il primo contatto con i L'Chal Dah nel sistema di Eta Cassiopeiae, giocato con le regole standard. Sei segnalini di civili; solo l'Egemonia ha i missili cercatori.",
			"fazioni": [
				{"nome": "Egemonia Pan-Umana", "razza": "h", "pedine": "h", "hm": "si",
					"P": [{"u": "S", "pl": 54}, {"u": "FT+HV", "pl": 32, "mine": 2}]},
				{"nome": "L'Chal Dah", "razza": "l", "pedine": "l", "hm": "no",
					"P": [{"u": "S", "pl": 50}, {"u": "FT+HV", "pl": 36}]},
			],
			"scontri": [[1, 0]], "situazioni": ["P"], "civili": 6,
		},
		{
			"id": 32, "nome": "Seconda guerra fra Egemonia e Lega", "anno": 2462,
			"testo": "Una guerra breve e senza esito: la Lega Umana sbarca su Lauren, nel sistema di Alpha Centauri, e viene respinta. Sette segnalini di civili, missili cercatori per tutti, supporto orbitale per la Lega.",
			"fazioni": [
				{"nome": "Egemonia Pan-Umana", "razza": "h", "pedine": "h", "hm": "si",
					"P": [{"u": "S", "pl": 54}, {"u": "FT+HV+HV", "pl": 41, "mine": 2}],
					"R": [{"u": "S", "pl": 54}, {"u": "FT+HV", "pl": 32, "mine": 3, "basi": 3}],
					"A": [{"u": "S+HV", "pl": 63}, {"u": "S+HV", "pl": 63, "mine": 4, "basi": 1}]},
				{"nome": "Lega Umana", "razza": "h", "pedine": "l", "orb": O_HALF, "hm": "si",
					"P": [{"u": "FT+HV", "pl": 32}, {"u": "FT+HV", "pl": 32, "mine": 2}],
					"R": [{"u": "S", "pl": 54}, {"u": "FT+HV", "pl": 32, "mine": 3, "basi": 3}],
					"A": [{"u": "S+HV", "pl": 63}, {"u": "S", "pl": 54, "mine": 4, "basi": 3, "contigue": true}]},
			],
			"scontri": [[1, 0]], "situazioni": ["P", "R", "A"], "civili": 7,
		},
		{
			"id": 33, "nome": "La rivolta di Epsilon Indi", "anno": 2465,
			"testo": "Epsilon Indi si ribella all'Egemonia; i vecchi membri della Lega Umana si schierano con gli insorti, mentre i L'Chal Dah intervengono per l'Egemonia solo a vittoria in vista. Si gioca Egemonia o L'Chal Dah contro la Lega. Quattro segnalini di civili.",
			"fazioni": [
				{"nome": "Egemonia Pan-Umana", "razza": "h", "pedine": "l", "orb": O_FULL, "hm": "si",
					"P": [{"u": "S", "pl": 54}, {"u": "FT+HV+HV", "pl": 41, "mine": 2}],
					"R": [{"u": "S", "pl": 54}, {"u": "S", "pl": 54, "mine": 3, "basi": 2}],
					"A": [{"u": "S+HV", "pl": 63}, {"u": "S", "pl": 54, "mine": 4, "basi": 2}]},
				{"nome": "L'Chal Dah", "razza": "l", "pedine": "l", "orb": O_FULL, "hm": "si",
					"P": [{"u": "FT+AD", "pl": 50}, {"u": "FT+AD", "pl": 50, "mine": 2}],
					"R": [{"u": "FT+FT+AD", "pl": 68}, {"u": "FT+AD", "pl": 50, "mine": 3, "basi": 2}],
					"A": [{"u": "S+AD", "pl": 82}, {"u": "S", "pl": 50, "mine": 4, "basi": 2}]},
				{"nome": "Lega Umana", "razza": "h", "pedine": "h", "hm": "si",
					"P": [{"u": "FT+FT", "pl": 46}, {"u": "FT+FT", "pl": 46, "mine": 2}],
					"R": [{"u": "S", "pl": 54}, {"u": "FT+FT", "pl": 46, "mine": 3, "basi": 2}],
					"A": [{"u": "S+HV", "pl": 63}, {"u": "S", "pl": 54, "mine": 4, "basi": 2}]},
			],
			"scontri": [[0, 2], [1, 2]], "situazioni": ["P", "R", "A"], "civili": 4,
		},
		{
			"id": 34, "nome": "La guerra con i Rame", "anno": 2476,
			"testo": "L'Egemonia, con i L'Chal Dah associati, cerca di sottomettere i Rame di 70 Ophiuchi. Inesperti ma con una mente comune, i Rame combattono bene in sciami killer. Tre segnalini di civili.",
			"fazioni": [
				{"nome": "Rame", "razza": "r", "pedine": "r", "hm": "no",
					"P": [{"u": "SW", "pl": 13}, {"u": "SW", "pl": 13}]},
				{"nome": "Egemonia Pan-Umana", "razza": "h", "pedine": "h", "hm": "si",
					"P": [{"u": "FT+HV", "pl": 32}, {"u": "FT", "pl": 23, "mine": 2}]},
				{"nome": "L'Chal Dah", "razza": "l", "pedine": "l", "hm": "si",
					"P": [{"u": "FT+AD", "pl": 50}, {"u": "AD", "pl": 32, "mine": 2}]},
			],
			"scontri": [[1, 0], [2, 0]], "situazioni": ["P"], "civili": 3,
		},
		{
			"id": 35, "nome": "L'espansione dei L'Chal Dah", "anno": 2480,
			"testo": "I L'Chal Dah cercano di rafforzarsi a spese dei Rame, che però hanno imparato in fretta a combattere a terra. Tre segnalini di civili; supporto orbitale per i L'Chal Dah.",
			"fazioni": [
				{"nome": "L'Chal Dah", "razza": "l", "pedine": "l", "orb": O_HALF, "hm": "si",
					"P": [{"u": "FT+AD", "pl": 50}, {"u": "AD", "pl": 32, "mine": 2}],
					"R": [{"u": "FT+AD+AD", "pl": 82}, {"u": "AD+AD", "pl": 64, "mine": 3, "basi": 1}],
					"A": [{"u": "S+AD", "pl": 82}, {"u": "FT+AD+AD", "pl": 82, "mine": 4, "basi": 1}]},
				{"nome": "Rame", "razza": "r", "pedine": "r", "hm": "si",
					"P": [{"u": "SW+AD", "pl": 30}, {"u": "SW", "pl": 13, "mine": 2}],
					"R": [{"u": "S", "pl": 26}, {"u": "SW+AD", "pl": 30, "mine": 3, "basi": 3}],
					"A": [{"u": "S+S", "pl": 52}, {"u": "S", "pl": 26, "mine": 4, "basi": 3}]},
			],
			"scontri": [[0, 1]], "situazioni": ["P", "R", "A"], "civili": 3,
		},
		{
			"id": 36, "nome": "La guerra della Lega di Difesa", "anno": 2482,
			"testo": "I L'Chal Dah, alla guida della Lega di Difesa con i riluttanti Rame, rinunciano all'associazione con l'Egemonia e puntano a sconfiggere gli umani. Sei segnalini di civili; supporto orbitale per i L'Chal Dah.",
			"fazioni": [
				{"nome": "L'Chal Dah", "razza": "l", "pedine": "l", "orb": O_HALF, "hm": "si",
					"P": [{"u": "FT+HV+AD", "pl": 68}, {"u": "FT+AD", "pl": 50, "mine": 2}],
					"R": [{"u": "HV+AD+AD", "pl": 82}, {"u": "FT+AD+AD", "pl": 82, "mine": 4, "basi": 1}],
					"A": [{"u": "S+AD", "pl": 82}, {"u": "S+AD", "pl": 82, "mine": 6, "basi": 1}]},
				{"nome": "Egemonia Pan-Umana", "razza": "h", "pedine": "h", "hm": "si",
					"P": [{"u": "FT+HV+AD", "pl": 56}, {"u": "FT+AD", "pl": 47, "mine": 2}],
					"R": [{"u": "FT+FT+HV", "pl": 55}, {"u": "S", "pl": 54, "mine": 4, "basi": 2}],
					"A": [{"u": "S+PL+PL", "pl": 60}, {"u": "S", "pl": 60, "mine": 6, "basi": 1}]},
			],
			"scontri": [[0, 1]], "situazioni": ["P", "R", "A"], "civili": 6,
		},
		{
			"id": 37, "nome": "La guerra per l'identità", "anno": 2487,
			"testo": "Crollata l'Egemonia nascono tre fazioni: la Lega Pan-Senziente (L'Chal Dah e Rame), la Lega Umana ridotta e il resto dell'Egemonia con base su Sol. I civili dipendono dal mondo di Bravo (Egemonia 7, Lega Umana 5, L'Chal Dah 6, Rame 3); l'attaccante ha il supporto orbitale.",
			"fazioni": [
				{"nome": "L'Chal Dah", "razza": "l", "pedine": "l", "hm": "si", "mondo": 6,
					"P": [{"u": "FT+HV+AD", "pl": 68}, {"u": "FT+AD", "pl": 50, "mine": 2}],
					"R": [{"u": "S+AD+PL", "pl": 86}, {"u": "FT+AD+AD", "pl": 82, "mine": 4, "basi": 1}],
					"A": [{"u": "S+HV+PL+PL", "pl": 76}, {"u": "S+AD+PL", "pl": 86, "basi": 1}]},
				{"nome": "Rame", "razza": "r", "pedine": "r", "hm": "si", "mondo": 3,
					"P": [{"u": "SW+AD", "pl": 30}, {"u": "SW+AD", "pl": 30, "mine": 2}],
					"R": [{"u": "S+AD", "pl": 42}, {"u": "S", "pl": 26, "mine": 4, "basi": 3}],
					"A": [{"u": "S+AD+PL+PL", "pl": 46}, {"u": "S+AD", "pl": 42, "basi": 2, "contigue": true}]},
				{"nome": "Egemonia Pan-Umana", "razza": "h", "pedine": "h", "hm": "si", "mondo": 7,
					"P": [{"u": "FT+HV+PL", "pl": 35}, {"u": "FT+AD", "pl": 47, "mine": 2}],
					"R": [{"u": "S+PL+PL", "pl": 60}, {"u": "FT+HV+PL", "pl": 35, "basi": 2}],
					"A": [{"u": "S+PL+PL", "pl": 60}, {"u": "FT+HV+AD+PL", "pl": 59, "basi": 2}]},
				{"nome": "Lega Umana", "razza": "h", "pedine": "h", "pedine_vs": {"2": "l"}, "hm": "si", "mondo": 5,
					"P": [{"u": "FT+HV+PL", "pl": 35}, {"u": "FT+AD", "pl": 47, "mine": 2}],
					"R": [{"u": "S+PL+PL", "pl": 60}, {"u": "FT+HV+PL", "pl": 35, "basi": 2}],
					"A": [{"u": "S+PL+PL", "pl": 60}, {"u": "FT+HV+AD+PL", "pl": 59, "basi": 2}]},
			],
			"scontri": [[0, 2], [0, 3], [1, 2], [1, 3], [2, 3]], "situazioni": ["P", "R", "A"], "identita": true,
		},
		{
			"id": 38, "nome": "La sconfitta degli Xenofobi", "anno": 2785,
			"testo": "Gli Xenofobi, incapaci di tollerare altri esseri senzienti, vengono ricacciati fino al loro mondo d'origine. Dodici Xenofobi armati di bombe al neutrone contro una Squadra con supporto orbitale. Niente civili e niente livelli di preservazione: vince chi elimina tutti i nemici.",
			"fazioni": [
				{"nome": "Xenofobi", "razza": "x", "pedine": "x", "hm": "no", "X": [{"u": "S", "pl": 0}]},
				{"nome": "Umani", "razza": "h", "pedine": "h", "orb": O_FULL, "hm": "si", "X": [{"u": "S", "pl": 0}]},
				{"nome": "L'Chal Dah", "razza": "l", "pedine": "l", "orb": O_FULL, "hm": "si", "X": [{"u": "S", "pl": 0}]},
				{"nome": "Rame", "razza": "r", "pedine": "r", "orb": O_FULL, "hm": "si", "X": [{"u": "S", "pl": 0}]},
			],
			"scontri": [[1, 0], [2, 0], [3, 0]], "situazioni": ["X"], "turni": 16,
		},
		{
			"id": 39, "nome": "Il Dinkblog di Delta Pavonis", "anno": 2500,
			"testo": "Su Delta Pavonis II i coloni incontrano il Dinkblog, un carnivoro a quattro zampe che si teletrasporta e ha preso gusto agli umani. Tre StarSoldier difendono dieci gruppi di civili. Punti: il Dinkblog 1 per civile divorato e 2 per soldato ucciso; gli umani 1 per averlo cacciato dalla mappa, 1 per averlo ferito o 5 per averlo ucciso.",
			"fazioni": [
				{"nome": "Umani", "razza": "h", "pedine": "h"},
				{"nome": "Dinkblog", "razza": "d", "pedine": "d"},
			],
			"scontri": [[1, 0]], "situazioni": ["D"], "turni": 10,
		},
		{
			"id": 40, "nome": "Assalto alla Stazione Zulu", "anno": 2482,
			"testo": "Nell'anello di detriti di 61 Cygni una Squadra di fuoco umana assalta dall'orbita l'asteroide cilindrico Zulu, difeso da una Squadra di fuoco L'Chal Dah. Niente atmosfera (nessuna attenuazione del fuoco), orizzonte vicinissimo e bordi Est e Ovest uniti. Vince chi spinge l'avversario oltre il suo livello di preservazione.",
			"fazioni": [
				{"nome": "Umani", "razza": "h", "pedine": "h", "Z": [{"u": "FT", "pl": 23}]},
				{"nome": "L'Chal Dah", "razza": "l", "pedine": "l", "Z": [{"u": "FT", "pl": 18}]},
			],
			"scontri": [[0, 1]], "situazioni": ["Z"], "turni": 16,
		},
	]


static func get_scn(id: int) -> Dictionary:
	for s in list():
		if int(s["id"]) == id:
			return s
	return list()[0]
