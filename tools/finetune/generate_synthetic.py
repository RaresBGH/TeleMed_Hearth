"""
Synthetic Romanian triage dialogue generator.
9b: 5 dry-run dialogues (DRY_RUN_DIALOGUES, unchanged)
9c-i: 25 batch dialogues (BATCH_25A_DIALOGUES, synth-006..synth-030)
"""

import json
import random
import re
import sys
from pathlib import Path

from pydantic import BaseModel, ValidationError, model_validator

OUTPUT_PATH_DRY    = Path("/home/corb_d/sovereign-factory/datasets/synthetic/synthetic_triage_ro_dry_run.jsonl")
OUTPUT_PATH_BATCH  = Path("/home/corb_d/sovereign-factory/datasets/synthetic/synthetic_triage_ro_batch_25a.jsonl")
OUTPUT_PATH_BATCH_B = Path("/home/corb_d/sovereign-factory/datasets/synthetic/synthetic_triage_ro_batch_25b.jsonl")
OUTPUT_PATH_BATCH_C   = Path("/home/corb_d/sovereign-factory/datasets/synthetic/synthetic_triage_ro_batch_50c.jsonl")
OUTPUT_PATH_EMERGENCY = Path("/home/corb_d/sovereign-factory/datasets/synthetic/synthetic_triage_ro_emergency_batch.jsonl")

DRUG_BLOCKLIST = {
    "paracetamol", "ibuprofen", "aspirin", "antibiotic", "antibiotice",
    "doxiciclină", "metformin", "analgezic", "antiinflamator",
}
_DOSAGE_RE = re.compile(r"\b\d+\s*(mg|ml|comprimat[ae]?)\b", re.IGNORECASE)

# Longest first so prefix matching is unambiguous
KNOWN_OPENERS = [
    "Vă mulțumesc că mi-ați descris",
    "Vă mulțumesc pentru detalii",
    "Înțeleg, vă mulțumesc",
    "Înțeleg situația",
    "Îmi pare rău să aud",
    "Bine, am notat",
    "Am înțeles",
    "Am notat",
    "Vă mulțumesc",
    "Înțeleg",
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _a(response, category, priority="normal", ready_to_finalize=False, emergency=False):
    return json.dumps({
        "response": response, "emergency": emergency, "confidence": 0.0,
        "priority": priority, "ready_to_finalize": ready_to_finalize, "category": category,
    }, ensure_ascii=False)

def _u(t): return {"role": "user", "content": t}
def _asst(c): return {"role": "assistant", "content": c}

def _split_sentences(text):
    return [p.strip() for p in re.split(r"[.!?]", text) if p.strip()]

def _detect_opener(response):
    for op in KNOWN_OPENERS:
        if response.startswith(op):
            return op
    return "other"


# ---------------------------------------------------------------------------
# 9b — 5 dry-run dialogues (unchanged)
# ---------------------------------------------------------------------------

DRY_RUN_DIALOGUES = [
    {
        "source": "synthetic_triage", "synthetic_id": "synth-001", "theme": "hypertension",
        "messages": [
            _u("Mă simt amețit de câteva zile, mai ales când mă ridic din pat dimineața. "
               "Îmi vine să cad, parcă mi se învârte capul. "
               "Am 75 de ani și tensiunea mi-a mai făcut năzbâtii câteodată."),
            _asst(_a("Vă mulțumesc că mi-ați descris simptomele. "
                     "Înțeleg că amețeala apare mai ales când vă ridicați. "
                     "De câte zile aveți această senzație?", "duration")),
            _u("Ei, de vreo cinci-șase zile, poate chiar o săptămână. Nu știu exact, că eu nu prea țin evidența."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Pe o scară de la 1 la 10, cât de intensă este amețeala?", "intensity")),
            _u("Cam 6-7, cred. Adică mă țin de perete când mă ridic, dar nu cad. Dacă stau câteva secunde, trece."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Mai aveți și alte simptome care însoțesc amețeala — "
                     "de exemplu vedere încetoșată, palpitații sau dureri de cap?", "associated_symptoms")),
            _u("Da, câteodată mă doare capul, mai ales dimineața. Inima bate cam tare uneori, "
               "dar nu știu dacă e de la tensiune sau de la emoții."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: amețeală la ridicare, "
                     "dureri de cap matinale și palpitații intermitente, cu o durată de aproximativ o săptămână. "
                     "Medicul de familie va primi acest raport înaintea consultației. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },
    {
        "source": "synthetic_triage", "synthetic_id": "synth-002", "theme": "diabetes",
        "messages": [
            _u("Nu știu ce am, dar de câteva zile beau apă de parcă am trecut prin deșert. "
               "Și merg la baie la toaletă de vreo zece ori pe zi. "
               "Am 72 de ani și mai am puțin diabet, cum zice doctorul."),
            _asst(_a("Vă mulțumesc că mi-ați descris situația. "
                     "De când sunt aceste simptome mai pronunțate decât de obicei?", "duration")),
            _u("De vreo patru zile, cred. De când am mâncat la nunta nepoatei, că au fost multe dulciuri."),
            _asst(_a("Înțeleg contextul, vă mulțumesc. "
                     "Mai simțiți și altceva în aceste zile — "
                     "de exemplu oboseală neobișnuită, vedere neclară sau răni care nu se vindecă?", "associated_symptoms")),
            _u("Da, sunt cam obosită, dar și vârsta... Ce să fac. Vedere — nu știu, poate că da, parcă nu văd la fel de bine seara."),
            _asst(_a("Am notat simptomele dumneavoastră: sete intensă, urinare frecventă, "
                     "oboseală și posibile modificări ale vederii, debutate în urmă cu aproximativ patru zile. "
                     "Medicul de familie va primi acest raport complet. "
                     "Vă mulțumesc că ați folosit acest serviciu!", "close", ready_to_finalize=True)),
        ],
    },
    {
        "source": "synthetic_triage", "synthetic_id": "synth-003", "theme": "arthritis",
        "messages": [
            _u("Mă dor genunchii și mâinile dimineața, de mă știu. "
               "Dar acum, de când a venit frigul, e mult mai rău. Am 78 de ani, toată viața am muncit la câmp."),
            _asst(_a("Înțeleg că durerile articulare s-au intensificat odată cu răcirea vremii. "
                     "Cât timp durează rigiditatea matinală înainte să vă puteți mișca mai ușor?", "duration")),
            _u("Ei, până mă încălzesc... cam o oră, poate mai mult. Dacă fac puțină mișcare prin casă, mai trece."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Pe o scară de la 1 la 10, cât de intensă este durerea în cel mai rău moment?", "intensity")),
            _u("Înainte era mai bine, acum nu mai e cum era. Și vremea asta rea nu ajută deloc, că nici soțul nu-i bine."),
            _asst(_a("Înțeleg că este o perioadă dificilă. "
                     "Care articulații vă deranjează cel mai mult — genunchii, mâinile sau ambele?", "associated_symptoms")),
            _u("Ambele, dar genunchii mai rău. Și dacă merg mai mult, seara mă dor și mai tare."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: dureri articulare la genunchi și mâini, "
                     "rigiditate matinală de peste o oră, agravate de frig și de efort fizic. "
                     "Medicul de familie va consulta acest raport înaintea programării. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },
    {
        "source": "synthetic_triage", "synthetic_id": "synth-004", "theme": "heart_failure",
        "messages": [
            _u("Am 73 de ani și am început să rămân fără suflare când urc scările. "
               "Înainte urcam la etaj fără probleme, acum mă opresc la jumătate. "
               "Și picioarele mi s-au mai umflat puțin la glezne."),
            _asst(_a("Vă mulțumesc că mi-ați descris situația. "
                     "De cât timp aveți dificultăți la urcatul scărilor?", "duration", priority="urgent")),
            _u("Cam de o lună, treptat. Nu dintr-o dată, că altfel mergeam la urgențe."),
            _asst(_a("Înțeleg că s-a agravat treptat. "
                     "Simțiți dificultăți de respirație și în repaus sau noaptea — "
                     "de exemplu, vă treziți din somn din cauza respirației?", "associated_symptoms", priority="urgent")),
            _u("Câteodată noaptea mă trezesc și parcă nu am aer, stau cu capul ridicat pe perne. "
               "Dar trece după câteva minute."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: dificultăți de respirație la efort și noaptea, "
                     "agravare treptată în ultima lună și umflarea gleznelor. "
                     "Medicul de familie va fi informat înaintea consultației. "
                     "Vă mulțumesc pentru că ați descris cu atenție ce simțiți!",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },
    {
        "source": "synthetic_triage", "synthetic_id": "synth-005", "theme": "copd",
        "messages": [
            _u("Am o tuse care nu mai trece de vreo două săptămâni. "
               "Tusesc mai ales dimineața și scot niște mucus, galben uneori. "
               "Am 70 de ani și am fumat mulți ani, că acum m-am lăsat."),
            _asst(_a("Vă mulțumesc că mi-ați descris simptomele. "
                     "Aceasta este mai intensă decât tusea obișnuită de dimineață pe care o aveați anterior?", "context")),
            _u("Da, mult mai intensă. Înainte tusea trecea repede, acum tusesc și ziua, și noaptea."),
            _asst(_a("Înțeleg. "
                     "Aveți și alte simptome care au apărut odată cu tusea — "
                     "de exemplu febră, frisoane, dificultăți de respirație sau dureri în piept?", "associated_symptoms")),
            _u("Febră nu cred că am, nu m-am măsurat. "
               "Dar când tusesc mult, mă doare un pic în piept, nu tare, mai mult un disconfort."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Ați mai avut episoade similare de tuse prelungită în trecut, mai ales iarna?", "history")),
            _u("Da, în fiecare iarnă am câte ceva, dar nu am un diagnostic clar. "
               "Doctorul mi-a zis că plămânii mei au suferit de la fumat."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: tuse productivă cu mucus timp de două săptămâni, "
                     "disconfort toracic la tuse și antecedente de fumat pe termen lung. "
                     "Medicul de familie va consulta acest raport înaintea programării. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },
]


# ---------------------------------------------------------------------------
# 9c-i — 25 batch dialogues (synth-006..synth-030)
# ---------------------------------------------------------------------------

BATCH_25A_DIALOGUES = [

    # ── HYPERTENSION ────────────────────────────────────────────────────────

    # synth-006: HT, 75F rural, 8T — headache + tinnitus
    {
        "source": "synthetic_triage", "synthetic_id": "synth-006", "theme": "hypertension",
        "messages": [
            _u("Bună ziua. Mă doare capul de câteva zile și am un fel de vâjâit în urechi. "
               "Am 75 de ani și tensiunea mare o am de mulți ani, dar acum parcă e mai rău ca de obicei."),
            _asst(_a("Înțeleg. "
                     "De câte zile sau săptămâni aveți aceste dureri de cap și zgomote în urechi?", "duration")),
            _u("Cam de două săptămâni, da. Mai ales dimineața, când mă trezesc, simt că mi se strânge capul."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Pe o scară de la 1 la 10, cât de intense sunt durerile?", "intensity")),
            _u("Cam 5, zic eu. Nu e chiar insuportabilă, dar mă deranjează. Dimineața e mai rău, după ce mă trezesc."),
            _asst(_a("Bine, am notat. "
                     "Există situații sau activități care vă agravează durerile de cap?", "context")),
            _u("Când mă enervez sau când am mult de lucru, da. Și când nu dorm bine."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: dureri de cap și zgomote în urechi de două săptămâni, "
                     "intensitate 5 din 10, agravate de stres și oboseală. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-007: HT, 68M urban, 8T — palpitations + dizziness at rest
    {
        "source": "synthetic_triage", "synthetic_id": "synth-007", "theme": "hypertension",
        "messages": [
            _u("Bună ziua. Am 68 de ani și am început să simt bătăi neregulate ale inimii. "
               "Mai am și amețeală câteodată. Am tensiune arterială crescută de vreo 10 ani."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "De câte zile observați aceste palpitații și amețeală?", "duration")),
            _u("De vreo trei-patru zile. Nu știu de ce, poate de la stres, că am avut mult de lucru."),
            _asst(_a("Am înțeles. "
                     "Palpitațiile apar mai ales în anumite situații sau și în repaus?", "context")),
            _u("Când urc scările sau mă grăbesc, da, palpitațiile sunt mai intense. Uneori și când stau, dar mai rar."),
            _asst(_a("Vă mulțumesc. "
                     "Pe lângă amețeală și palpitații, mai aveți și alte simptome — "
                     "de exemplu dificultăți de respirație sau dureri în piept?", "associated_symptoms")),
            _u("Da, câteodată simt că nu am aer, mai ales după ce merg repede. Nu e grav, dar mă îngrijorează."),
            _asst(_a("Am notat: palpitații și amețeală de câteva zile, agravate la efort, cu dificultăți de respirație. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-008: HT, 71F rural, 6T — occipital headache + visual floaters
    {
        "source": "synthetic_triage", "synthetic_id": "synth-008", "theme": "hypertension",
        "messages": [
            _u("Bună ziua. Mă doare ceafa de o săptămână și am și dureri de cap în spate. "
               "Am 71 de ani și știu că tensiunea nu mi-e prea bine niciodată."),
            _asst(_a("Îmi pare rău să aud. "
                     "De câte zile aveți această durere la ceafă și occiput?", "duration")),
            _u("Cam de o săptămână bună. Uneori mă ia și greața."),
            _asst(_a("Am notat. "
                     "Mai aveți și alte simptome — de exemplu vedere neclară, greață sau zgomote în urechi?", "associated_symptoms")),
            _u("Da, câteodată văd niște punctișoare care se mișcă. De când eram mai tânără am asta, dar acum parcă mai des."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu dureri la ceafă și floatere vizuale de o săptămână va ajunge la medicul de familie. "
                     "Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-009: HT, 80M rural, 8T — sudden worse headache + blurred vision
    {
        "source": "synthetic_triage", "synthetic_id": "synth-009", "theme": "hypertension",
        "messages": [
            _u("Bună ziua. Am 80 de ani și de dimineață mă doare capul mai tare decât de obicei. "
               "Și văd cam neclar, de parcă am ceață în față."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "De cât timp aveți această durere de cap mai intensă și vedere încetoșată?", "duration")),
            _u("De cum m-am trezit, de pe la șase dimineața. Nu a trecut deloc."),
            _asst(_a("Înțeleg. "
                     "Pe o scară de la 1 la 10, cât de intensă este durerea de cap chiar acum?", "intensity")),
            _u("Cam 7, zic eu. E mai rău decât de obicei, că de obicei am dureri mai mici."),
            _asst(_a("Înțeleg situația. "
                     "Ați mai avut episoade similare de durere de cap intensă cu vedere neclară în trecut?", "history")),
            _u("Da, s-a mai întâmplat, mai rar. Dar de data asta mi-e frică că e mai rău."),
            _asst(_a("Am înregistrat toate detaliile despre durere de cap intensă cu vedere încetoșată, "
                     "apărută brusc în această dimineață, cu intensitate 7 din 10. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-010: HT, 73F urban, 6T — orthostatic dizziness, VAGUE patient turn
    {
        "source": "synthetic_triage", "synthetic_id": "synth-010", "theme": "hypertension",
        "messages": [
            _u("Bună ziua. Am 73 de ani și în ultima vreme mă simt amețită când mă ridic din pat sau de pe scaun. "
               "Tensiunea am mai ridicată, doctorul mi-a spus de ani de zile."),
            _asst(_a("Vă mulțumesc. "
                     "De câte zile sau săptămâni aveți această amețeală când vă ridicați?", "duration")),
            _u("Nu știu exact. Că la mine acasă e mai frig acum și poate de aia. Și am mâncat mai puțin în ultimele zile."),
            _asst(_a("Bine, am notat. "
                     "Amețeala apare mai ales dimineața când vă ridicați sau și în alte momente ale zilei?", "context")),
            _u("Mai ales dimineața, da. Câteodată și după prânz dacă stau mult jos și mă ridic repede."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: amețeală la ridicare, mai ales dimineața, "
                     "cu durată de câteva zile. Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── DIABETES ────────────────────────────────────────────────────────────

    # synth-011: DM, 70F rural, 8T — thirst + fatigue + non-healing foot wound
    {
        "source": "synthetic_triage", "synthetic_id": "synth-011", "theme": "diabetes",
        "messages": [
            _u("Bună ziua. Am 70 de ani și am diabet de multă vreme. "
               "Ultimele zile beau multă apă și sunt mai obosită ca de obicei. "
               "Și am o rănuță la picior care nu vrea să se vindece."),
            _asst(_a("Înțeleg. "
                     "De câte zile aveți aceste simptome de sete intensă și oboseală?", "duration")),
            _u("Cam de vreo zece zile am oboseala și setea mai mare. Rana la picior e de mai bine de două săptămâni."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Rana de pe picior s-a deschis recent sau este o rană mai veche care nu se vindecă?", "context")),
            _u("E la călcâi. Am luat-o de la o bătătură și acum e o rană mică, dar tot roșie. Nu prea doare."),
            _asst(_a("Am notat. "
                     "Ați mai avut răni la picioare care au durat mult să se vindece și în trecut?", "history")),
            _u("Da, am mai avut, că picioarele mele nu se vindecă repede. Doctorul mi-a zis să am grijă mai mare."),
            _asst(_a("Am notat: sete intensă, oboseală și rană la călcâi care nu se vindecă în două săptămâni. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-012: DM, 78M rural, 8T — blurred vision + polyuria + weight loss
    {
        "source": "synthetic_triage", "synthetic_id": "synth-012", "theme": "diabetes",
        "messages": [
            _u("Bună ziua. Am 78 de ani și am diabetul de mult timp. "
               "De ceva vreme văd mai rău și merg la baie de vreo opt ori pe noapte. Mă îngrijorează."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "De cât timp observați că vederea dumneavoastră s-a modificat?", "duration")),
            _u("Cam de o lună, poate mai mult. Nu mai știu sigur."),
            _asst(_a("Îmi pare rău să aud. "
                     "Puteți să citiți sau să vă desfășurați activitățile obișnuite, "
                     "sau vederea neclară vă împiedică semnificativ?", "intensity")),
            _u("Nu mai pot citi ziarul deloc. La televizor mai merge, dar și acolo e cam neclar."),
            _asst(_a("Vă mulțumesc. "
                     "Pe lângă vedere neclară și urinare frecventă, mai aveți și alte schimbări recente — "
                     "de exemplu pierdere în greutate sau oboseală marcată?", "associated_symptoms")),
            _u("Da, am slăbit vreo trei kilograme în ultima lună fără să încerc. Mă îmbrac și hainele sunt mai largi."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu vedere neclară de o lună, urinare frecventă și pierdere în greutate "
                     "va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-013: DM, 65F urban, 6T — neuropathic tingling in feet
    {
        "source": "synthetic_triage", "synthetic_id": "synth-013", "theme": "diabetes",
        "messages": [
            _u("Bună ziua. Am 65 de ani și am diabet de vreo cinci ani. "
               "Ultima perioadă am simțit că picioarele mi se amorțesc și mă furnice, mai ales seara."),
            _asst(_a("Am înțeles. "
                     "De câte zile sau săptămâni simțiți amorțeală și furnicături la picioare?", "duration")),
            _u("Cam de trei săptămâni, aș zice. La început era mai rar, acum e mai des."),
            _asst(_a("Înțeleg situația. "
                     "Amorțeala și furnicăturile apar mai ales noaptea sau și în timpul zilei?", "context")),
            _u("Mai ales noaptea, când stau în pat. Câteodată mă trezesc din cauza furnicăturilor și nu pot să adorm înapoi."),
            _asst(_a("Am înregistrat toate detaliile despre amorțeală și furnicături la picioare, "
                     "prezente de trei săptămâni, mai intense noaptea. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-014: DM, 72M rural, 8T — high home glucose + headache, VAGUE patient turn
    {
        "source": "synthetic_triage", "synthetic_id": "synth-014", "theme": "diabetes",
        "messages": [
            _u("Bună ziua. Am 72 de ani și diabet de mulți ani. "
               "Glicemia la aparat mi-a ieșit mai mare decât de obicei și mă doare capul în ultima vreme."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "De câte zile observați valorile mai mari ale glicemiei acasă?", "duration")),
            _u("Ei, la mine glicemia e mereu cam sus, că nu prea pot ține dieta. "
               "Că la nuntă am mâncat ce mi-a plăcut, și la cumetrie la fel."),
            _asst(_a("Bine, am notat. "
                     "Durerile de cap pe care le menționați apar mai ales dimineața sau de-a lungul zilei?", "context")),
            _u("Mai ales dimineața, da. Câteodată și la prânz."),
            _asst(_a("Înțeleg. "
                     "Pe lângă durerile de cap, mai simțiți și alte schimbări — "
                     "de exemplu sete crescută, oboseală sau vedere neclară?", "associated_symptoms")),
            _u("Da, sunt mai obosit și beau mai multă apă. Văd cam la fel, nu mi se pare schimbat."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: glicemie ridicată, dureri de cap matinale, "
                     "oboseală și sete crescută. Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-015: DM, 80F rural, 6T — fatigue + non-healing leg wound + swollen feet
    {
        "source": "synthetic_triage", "synthetic_id": "synth-015", "theme": "diabetes",
        "messages": [
            _u("Bună ziua. Am 80 de ani și am diabet. "
               "Sunt cam slabă de puteri în ultima vreme și am o rănuță la picior care nu se vindecă de vreo trei săptămâni."),
            _asst(_a("Am notat. "
                     "De cât timp aveți această rană la picior care nu vrea să se vindece?", "duration")),
            _u("Cam de trei săptămâni, da. Am pus niște comprese, dar tot nu trece."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Pe lângă rană și oboseală, mai aveți și alte simptome — "
                     "de exemplu picioare umflate sau amorțeală?", "associated_symptoms")),
            _u("Da, picioarele mi s-au mai umflat, mai ales seara. Și amorțesc câteodată."),
            _asst(_a("Am notat: rană la picior de trei săptămâni care nu se vindecă, oboseală și picioare umflate. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── ARTHRITIS ───────────────────────────────────────────────────────────

    # synth-016: AR, 77F rural, 8T — hip pain radiating to knee
    {
        "source": "synthetic_triage", "synthetic_id": "synth-016", "theme": "arthritis",
        "messages": [
            _u("Bună ziua. Am 77 de ani și mă doare șoldul de ceva vreme. "
               "Durerea merge și spre genunchi câteodată. Artrita am de mult, dar ultimele luni e mai rău."),
            _asst(_a("Înțeleg. "
                     "De cât timp aveți această durere la șold care se extinde spre genunchi?", "duration")),
            _u("Cam de două luni s-a înrăutățit. Înainte mai trecea singură, acum nu prea."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Pe o scară de la 1 la 10, cât de intensă este durerea în cel mai dificil moment?", "intensity")),
            _u("Cam 6, aș zice. Mă doare destul de tare când merg, dar în repaus mai suport."),
            _asst(_a("Bine, am notat. "
                     "În ce situații este durerea mai intensă — la mers, la urcat scări sau în repaus?", "context")),
            _u("La mers mă doare mai tare și scările sunt o problemă mare. Și dimineața când mă ridic."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu dureri la șold și genunchi de două luni, intensitate 6, "
                     "agravate la mers și scări va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-017: AR, 74M rural, 8T — stiff swollen fingers, VAGUE patient turn
    {
        "source": "synthetic_triage", "synthetic_id": "synth-017", "theme": "arthritis",
        "messages": [
            _u("Bună ziua. Am 74 de ani și de câteva luni dimineața nu-mi pot îndrepta degetele de la mâini. "
               "Sunt umflate și mă dor, mai ales când vreau să apuc ceva."),
            _asst(_a("Îmi pare rău să aud. "
                     "De câte luni aveți degetele rigide și umflate dimineața?", "duration")),
            _u("Cam de patru-cinci luni. Nu știu exact, că nu am ținut evidența."),
            _asst(_a("Vă mulțumesc. "
                     "Pe o scară de la 1 la 10, cât de mult vă afectează rigiditatea dimineții activitățile zilnice?", "intensity")),
            _u("Mă afectează mult, dar ce să fac, asta e bătrânețea. Și soția mea are aceleași probleme. Parcă ne-am strâns amândoi."),
            _asst(_a("Am înțeles că este dificil. "
                     "Durerea de la degete se extinde și la încheietura mâinii sau rămâne doar la degete?", "associated_symptoms")),
            _u("Da, și la încheietura mâinii mă doare câteodată. Și la cot puțin, mai rar."),
            _asst(_a("Am înregistrat toate detaliile despre rigiditate și umflarea degetelor dimineața de câteva luni, "
                     "cu extindere la încheietura mâinii. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-018: AR, 82F rural, 6T — lumbar pain radiating down leg
    {
        "source": "synthetic_triage", "synthetic_id": "synth-018", "theme": "arthritis",
        "messages": [
            _u("Bună ziua. Am 82 de ani și de câteva săptămâni mă doare spatele în zona de jos, "
               "și durerea merge și pe picior, pe coapsă și uneori până la genunchi."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "De câte zile sau săptămâni aveți această durere în zona lombară care coboară pe picior?", "duration")),
            _u("Cam de trei săptămâni, zic eu. A început după ce am ridicat ceva greu."),
            _asst(_a("Am notat. "
                     "Durerea este mai degrabă surdă și permanentă sau apare în crize, "
                     "ca niște curenți sau împunsături?", "context")),
            _u("E mai mult o durere surdă, tot timpul acolo. Dar când stau în picioare mai mult, se înrăutățește tare."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: dureri lombare cu iradiere pe picior de trei săptămâni, "
                     "surdă și permanentă, agravată la ortostatism. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-019: AR, 69M urban, 6T — knee pain after walks + occasional swelling
    {
        "source": "synthetic_triage", "synthetic_id": "synth-019", "theme": "arthritis",
        "messages": [
            _u("Bună ziua. Am 69 de ani și de ceva timp mă dor genunchii după ce merg mai mult. "
               "Uneori se și umflă puțin, mai ales cel stâng. Am și eu artrita mea."),
            _asst(_a("Înțeleg situația. "
                     "De cât timp vă deranjează această durere la genunchi după mers?", "duration")),
            _u("Cam de șase luni. A început treptat, la început mai rar, acum mai des."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Durerea apare după ce mergeți o anumită distanță sau și de la începutul mersului?", "context")),
            _u("Dacă merg mai mult de vreo jumătate de oră, începe să mă doară. La mers scurt merge."),
            _asst(_a("Am notat: dureri de genunchi cu umflare ocazională, prezente de 6 luni, "
                     "apărute după mers de 30 de minute. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── HEART FAILURE ───────────────────────────────────────────────────────

    # synth-020: HF, 76F rural, 8T — fatigue + edema + orthopnea
    {
        "source": "synthetic_triage", "synthetic_id": "synth-020", "theme": "heart_failure",
        "messages": [
            _u("Bună ziua. Am 76 de ani și în ultima vreme mă simt foarte obosită. "
               "Picioarele mi s-au umflat și când mă culc seara nu pot respira bine dacă nu stau cu capul ridicat."),
            _asst(_a("Înțeleg. "
                     "De câte zile sau săptămâni aveți această oboseală, umflarea picioarelor și dificultăți de respirație?",
                     "duration", priority="urgent")),
            _u("Cam de vreo două-trei săptămâni. S-a înrăutățit treptat."),
            _asst(_a("Bine, am notat. "
                     "Pe lângă oboseală și umflarea picioarelor, mai aveți și alte simptome — "
                     "de exemplu tuse sau senzație de greutate în piept?", "associated_symptoms", priority="urgent")),
            _u("Da, seara picioarele sunt mult mai umflate decât dimineața. Pantoful nu mai intră pe picior seara."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Când dormiți, aveți nevoie să stați cu capul ridicat pe perne pentru a respira mai ușor?",
                     "context", priority="urgent")),
            _u("Da, de obicei am trei perne. Dacă stau plat, parcă mă sufoc."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu oboseală, umflarea picioarelor seara și necesitate de perne multiple la somn "
                     "va ajunge la medicul de familie. Așteptați consultația.",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # synth-021: HF, 70M rural, 6T — nocturnal cough + orthopnea, VAGUE patient turn
    {
        "source": "synthetic_triage", "synthetic_id": "synth-021", "theme": "heart_failure",
        "messages": [
            _u("Bună ziua. Am 70 de ani și tusesc mult noaptea. "
               "Când mă culc, parcă nu am aer și trebuie să stau pe jumătate ridicat. Mă îngrijorează."),
            _asst(_a("Înțeleg situația. "
                     "De cât timp aveți această tuse și dificultăți de respirație când vă culcați?",
                     "duration", priority="urgent")),
            _u("Ei, de ceva vreme, nu știu sigur. La vârsta mea e greu să ții minte când a început fiecare lucru. Oricum, nu e bine."),
            _asst(_a("Vă mulțumesc. "
                     "Glezna sau laba piciorului vi s-a umflat în această perioadă?",
                     "associated_symptoms", priority="urgent")),
            _u("Da, am observat că glezna stângă e mai umflată. Seara mai ales."),
            _asst(_a("Am înregistrat toate detaliile despre tuse, dificultăți de respirație la culcat și umflarea gleznei stângi. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # synth-022: HF, 81F rural, 8T — rapid weight gain + edema + nocturnal cough
    {
        "source": "synthetic_triage", "synthetic_id": "synth-022", "theme": "heart_failure",
        "messages": [
            _u("Bună ziua. Am 81 de ani și în ultimele două săptămâni m-am îngrășat mult, cam trei kilograme, "
               "fără să mănânc mai mult. Și picioarele sunt umflate și sunt foarte obosită."),
            _asst(_a("Am notat. "
                     "De câte zile observați că ați luat în greutate brusc și aveți picioarele umflate?",
                     "duration", priority="urgent")),
            _u("De vreo două săptămâni, da. A venit destul de repede, nu știam ce e."),
            _asst(_a("Îmi pare rău să aud. "
                     "Pe lângă oboseală și umflarea picioarelor, mai aveți și alte simptome — "
                     "de exemplu tuse sau respirație dificilă?", "associated_symptoms", priority="urgent")),
            _u("Da, tusesc mai ales noaptea. Nu mă lasă să dorm bine. Mă trezesc și parcă am ceva greu pe piept."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Tusea se înrăutățește mai ales noaptea sau și în timpul zilei?",
                     "context", priority="urgent")),
            _u("Când mă culc plat, tusea se înrăutățește. Dacă stau pe jumătate ridicată, e puțin mai bine."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: creștere rapidă în greutate, picioare umflate, "
                     "oboseală și tuse nocturnă de două săptămâni. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # synth-023: HF, 67M rural, 6T — progressive fatigue + swollen feet + exertional dyspnea
    {
        "source": "synthetic_triage", "synthetic_id": "synth-023", "theme": "heart_failure",
        "messages": [
            _u("Bună ziua. Am 67 de ani și de câteva săptămâni mă simt din ce în ce mai obosit. "
               "Picioarele mi s-au umflat și nu prea am chef de nimic."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "De câte zile sau săptămâni vă simțiți obosit și aveți picioarele umflate?",
                     "duration", priority="urgent")),
            _u("Cam de trei săptămâni, da. Treptat, nu dintr-o dată."),
            _asst(_a("Am înțeles. "
                     "Simțiți și dificultăți de respirație — de exemplu când urcați scările sau faceți efort?",
                     "associated_symptoms", priority="urgent")),
            _u("Da, când urc scările la etaj rămân fără suflare. Înainte nu aveam această problemă."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu oboseală marcată, picioare umflate și dificultăți de respirație la efort, "
                     "prezente de trei săptămâni, va ajunge la medicul de familie. Așteptați consultația.",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # ── COPD ────────────────────────────────────────────────────────────────

    # synth-024: COPD, 72M rural, 8T — worsening cough + wheezing + reduced exertion
    {
        "source": "synthetic_triage", "synthetic_id": "synth-024", "theme": "copd",
        "messages": [
            _u("Bună ziua. Am 72 de ani și am bronhopneumopatie, știu că am. "
               "Dar ultima lună tusesc mai mult decât de obicei și scot mai mult mucus, galben-verzui. Și respir mai greu."),
            _asst(_a("Înțeleg. "
                     "De câte zile sau săptămâni s-a agravat tusea și a apărut dificultatea de respirație?", "duration")),
            _u("Cam de trei săptămâni s-a înrăutățit. A început după ce am prins o răceală."),
            _asst(_a("Vă mulțumesc. "
                     "Cât de mult vă afectează dificultatea de respirație — puteți merge normal sau vă opriți des?",
                     "intensity")),
            _u("Nu pot merge prea mult. Cam 100 de metri și trebuie să mă opresc să-mi revin."),
            _asst(_a("Bine, am notat. "
                     "Aveți un diagnostic stabilit de bronhopneumopatie cronică sau alte afecțiuni pulmonare?", "history")),
            _u("Da, am diagnosis de la doctor. Mai am câte o agravare în fiecare an, mai ales iarna."),
            _asst(_a("Am înregistrat toate detaliile despre agravarea tusei, wheezing și dificultăți de respirație de trei săptămâni, "
                     "cu toleranță redusă la efort. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-025: COPD, 68F rural, 6T — chronic cough worse + fatigue, VAGUE patient turn
    {
        "source": "synthetic_triage", "synthetic_id": "synth-025", "theme": "copd",
        "messages": [
            _u("Bună ziua. Am 68 de ani și tusesc de mulți ani. "
               "Dar în ultima lună parcă e mai rău și mă simt mai obosită ca de obicei."),
            _asst(_a("Am înțeles. "
                     "Această tuse este mai intensă decât tusea obișnuită pe care o aveați anterior?", "context")),
            _u("Ei, la mine tusea e tot timpul, de când știu eu. Acum parcă nu mă mai simt bine în general. Dar asta e, nu mai sunt tânără."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Simțiți o strângere sau presiune în piept dimineața sau în alte momente ale zilei?",
                     "associated_symptoms")),
            _u("Da, dimineața când mă trezesc simt că mi s-a strâns pieptul. Durează cam o oră și după trece un pic."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: tuse cronică agravată, oboseală și strângere toracică matinală. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-026: COPD, 75M urban, 8T — progressive dyspnea + yellow sputum increase
    {
        "source": "synthetic_triage", "synthetic_id": "synth-026", "theme": "copd",
        "messages": [
            _u("Bună ziua. Am 75 de ani și am BPOC. "
               "Ultima lună am simțit că respir mai greu și nu mai pot merge până la piață singur cum făceam înainte."),
            _asst(_a("Înțeleg situația. "
                     "De câte zile sau săptămâni vă este mai greu să respirați și să mergeți distanțe mai lungi?",
                     "duration")),
            _u("Cam de o lună. Treptat, nu deodată. Parcă cu fiecare zi e puțin mai greu."),
            _asst(_a("Am notat. "
                     "Aproximativ câți metri puteți merge înainte să trebuiască să vă opriți?", "intensity")),
            _u("Cam 50 de metri, poate mai puțin. Trebuie să mă opresc și să-mi trag sufletul."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Ați observat vreo schimbare în sputa pe care o eliminați — "
                     "mai multă, de altă culoare sau consistență?", "associated_symptoms")),
            _u("Da, mai scot spută decât de obicei. E mai gălbuie. Înainte era mai clară."),
            _asst(_a("Am notat: dificultăți de respirație agravate, toleranță la efort redusă la 50 de metri "
                     "și spută galbenă în cantitate crescută, de o lună. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-027: COPD, 65F urban, 6T — chronic morning cough + exertional dyspnea
    {
        "source": "synthetic_triage", "synthetic_id": "synth-027", "theme": "copd",
        "messages": [
            _u("Bună ziua. Am 65 de ani și am fumat 15 ani, acum nu mai fumez. "
               "Tusesc dimineața de ani de zile și scot mucus. Ultima perioadă parcă e mai mult."),
            _asst(_a("Îmi pare rău să aud. "
                     "De cât timp aveți această tuse matinală productivă?", "duration")),
            _u("De mulți ani am tusea asta. Dar acum parcă e mai pronunțată și mai des, nu mai la fel."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Aveți și dificultăți de respirație — de exemplu la efort sau la urcat scări?",
                     "associated_symptoms")),
            _u("Când urc scările la bloc îmi vine greu uneori. Dar când stau nu mă deranjează."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu tuse matinală productivă cronică agravată, antecedente de fumat și dispnee la efort "
                     "va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── GENERAL ─────────────────────────────────────────────────────────────

    # synth-028: general/cough, 72F rural, 6T — acute cough after rain exposure
    {
        "source": "synthetic_triage", "synthetic_id": "synth-028", "theme": "general",
        "messages": [
            _u("Bună ziua. Am 72 de ani și tusesc de o săptămână. "
               "Am prins-o probabil de la ploaie, că m-am udat bine. Nu am probleme cu plămânii în mod normal."),
            _asst(_a("Înțeleg. "
                     "Această tuse a apărut recent sau o aveați și înainte?", "context")),
            _u("E nouă această tuse, de o săptămână exact. Până atunci nu tusisem."),
            _asst(_a("Vă mulțumesc. "
                     "Pe lângă tuse, mai aveți și alte simptome — "
                     "de exemplu dureri în gât, nas înfundat sau febră?", "associated_symptoms")),
            _u("Mă doare un pic în gât, mai ales când înghit. Febră nu mi-am măsurat, dar nu cred că am."),
            _asst(_a("Am înregistrat toate detaliile despre tuse nouă de o săptămână, cu durere ușoară în gât, "
                     "apărută după expunere la frig și ploaie. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-029: general/fever, 75M urban, 6T — fever + chills + body ache
    {
        "source": "synthetic_triage", "synthetic_id": "synth-029", "theme": "general",
        "messages": [
            _u("Bună ziua. Am 75 de ani și de ieri am frisoane și mă simt rău. "
               "Cred că am febră, că îmi e și frig și cald."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "De cât timp aveți febră și ați reușit să o măsurați?", "duration")),
            _u("De ieri seara. Am măsurat și am 38 și ceva, 38,5 am văzut ultima oară."),
            _asst(_a("Am notat. "
                     "Pe lângă febră și frisoane, mai aveți și alte simptome — "
                     "de exemplu dureri musculare, dureri de cap sau tuse?", "associated_symptoms")),
            _u("Mă dor mușchii și capul. Tuse nu am. Simt că mă doare tot corpul, ca la gripă."),
            _asst(_a("Am notat: febră de 38,5 grade și frisoane de ieri, cu dureri musculare și dureri de cap, fără tuse. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-030: general/fatigue, 78F rural, 6T — unexplained fatigue + anorexia + weight loss
    {
        "source": "synthetic_triage", "synthetic_id": "synth-030", "theme": "general",
        "messages": [
            _u("Bună ziua. Am 78 de ani și de ceva vreme nu mai am energie deloc. "
               "Mă obosesc din orice lucru, chiar și din treburile de casă pe care le făceam fără probleme."),
            _asst(_a("Bine, am notat. "
                     "De câte zile sau săptămâni vă simțiți atât de obosită și lipsită de energie?", "duration")),
            _u("Cam de trei-patru săptămâni. A venit treptat, nu brusc."),
            _asst(_a("Înțeleg situația. "
                     "Pe lângă oboseală, mai aveți și alte schimbări — "
                     "de exemplu poftă de mâncare scăzută, slăbire sau alte simptome noi?", "associated_symptoms")),
            _u("Da, nu prea mi-e foame. Mănânc mai puțin. Și am slăbit cam două kilograme."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu oboseală marcată de trei-patru săptămâni, apetit scăzut și pierdere în greutate "
                     "va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },
]


# ---------------------------------------------------------------------------
# 9c-ii — 25 batch dialogues (synth-031..synth-055)
# ---------------------------------------------------------------------------

BATCH_25B_DIALOGUES = [

    # ── HYPERTENSION ─────────────────────────────────────────────────────────

    # synth-031: HT, 66M rural, 8T, no greeting — palpitations + dizziness
    {
        "source": "synthetic_triage", "synthetic_id": "synth-031", "theme": "hypertension",
        "messages": [
            _u("Am 66 de ani și am tensiunea mare de mai mulți ani. "
               "De câteva zile simt inima bătând mai rapid și mă amețesc câteodată, mai ales seara."),
            _asst(_a("Înțeleg. "
                     "De câte zile simțiți aceste bătăi rapide ale inimii și amețeala?", "duration")),
            _u("Cam de patru-cinci zile. Seara e mai rău. Ziua e mai suportabil."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Pe o scară de la 1 la 10, cât de deranjante sunt palpitațiile?", "intensity")),
            _u("Cam 5-6. Nu mă opresc din ce fac, dar mă îngrijorează. Mâinile îmi mai tremură puțin."),
            _asst(_a("Am notat. "
                     "Pe lângă palpitații și amețeală, mai aveți și alte simptome — "
                     "de exemplu dureri de cap, transpirații sau dificultăți de respirație?", "associated_symptoms")),
            _u("Da, mă doare capul câteodată, mai ales dimineața. Transpirații nu prea am. Respirația e normală."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: palpitații, amețeală și dureri de cap matinale "
                     "de patru-cinci zile, cu tremurături ușoare ale mâinilor. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-032: HT, 79F urban, 6T, no greeting, VAGUE (changes topic to son's illness)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-032", "theme": "hypertension",
        "messages": [
            _u("Am 79 de ani și de câteva zile am dimineața dureri de cap și văd cam neclar. "
               "Tensiunea mi-a fost mereu cam ridicată."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "De câte zile aveți aceste dureri de cap dimineața și vedere neclară?", "duration")),
            _u("Nu știu exact. Că și băiatul meu are tensiunea mare și se descurcă singur. "
               "La el nu trece, la mine nu știu de câte zile e."),
            _asst(_a("Bine, am notat. "
                     "Vederea neclară apare mai ales dimineața sau și pe parcursul zilei?", "context")),
            _u("Mai mult dimineața. Când mă ridic din pat, văd cam neclar cam jumătate de oră, după se mai duce."),
            _asst(_a("Am notat: dureri de cap matinale și vedere neclară de câteva zile, "
                     "cu ameliorare după jumătate de oră. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-033: HT, 72M rural, 8T, greeting — severe headache + nausea + photopsia
    {
        "source": "synthetic_triage", "synthetic_id": "synth-033", "theme": "hypertension",
        "messages": [
            _u("Bună ziua. Am 72 de ani și de ieri am o durere de cap foarte puternică. "
               "Mi-e și greață. Am tensiunea mare de mulți ani."),
            _asst(_a("Îmi pare rău să aud. "
                     "De cât timp aveți această durere de cap intensă și greață?", "duration")),
            _u("De ieri după-amiază. Nu am dormit bine din cauza ei."),
            _asst(_a("Vă mulțumesc. "
                     "Pe o scară de la 1 la 10, cât de intensă este durerea de cap acum?", "intensity")),
            _u("Cam 8, e destul de tare. Nu am mâncat nimic azi de la greață."),
            _asst(_a("Înțeleg situația. "
                     "Pe lângă durerea de cap și greață, mai aveți și alte simptome — "
                     "de exemplu vedere încetoșată, lumini în fața ochilor sau amețeală?", "associated_symptoms")),
            _u("Da, câteodată văd niște lumini. Și amețeală puțin. Nu am mai avut atât de rău."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu durere de cap intensă, greață, fosfene și amețeală de ieri "
                     "va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-034: HT, 85F rural, 6T, greeting — leg weakness + mild headache
    {
        "source": "synthetic_triage", "synthetic_id": "synth-034", "theme": "hypertension",
        "messages": [
            _u("Bună ziua. Am 85 de ani și în ultima săptămână simt că picioarele sunt mai slabe "
               "și mă doare capul ușor câteodată. Tensiunea am de foarte mulți ani."),
            _asst(_a("Am înțeles. "
                     "De câte zile sau săptămâni simțiți această slăbiciune la picioare?", "duration")),
            _u("Cam de o săptămână. Mă țin de perete când merg prin casă, că nu mă simt stabilă."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Pe lângă slăbiciunea picioarelor, mai aveți și alte simptome noi — "
                     "de exemplu amorțeală, furnicături sau dificultăți la vorbire?", "associated_symptoms")),
            _u("Nu prea. Uneori degetele de la mâini se amorțesc puțin. La vorbire sunt bine."),
            _asst(_a("Am înregistrat toate detaliile despre slăbiciune la picioare de o săptămână, "
                     "dureri de cap ușoare și amorțeală intermitentă a degetelor. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-035: HT, 68M urban, 6T, greeting — facial flushing + headache
    {
        "source": "synthetic_triage", "synthetic_id": "synth-035", "theme": "hypertension",
        "messages": [
            _u("Bună ziua. Am 68 de ani și de câteva zile mi se înroșește fața brusc câteodată "
               "și mă doare capul după. Am tensiunea cam ridicată de ani de zile."),
            _asst(_a("Înțeleg. "
                     "De câte zile observați aceste episoade de înroșire a feței și dureri de cap?", "duration")),
            _u("Cam de cinci zile, de săptămâna trecută. Se întâmplă de vreo două-trei ori pe zi."),
            _asst(_a("Am notat. "
                     "Înroșirea feței apare după anumite activități, alimente sau emoții sau vine fără motiv aparent?",
                     "context")),
            _u("Câteodată după ce beau cafea sau mă înervez. Câteodată pur și simplu, fără nimic."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: episoade de înroșire facială de cinci zile, "
                     "de două-trei ori pe zi, asociate cu dureri de cap, uneori declanșate de cafea sau emoții. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── DIABETES ─────────────────────────────────────────────────────────────

    # synth-036: DM, 74F urban, 8T, no greeting — foot numbness + slow-healing wounds
    {
        "source": "synthetic_triage", "synthetic_id": "synth-036", "theme": "diabetes",
        "messages": [
            _u("Am 74 de ani și am diabet de vreo 12 ani. "
               "De câteva luni picioarele îmi amorțesc tot mai des și am mai multe răni mici care nu se vindecă repede."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "De câte luni aveți amorțeala la picioare și rănile care se vindecă greu?", "duration")),
            _u("Amorțeala cam de două-trei luni. Rănile mai de mult, dar acum mai des."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Amorțeala apare mai ales noaptea sau și în timpul zilei, la mers?", "context")),
            _u("Mai ales noaptea, dar și ziua când stau jos mult timp. Uneori simt ca niște curenți."),
            _asst(_a("Bine, am notat. "
                     "Pe lângă amorțeală și răni, mai aveți și alte simptome noi — "
                     "de exemplu vedere neclară, oboseală marcată sau sete crescută?", "associated_symptoms")),
            _u("Da, sunt mai obosită și beau mai multă apă decât înainte. Vedere nu mi s-a modificat."),
            _asst(_a("Am notat: amorțeală la picioare de două-trei luni, răni care se vindecă lent, "
                     "oboseală și sete crescută. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-037: DM, 77M rural, 6T, greeting, VAGUE (wildly inconsistent time range)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-037", "theme": "diabetes",
        "messages": [
            _u("Bună ziua. Am 77 de ani și am diabet. "
               "Am slăbit mult fără să vreau și merg mult la baie noaptea, de mă trezesc de câteva ori."),
            _asst(_a("Vă mulțumesc. "
                     "De câte zile sau săptămâni observați această pierdere în greutate și urinarea frecventă nocturnă?",
                     "duration")),
            _u("Ei, poate de o săptămână, poate de trei luni, nu știu. "
               "La mine lucrurile se schimbă pe nesimțite. Câteodată mi se pare că de la iarnă, câteodată că de recent."),
            _asst(_a("Înțeleg situația. "
                     "Câte kilograme aproximativ ați pierdut în această perioadă?", "intensity")),
            _u("Cam patru-cinci kilograme, cred. Pantalonii sunt mai largi acum."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu pierdere în greutate de aproximativ cinci kilograme și urinare frecventă nocturnă "
                     "va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-038: DM, 65F rural, 8T, no greeting — hypoglycemic episodes (shakiness + sweating)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-038", "theme": "diabetes",
        "messages": [
            _u("Am 65 de ani și am diabet. Câteodată mă ia tremurăturile și transpir mult, "
               "mai ales dimineața înainte de masă. Mă simt slăbită și panicată în acele momente."),
            _asst(_a("Îmi pare rău să aud. "
                     "De câte ori pe săptămână apar aceste episoade de tremurături și transpirații?", "duration")),
            _u("Cam de două-trei ori pe săptămână în ultima lună. Uneori și după prânz."),
            _asst(_a("Am înțeles. "
                     "Episoadele apar mai ales înainte de masă sau și în alte momente — de exemplu după activitate fizică?",
                     "context")),
            _u("Cel mai des dimineața, înainte de micul dejun. Și o dată a apărut după ce am mers mai mult pe jos."),
            _asst(_a("Înțeleg. "
                     "Cât de repede trece senzația dacă mâncați sau beți ceva dulce?", "associated_symptoms")),
            _u("Repede, cam în zece minute. Dacă mănânc ceva, trece. Dar mă sperie de fiecare dată."),
            _asst(_a("Am înregistrat toate detaliile despre episoade de tremurături și transpirații "
                     "de două-trei ori pe săptămână, mai ales dimineața, cu ameliorare după ingestie de alimente. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-039: DM, 81M rural, 6T, greeting — blurred vision + non-healing hand wound
    {
        "source": "synthetic_triage", "synthetic_id": "synth-039", "theme": "diabetes",
        "messages": [
            _u("Bună ziua. Am 81 de ani și diabet de mult timp. "
               "Văd mai rău de vreo lună și am o rănuță la mâna dreaptă care nu se vindecă de două săptămâni."),
            _asst(_a("Bine, am notat. "
                     "Vederea s-a modificat treptat sau ați observat o schimbare bruscă?", "duration")),
            _u("Treptat, nu dintr-o dată. Parcă cu fiecare săptămână văd puțin mai rău."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Pe lângă vedere și rana de la mână, mai aveți și alte simptome noi — "
                     "de exemplu sete mai mare, oboseală sau urinare frecventă?", "associated_symptoms")),
            _u("Sunt cam obosit, da. Sete mai multă nu prea am. Urinarea e cam la fel ca înainte."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: vedere neclară progresivă de o lună, "
                     "rană la mâna dreaptă care nu se vindecă în două săptămâni și oboseală. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-040: DM, 70F urban, 8T, greeting — fatigue + thirst + poor sleep + neuropathy
    {
        "source": "synthetic_triage", "synthetic_id": "synth-040", "theme": "diabetes",
        "messages": [
            _u("Bună ziua. Am 70 de ani și am diabet de cinci ani. "
               "Ultima vreme sunt foarte obosită, beau multă apă și nu dorm bine."),
            _asst(_a("Am notat. "
                     "De câte zile sau săptămâni aveți aceste simptome de oboseală, sete crescută și somn perturbat?",
                     "duration")),
            _u("De vreo trei săptămâni, cam așa. S-a înrăutățit treptat."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Cât de mult vă afectează oboseala — puteți face treburile obișnuite de casă?", "intensity")),
            _u("Greu. Mă obosesc din orice. Până și gătitul îmi ia mai mult decât înainte."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Mai aveți și alte simptome — de exemplu furnicături la picioare, vedere neclară sau răni ce se vindecă greu?",
                     "associated_symptoms")),
            _u("Da, picioarele furnicată câteodată noaptea. Răni nu am în prezent. Vederea nu s-a schimbat."),
            _asst(_a("Am notat: oboseală marcată, sete crescută, somn perturbat și furnicături la picioare, "
                     "prezente de trei săptămâni. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── ARTHRITIS ────────────────────────────────────────────────────────────

    # synth-041: AR, 73M rural, 8T, no greeting — shoulder pain + limited ROM
    {
        "source": "synthetic_triage", "synthetic_id": "synth-041", "theme": "arthritis",
        "messages": [
            _u("Am 73 de ani și de câteva luni mă doare umărul drept și nu-l mai pot ridica sus. "
               "Am mai mult artroză la genunchi, dar umărul e nou."),
            _asst(_a("Înțeleg. "
                     "De câte luni aveți durerea la umărul drept și limitarea mișcărilor?", "duration")),
            _u("Cam de trei luni. La început era doar când ridicam ceva greu, acum și fără să fac nimic."),
            _asst(_a("Îmi pare rău să aud. "
                     "Pe o scară de la 1 la 10, cât de intensă este durerea la umăr în cel mai rău moment?", "intensity")),
            _u("Cam 7 când ridic brațul. Noaptea e și mai rău, că nu știu cum să dorm."),
            _asst(_a("Vă mulțumesc. "
                     "Umărul s-a umflat vizibil sau aveți și slăbiciune la nivelul brațului — "
                     "de exemplu nu puteți apuca obiecte?", "associated_symptoms")),
            _u("Nu e umflat. Dar când încerc să prind ceva sus sau să mă pieptăn, nu pot din cauza durerii."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu durere la umărul drept de trei luni, intensitate 7, "
                     "cu limitarea mișcărilor și durere nocturnă va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-042: AR, 80F rural, 6T, greeting, VAGUE (mentions unrelated stomach pain as more important)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-042", "theme": "arthritis",
        "messages": [
            _u("Bună ziua. Am 80 de ani și mi s-a umflat glezna stângă după ce am alunecat în curte acum zece zile. "
               "Nu am căzut, dar m-am lovit puțin."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Glezna este mai dureroasă, mai caldă sau mai roșie față de cealaltă?", "context")),
            _u("Da, e puțin umflată. Dar vă spun eu, mai mult mă preocupă că am dureri de stomac de ieri. "
               "Aia mi se pare mai importantă acum."),
            _asst(_a("Am notat. "
                     "Revenind la gleznă — puteți pune greutate pe piciorul stâng fără să simțiți durere?", "intensity")),
            _u("Da, pot merge, dar șchiopătez puțin. Durerea nu e prea mare, cam suportabilă."),
            _asst(_a("Am înregistrat toate detaliile despre glezna stângă umflată de zece zile, "
                     "cu șchiopătat ușor, apărută după un traumatism minor. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-043: AR, 67F urban, 8T, no greeting — cervical pain + neck stiffness + arm radiation
    {
        "source": "synthetic_triage", "synthetic_id": "synth-043", "theme": "arthritis",
        "messages": [
            _u("Am 67 de ani și mă doare gâtul și ceafa de câteva săptămâni. "
               "Nu pot întoarce capul bine în niciun sens și durerea coboară câteodată în braț."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "De câte zile sau săptămâni aveți această durere cervicală cu iradiere în braț?", "duration")),
            _u("De vreo patru-cinci săptămâni. A început de la un curent de aer, cred."),
            _asst(_a("Bine, am notat. "
                     "Pe o scară de la 1 la 10, cât de intensă este durerea în cel mai rău moment?", "intensity")),
            _u("Cam 6-7. Noaptea e mai rău, că nu găsesc o poziție bună."),
            _asst(_a("Înțeleg situația. "
                     "Aveți și amorțeală sau slăbiciune la brațul sau mâna unde coboară durerea?", "associated_symptoms")),
            _u("Câteodată degetele de la mâna dreaptă amorțesc. Slăbiciune nu cred că am, apuc lucrurile normal."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: durere cervicală cu iradiere în brațul drept "
                     "de patru-cinci săptămâni, intensitate 6-7, cu amorțeală la degete și limitare la rotarea capului. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-044: AR, 76M rural, 6T, greeting — bilateral knee pain + crepitus
    {
        "source": "synthetic_triage", "synthetic_id": "synth-044", "theme": "arthritis",
        "messages": [
            _u("Bună ziua. Am 76 de ani și mă dor amândoi genunchii de mult timp. "
               "Câteodată trossnesc când mă ridic. E mai rău în ultima lună."),
            _asst(_a("Vă mulțumesc. "
                     "Durerea s-a înrăutățit recent — de câte zile sau săptămâni se întâmplă asta?", "duration")),
            _u("De cam o lună s-a înrăutățit. Nu știu de ce, că nu am căzut sau nimic."),
            _asst(_a("Am înțeles. "
                     "Durerea este mai intensă la mers, la urcat scări sau mai ales dimineața la ridicare?", "context")),
            _u("La urcat scări cel mai tare. Și la ridicare dimineața. La mers pe plat mai suport."),
            _asst(_a("Am notat: durere bilaterală de genunchi cu crepitus, agravată în ultima lună, "
                     "mai intensă la scări și la ridicare. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── HEART FAILURE ────────────────────────────────────────────────────────

    # synth-045: HF, 78M rural, 8T, no greeting — edema + fatigue + orthopnea
    {
        "source": "synthetic_triage", "synthetic_id": "synth-045", "theme": "heart_failure",
        "messages": [
            _u("Am 78 de ani și de câteva săptămâni nu mai am forță deloc. "
               "Picioarele mi s-au umflat și când merg repede sau urc, respir greu."),
            _asst(_a("Înțeleg. "
                     "De câte zile sau săptămâni aveți oboseală, umflarea picioarelor și dificultăți de respirație la efort?",
                     "duration", priority="urgent")),
            _u("Cam de trei săptămâni. S-a înrăutățit progresiv, nu brusc."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Aveți și tuse sau senzație de greutate în piept, mai ales când vă culcați?",
                     "associated_symptoms", priority="urgent")),
            _u("Da, noaptea tușesc câteodată și stau mai ridicat cu pernele. Altfel parcă nu am aer."),
            _asst(_a("Îmi pare rău să aud. "
                     "Câte perne folosiți de obicei ca să respirați mai ușor noaptea?",
                     "context", priority="urgent")),
            _u("Două-trei. Dacă stau cu una singură, mă trezesc că nu am aer."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu oboseală, picioare umflate, dificultăți de respirație la efort "
                     "și tuse nocturnă cu necesitate de două-trei perne va ajunge la medicul de familie. "
                     "Așteptați consultația.",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # synth-046: HF, 71F urban, 6T, greeting, VAGUE (patient says "don't know" verbally shrugs)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-046", "theme": "heart_failure",
        "messages": [
            _u("Bună ziua. Am 71 de ani și mă trezesc noaptea cu inima bătând repede și nu am aer. "
               "Se întâmplă de câteva ori pe săptămână."),
            _asst(_a("Am notat. "
                     "De câte săptămâni apar aceste episoade nocturne cu palpitații și lipsă de aer?",
                     "duration", priority="urgent")),
            _u("Nu știu. Nici nu mai țin minte. Câteodată mi se pare că de mult, câteodată că de curând. "
               "Pur și simplu nu știu să vă spun."),
            _asst(_a("Bine, am notat. "
                     "Pe lângă palpitații și lipsă de aer noaptea, aveți și picioarele umflate sau oboseală în timpul zilei?",
                     "associated_symptoms", priority="urgent")),
            _u("Da, picioarele mi s-au umflat puțin la glezne. Și sunt obosită, dar credeam că e de la vârstă."),
            _asst(_a("Am înregistrat toate detaliile despre episoade nocturne cu palpitații și dispnee, "
                     "umflarea gleznelor și oboseală diurnă. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # synth-047: HF, 83M rural, 8T, greeting — rapid weight gain + ascites + orthopnea
    {
        "source": "synthetic_triage", "synthetic_id": "synth-047", "theme": "heart_failure",
        "messages": [
            _u("Bună ziua. Am 83 de ani și m-am îngrășat cam cinci kilograme în două săptămâni. "
               "Am și burta umflată și noaptea nu pot respira dacă nu stau cu capul sus."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "De câte săptămâni ați observat această creștere în greutate și umflarea abdomenului?",
                     "duration", priority="urgent")),
            _u("De vreo două săptămâni, da. A venit destul de repede, că nu am mâncat mai mult."),
            _asst(_a("Vă mulțumesc. "
                     "Pe lângă greutate și abdomen umflat, aveți și picioarele umflate sau dificultăți de respirație în timpul zilei?",
                     "associated_symptoms", priority="urgent")),
            _u("Da, picioarele sunt umflate tot timpul. Și pe scări respir foarte greu, nu mai pot urca."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Câte perne folosiți noaptea pentru a respira mai ușor?",
                     "context", priority="urgent")),
            _u("Patru perne. Dacă stau mai plat, mă trezesc că mă sufoc aproape."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: creștere rapidă în greutate de cinci kilograme "
                     "în două săptămâni, abdomen umflat, picioare edematiate și dispnee cu ortopnee la patru perne. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # synth-048: HF, 68F urban, 6T, greeting — persistent cough + dyspnea on stairs + ankle edema
    {
        "source": "synthetic_triage", "synthetic_id": "synth-048", "theme": "heart_failure",
        "messages": [
            _u("Bună ziua. Am 68 de ani și tusesc des în ultima perioadă, mai ales când mă culc. "
               "Și scările le urc tot mai greu."),
            _asst(_a("Înțeleg situația. "
                     "De câte săptămâni aveți această tuse și dificultăți la urcat scări?",
                     "duration", priority="urgent")),
            _u("Cam de o lună, poate puțin mai mult. S-a înrăutățit treptat."),
            _asst(_a("Am înțeles. "
                     "Aveți și picioarele umflate sau senzația de greutate în piept — mai ales seara sau la culcare?",
                     "associated_symptoms", priority="urgent")),
            _u("Da, seara glezna mi se umflă. Și câteodată simt ceva greu în piept când tușesc mult."),
            _asst(_a("Am notat: tuse persistentă mai ales la culcare, dificultăți la urcat scări, "
                     "umflarea gleznei seara și senzație de greutate toracică, prezente de o lună. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # ── COPD ─────────────────────────────────────────────────────────────────

    # synth-049: COPD, 74M rural, 8T, no greeting — exacerbation: dyspnea + yellow sputum + fever
    {
        "source": "synthetic_triage", "synthetic_id": "synth-049", "theme": "copd",
        "messages": [
            _u("Am 74 de ani și am BPOC confirmat. "
               "De vreo zece zile respir mai greu decât de obicei și scot mai mult mucus galben. Am și o febră ușoară."),
            _asst(_a("Înțeleg. "
                     "De câte zile s-au agravat dificultățile de respirație și a apărut sputa galbenă?", "duration")),
            _u("Cam de zece zile. A început după o răceală."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Cât de limitați sunteți acum față de obișnuit — ce distanță puteți parcurge fără să vă opriți?",
                     "intensity")),
            _u("Cam 50-60 de metri. Înainte mergeam până la vecini fără problemă, acum nu mai pot."),
            _asst(_a("Am notat. "
                     "Aveți și febră măsurată sau durere în piept pe lângă tusea cu spută galbenă?", "associated_symptoms")),
            _u("Febra am măsurat-o ieri, 37,8. Durere în piept nu am, dar simt o presiune când tușesc."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu agravarea dispneei, spută galbenă și febră de zece zile, "
                     "cu reducerea toleranței la efort, va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-050: COPD, 67F urban, 6T, greeting, VAGUE (repeats herself, goes around the question)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-050", "theme": "copd",
        "messages": [
            _u("Bună ziua. Am 67 de ani și am bronșită cronică. "
               "Am început să respir din ce în ce mai greu și nu mai pot face ce făceam înainte."),
            _asst(_a("Îmi pare rău să aud. "
                     "De câte săptămâni sau luni s-a înrăutățit respirația dumneavoastră?", "duration")),
            _u("Ei, e greu de spus. Mereu am avut probleme. Cam greu respir de când mă știu. "
               "Acum e mai greu, dar tot timpul a fost greu. Nu știu cum să vă spun mai bine."),
            _asst(_a("Bine, am notat. "
                     "Față de acum trei luni, puteți face mai puțin — de exemplu mersul la piață sau urcatul scărilor?",
                     "context")),
            _u("Da, față de iarnă e mai rău. Piața nu mai pot să merg singură, că mă opresc de două-trei ori."),
            _asst(_a("Am înregistrat toate detaliile despre agravarea dispneei față de acum trei luni, "
                     "cu reducerea toleranței la mers și necesitate de pauze frecvente. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-051: COPD, 81M rural, 8T, greeting — chronic cough suddenly worse + chest tightness after URI
    {
        "source": "synthetic_triage", "synthetic_id": "synth-051", "theme": "copd",
        "messages": [
            _u("Bună ziua. Am 81 de ani și tusesc de mulți ani, că am fumatul la tineret. "
               "Dar ultimele două săptămâni tusea s-a înrăutățit brusc și simt o strângere în piept."),
            _asst(_a("Vă mulțumesc. "
                     "Această agravare bruscă a tusei și strângerea din piept au apărut după o răceală sau alt eveniment?",
                     "context")),
            _u("Da, după o răceală cam acum trei săptămâni. Răceala s-a mai dus, dar tusea și strângerea au rămas."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Pe lângă tuse și strângere în piept, aveți și dificultăți de respirație mai mari decât de obicei sau febră?",
                     "associated_symptoms")),
            _u("Dificultăți de respirație da, mai mult ca de obicei. Febră nu am."),
            _asst(_a("Înțeleg situația. "
                     "Cât de mult puteți merge fără să vă opriți din cauza respirației?", "intensity")),
            _u("Cam 50 de metri pe plat. Mai puțin dacă e deal. Nu mai pot merge la capătul satului."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: agravarea bruscă a tusei cronice și strângere în piept "
                     "de două-trei săptămâni, după o răceală, cu dificultăți de respirație și toleranță redusă la efort. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-052: COPD, 65F urban, 6T, no greeting — new respiratory symptoms after quitting smoking
    {
        "source": "synthetic_triage", "synthetic_id": "synth-052", "theme": "copd",
        "messages": [
            _u("Am 65 de ani și am renunțat la fumat acum trei luni. "
               "Dar de atunci, în loc să mă simt mai bine, am o tuse mai persistentă și uneori respir mai greu."),
            _asst(_a("Am înțeles. "
                     "De câte luni aveți această tuse persistentă de la oprirea fumatului?", "duration")),
            _u("De cam două luni. Am crezut că trece singură, că am auzit că e normal la început."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Pe lângă tuse, aveți și spută, dificultăți de respirație la efort sau alte simptome noi?",
                     "associated_symptoms")),
            _u("Câteva spute dimineața, da, uneori gălbui. La urcatul scărilor respir mai greu decât înainte de a lăsa fumatul."),
            _asst(_a("Am notat: tuse persistentă de două luni de la renunțarea la fumat, spută gălbuie dimineața "
                     "și dispnee la urcat scări, cu antecedente de fumat. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── GENERAL ──────────────────────────────────────────────────────────────

    # synth-053: general/headache, 72M rural, 6T, greeting, VAGUE (patient deflects to stress/gardening)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-053", "theme": "general",
        "messages": [
            _u("Bună ziua. Am 72 de ani și mă doare capul de mai bine de o săptămână. "
               "Nu e un cap de durere obișnuit, e mai persistent."),
            _asst(_a("Înțeleg. "
                     "Unde exact vă doare capul — în față, în spate, pe o parte sau tot capul?", "context")),
            _u("Mă doare tot capul, dar știți, am multă treabă acum. Că nepotul a venit și am stat mult în grădină. "
               "Poate e de la asta, că am muncit prea mult."),
            _asst(_a("Am notat. "
                     "Durerea se înrăutățește la lumină sau zgomot sau este constantă pe tot parcursul zilei?",
                     "associated_symptoms")),
            _u("Nu mi se pare că o face lumina mai rea. E constantă, tot timpul e acolo, mai tare sau mai puțin tare."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu durere de cap difuză și persistentă de o săptămână, posibil legată de suprasolicitare fizică, "
                     "va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-054: general/back pain, 69F urban, 6T, no greeting — acute lumbar pain after gardening
    {
        "source": "synthetic_triage", "synthetic_id": "synth-054", "theme": "general",
        "messages": [
            _u("Am 69 de ani și ieri am muncit în grădină și acum mă doare spatele în zona de jos, "
               "nu mă pot îndoi bine. E durere acută, brusc apărută."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Durerea a apărut imediat după ce ați muncit sau la câteva ore distanță?", "duration")),
            _u("La câteva ore, seara. Dimineața m-am trezit și abia puteam să mă ridic din pat."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Pe o scară de la 1 la 10, cât de intensă este durerea de spate acum?", "intensity")),
            _u("Cam 7-8. Mă doare și când stau jos și când mă ridic. Să mă aplec nu pot deloc."),
            _asst(_a("Am înregistrat toate detaliile despre durere lombară acută de intensitate 7-8, "
                     "apărută după efort fizic în grădină, cu limitarea mișcărilor de flexie și dificultăți la ridicare. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-055: general/dizziness, 76F rural, 6T, greeting — positional vertigo episodes
    {
        "source": "synthetic_triage", "synthetic_id": "synth-055", "theme": "general",
        "messages": [
            _u("Bună ziua. Am 76 de ani și de câteva zile mă amețesc când mă întorc în pat "
               "sau când îmi ridic capul brusc. Trece repede, dar mă sperie."),
            _asst(_a("Bine, am notat. "
                     "De câte zile apar aceste episoade de amețeală la schimbarea poziției capului?", "duration")),
            _u("De vreo patru-cinci zile. Se întâmplă de câteva ori pe zi, mai ales dimineața."),
            _asst(_a("Vă mulțumesc. "
                     "Pe lângă amețeală, mai aveți și alte simptome — "
                     "de exemplu greață, zgomote în urechi sau dificultăți de echilibru la mers?", "associated_symptoms")),
            _u("Câteodată mi-e și un pic greață. Zgomote nu am. La mers sunt OK dacă merg încet."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: amețeală pozițională de patru-cinci zile, "
                     "cu greață ușoară, declanșată de schimbarea poziției capului. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },
]


# ---------------------------------------------------------------------------
# 9c-iii — 50 batch dialogues (synth-056..synth-105)
# ---------------------------------------------------------------------------

_BOUNDARY = "Medicul de familie va răspunde la această întrebare în cadrul consultației."

BATCH_50C_DIALOGUES = [

    # ── HYPERTENSION ─────────────────────────────────────────────────────────

    # synth-056: HT, 67F urban, 8T, no greeting — fatigue + high home BP readings
    {
        "source": "synthetic_triage", "synthetic_id": "synth-056", "theme": "hypertension",
        "messages": [
            _u("Am 67 de ani și am tensiunea mare de câțiva ani. "
               "De câteva zile mă simt obosită și am măsurat tensiunea acasă — mi-a ieșit valori mari."),
            _asst(_a("Înțeleg. De câte zile aveți aceste valori ridicate acasă și vă simțiți obosită?",
                     "duration")),
            _u("De vreo cinci zile. Dimineața e mai mare, spre seară mai puțin."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Ce valori ați obținut la aparat, aproximativ?", "intensity")),
            _u("Cam 160 în sus. Uneori 170. Doctorul mi-a zis să am sub 140."),
            _asst(_a("Bine, am notat. "
                     "Pe lângă oboseală și tensiunea crescută, mai aveți și alte simptome — "
                     "de exemplu dureri de cap, amețeală sau vedere neclară?", "associated_symptoms")),
            _u("Da, mă doare capul puțin în fiecare dimineață. Amețeală nu am prea mult."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: oboseală, valori tensionale ridicate acasă "
                     "și dureri de cap matinale de cinci zile. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-057: HT, 74M rural, 6T, greeting — nosebleeds + headache
    {
        "source": "synthetic_triage", "synthetic_id": "synth-057", "theme": "hypertension",
        "messages": [
            _u("Bună ziua. Am 74 de ani și din când în când îmi curge sânge din nas. "
               "Săptămâna trecută a durat mai mult. Am și dureri de cap câteodată."),
            _asst(_a("Am notat. De câte ori pe lună vi se întâmplă să curgă sânge din nas?", "duration")),
            _u("Cam de două-trei ori. Dar săptămâna trecută a durat cam zece minute și nu s-a oprit ușor."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Pe lângă sângerările nazale și durerile de cap, mai aveți și alte simptome noi — "
                     "de exemplu amețeală sau vedere încetoșată?", "associated_symptoms")),
            _u("Amețeală câteodată, da. Vedere mai puțin, nu prea observ schimbări."),
            _asst(_a("Am notat: sângerări nazale recurente cu un episod prelungit de zece minute, "
                     "dureri de cap și amețeală ocazională. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-058: HT, 80F rural, 8T, greeting — severe morning headache + neck stiffness
    {
        "source": "synthetic_triage", "synthetic_id": "synth-058", "theme": "hypertension",
        "messages": [
            _u("Bună ziua. Am 80 de ani și în ultima săptămână mă doare capul puternic dimineața, "
               "mai ales când mă trezesc. Și ceafa mi-e cam rigidă."),
            _asst(_a("Îmi pare rău să aud. "
                     "De câte zile aveți această durere de cap matinală și rigiditate la ceafă?", "duration")),
            _u("De o săptămână, cam de luni. Nu a mai trecut de atunci."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Pe o scară de la 1 la 10, cât de intensă este durerea de cap la trezire?", "intensity")),
            _u("Cam 7-8. E destul de rău. Dimineața e cel mai greu."),
            _asst(_a("Am înțeles. "
                     "Pe lângă durerea de cap și ceafa rigidă, mai aveți și alte simptome — "
                     "de exemplu greață, vedere neclară sau sensibilitate la lumină?", "associated_symptoms")),
            _u("Da, greață am un pic dimineața. La lumină nu mă deranjează. Văd la fel."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu dureri de cap matinale de intensitate 7-8, ceafă rigidă și greață de o săptămână "
                     "va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-059: HT, 72M urban, 6T, no greeting, VAGUE (minimizes: "nu e nimic grav")
    {
        "source": "synthetic_triage", "synthetic_id": "synth-059", "theme": "hypertension",
        "messages": [
            _u("Am 72 de ani. Mă bâzâie urechile câteodată și mă amețesc. "
               "Dar nu e nimic grav, cred, pentru că îmi trece singur."),
            _asst(_a("Vă mulțumesc. "
                     "De câte zile sau săptămâni aveți aceste episoade de bâzâit în urechi și amețeală?",
                     "duration")),
            _u("Ei, câteodată apare, nu știu exact. Nu e nimic grav probabil. "
               "La vârsta mea e normal să mai apară ceva."),
            _asst(_a("Înțeleg situația. "
                     "Episoadele apar mai ales la schimbarea poziției sau și în repaus?", "context")),
            _u("Mai ales când mă ridic. Stând jos nu prea îmi bâzâie."),
            _asst(_a("Am înregistrat toate detaliile despre bâzâit în urechi și amețeală la ridicare, "
                     "cu durată și frecvență nedeterminate. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-060: HT, 65F rural, 6T, no greeting — visual aura + headache
    {
        "source": "synthetic_triage", "synthetic_id": "synth-060", "theme": "hypertension",
        "messages": [
            _u("Am 65 de ani și am tensiunea mare de câțiva ani. "
               "Câteodată înainte să mă doară capul văd niște lumini sau scântei în fața ochilor."),
            _asst(_a("Înțeleg. "
                     "De câte săptămâni apar aceste lumini vizuale înainte de durerea de cap?", "duration")),
            _u("De câteva săptămâni, cam o dată pe săptămână. Durează cam 20 de minute."),
            _asst(_a("Am notat. "
                     "Pe lângă luminile vizuale și durerea de cap, mai aveți și alte simptome în acel episod — "
                     "de exemplu greață, amețeală sau amorțeală?", "associated_symptoms")),
            _u("Câteodată mi-e și un pic greață. Amețeală ușoară. Nu am amorțeală."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: episoade de scântei vizuale urmate de dureri de cap, "
                     "o dată pe săptămână de câteva săptămâni, cu greață și amețeală ușoare. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-061: HT, 78M urban, 8T, greeting — TIA-like episode (confuzie + dysarthria + arm weakness)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-061", "theme": "hypertension",
        "messages": [
            _u("Bună ziua. Am 78 de ani și tensiunea am ridicată. "
               "Ieri am avut un episod ciudat — pentru câteva minute am fost confuz, nu știam unde sunt. "
               "Soția a zis că vorbeam neinteligibil."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Cât timp a durat acest episod de confuzie și vorbire neclară?", "duration",
                     priority="urgent")),
            _u("Cam cinci-zece minute. Soția a cronometrat. Și a trecut de la sine."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Pe lângă confuzie și vorbire neclară, ați mai avut slăbiciune pe o parte a corpului "
                     "sau vedere neclară în acel episod?", "associated_symptoms", priority="urgent")),
            _u("Slăbiciune nu știu, nu prea am simțit. Soția zice că brațul stâng îl mișcam mai greu."),
            _asst(_a("Îmi pare rău să aud. "
                     "Ați mai avut episoade similare de confuzie sau slăbiciune tranzitorie în trecut?",
                     "history", priority="urgent")),
            _u("Nu, e prima dată. Ieri a fost primul episod de acest gen."),
            _asst(_a("Am notat: episod de confuzie, vorbire neclară și posibilă slăbiciune a brațului stâng ieri, "
                     "cu durată de cinci-zece minute și remisiune spontană. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # ── DIABETES ─────────────────────────────────────────────────────────────

    # synth-062: DM, 71F rural, 6T, greeting — polyuria + polydipsia + weight gain
    {
        "source": "synthetic_triage", "synthetic_id": "synth-062", "theme": "diabetes",
        "messages": [
            _u("Bună ziua. Am 71 de ani și am diabet. "
               "Ultima lună beau mult mai multă apă decât de obicei și merg des la toaletă. "
               "Am și luat puțin în greutate, ciudat, că nu mănânc mai mult."),
            _asst(_a("Bine, am notat. "
                     "De câte săptămâni aveți aceste simptome de sete intensă și urinare frecventă?", "duration")),
            _u("Cam de o lună, da. A venit treptat."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Pe lângă sete, urinare frecventă și creștere în greutate, mai simțiți și alte schimbări — "
                     "de exemplu oboseală, vedere neclară sau furnicături?", "associated_symptoms")),
            _u("Sunt mai obosită decât de obicei. Vedere și furnicături nu prea."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu sete intensă, urinare frecventă, creștere ușoară în greutate și oboseală de o lună "
                     "va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-063: DM, 78M urban, 8T, greeting — diabetic foot: darkened toe, painless
    {
        "source": "synthetic_triage", "synthetic_id": "synth-063", "theme": "diabetes",
        "messages": [
            _u("Bună ziua. Am 78 de ani și am diabet de mulți ani. "
               "Piciorul drept mi s-a înnegrit la un deget — o bătătură veche, dar acum e mai rea, "
               "cu o zonă întunecată."),
            _asst(_a("Înțeleg. "
                     "De câte zile sau săptămâni observați această zonă întunecată la degetul piciorului drept?",
                     "duration")),
            _u("De cam două săptămâni m-am uitat la ea mai atent. Dar bătătura e de mai mult."),
            _asst(_a("Am înțeles. "
                     "Zona afectată este dureroasă sau nu simțiți durere în acel deget?", "intensity")),
            _u("Nu prea doare, de fapt. Și asta mă îngrijorează, că am auzit că e rău când nu doare."),
            _asst(_a("Vă mulțumesc. "
                     "Mai aveți și alte răni sau zone similare la picioare sau alte simptome noi — "
                     "de exemplu febră sau umflare?", "associated_symptoms")),
            _u("Nu am altceva. Umflare nu am la picior. Febră nu am."),
            _asst(_a("Am înregistrat toate detaliile despre zona întunecată la degetul piciorului drept "
                     "de două săptămâni, nedureroasă, pe fond de diabet. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-064: DM, 66F rural, 6T, no greeting — hyperosmolar: severe thirst + weakness
    {
        "source": "synthetic_triage", "synthetic_id": "synth-064", "theme": "diabetes",
        "messages": [
            _u("Am 66 de ani și am diabet de trei ani. "
               "De câteva zile sete mi-e extraordinar de mare, beau litri de apă. Și mă simt foarte slabă."),
            _asst(_a("Am notat. "
                     "De câte zile aveți această sete intensă și slăbiciune marcată?", "duration")),
            _u("De vreo patru-cinci zile. E mai rău decât am mai simțit înainte."),
            _asst(_a("Înțeleg situația. "
                     "Pe lângă sete și slăbiciune, mai aveți și alte simptome — "
                     "de exemplu greață, amețeală sau respirație cu miros diferit?", "associated_symptoms")),
            _u("Am și greață un pic. Amețeală câteodată când mă ridic. Respirație nu știu."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: sete intensă, slăbiciune marcată, greață "
                     "și amețeală ortostatică de patru-cinci zile, mai pronunțate decât de obicei. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-065: DM, 82M rural, 8T, greeting, VAGUE (dumps multiple complaints at once)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-065", "theme": "diabetes",
        "messages": [
            _u("Bună ziua. Am 82 de ani și am diabet. "
               "Mă simt rău în ultimul timp — am oboseală, văd mai rău și picioarele mă furnicată, toate deodată."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Care dintre aceste simptome vă deranjează cel mai mult și a apărut primul?", "context")),
            _u("Oboseala e cel mai rău. Furnicăturile le am de mai mult, dar oboseala e mai nouă."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "De câte zile sau săptămâni simțiți această oboseală mai intensă față de obișnuit?", "duration")),
            _u("De cam trei săptămâni, da. Mă obosesc din orice, nu mai pot face nimic."),
            _asst(_a("Bine, am notat. "
                     "Oboseala este însoțită și de sete mai mare sau de urinare mai frecventă decât de obicei?",
                     "associated_symptoms")),
            _u("Da, beau mai multă apă și merg mai des la baie. Mai ales noaptea mă trezesc."),
            _asst(_a("Am notat: oboseală marcată de trei săptămâni, furnicături la picioare de durată mai lungă, "
                     "vedere modificată, sete crescută și urinare nocturnă frecventă. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-066: DM, 70F urban, 6T, no greeting — recurrent UTIs as DM complication
    {
        "source": "synthetic_triage", "synthetic_id": "synth-066", "theme": "diabetes",
        "messages": [
            _u("Am 70 de ani și diabet. Am tot mai des senzație de arsură când fac pipi "
               "și merg mai des la baie. S-a întâmplat de câteva ori în ultimele luni."),
            _asst(_a("Înțeleg. "
                     "Cât de des ați avut aceste episoade de arsură la urinare în ultimele luni?", "duration")),
            _u("Cam de trei-patru ori în ultimele șase luni. Acum a venit din nou."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Pe lângă arsura la urinare și frecvența crescută, mai aveți și alte simptome — "
                     "de exemplu febră, frisoane sau dureri în zona lombară?", "associated_symptoms")),
            _u("Câteodată am o ușoară febră. Dureri în spate nu am. Frisoane nu."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu episoade recurente de arsură la urinare și frecvență crescută, "
                     "cu febră ușoară ocazională, va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-067: DM, 75M rural, 6T, greeting — weight loss + nausea + anorexia
    {
        "source": "synthetic_triage", "synthetic_id": "synth-067", "theme": "diabetes",
        "messages": [
            _u("Bună ziua. Am 75 de ani și diabet. "
               "Ultima lună am slăbit cam patru kilograme fără să încerc și mi-e greață câteodată, "
               "mai ales dimineața."),
            _asst(_a("Îmi pare rău să aud. "
                     "De câte săptămâni aveți această pierdere în greutate și greață matinală?", "duration")),
            _u("De cam o lună. Am slăbit cam patru kilograme, că pantalonii nu mai stau."),
            _asst(_a("Am notat. "
                     "Pe lângă slăbire și greață, mai aveți și alte simptome — de exemplu dureri abdominale "
                     "sau modificări ale apetitului?", "associated_symptoms")),
            _u("Nu prea am chef de mâncat. Stomacul nu mă doare, dar mi-e greață când mă gândesc la mâncare."),
            _asst(_a("Am înregistrat toate detaliile despre pierdere în greutate de patru kilograme, "
                     "greață matinală și apetit scăzut de o lună. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── ARTHRITIS ────────────────────────────────────────────────────────────

    # synth-068: AR, 70F rural, 6T, no greeting — wrist pain + morning stiffness
    {
        "source": "synthetic_triage", "synthetic_id": "synth-068", "theme": "arthritis",
        "messages": [
            _u("Am 70 de ani și de câteva luni mă dor încheieturile mâinilor. "
               "Dimineața sunt rigide și umflate. Am artroză la genunchi de mai mult timp, dar mâinile sunt noi."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "De câte luni aveți durerea și rigiditatea matinală la încheieturile mâinilor?", "duration")),
            _u("Cam de trei luni. A început treptat, prima dată mâna dreaptă, acum și stânga."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Rigiditatea matinală durează mai mult de 30 de minute sau trece mai repede?", "intensity")),
            _u("Cam 45-60 de minute. Dacă fac mișcare, mai trece. Stând nemișcată e mai rău."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: durere și rigiditate matinală la ambele mâini "
                     "de trei luni, cu durată de 45-60 de minute. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-069: AR, 78M urban, 8T, greeting — lumbar stenosis: pain + neurogenic claudication
    {
        "source": "synthetic_triage", "synthetic_id": "synth-069", "theme": "arthritis",
        "messages": [
            _u("Bună ziua. Am 78 de ani și de ceva vreme mă doare spatele jos și simt că picioarele îmi slăbesc "
               "când merg mai mult. Trebuie să mă opresc și să mă sprijin de ceva."),
            _asst(_a("Vă mulțumesc. "
                     "De câte luni aveți această durere lombară cu slăbiciune la picioare la mers?", "duration")),
            _u("De cam șase luni s-a înrăutățit. Înainte mai trecea singură, acum nu prea."),
            _asst(_a("Înțeleg. "
                     "După câți metri de mers trebuie să vă opriți?", "intensity")),
            _u("Cam 100-150 de metri. Dacă mă sprijin de ceva sau mă aplec puțin, trece și pot continua."),
            _asst(_a("Am înțeles. "
                     "Durerea și slăbiciunea la picioare apar mai mult la mers sau și când stați în picioare nemișcat?",
                     "context")),
            _u("Mai mult la mers, dar și dacă stau în picioare mult. Când stau jos, trece aproape complet."),
            _asst(_a("Am notat: durere lombară cu slăbiciune la picioare la mers de șase luni, "
                     "ameliorată la aplecarea înainte și dispărând la șezut. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-070: AR, 73F rural, 6T, greeting, VAGUE (folk medicine: "e de la frig și umezeală")
    {
        "source": "synthetic_triage", "synthetic_id": "synth-070", "theme": "arthritis",
        "messages": [
            _u("Bună ziua. Am 73 de ani și genunchii mă dor, că am artroză. "
               "Mai rău e acum de la umezeală și frig, știu eu că e de la asta."),
            _asst(_a("Am notat. "
                     "Pe o scară de la 1 la 10, cât de intensă este durerea la genunchi în momentele cele mai dificile?",
                     "intensity")),
            _u("Ei, depinde de vreme. Dacă plouă, e cam 8. Dacă e frumos, e cam 4-5. "
               "Doctorii nu cred în treaba cu vremea, dar eu știu că e adevărat."),
            _asst(_a("Înțeleg situația. "
                     "Genunchii se și umflă sau prezintă roșeață — indiferent de condițiile meteo?", "associated_symptoms")),
            _u("Câteodată se umflă puțin, mai ales cel stâng. Roșeață nu observ."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu dureri de genunchi variind între 4 și 8, cu umflare ocazională a genunchiului stâng, "
                     "va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-071: AR, 81M rural, 8T, no greeting — post-hip-prosthesis persistent pain
    {
        "source": "synthetic_triage", "synthetic_id": "synth-071", "theme": "arthritis",
        "messages": [
            _u("Am 81 de ani și am schimbat șoldul drept cu proteză acum doi ani. "
               "Dar ultimele luni tot mă doare în zona operată, mai ales când merg pe distanțe mai lungi."),
            _asst(_a("Înțeleg. "
                     "De câte luni ați observat că durerea în zona protezei a revenit sau s-a înrăutățit?",
                     "duration")),
            _u("De cam trei luni. La început credeam că e normal, dar nu trece."),
            _asst(_a("Bine, am notat. "
                     "Pe o scară de la 1 la 10, cât de intensă este durerea la mers?", "intensity")),
            _u("Cam 5-6. Nu mă opresc din mers, dar la capătul zilei sunt foarte obosit de durere."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Durerea apare mai ales la mers sau și în repaus sau noaptea?", "context")),
            _u("La mers mai mult. Noaptea câteodată mă trezesc, mai rar. În repaus stau bine."),
            _asst(_a("Am înregistrat toate detaliile despre durere la zona protezei de șold drept de trei luni, "
                     "intensitate 5-6, mai accentuată la mers și ocazional nocturnă. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-072: AR, 68F urban, 8T, greeting — widespread pain + fatigue (fibromyalgia-like)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-072", "theme": "arthritis",
        "messages": [
            _u("Bună ziua. Am 68 de ani și de câteva luni mă doare tot corpul, nu în articulații anume, "
               "ci mai difuz. Și mă simt extrem de obosită, chiar și după un somn bun."),
            _asst(_a("Îmi pare rău să aud. "
                     "De câte luni aveți această durere difuză în tot corpul și oboseala intensă?", "duration")),
            _u("De cam patru luni. A venit treptat, fără motiv aparent."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Pe o scară de la 1 la 10, cât de intensă este durerea difuză în cele mai rele momente?",
                     "intensity")),
            _u("Cam 6-7. Nu pot face treburile casei fără să mă opresc des."),
            _asst(_a("Am notat. "
                     "Durerea se înrăutățește cu activitatea fizică sau și în repaus — "
                     "de exemplu dimineața la trezire?", "context")),
            _u("Dimineața sunt cel mai rău, cu rigiditate. Dar după activitate mă simt mai rău seara."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: durere difuză în tot corpul, oboseală marcată "
                     "și rigiditate matinală de patru luni, cu agravare la efort. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── HEART FAILURE ────────────────────────────────────────────────────────

    # synth-073: HF, 79M rural, 8T, no greeting — edema + cough + exertional dyspnea
    {
        "source": "synthetic_triage", "synthetic_id": "synth-073", "theme": "heart_failure",
        "messages": [
            _u("Am 79 de ani și am probleme cu inima de mulți ani. "
               "Ultimele trei săptămâni picioarele s-au umflat tot mai mult, tușesc mai des și mă obosesc repede."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "De câte săptămâni s-au înrăutățit umflarea picioarelor și tusea?",
                     "duration", priority="urgent")),
            _u("De cam trei săptămâni. S-a agravat treptat."),
            _asst(_a("Înțeleg situația. "
                     "Pe lângă picioarele umflate și tuse, aveți și dificultăți de respirație — "
                     "mai ales noaptea sau la urcat scări?", "associated_symptoms", priority="urgent")),
            _u("Da, pe scări nu mai pot urca. Și noaptea câteodată mă trezesc să stau cu capul sus."),
            _asst(_a("Bine, am notat. "
                     "Câte perne folosiți noaptea pentru a respira mai ușor?", "context", priority="urgent")),
            _u("Două-trei, cam câte am. Dacă stau cu una, parcă mă sufoc."),
            _asst(_a("Am notat: umflarea progresivă a picioarelor, tuse, dispnee la efort și nocturnă "
                     "cu necesitate de două-trei perne, de trei săptămâni. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # synth-074: HF, 72F urban, 6T, greeting — fatigue + bilateral leg edema + orthopnea
    {
        "source": "synthetic_triage", "synthetic_id": "synth-074", "theme": "heart_failure",
        "messages": [
            _u("Bună ziua. Am 72 de ani și am o boală de inimă. "
               "De câteva săptămâni oboseala s-a înrăutățit mult și picioarele mi s-au umflat. "
               "Și noaptea nu pot sta plat."),
            _asst(_a("Înțeleg. "
                     "De câte săptămâni aveți oboseala agravată și umflarea picioarelor?",
                     "duration", priority="urgent")),
            _u("De cam patru săptămâni. S-a înrăutățit treptat."),
            _asst(_a("Am înțeles. "
                     "Pe lângă oboseală și picioarele umflate, mai aveți și alte simptome — "
                     "de exemplu tuse sau senzație de greutate în piept?", "associated_symptoms", priority="urgent")),
            _u("Da, tușesc destul de des, mai ales seara. Și câteodată simt o presiune în piept când urc scările."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu oboseală, picioare umflate, tuse și presiune toracică de patru săptămâni "
                     "va ajunge la medicul de familie. Așteptați consultația.",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # synth-075: HF, 84M rural, 6T, no greeting, VAGUE (asks AI question: "ce să fac?")
    {
        "source": "synthetic_triage", "synthetic_id": "synth-075", "theme": "heart_failure",
        "messages": [
            _u("Am 84 de ani și inima mea nu mai e ce-a fost. "
               "De câteva zile respir greu și îmi bate inima tare câteodată."),
            _asst(_a("Am notat. "
                     "De câte zile aveți dificultăți de respirație și palpitații?",
                     "duration", priority="urgent")),
            _u("De vreo cinci zile. Ce să fac cu asta? E grav?"),
            _asst(_a(f"Vă mulțumesc. {_BOUNDARY} "
                     "Aveți și picioarele umflate sau vă treziți noaptea din cauza respirației?",
                     "associated_symptoms", priority="urgent")),
            _u("Da, picioarele se umflă un pic. Noaptea mă trezesc câteodată că nu am aer."),
            _asst(_a("Am înregistrat toate detaliile despre dificultăți de respirație, palpitații "
                     "și umflarea picioarelor de cinci zile, cu treziri nocturne. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # synth-076: HF, 70F rural, 8T, greeting — cardiac hx + rapid weight gain + dyspnea
    {
        "source": "synthetic_triage", "synthetic_id": "synth-076", "theme": "heart_failure",
        "messages": [
            _u("Bună ziua. Am 70 de ani și am o afecțiune cardiacă urmărită de mai mulți ani. "
               "Dar acum am luat cam trei kilograme în două săptămâni și respir mai greu."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "De câte săptămâni ați observat această creștere în greutate și dificultăți de respirație?",
                     "duration", priority="urgent")),
            _u("De vreo două săptămâni. Cam rapid a venit creșterea în greutate."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Pe lângă creșterea în greutate și dificultăți de respirație, "
                     "aveți și picioarele umflate sau tuse?", "associated_symptoms", priority="urgent")),
            _u("Da, glezna mi s-a umflat. Și tușesc mai ales noaptea."),
            _asst(_a("Îmi pare rău să aud. "
                     "Aveți nevoie să stați cu capul ridicat pe perne ca să respirați mai ușor noaptea?",
                     "context", priority="urgent")),
            _u("Da, stau cu două-trei perne. Altfel mă trezesc că parcă nu am aer."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: creștere în greutate de trei kilograme "
                     "în două săptămâni, gleznă umflată, tuse nocturnă și ortopnee la două-trei perne. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # synth-077: HF, 77M urban, 6T, no greeting — worsening bilateral ankle edema
    {
        "source": "synthetic_triage", "synthetic_id": "synth-077", "theme": "heart_failure",
        "messages": [
            _u("Am 77 de ani și inima mea e urmărită de mulți ani. "
               "Dar ultima lună mi s-au umflat ambele glezne mai rău ca de obicei și nu mai pot merge la fel."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "De câte săptămâni s-a agravat umflarea gleznelor față de starea obișnuită?",
                     "duration", priority="urgent")),
            _u("De cam o lună. Înainte se mai umflau puțin, acum e mult mai vizibil."),
            _asst(_a("Înțeleg. "
                     "Pe lângă gleznele umflate, mai aveți și alte simptome noi — "
                     "de exemplu dificultăți de respirație la mers sau tuse?", "associated_symptoms", priority="urgent")),
            _u("Da, pe scări respir greu. Tuse am câteodată, mai ales seara."),
            _asst(_a("Am notat: agravarea umflării bilaterale a gleznelor de o lună, "
                     "dispnee la urcat scări și tuse vesperală. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", priority="urgent", ready_to_finalize=True)),
        ],
    },

    # ── COPD ─────────────────────────────────────────────────────────────────

    # synth-078: COPD, 66M rural, 6T, greeting — acute exacerbation: dyspnea + purulent sputum
    {
        "source": "synthetic_triage", "synthetic_id": "synth-078", "theme": "copd",
        "messages": [
            _u("Bună ziua. Am 66 de ani și am bronhopneumopatie cronică. "
               "De vreo zece zile am o agravare — respir mult mai greu și scot mucus verde-gălbui."),
            _asst(_a("Am notat. "
                     "De câte zile s-au agravat dificultățile de respirație și s-a modificat culoarea sputei?",
                     "duration")),
            _u("De cam zece zile, da. A venit după o răceală."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Cât de limitați sunteți față de obișnuit — ce distanță puteți parcurge fără oprire?",
                     "intensity")),
            _u("Cam 30-40 de metri. Înainte puteam mult mai mult fără să mă opresc."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu agravarea dispneei și spută verde-gălbuie de zece zile, "
                     "cu toleranță la efort redusă la 30-40 de metri, va ajunge la medicul de familie. "
                     "Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-079: COPD, 79F rural, 8T, no greeting — chronic productive cough + weight loss + night sweats
    {
        "source": "synthetic_triage", "synthetic_id": "synth-079", "theme": "copd",
        "messages": [
            _u("Am 79 de ani și am bronșită cronică. Tusesc de mulți ani. "
               "Dar ultimele două luni scot mai mult mucus și am slăbit cam trei kilograme. Mă îngrijorează."),
            _asst(_a("Înțeleg. "
                     "De câte luni ați observat că tusea s-a înrăutățit și ați început să slăbiți?", "duration")),
            _u("Cam de două luni, da. Slăbitul a venit treptat."),
            _asst(_a("Bine, am notat. "
                     "Sputa pe care o eliminați și-a schimbat culoarea sau consistența față de obișnuit?", "context")),
            _u("Da, e mai multă și mai gălbuie. Înainte era mai clară și mai puțin."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Pe lângă tusea agravată, sputa modificată și slăbire, mai aveți și alte simptome — "
                     "de exemplu febră, transpirații sau dificultăți de respirație mai mari?", "associated_symptoms")),
            _u("Transpirații câteodată noaptea. Respirația e cam la fel, nu mult mai rău față de obișnuit. Febră nu am."),
            _asst(_a("Am înregistrat toate detaliile despre agravarea tusei cronice cu spută gălbuie, "
                     "pierdere în greutate de trei kilograme și transpirații nocturne de două luni. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-080: COPD, 73M urban, 6T, greeting, VAGUE (minimizes: "nu e nimic grav probabil")
    {
        "source": "synthetic_triage", "synthetic_id": "synth-080", "theme": "copd",
        "messages": [
            _u("Bună ziua. Am 73 de ani și am BPOC. "
               "Cam în fiecare toamnă mi se înrăutățește tusea. Acum e cam la fel, nu e nimic grav probabil."),
            _asst(_a("Vă mulțumesc. "
                     "Față de toamnele anterioare, agravarea din acest an este la fel de intensă sau mai severă?",
                     "context")),
            _u("Nu e nimic grav probabil. Că tot apar. Nu știu, cam la fel, poate ceva mai rău, dar nu e sigur. E sezonul."),
            _asst(_a("Am înțeles. "
                     "Cât de mult puteți merge înainte să vă opriți din cauza respirației acum, "
                     "față de urmă cu o lună?", "intensity")),
            _u("Cam jumătate din cât puteam. Înainte mergeam la magazin fără oprire, acum mă opresc o dată."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: agravare sezonieră a BPOC cu reducerea la jumătate "
                     "a toleranței la mers față de o lună în urmă. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-081: COPD, 68F rural, 6T, greeting — new dyspnea at rest (previously only on exertion)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-081", "theme": "copd",
        "messages": [
            _u("Bună ziua. Am 68 de ani și am BPOC. "
               "Ultima lună am dificultăți de respirație chiar și când stau liniștită. "
               "Înainte era mai ales la efort."),
            _asst(_a("Îmi pare rău să aud. "
                     "De câte săptămâni aveți dificultăți de respirație și în repaus, nu doar la efort?",
                     "duration")),
            _u("De cam trei săptămâni s-a schimbat. Acum respir greu și stând jos."),
            _asst(_a("Înțeleg situația. "
                     "Pe lângă dispneea de repaus, mai aveți și alte simptome noi — "
                     "de exemplu spută mai multă, febră sau palpitații?", "associated_symptoms")),
            _u("Da, scot mai multă spută, mai gălbuie. Febră nu am. Inima nu o simt diferit."),
            _asst(_a("Am notat: dispnee de repaus de trei săptămâni, agravare față de dispneea de efort obișnuită, "
                     "cu spută gălbuie crescută. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-082: COPD, 85M rural, 8T, no greeting — chronic cough + new hoarseness + weight loss
    {
        "source": "synthetic_triage", "synthetic_id": "synth-082", "theme": "copd",
        "messages": [
            _u("Am 85 de ani și tusesc de mulți ani. "
               "Dar ultima lună a apărut ceva nou — mi s-a schimbat vocea, e mai ragușită, și am slăbit."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "De câte săptămâni aveți această schimbare de voce și pierdere în greutate?", "duration")),
            _u("De cam o lună. Vocea s-a schimbat treptat. Slăbitul cam de patru-cinci săptămâni."),
            _asst(_a("Înțeleg. "
                     "Pe lângă răgușeală și slăbire, mai aveți și alte simptome noi — "
                     "de exemplu dificultăți la înghițit, tuse cu sânge sau dureri în piept?", "associated_symptoms")),
            _u("Nu am dificultăți la înghițit. Tuse cu sânge nu am. Durere în piept nu simt."),
            _asst(_a("Am notat. "
                     "Câte kilograme ați pierdut aproximativ în ultima lună?", "intensity")),
            _u("Cam cinci kilograme. Nu am încercat să slăbesc, vine singur."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu răgușeală progresivă de o lună și pierdere în greutate de cinci kilograme "
                     "fără cauză aparentă va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── GENERAL ──────────────────────────────────────────────────────────────

    # synth-083: general/cough, 70M rural, 8T, greeting — persistent dry cough 3+ weeks
    {
        "source": "synthetic_triage", "synthetic_id": "synth-083", "theme": "general",
        "messages": [
            _u("Bună ziua. Am 70 de ani și tusesc de mai bine de trei săptămâni. "
               "La început mi s-a părut că e o răceală, dar nu trece. Nu am probleme cu plămânii stabilite."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Tusea este uscată sau productivă — scoateți și mucus când tusiți?", "context")),
            _u("E mai mult uscată. Câteodată scot un pic de mucus, dar mai rar."),
            _asst(_a("Vă mulțumesc. "
                     "Tusea este mai accentuată noaptea, dimineața sau pe tot parcursul zilei?", "intensity")),
            _u("Noaptea e mai rău. Mă trezesc din somn câteodată."),
            _asst(_a("Bine, am notat. "
                     "Pe lângă tuse, mai aveți și alte simptome — "
                     "de exemplu dureri în gât, febră sau dificultăți de respirație?", "associated_symptoms")),
            _u("Durere în gât nu am. Febră nu cred că am. Respir bine."),
            _asst(_a("Am înregistrat toate detaliile despre tuse persistentă predominant uscată de trei săptămâni, "
                     "mai accentuată noaptea, fără semne de infecție activă. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-084: general/fever, 68F rural, 6T, no greeting — recurrent low-grade fever + night sweats
    {
        "source": "synthetic_triage", "synthetic_id": "synth-084", "theme": "general",
        "messages": [
            _u("Am 68 de ani și de câteva săptămâni mi-e cald câteodată seara și transpir. "
               "Nu am febră mare, dar temperaturi de 37-37,5 le-am mai măsurat."),
            _asst(_a("Înțeleg. "
                     "De câte săptămâni aveți aceste episoade de temperatură ușoară și transpirații serale?",
                     "duration")),
            _u("De cam trei-patru săptămâni. Se întâmplă mai ales seara și noaptea."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Pe lângă transpirații nocturne și febră ușoară, mai aveți și alte simptome — "
                     "de exemplu oboseală, pierdere în greutate sau tuse?", "associated_symptoms")),
            _u("Da, sunt mai obosită. Am slăbit cam două kilograme. Tuse nu am."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: transpirații nocturne și temperaturi de 37-37,5 "
                     "de trei-patru săptămâni, cu oboseală și pierdere de două kilograme în greutate. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-085: general/fatigue, 75M urban, 6T, greeting — marked fatigue + pallor + dizziness
    {
        "source": "synthetic_triage", "synthetic_id": "synth-085", "theme": "general",
        "messages": [
            _u("Bună ziua. Am 75 de ani și de câteva săptămâni sunt extrem de obosit, fără chef de nimic. "
               "Și mi s-a mai spus că arăt palid."),
            _asst(_a("Am notat. "
                     "De câte zile sau săptămâni aveți oboseala intensă și paloarea?", "duration")),
            _u("De cam o lună. S-a accentuat treptat, nu a venit brusc."),
            _asst(_a("Înțeleg situația. "
                     "Pe lângă oboseală și paloare, mai aveți și alte simptome — "
                     "de exemplu amețeală, palpitații sau dificultăți de respirație?", "associated_symptoms")),
            _u("Da, amețeală câteodată, mai ales când mă ridic repede. Palpitații nu prea. Respirația e normală."),
            _asst(_a("Am notat: oboseală marcată, paloare și amețeală ortostatică de o lună, cu instalare treptată. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-086: general/dizziness, 72F rural, 8T, greeting, VAGUE (dumps all symptoms at once)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-086", "theme": "general",
        "messages": [
            _u("Bună ziua. Am 72 de ani și am tot felul de probleme: mă amețesc, îmi bâzâie urechile "
               "și mă doare capul. Toate deodată, nu știu de care să mă plâng mai întâi."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Care dintre aceste simptome a apărut primul și îl resimțiți cel mai intens?", "context")),
            _u("Amețeala e cel mai rău. A apărut prima. Celelalte au venit după, cam în același timp."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "De câte zile sau săptămâni aveți această amețeală?", "duration")),
            _u("De cam zece zile. Se întâmplă de câteva ori pe zi."),
            _asst(_a("Am înțeles. "
                     "Amețeala apare la schimbarea poziției capului sau și când stați nemișcată?", "context")),
            _u("Și când întorc capul brusc, și când mă ridic din pat. Câteodată și stând jos."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu amețeală de zece zile, pozițională și spontană, "
                     "însoțită de bâzâit în urechi și dureri de cap va ajunge la medicul de familie. "
                     "Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-087: general/headache, 80M rural, 6T, no greeting — cluster-like periorbital headache
    {
        "source": "synthetic_triage", "synthetic_id": "synth-087", "theme": "general",
        "messages": [
            _u("Am 80 de ani și de câteva zile mă doare capul pe o parte, în jurul ochiului drept. "
               "E un fel de durere intensă care durează o oră-două."),
            _asst(_a("Îmi pare rău să aud. "
                     "De câte zile aveți aceste episoade de durere intensă în jurul ochiului?", "duration")),
            _u("De vreo cinci zile. Apare de câteva ori pe zi, la aceleași ore."),
            _asst(_a("Înțeleg. "
                     "Pe lângă durerea din jurul ochiului, mai aveți și alte simptome în acel episod — "
                     "de exemplu lacrimare, ochi roșu sau nas înfundat pe aceeași parte?", "associated_symptoms")),
            _u("Da, ochiul drept îmi lăcrimează și e puțin roșu. Nasul îmi curge pe dreapta în acel moment."),
            _asst(_a("Am înregistrat toate detaliile despre episoade de durere intensă perioorbitală dreaptă "
                     "de cinci zile, cu lacrimare, ochi roșu și rinoree ipsilaterală. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-088: general/back pain, 73F urban, 6T, greeting — lumbar pain + urinary frequency
    {
        "source": "synthetic_triage", "synthetic_id": "synth-088", "theme": "general",
        "messages": [
            _u("Bună ziua. Am 73 de ani și de două săptămâni mă doare spatele jos, "
               "și durerea coboară pe picior. Și în ultimele zile merg mai des la baie."),
            _asst(_a("Bine, am notat. "
                     "De câte zile aveți această durere lombară cu iradiere pe picior?", "duration")),
            _u("De două săptămâni. A început după ce am stat mult în picioare."),
            _asst(_a("Vă mulțumesc. "
                     "Urinarea frecventă a apărut în același timp cu durerea de spate sau e mai recentă?",
                     "associated_symptoms")),
            _u("E mai recentă, de vreo trei-patru zile. Și mă doare un pic și jos pe abdomen."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: durere lombară cu iradiere pe picior de două săptămâni, "
                     "urinare frecventă și durere abdominală inferioară apărute mai recent. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── DERMATOLOGY ──────────────────────────────────────────────────────────

    # synth-089: derm/rash, 71M rural, 8T, no greeting — itchy rash trunk + arms
    {
        "source": "synthetic_triage", "synthetic_id": "synth-089", "theme": "dermatology",
        "messages": [
            _u("Am 71 de ani și de câteva săptămâni am o erupție pe trunchi și brațe, cu mâncerime. "
               "Nu știu de la ce, că nu am mâncat altceva."),
            _asst(_a("Înțeleg. "
                     "De câte zile sau săptămâni aveți această erupție și mâncerime?", "duration")),
            _u("De cam două-trei săptămâni. A apărut mai întâi pe burtă, acum e și pe brațe."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Erupția a apărut după contactul cu ceva nou — de exemplu un detergent, o haină sau o plantă?",
                     "context")),
            _u("Nu știu. Nu am schimbat nimic, mă gândeam și eu. Poate de la iarba din grădină."),
            _asst(_a("Am notat. "
                     "Mâncărimea vă deranjează somnul sau activitățile zilnice — pe o scară de la 1 la 10?",
                     "intensity")),
            _u("Cam 6-7. Noaptea mă trezesc din cauza mâncărimii. Ziua mă scarp mult."),
            _asst(_a("Am notat: erupție pe trunchi și brațe cu mâncerime intensă de două-trei săptămâni, "
                     "cu extindere progresivă. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-090: derm/itch, 75F rural, 6T, greeting, VAGUE (folk medicine: "e de la ficat")
    {
        "source": "synthetic_triage", "synthetic_id": "synth-090", "theme": "dermatology",
        "messages": [
            _u("Bună ziua. Am 75 de ani și mă mâncărime tot corpul de câteva săptămâni, fără să văd vreo erupție. "
               "Sigur e de la ficat, mi-a spus o vecină."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "De câte săptămâni aveți această mâncerime generalizată fără erupție vizibilă?", "duration")),
            _u("De vreo trei-patru săptămâni. E de la ficat, sigur. "
               "La noi în sat se știe că mâncărimile sunt de la ficat. Doctorii nu cred, dar e adevărat."),
            _asst(_a("Înțeleg situația. "
                     "Pe lângă mâncerime, mai aveți și alte simptome — "
                     "de exemplu oboseală, culoare galbenă la piele sau ochi, sau modificări ale urinei?",
                     "associated_symptoms")),
            _u("Nu am galben. Sunt mai obosită. Urina parcă e mai închisă la culoare."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu mâncerime generalizată fără erupție de trei-patru săptămâni, "
                     "oboseală și urină mai închisă va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-091: derm/wound, 78M rural, 6T, greeting — slow-healing shin wound on DM patient
    {
        "source": "synthetic_triage", "synthetic_id": "synth-091", "theme": "dermatology",
        "messages": [
            _u("Bună ziua. Am 78 de ani și am o rană la gamba stângă care nu se vindecă de o lună. "
               "Am diabet și inimă la urmărit."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "De câte săptămâni sau luni nu se vindecă această rană la gambă?", "duration")),
            _u("De cam o lună. A început de la un zgâriet și nu s-a mai închis."),
            _asst(_a("Bine, am notat. "
                     "Rana este dureroasă, are roșeață în jur sau secreție, "
                     "sau este relativ nedureroasă și uscată?", "context")),
            _u("E un pic roșie în jur. Nu prea doare. Nu am văzut secreție, mai mult roșeață."),
            _asst(_a("Am înregistrat toate detaliile despre rană la gamba stângă de o lună, "
                     "cu roșeață periferică și vindecare absentă, pe fond de diabet. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── GASTROINTESTINAL ─────────────────────────────────────────────────────

    # synth-092: GI/nausea, 69F urban, 8T, no greeting — persistent nausea + anorexia + weight loss
    {
        "source": "synthetic_triage", "synthetic_id": "synth-092", "theme": "gastrointestinal",
        "messages": [
            _u("Am 69 de ani și de câteva săptămâni mi-e greață aproape în fiecare zi. "
               "Nu mai mănânc bine și am slăbit. Nu am dureri de stomac."),
            _asst(_a("Vă mulțumesc. "
                     "De câte săptămâni aveți greața zilnică și pierderea apetitului?", "duration")),
            _u("De cam trei săptămâni. La început era câteodată, acum e aproape în fiecare zi."),
            _asst(_a("Am înțeles. "
                     "Greața apare mai ales dimineața, după masă sau pe tot parcursul zilei?", "context")),
            _u("Mai ales dimineața. Și după masă câteodată. Seara e mai bine."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Pe lângă greață și apetit scăzut, mai aveți și alte simptome — "
                     "de exemplu vărsături, dureri abdominale sau modificări ale tranzitului?",
                     "associated_symptoms")),
            _u("Vărsături nu am. Stomacul nu mă doare. Câteodată am balonare. Tranzitul e la fel."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: greață zilnică mai ales matinală, apetit scăzut, "
                     "slăbire și balonare ocazională de trei săptămâni. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-093: GI/constipation, 74M rural, 6T, greeting, VAGUE (asks AI: "ce să mănânc?")
    {
        "source": "synthetic_triage", "synthetic_id": "synth-093", "theme": "gastrointestinal",
        "messages": [
            _u("Bună ziua. Am 74 de ani și de zece zile nu am mai mers la baie deloc. "
               "Nimic. Mă doare un pic burta."),
            _asst(_a("Am notat. De câte zile nu ați mai avut scaun?", "duration")),
            _u("De exact zece zile. Și ce să mănânc ca să treacă? Ce îmi recomandați?"),
            _asst(_a(f"Înțeleg. {_BOUNDARY} "
                     "Pe lângă lipsa scaunului, mai aveți și alte simptome — "
                     "de exemplu greață, vărsături sau durere abdominală intensă?", "associated_symptoms")),
            _u("Greață un pic. Durere nu prea, mai mult un disconfort. Vărsături nu."),
            _asst(_a("Am notat: absența scaunului de zece zile, cu disconfort abdominal și ușoară greață. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-094: GI/pain, 70F urban, 6T, greeting — postprandial epigastric pain + bloating
    {
        "source": "synthetic_triage", "synthetic_id": "synth-094", "theme": "gastrointestinal",
        "messages": [
            _u("Bună ziua. Am 70 de ani și de câteva luni mă doare burta în zona de sus, "
               "mai ales după ce mănânc. Și mă mai balonez."),
            _asst(_a("Înțeleg situația. "
                     "De câte luni aveți această durere epigastrică după masă și balonare?", "duration")),
            _u("De cam două luni. Se întâmplă după aproape fiecare masă mai consistentă."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Durerea apare imediat după masă sau la câteva zeci de minute distanță?", "context")),
            _u("Cam la 30-60 de minute după masă. Durează câteva ore și se mai duce."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu durere epigastrică postprandială și balonare de două luni, "
                     "apărând la 30-60 de minute după masă, va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── MENTAL HEALTH ────────────────────────────────────────────────────────

    # synth-095: MH/mood, 73F rural, 8T, no greeting — low mood after husband's hospitalization
    {
        "source": "synthetic_triage", "synthetic_id": "synth-095", "theme": "mental_health",
        "messages": [
            _u("Am 73 de ani și de când soțul meu a ajuns la spital luna trecută, nu mai pot funcționa normal. "
               "Plâng des, nu mă pot concentra și nu dorm bine."),
            _asst(_a("Îmi pare rău să aud. "
                     "De câte săptămâni aveți aceste dificultăți de somn, concentrare și tristețe?", "duration")),
            _u("De cam o lună, de când s-a îmbolnăvit el. Nu am mai dormit bine deloc."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Cât de mult vă afectează această stare activitățile zilnice — "
                     "gătiți, vă îngrijiți, ieșiți din casă?", "intensity")),
            _u("Greu fac orice. Câteodată uit să mănânc. Ies din casă numai când trebuie."),
            _asst(_a("Înțeleg. "
                     "Pe lângă tristețe și somn perturbat, mai aveți și alte simptome — "
                     "de exemplu palpitații, dificultăți de respirație sau dureri fizice noi?", "associated_symptoms")),
            _u("Da, inima îmi bate uneori mai repede. Dureri noi nu prea. Respirația e normală."),
            _asst(_a("Am înregistrat toate detaliile despre stare de tristețe, somn perturbat "
                     "și funcționare zilnică redusă de o lună, apărute în contextul bolii soțului. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-096: MH/sleep, 68M urban, 6T, greeting, VAGUE (minimizes: "nu e nimic, maybe stress")
    {
        "source": "synthetic_triage", "synthetic_id": "synth-096", "theme": "mental_health",
        "messages": [
            _u("Bună ziua. Am 68 de ani și nu dorm bine de câteva săptămâni. "
               "Mă trezesc la trei-patru noaptea și nu mai pot adormi. Dar nu e nimic, poate e de la stres."),
            _asst(_a("Bine, am notat. "
                     "De câte săptămâni aveți aceste treziri nocturne și dificultăți de a readormi?", "duration")),
            _u("Nu e nimic, probabil stres. Cam de o lună. Nu e grav, că alții au probleme mai mari. "
               "Nu vreau să deranjez."),
            _asst(_a("Am înțeles. "
                     "Cât de odihnit vă simțiți dimineața — puteți funcționa normal ziua sau simțiți "
                     "oboseală semnificativă?", "intensity")),
            _u("Foarte obosit dimineața. Ziua nu pot să mă concentrez bine. Câteodată adorm involuntar."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: treziri nocturne la ora trei-patru de o lună, "
                     "cu oboseală diurnă marcată și dificultăți de concentrare. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-097: MH/anxiety, 77F rural, 6T, greeting — health anxiety after cardiac diagnosis
    {
        "source": "synthetic_triage", "synthetic_id": "synth-097", "theme": "mental_health",
        "messages": [
            _u("Bună ziua. Am 77 de ani și de când doctorul mi-a spus că am ceva la inimă, "
               "mi-e mereu frică că mi se va întâmpla ceva rău. Inima îmi bate tare de frică."),
            _asst(_a("Înțeleg. "
                     "De câte zile sau săptămâni aveți această stare de teamă intensă și palpitații asociate?",
                     "duration")),
            _u("De două săptămâni, de la vizita la cardiolog. Nu mai pot sta liniștită."),
            _asst(_a("Vă mulțumesc. "
                     "Pe lângă frică și palpitații, mai aveți și alte simptome — "
                     "de exemplu dificultăți de respirație, transpirații sau amețeală?", "associated_symptoms")),
            _u("Câteodată respir greu de emoție. Transpirații câteodată. Amețeală puțin."),
            _asst(_a("Am notat: stare de anxietate intensă cu palpitații, dificultăți respiratorii și transpirații "
                     "de două săptămâni, apărute după vestea diagnosticului cardiac. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── URINARY ──────────────────────────────────────────────────────────────

    # synth-098: URI/frequency, 71M rural, 8T, no greeting — nocturia + weak stream + incomplete emptying
    {
        "source": "synthetic_triage", "synthetic_id": "synth-098", "theme": "urinary",
        "messages": [
            _u("Am 71 de ani și de câteva luni merg mult prea des la baie noaptea — de câte patru-cinci ori. "
               "Și când merg, jetul e slab și nu simt că mă golesc complet."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "De câte luni aveți aceste treziri nocturne frecvente pentru urinat?", "duration")),
            _u("De cam trei-patru luni. S-a înrăutățit treptat."),
            _asst(_a("Bine, am notat. "
                     "Cât de mult vă afectează somnul aceste treziri — dimineața vă simțiți odihnit sau obosit?",
                     "intensity")),
            _u("Foarte obosit dimineața. Nu mai dorm bine de luni de zile."),
            _asst(_a("Înțeleg situația. "
                     "Pe lângă nocturia și jetul slab, mai aveți și alte simptome — "
                     "de exemplu arsură la urinare, urgență sau sânge în urină?", "associated_symptoms")),
            _u("Urinare urgentă câteodată, da. Arsură nu am. Sânge nu am observat."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu nocturia de patru-cinci ori pe noapte, jet slab, golire incompletă "
                     "și urgentă micțională de trei-patru luni va ajunge la medicul de familie. "
                     "Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-099: URI/incontinence, 78F urban, 6T, greeting, VAGUE (asks AI: "e normal la vârsta mea?")
    {
        "source": "synthetic_triage", "synthetic_id": "synth-099", "theme": "urinary",
        "messages": [
            _u("Bună ziua. Am 78 de ani și din când în când pierd puțin urină fără să vreau, "
               "mai ales când tușesc sau ridic ceva."),
            _asst(_a("Am notat. "
                     "De câte luni observați această pierdere involuntară de urină la tuse sau efort?",
                     "duration")),
            _u("De cam șase luni. Dar e normal la vârsta mea, nu? De câte ori ați văzut asta la femei în vârstă?"),
            _asst(_a(f"Vă mulțumesc. {_BOUNDARY} "
                     "Cât de mult vă afectează această situație activitățile zilnice?", "intensity")),
            _u("Mă jenează. Trebuie să port protecție și asta mă incomodează. Nu mai ies la fel."),
            _asst(_a("Am înregistrat toate detaliile despre pierdere involuntară de urină la efort de șase luni, "
                     "cu impact semnificativ asupra calității vieții. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-100: URI/burning, 65F rural, 6T, greeting — burning + frequency + suprapubic pressure
    {
        "source": "synthetic_triage", "synthetic_id": "synth-100", "theme": "urinary",
        "messages": [
            _u("Bună ziua. Am 65 de ani și de câteva zile mă arde la urinat și merg des la baie. "
               "Câteodată simt și o presiune în jos pe burtă."),
            _asst(_a("Înțeleg. "
                     "De câte zile aveți arsura la urinare și frecvența crescută?", "duration")),
            _u("De vreo trei-patru zile. A venit destul de brusc."),
            _asst(_a("Îmi pare rău să aud. "
                     "Pe lângă arsura la urinare și frecvența crescută, mai aveți și alte simptome — "
                     "de exemplu febră, frisoane sau dureri în zona lombară?", "associated_symptoms")),
            _u("Febră nu cred că am. Dureri în spate nu am. Doar presiunea aia jos pe burtă."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: arsură la urinare, frecvență crescută "
                     "și presiune suprapubiană de trei-patru zile, cu debut brusc. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── MEDICATION MANAGEMENT ────────────────────────────────────────────────

    # synth-101: MEDMGMT, 76M rural, 8T, no greeting — confusion about BP pill schedule
    {
        "source": "synthetic_triage", "synthetic_id": "synth-101",
        "theme": "medication_management",
        "messages": [
            _u("Am 76 de ani și am tensiunea mare urmărită de mulți ani. "
               "Dar mă încurc cu pastilele — iau una dimineața, dar uneori uit dacă am luat-o deja sau nu. "
               "Și nu știu ce să fac."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "De câte zile sau săptămâni aveți această dificultate de a ține evidența medicamentului "
                     "de dimineață?", "duration")),
            _u("De cam două-trei luni. Uneori iau de două ori, uneori nu iau deloc. Nu știu."),
            _asst(_a("Am înțeles. "
                     "Cât de des aproximativ se întâmplă să nu fiți sigur dacă ați luat pastila — "
                     "zilnic sau mai rar?", "context")),
            _u("Cam de trei-patru ori pe săptămână. Câteodată și zilnic."),
            _asst(_a("Vă mulțumesc pentru detalii. "
                     "Această dificultate de a ține evidența apare și la alte medicamente sau doar la acesta?",
                     "associated_symptoms")),
            _u("Și la celelalte, da. Dar la asta mă îngrijorează cel mai mult că e pentru tensiune."),
            _asst(_a("Am notat: dificultate de a ține evidența administrării zilnice a medicamentelor "
                     "de câteva luni, cu episoade de administrare dublă sau omisă. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-102: MEDMGMT, 80F urban, 6T, greeting, VAGUE (multiple pill complaints at once)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-102",
        "theme": "medication_management",
        "messages": [
            _u("Bună ziua. Am 80 de ani. Am două medicamente noi de la doctor de acum o lună "
               "și nu știu care e care, nu știu dacă le iau corect, nu știu câte iau, "
               "și mi-e frică să greșesc."),
            _asst(_a("Vă mulțumesc. "
                     "Cel mai frecvent, când apare confuzia — dimineața când vă pregătiți "
                     "sau pe tot parcursul zilei?", "context")),
            _u("Tot timpul. Nu știu dacă le iau la ore greșite, nu știu dacă le-am luat deja, "
               "nu știu dacă trebuie cu mâncare sau fără. Totul e confuz."),
            _asst(_a("Bine, am notat. "
                     "De câte săptămâni aveți această confuzie cu cele două medicamente noi?", "duration")),
            _u("De o lună, de când le-am primit. Nu am reușit să înțeleg."),
            _asst(_a("Mulțumesc pentru informații. "
                     "Raportul cu dificultate semnificativă de gestionare a două medicamente noi de o lună "
                     "va ajunge la medicul de familie. Așteptați consultația.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-103: MEDMGMT, 72M rural, 6T, greeting — missed pills repeatedly, anxious about effects
    {
        "source": "synthetic_triage", "synthetic_id": "synth-103",
        "theme": "medication_management",
        "messages": [
            _u("Bună ziua. Am 72 de ani și iau medicamente pentru tensiune de ani de zile. "
               "Dar ultima săptămână le-am uitat de câteva ori. Mă îngrijorează că o să mi se facă rău."),
            _asst(_a("Înțeleg. "
                     "De câte zile aveți dificultăți în a vă aminti dacă ați luat sau nu medicamentele?",
                     "duration")),
            _u("De cam o săptămână. S-a întâmplat de vreo trei ori că nu am mai știut. "
               "Ieri nici nu știu dacă am luat."),
            _asst(_a("Înțeleg situația. "
                     "Uitarea apare mai des dimineața sau și la alte ore ale zilei?", "context")),
            _u("Mai ales dimineața. Că seara mai rețin, că mă pregătesc de culcat. Dimineața mă grăbesc."),
            _asst(_a("Am înregistrat toate detaliile despre dificultăți de memorie la administrarea "
                     "medicamentelor de o săptămână, cu episoade multiple de incertitudine. "
                     "Medicul de familie va primi raportul înainte de consultație. Vă mulțumesc!",
                     "close", ready_to_finalize=True)),
        ],
    },

    # ── VISION / HEARING ─────────────────────────────────────────────────────

    # synth-104: VH/vision, 75F rural, 8T, no greeting — progressive near-vision blurring
    {
        "source": "synthetic_triage", "synthetic_id": "synth-104", "theme": "vision_hearing",
        "messages": [
            _u("Am 75 de ani și de câteva luni văd tot mai greu aproape. "
               "Nu mai pot citi o carte sau ziarul. La televizor mai merge, dar și acolo e mai neclar."),
            _asst(_a("Am notat. "
                     "De câte luni observați această deteriorare progresivă a vederii de aproape?", "duration")),
            _u("De cam patru-cinci luni. A venit treptat, nu brusc."),
            _asst(_a("Vă mulțumesc că mi-ați descris. "
                     "Vederea la distanță s-a schimbat și ea sau doar cea de aproape?", "intensity")),
            _u("Departe văd mai bine. Aproape e problema. Am purtat ochelari de citit, dar nu mai ajung."),
            _asst(_a("Înțeleg, vă mulțumesc. "
                     "Pe lângă vederea neclară de aproape, mai aveți și alte simptome oculare — "
                     "de exemplu durere la ochi, halos în jurul luminilor sau vedere dublă?", "associated_symptoms")),
            _u("Câteodată halos seara în jurul luminilor. Durere nu am. Vedere dublă nu."),
            _asst(_a("Am înregistrat simptomele dumneavoastră: deteriorare progresivă a vederii de aproape "
                     "de patru-cinci luni, cu halos nocturn în jurul luminilor. "
                     "Medicul de familie va consulta raportul. Vă mulțumesc.",
                     "close", ready_to_finalize=True)),
        ],
    },

    # synth-105: VH/hearing, 78M rural, 6T, no greeting, VAGUE (multiple: tinnitus + hearing + headache)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-105", "theme": "vision_hearing",
        "messages": [
            _u("Am 78 de ani. Am mai multe probleme cu urechile: îmi bâzâie, aud mai greu decât înainte "
               "și câteodată mă doare capul. Toate deodată."),
            _asst(_a("Îmi pare rău să aud. "
                     "Care dintre aceste simptome vă deranjează cel mai mult și de când a apărut?", "context")),
            _u("Bâzâitul e cel mai deranjant. A apărut cam acum o lună. "
               "Auzul mai rău e de mai mult, dar s-a înrăutățit și el."),
            _asst(_a("Înțeleg. "
                     "Bâzâitul din urechi este continuu sau apare și dispare în episoade?", "intensity")),
            _u("E mai mult continuu, zi și noapte. Câteodată mai tare, câteodată mai slab. Nu tace deloc."),
            _asst(_a("Am notat: acufene continue de o lună cu variații de intensitate, "
                     "agravarea pierderii de auz preexistente și cefalee asociată. "
                     "Medicul de familie va fi informat. Mulțumesc că ați folosit acest serviciu.",
                     "close", ready_to_finalize=True)),
        ],
    },
]


# ---------------------------------------------------------------------------
# Pydantic schema
# ---------------------------------------------------------------------------

class _AsstPayload(BaseModel):
    response: str
    emergency: bool
    confidence: float
    priority: str
    ready_to_finalize: bool
    category: str

    @model_validator(mode="after")
    def check_no_drugs(self):
        lower = self.response.lower()
        hits = [d for d in DRUG_BLOCKLIST if d in lower]
        if hits:
            raise ValueError(f"drug mention: {hits}")
        return self

    @model_validator(mode="after")
    def check_no_dosage(self):
        if _DOSAGE_RE.search(self.response):
            raise ValueError("dosage pattern found")
        return self


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

def _validate_batch(dialogues, label="batch", opener_limit_pct=25):
    errors = []
    opener_counts: dict[str, int] = {}
    total_non_close = 0
    max_sentence_words = 0
    total_turns = 0

    for d in dialogues:
        sid = d.get("synthetic_id", "?")
        msgs = d.get("messages", [])
        total_turns += len(msgs)

        if not msgs or len(msgs) % 2 != 0:
            errors.append(f"[{sid}] message count {len(msgs)} not positive even")
            continue

        for i, msg in enumerate(msgs):
            exp = "user" if i % 2 == 0 else "assistant"
            if msg["role"] != exp:
                errors.append(f"[{sid}] turn {i}: expected '{exp}', got '{msg['role']}'")

        asst_turns = [(i, m) for i, m in enumerate(msgs) if m["role"] == "assistant"]
        last_idx = asst_turns[-1][0] if asst_turns else -1
        finalize_count = 0

        for turn_i, msg in asst_turns:
            is_last = (turn_i == last_idx)
            try:
                p = _AsstPayload(**json.loads(msg["content"]))
            except (json.JSONDecodeError, ValidationError, TypeError) as e:
                errors.append(f"[{sid}] turn {turn_i}: {e}")
                continue

            resp = p.response
            if p.ready_to_finalize:
                finalize_count += 1

            # Rule B
            if "Bună ziua" in resp or "Buna ziua" in resp:
                errors.append(f"[{sid}] turn {turn_i}: 'Bună ziua' in assistant response")

            # Rule A
            for sent in _split_sentences(resp):
                wc = len(sent.split())
                if wc > max_sentence_words:
                    max_sentence_words = wc
                if wc > 30:
                    errors.append(f"[{sid}] turn {turn_i}: sentence {wc} words>30: «{sent[:60]}»")

            # Rule C
            qmarks = resp.count("?")
            if is_last:
                if qmarks != 0:
                    errors.append(f"[{sid}] close turn {turn_i}: has {qmarks} ?")
            else:
                if qmarks > 1:
                    errors.append(f"[{sid}] turn {turn_i}: {qmarks} ? (max 1)")
                # Opener tracking
                total_non_close += 1
                op = _detect_opener(resp)
                opener_counts[op] = opener_counts.get(op, 0) + 1

        if finalize_count != 1:
            errors.append(f"[{sid}] ready_to_finalize=true: {finalize_count} times (expected 1)")
        if asst_turns:
            try:
                last_p = json.loads(asst_turns[-1][1]["content"])
                if not last_p.get("ready_to_finalize"):
                    errors.append(f"[{sid}] last assistant turn missing ready_to_finalize=true")
            except Exception:
                pass

    # Opener histogram check
    if total_non_close > 0:
        for op, cnt in opener_counts.items():
            pct = cnt / total_non_close * 100
            if pct > opener_limit_pct:
                errors.append(
                    f"Opener '{op}' used {cnt}/{total_non_close} times = {pct:.1f}% > {opener_limit_pct}%"
                )

    # Check 9: medication-management dialogues must not contain drug names or dosages
    for d in dialogues:
        if d.get("theme") != "medication_management":
            continue
        sid = d.get("synthetic_id", "?")
        for i, msg in enumerate(d.get("messages", [])):
            if msg["role"] != "assistant":
                continue
            try:
                resp = json.loads(msg["content"]).get("response", "")
            except Exception:
                continue
            lower = resp.lower()
            drug_hits = [dr for dr in DRUG_BLOCKLIST if dr in lower]
            if drug_hits:
                errors.append(
                    f"[{sid}] turn {i} (check 9 — med-mgmt drug): {drug_hits} in response"
                )
            if _DOSAGE_RE.search(resp):
                errors.append(
                    f"[{sid}] turn {i} (check 9 — med-mgmt dosage): dosage pattern in response"
                )

    stats = {
        "total_turns": total_turns,
        "max_sentence_words": max_sentence_words,
        "opener_counts": opener_counts,
        "total_non_close": total_non_close,
    }
    return errors, stats


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    rng = random.Random(7)
    dialogues = BATCH_50C_DIALOGUES

    errors, stats = _validate_batch(dialogues, opener_limit_pct=25)
    if errors:
        print(f"VALIDATION FAILED ({len(errors)} errors):")
        for e in errors:
            print(f"  {e}")
        sys.exit(1)

    print(f"Validation: all {len(dialogues)} dialogues passed.")

    OUTPUT_PATH_BATCH_C.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_PATH_BATCH_C.open("w", encoding="utf-8") as f:
        for d in dialogues:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")

    themes: dict[str, int] = {}
    greet_count = 0
    boundary_count = 0
    medmgmt_count = 0
    for d in dialogues:
        t = d.get("theme", "?")
        themes[t] = themes.get(t, 0) + 1
        if t == "medication_management":
            medmgmt_count += 1
        first_patient = next((m["content"] for m in d["messages"] if m["role"] == "user"), "")
        if first_patient.startswith("Bună ziua"):
            greet_count += 1
        for msg in d["messages"]:
            if msg["role"] == "assistant":
                try:
                    resp = json.loads(msg["content"]).get("response", "")
                    if "Medicul de familie va răspunde la această întrebare" in resp:
                        boundary_count += 1
                        break
                except Exception:
                    pass

    greet_pct = greet_count / max(len(dialogues), 1) * 100

    print(f"Wrote {len(dialogues)} dialogues → {OUTPUT_PATH_BATCH_C}")
    print(f"Total turns: {stats['total_turns']} | Max sentence words: {stats['max_sentence_words']}")
    print(f"Themes: {themes}")
    print(f"Patient greeting rate: {greet_count}/{len(dialogues)} = {greet_pct:.0f}%")
    print(f"Boundary dialogues (patient asked AI question): {boundary_count}")
    print(f"Medication management dialogues: {medmgmt_count}")
    print(f"Opener histogram ({stats['total_non_close']} non-close turns):")
    for op, cnt in sorted(stats["opener_counts"].items(), key=lambda x: -x[1]):
        pct = cnt / max(stats["total_non_close"], 1) * 100
        print(f"  {op!r:42s} {cnt:3d}  ({pct:.1f}%)")

    sample = rng.sample(dialogues, 3)
    print("\n" + "=" * 66)
    print("SPOT CHECK — 3 random dialogues")
    print("=" * 66)
    for d in sample:
        print(f"\n{'─'*60}")
        print(f"[{d['synthetic_id']}] theme={d['theme']}")
        for msg in d["messages"]:
            if msg["role"] == "user":
                print(f"  PATIENT  : {msg['content']}")
            else:
                try:
                    p = json.loads(msg["content"])
                    print(f"  ASSISTANT [{p['category']} | finalize={p['ready_to_finalize']} | "
                          f"priority={p['priority']} | ?s={p['response'].count('?')}]")
                    print(f"    {p['response']}")
                except Exception:
                    print(f"  ASSISTANT (err): {msg['content'][:80]}")
    print(f"\n{'='*66}")


# ---------------------------------------------------------------------------
# 9d — 16 emergency dialogues (synth-106..synth-121)
# ---------------------------------------------------------------------------

_T_A = "Sunați 112 imediat."
_T_B = ("Sunați 112 imediat. "
        "Sau sunați la 0800 801 200, Telefonul Antisuicid. "
        "Nu sunteți singur, există ajutor.")

EXPECTED_SUBCATEGORY_COUNTS = {
    "chest_pain_dyspnea": 3,
    "stroke": 3,
    "bleeding": 2,
    "loss_of_consciousness": 2,
    "anaphylaxis": 2,
    "suicidal_ideation": 3,
    "thunderclap_headache": 1,
}


def _emrg(response: str) -> str:
    return json.dumps({
        "response": response,
        "emergency": True,
        "confidence": 0.9,
        "priority": "emergency",
        "ready_to_finalize": False,
        "category": "emergency",
    }, ensure_ascii=False)


EMERGENCY_DIALOGUES: list[dict] = [

    # ── CHEST PAIN + DYSPNEA (3) ─────────────────────────────────────────────

    # synth-106: short panicked
    {
        "source": "synthetic_triage", "synthetic_id": "synth-106",
        "theme": "emergency", "subcategory": "chest_pain_dyspnea",
        "messages": [
            _u("Mă doare tare pieptul și nu mai pot respira. Am 72 de ani. Ajutor."),
            _asst(_emrg(_T_A)),
        ],
    },

    # synth-107: longer rambling
    {
        "source": "synthetic_triage", "synthetic_id": "synth-107",
        "theme": "emergency", "subcategory": "chest_pain_dyspnea",
        "messages": [
            _u("Bună ziua, am 68 de ani și tocmai am terminat de cărat niște lemne în curte "
               "când m-a apucat o durere puternică în piept, spre stânga, și acum respir greu. "
               "Mă simt slăbit și am transpirații. Soția e lângă mine."),
            _asst(_emrg(_T_A)),
        ],
    },

    # synth-108: vernacular without standard keywords
    {
        "source": "synthetic_triage", "synthetic_id": "synth-108",
        "theme": "emergency", "subcategory": "chest_pain_dyspnea",
        "messages": [
            _u("Mă strânge tare în piept și mi-e rău, rău de tot. Respir greu. "
               "Îmi vine să cad. Nu mai pot."),
            _asst(_emrg(_T_A)),
        ],
    },

    # ── STROKE SIGNS (3) ─────────────────────────────────────────────────────

    # synth-109: longer rambling (caller describing spouse)
    {
        "source": "synthetic_triage", "synthetic_id": "synth-109",
        "theme": "emergency", "subcategory": "stroke",
        "messages": [
            _u("Sunt soția și sun pentru bărbatul meu. Are 77 de ani și nu mai poate vorbi bine, "
               "îi atârnă o parte a feței și nu își poate ridica brațul stâng. "
               "S-a întâmplat acum zece minute, brusc, fără niciun motiv."),
            _asst(_emrg(_T_A)),
        ],
    },

    # synth-110: vernacular
    {
        "source": "synthetic_triage", "synthetic_id": "synth-110",
        "theme": "emergency", "subcategory": "stroke",
        "messages": [
            _u("Doamne, nu știu ce s-a întâmplat cu mine. Vorbesc ciudat, nu mai ies cuvintele bine. "
               "Și brațul drept nu-l mai simt. Mi-a venit brusc."),
            _asst(_emrg(_T_A)),
        ],
    },

    # synth-111: longer rambling
    {
        "source": "synthetic_triage", "synthetic_id": "synth-111",
        "theme": "emergency", "subcategory": "stroke",
        "messages": [
            _u("Am 73 de ani și acum câteva minute am simțit că nu mai văd dintr-un ochi, "
               "mi s-a înmuiat piciorul stâng și nu mai pot vorbi cum trebuie. "
               "Sunt singur în casă și îmi e frică."),
            _asst(_emrg(_T_A)),
        ],
    },

    # ── SEVERE UNCONTROLLED BLEEDING (2) ─────────────────────────────────────

    # synth-112: short panicked
    {
        "source": "synthetic_triage", "synthetic_id": "synth-112",
        "theme": "emergency", "subcategory": "bleeding",
        "messages": [
            _u("Sângerez mult la picior, am tăiat-o adânc cu coasa. Nu se oprește. "
               "Am 70 de ani. Mult sânge."),
            _asst(_emrg(_T_A)),
        ],
    },

    # synth-113: longer rambling
    {
        "source": "synthetic_triage", "synthetic_id": "synth-113",
        "theme": "emergency", "subcategory": "bleeding",
        "messages": [
            _u("Am 75 de ani și am căzut și m-am lovit la cap de marginea mesei. "
               "Sângerează tare și nu se mai oprește de zece minute. "
               "Prosopul e plin de sânge. Nu e nimeni cu mine."),
            _asst(_emrg(_T_A)),
        ],
    },

    # ── LOSS OF CONSCIOUSNESS (2) ─────────────────────────────────────────────

    # synth-114: short panicked
    {
        "source": "synthetic_triage", "synthetic_id": "synth-114",
        "theme": "emergency", "subcategory": "loss_of_consciousness",
        "messages": [
            _u("Am leșinat și m-am trezit pe jos. Acum îmi e rău și nu înțeleg unde sunt. Am 69 de ani."),
            _asst(_emrg(_T_A)),
        ],
    },

    # synth-115: vernacular
    {
        "source": "synthetic_triage", "synthetic_id": "synth-115",
        "theme": "emergency", "subcategory": "loss_of_consciousness",
        "messages": [
            _u("Mi-a luat vederea și am căzut, nu știu cât timp am stat jos. "
               "Acum m-am trezit dar nu mă simt bine, îmi merge capul. Nu știu ce mi s-a întâmplat."),
            _asst(_emrg(_T_A)),
        ],
    },

    # ── ANAPHYLAXIS (2) ──────────────────────────────────────────────────────

    # synth-116: short panicked
    {
        "source": "synthetic_triage", "synthetic_id": "synth-116",
        "theme": "emergency", "subcategory": "anaphylaxis",
        "messages": [
            _u("Nu pot înghiți, mi se strânge gâtul. Am mâncat ceva și acum nu mai pot respira bine. "
               "Fața mi s-a umflat."),
            _asst(_emrg(_T_A)),
        ],
    },

    # synth-117: longer rambling
    {
        "source": "synthetic_triage", "synthetic_id": "synth-117",
        "theme": "emergency", "subcategory": "anaphylaxis",
        "messages": [
            _u("Am 67 de ani și am luat ceva nou de la doctori acum o jumătate de oră. "
               "De atunci buza mi s-a umflat foarte mult, simt că gâtul mi se strânge "
               "și mi-e greu să respir. Niciodată nu mi s-a întâmplat asta."),
            _asst(_emrg(_T_A)),
        ],
    },

    # ── SUICIDAL IDEATION WITH INTENT (3) — Template B ───────────────────────

    # synth-118: vernacular
    {
        "source": "synthetic_triage", "synthetic_id": "synth-118",
        "theme": "emergency", "subcategory": "suicidal_ideation",
        "messages": [
            _u("Nu mai pot trăi așa. Nu mai vreau nimic din viață. "
               "Am luat o decizie și nu mă mai poate opri nimeni."),
            _asst(_emrg(_T_B)),
        ],
    },

    # synth-119: vernacular
    {
        "source": "synthetic_triage", "synthetic_id": "synth-119",
        "theme": "emergency", "subcategory": "suicidal_ideation",
        "messages": [
            _u("Vreau să-mi pun capăt zilelor. Nu mai este nicio soluție pentru mine. "
               "Nu am mai spus asta nimănui."),
            _asst(_emrg(_T_B)),
        ],
    },

    # synth-120: short + direct
    {
        "source": "synthetic_triage", "synthetic_id": "synth-120",
        "theme": "emergency", "subcategory": "suicidal_ideation",
        "messages": [
            _u("Nu mai vreau să trăiesc. Am 71 de ani și am decis. Nu mai pot continua."),
            _asst(_emrg(_T_B)),
        ],
    },

    # ── THUNDERCLAP HEADACHE (1) ─────────────────────────────────────────────

    # synth-121: longer rambling
    {
        "source": "synthetic_triage", "synthetic_id": "synth-121",
        "theme": "emergency", "subcategory": "thunderclap_headache",
        "messages": [
            _u("Am 74 de ani și acum câteva minute m-a lovit o durere de cap cum nu am mai simțit "
               "în viața mea, ca o lovitură de ciocan. Cel mai rău cap de durere din toată viața mea. "
               "Sunt culcată și nu pot ridica capul de pe pernă."),
            _asst(_emrg(_T_A)),
        ],
    },
]


# ---------------------------------------------------------------------------
# Emergency validation
# ---------------------------------------------------------------------------

def _validate_emergency(dialogues: list[dict]) -> list[str]:
    errors: list[str] = []
    subcategory_counts: dict[str, int] = {}

    suicidal_themes = {"suicidal_ideation"}

    for d in dialogues:
        sid = d.get("synthetic_id", "?")
        theme = d.get("theme", "?")
        subcat = d.get("subcategory", "?")
        msgs = d.get("messages", [])

        subcategory_counts[subcat] = subcategory_counts.get(subcat, 0) + 1

        if theme != "emergency":
            errors.append(f"[{sid}] theme is '{theme}', expected 'emergency'")

        if len(msgs) != 2:
            errors.append(f"[{sid}] has {len(msgs)} turns, expected 2")
            continue

        if msgs[0]["role"] != "user":
            errors.append(f"[{sid}] turn 0 role is '{msgs[0]['role']}', expected 'user'")
        if msgs[1]["role"] != "assistant":
            errors.append(f"[{sid}] turn 1 role is '{msgs[1]['role']}', expected 'assistant'")

        try:
            payload = json.loads(msgs[1]["content"])
        except (json.JSONDecodeError, TypeError) as e:
            errors.append(f"[{sid}] assistant content not valid JSON: {e}")
            continue

        required = {"response", "emergency", "confidence", "priority", "ready_to_finalize", "category"}
        missing = required - set(payload.keys())
        if missing:
            errors.append(f"[{sid}] missing fields: {missing}")

        if payload.get("emergency") is not True:
            errors.append(f"[{sid}] emergency is not true")
        if payload.get("confidence") != 0.9:
            errors.append(f"[{sid}] confidence is {payload.get('confidence')}, expected 0.9")
        if payload.get("priority") != "emergency":
            errors.append(f"[{sid}] priority is '{payload.get('priority')}', expected 'emergency'")
        if payload.get("ready_to_finalize") is not False:
            errors.append(f"[{sid}] ready_to_finalize must be false")
        if payload.get("category") != "emergency":
            errors.append(f"[{sid}] category is '{payload.get('category')}', expected 'emergency'")

        # Exact response match
        resp = payload.get("response", "")
        if subcat in suicidal_themes:
            if resp != _T_B:
                errors.append(f"[{sid}] suicidal response does not match Template B exactly")
        else:
            if resp != _T_A:
                errors.append(f"[{sid}] medical response does not match Template A exactly: '{resp[:60]}'")

    # Category count check
    for subcat, expected in EXPECTED_SUBCATEGORY_COUNTS.items():
        actual = subcategory_counts.get(subcat, 0)
        if actual != expected:
            errors.append(
                f"subcategory '{subcat}': expected {expected}, got {actual}"
            )

    return errors


def main_emergency() -> None:
    dialogues = EMERGENCY_DIALOGUES

    errors = _validate_emergency(dialogues)
    if errors:
        print(f"VALIDATION FAILED ({len(errors)} errors):")
        for e in errors:
            print(f"  {e}")
        sys.exit(1)

    print(f"Validation: all {len(dialogues)} emergency dialogues passed.")

    OUTPUT_PATH_EMERGENCY.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_PATH_EMERGENCY.open("w", encoding="utf-8") as f:
        for d in dialogues:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")

    template_a = sum(
        1 for d in dialogues if d.get("subcategory") not in {"suicidal_ideation"}
    )
    template_b = sum(
        1 for d in dialogues if d.get("subcategory") == "suicidal_ideation"
    )
    categories = len(EXPECTED_SUBCATEGORY_COUNTS)

    print(f"Wrote {len(dialogues)} dialogues → {OUTPUT_PATH_EMERGENCY}")
    print(f"Total turns: {len(dialogues) * 2}")
    print(f"Template A (medical emergency): {template_a}")
    print(f"Template B (suicidal ideation): {template_b}")
    print(f"Categories covered: {categories}")

    # Print 5 samples — include at least synth-108 (vernacular), synth-118 (suicidal vernacular)
    samples = [
        next(d for d in dialogues if d["synthetic_id"] == "synth-107"),
        next(d for d in dialogues if d["synthetic_id"] == "synth-108"),
        next(d for d in dialogues if d["synthetic_id"] == "synth-110"),
        next(d for d in dialogues if d["synthetic_id"] == "synth-118"),
        next(d for d in dialogues if d["synthetic_id"] == "synth-121"),
    ]

    print("\n" + "=" * 66)
    print("SAMPLE — 5 dialogues (vernacular + suicidal cases included)")
    print("=" * 66)
    for d in samples:
        print(f"\n{'─'*60}")
        print(f"[{d['synthetic_id']}] subcategory={d['subcategory']}")
        print(f"  PATIENT  : {d['messages'][0]['content']}")
        try:
            p = json.loads(d["messages"][1]["content"])
            print(f"  ASSISTANT: {p['response']}")
            print(f"             emergency={p['emergency']} | priority={p['priority']}")
        except Exception:
            print(f"  ASSISTANT (err)")
    print(f"\n{'='*66}")


if __name__ == "__main__":
    main_emergency()
