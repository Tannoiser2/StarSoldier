# StarSoldier – regole in breve

*StarSoldier* (SPI, 1977) simula il combattimento uomo contro uomo nel XXV secolo, nello stesso universo di *StarForce* e *Outreach*. Ogni giocatore comanda da tre a una dozzina di StarSoldier in tuta da battaglia attiva. Il gioco è **simultaneo**: entrambi i giocatori scrivono in segreto i compiti di ogni soldato, poi tutto viene eseguito insieme. Nella versione digitale il piano si costruisce con il pannello di destra e il motore esegue la sequenza di gioco, tira i dadi e consulta le tabelle.

## La mappa

Ogni esagono misura un chilometro. Gli esagoni hanno il numero XXYY della mappa SPI: qui la mappa è girata in orizzontale, con la riga 39 in alto e la colonna 01 a sinistra (bordo Ovest). Il terreno ha un **valore** che conta per il movimento a terra, per la difesa e per le esplosioni:

- sereno (beige) 1;
- accidentato (giallo) 2;
- copertura organica (verde) 3, blocca il fuoco di chi è a terra;
- montagna (marrone) e urbano (edifici) 6, bloccano il fuoco di chi è a terra o in volo radente;
- lago (azzurro) 2;
- cratere (segnalino) 2.

## Le specie

Ogni soldato ha un'**ampiezza di compito** (TPA, i punti di compito per turno), un'**efficienza** che moltiplica tutto ciò che fa, e un **ritmo di recupero**.

| Specie | Gioco base | Gioco standard |
|---|---|---|
| Umani | 5 / 2 / 1 | 9 / 2 / 3 |
| L'Chal Dah | 6 / 2 / 1 | 12 / 2 / 1 |
| Rame | – | 6 / 4 / 2 |
| Xenofobi | – | 9 / 1 / 1 |
| Androidi | – | come la specie, recupero 0 |
| Basi (per esagono) | – | 6 / 2 / 0 |

Le **armi pesanti** (Hw) raddoppiano l'efficienza quando sparano ma non usano il fuoco ristretto.

## La sequenza di gioco

**Gioco base**, un turno:

1. **Piano**: ogni giocatore assegna in segreto i compiti a tutti i suoi soldati.
2. **Esecuzione**: prima tutto il fuoco diretto, poi tutti i lanci. Le perdite del fuoco hanno effetto solo dopo i lanci (chi viene colpito lancia comunque).
3. **Movimento**: i soldati si muovono come da piano, un passo a testa alternando i lati; intanto si risolve il fuoco d'opportunità.
4. **Armi lanciate**: dispersione delle bombe guidate, intercettazione dei missili, poi le detonazioni.
5. **Recupero**: chi non ha subito perdite né stordimenti recupera punti di compito fino al valore iniziale.

**Gioco standard**: il turno ha due **Stadi** uguali, ognuno con piano, esecuzione, movimento, armi lanciate e recupero. In uno stadio un soldato non può spendere più di 6 TP; nel secondo ha i punti del suo TPA attuale meno quelli spesi davvero nel primo. Nell'esecuzione sparano e lanciano prima i soldati in **comunicazione di comando**, poi gli indipendenti; le perdite del primo gruppo hanno effetto prima che spari il secondo.

## I compiti

- **Movimento**. A terra si spende il valore del terreno di ogni esagono in cui si entra. In volo (radente o alta quota) ogni esagono costa ½ TP qualunque sia il terreno. Cambiare quota: da terra a volo radente 3, da volo radente ad alta quota 3, da terra ad alta quota 6; scendere dal volo radente a terra è gratis, dall'alta quota costa 3. Chi entra dal bordo spende i punti dal primo esagono; nello stadio d'ingresso può solo muovere e mettere contromisure.
- **Contromisure (CM)**: ogni TP vale l'efficienza; per Umani e L'Chal Dah l'efficienza è dimezzata se il soldato passa in volo una parte dello stadio (per i Rame è il contrario: dimezzata se passano tempo a terra).
- **Fuoco diretto**: contro un esagono e una quota (a terra, volo radente, alta quota); colpisce separatamente ogni nemico a quella quota nell'esagono, con la posizione di inizio stadio.
- **Fuoco ristretto**: contro un solo soldato nemico; può passare tra gli amici.
- **Fuoco d'opportunità**: solo per chi non si muove; punti messi da parte per colpire durante il movimento. Nella versione digitale si sceglie quanti punti spendere per colpo e il soldato spara da solo al primo bersaglio con un differenziale di almeno +2 (alla fine del movimento basta +1).
- **Armi lanciate**: bomba guidata a positroni (almeno 3 TP), missili a volo libero (3 TP, gittata 10), granata opacizzante (come i missili), missile cercatore, bomba al neutrone (solo Xenofobi).
- **Ricerca** (1 TP) e **trasporto** (3 TP) dei civili nel gioco base.

## Il fuoco

**Attacco** = efficienza × TP spesi (× 2 per le armi pesanti).
**Difesa** = attenuazione della distanza + contromisure del bersaglio + effetto movimento + valore del terreno.

- **Attenuazione**: 1 ogni dieci esagoni (o frazione) di distanza; si aggiungono 5 esagoni se uno dei due è in alta quota e l'altro no; 0 nello stesso esagono.
- **Effetto movimento**: +1 per ogni TP che il bersaglio ha in piano di spendere nel movimento dello stadio.
- **Terreno**: il valore dell'esagono; in alta quota vale sempre 1; nei crateri e nei laghi vale 1 a chi non è a terra.

Il **differenziale** (attacco meno difesa) deve essere almeno +1. Si tirano due dadi sulla tabella del fuoco: il risultato sono i TP persi dal bersaglio. Chi arriva a TPA zero è eliminato.

**Linea di fuoco**: la copertura organica blocca chi è a terra, montagne e città bloccano chi è a terra o in volo radente; chi è in alta quota spara e viene colpito ovunque. Nessun fuoco (salvo il ristretto) può passare o entrare in un esagono con soldati amici. Il fumo delle granate blocca il passaggio.

## Le armi lanciate

L'esplosione colpisce l'esagono di detonazione con forza 30, gli esagoni vicini con forza 15 se raggiungibili con due punti di movimento a terra (terreno fino a 2) e quelli a due esagoni con forza 5 se il percorso costa al massimo 2. Contro ogni soldato si divide la forza per il valore del terreno e si tira sulla tabella delle armi lanciate (S = stordito: niente recupero). Le esplosioni a terra colpiscono chi è a terra o in volo radente e lasciano un cratere (non in montagna, città e laghi); quelle in alta quota colpiscono solo chi è in alta quota.

- **Bomba guidata**: differenziale di dispersione = efficienza × TP - (distanza ÷ 5, arrotondata per eccesso + contromisure di tutti i bersagli nel raggio). Se è negativo si tira sulla tabella di dispersione e la bomba può finire fino a tre esagoni più in là, nella direzione indicata dal diagramma della mappa.
- **Missili a volo libero**: non si disperdono ma possono essere intercettati: contromisure nel raggio × 1 (fino a 5 esagoni) o × 2 (da 6 a 10).
- **Granata opacizzante**: fumo elettronico per un turno intero: +2 al terreno per movimento e difesa, nessuna linea di fuoco attraverso, chi è nell'esagono è stordito.
- **Missile cercatore**: lanciato ad almeno 15 esagoni (5 per TP) oppure nascosto come mina. Si attiva quando un nemico ha una difesa di 10 o meno rispetto a lui, lo insegue fino a 12 esagoni ed esplode come una bomba; il bersaglio con fuoco d'opportunità può abbatterlo.

## Comando, preservazione e recupero

- **Comunicazioni di comando**: un soldato è in comando se il valore del terreno del suo esagono più la distanza dal capo ÷ 5 (per eccesso) non supera il suo TPA. Il capo è il primo StarSoldier di ogni Squadra o Squadra di fuoco. I Rame, le piattaforme e le basi sono sempre in comando.
- **Livello di preservazione**: quando i TP persi da un lato (meno quelli recuperati) superano il suo livello, dal turno dopo l'efficienza di tutti i suoi soldati è dimezzata. Se succede prima a uno, l'altro non ne subisce più l'effetto.
- **Recupero**: alla fine di ogni stadio chi non ha perso TP né è stato stordito recupera il suo ritmo di recupero.

## Armi e truppe speciali

- **Supporto orbitale** (per turno, secondo lo scenario): **bombardamento** (dispersione sulla colonna -4 con distanza doppia, forza 90/30/15, crateri dove la forza è almeno 30), **raffica laser** (fuoco diretto con attacco 24 e attenuazione 0), **bomba opacizzante** (+6 al terreno, stordisce, si disperde con 1-2 su un dado a ogni turno).
- **Piattaforme di supporto**: sempre in alta quota, difendono con terreno 10, perdite sotto 6 ignorate, sopra si tira sulla tabella dei danni; cannone laser con attacco 24 una volta per stadio senza spendere punti, che può registrarsi su due esagoni per ignorare le contromisure.
- **Androidi**: non recuperano e non fanno da capi.
- **Rame**: mente comune: due o più Rame nello stesso esagono e quota sommano le contromisure; tre Rame che sparano con gli stessi TP sullo stesso esagono fanno un solo attacco con la forza sommata.
- **Xenofobi**: solo bombe al neutrone (come le guidate ma con dispersione peggiore): vaporizzano chi è nell'esagono alla stessa quota e stordiscono gli altri. Si combatte fino all'ultimo.
- **Civili** (gioco standard): un fuoco diretto a terra o in volo radente in un esagono con civili, o un'esplosione, li colpisce: i TP persi sono punti di vittime civili. Chi alla fine ne ha causati più di cinque in più dell'avversario perde la partita.

## Le situazioni generali

- **Pattuglia**: la base di Bravo è oltre il bordo Est o Ovest. Alpha entra dal bordo opposto e deve far uscire più soldati possibile dal bordo della base. Alpha prende 2 punti per ogni TP perso da Bravo e 10 per ogni soldato uscito; Bravo prende 3 punti per ogni TP perso da Alpha. Scarto fino a 12: vittoria marginale; da 13 a 25 sostanziale; oltre decisiva.
- **Ricognizione**: Bravo schiera in segreto forze e basi. I soldati restano nascosti finché non spendono punti; una base si scopre quando spende punti o quando un soldato Alpha a terra o in volo radente passa entro quattro esagoni (due dopo la preservazione). Alpha vince se le scopre tutte.
- **Assalto**: Alpha deve distruggere tutte le basi (ogni esagono di base difende come una piattaforma). Se Alpha ha il supporto orbitale attacca dallo spazio: dieci bombardamenti e tre bombe opacizzanti preparano l'assalto, poi le sue forze scendono in alta quota dove vuole.

## Il gioco base: Primo contatto (2451)

Una Squadra L'Chal Dah (sette soldati, due con armi pesanti) entra da un bordo tirato a sorte e cerca tra dieci segnalini di civili nelle città (tre veri e sette fittizi) uno vero da portare fuori dalla mappa. Per scoprirlo un soldato resta nell'esagono per un movimento spendendo 1 TP; per portarlo via spende 3 TP per turno. Nelle città con civili si spara solo con il fuoco ristretto; gli umani non possono lanciare sui civili. La Squadra di fuoco umana (cinque soldati) riceve rinforzi da un turno tirato a sorte. Vittorie: un civile portato fuori senza vittime è sostanziale per i L'Chal Dah (marginale se gli umani hanno ucciso civili); nessun civile portato fuori è sostanziale per gli umani (marginale se hanno ucciso civili); un civile ucciso dai L'Chal Dah è una vittoria decisiva umana.

## Note sulla versione digitale

- L'organizzazione delle unità (25.1) non è leggibile nella scansione del regolamento: Squadra di fuoco umana 4 StarSoldier e un'arma pesante, Squadra umana 8 + 2, Squadra L'Chal Dah 5 + 2, Squadra di fuoco L'Chal Dah 3 + 1, Sezione armi pesanti 2, Squadra di androidi 4, Sciame Rame 3 (Squadra 6), Xenofobi 12. I livelli di preservazione sono quelli degli scenari.
- In Ricognizione Alpha entra dal bordo Ovest e Bravo si schiera ad almeno dieci colonne di distanza; nell'Assalto senza supporto orbitale Alpha entra dal bordo Ovest.
- Le perdite tolgono i punti ancora da spendere prima al fuoco d'opportunità, poi alle contromisure e infine al movimento.
- Ogni scenario ha un limite di turni: alla fine si assegna la vittoria secondo la situazione (in Pattuglia contano i punti; in Ricognizione e Assalto vince Bravo).
- Il gioco collegato con *StarForce* (41.0) non è incluso.
