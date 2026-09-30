#!/usr/bin/env python3
"""Génère en.lproj, ru.lproj et de.lproj/Localizable.strings depuis t1..t4.py (clé = texte français).

Usage : python3 generer.py                  → écrit les .strings
        python3 generer.py --verifier <dir>  → liste les textes de l'app (fichiers .stringsdata du compilateur)
                                               qui n'ont pas encore de traduction
"""
import glob, json, os, re, sys

ici = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ici)
T = {}
for m in ["t1", "t2", "t3", "t4", "t5", "t6"]:
    T.update(__import__(m).T)

spec = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|lf|f|%)")
erreurs = []
for cle, trads in T.items():
    attendu = sorted(spec.findall(cle))
    for langue, t in zip(["en", "ru", "de"], trads):
        if sorted(spec.findall(t)) != attendu:
            erreurs.append(f"{langue} : formats différents pour « {cle} » → « {t} »")
if erreurs:
    print("\n".join(erreurs)); sys.exit(1)

def echapper(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

if len(sys.argv) > 2 and sys.argv[1] == "--verifier":
    cles = set()
    for f in glob.glob(os.path.join(sys.argv[2], "*.stringsdata")):
        for table in json.load(open(f)).get("tables", {}).values():
            cles.update(e["key"] for e in table)
    utiles = [k for k in cles if re.search(r"[A-Za-zÀ-ÿА-я]{2,}", spec.sub("", k))]
    manquantes = sorted(k for k in utiles if k not in T)
    print(f"{len(utiles)} textes, {len(manquantes)} sans traduction")
    for k in manquantes: print("  " + k)
    sys.exit(0)

for i, langue in enumerate(["en", "ru", "de"]):
    d = os.path.join(ici, f"{langue}.lproj")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "Localizable.strings"), "w", encoding="utf-8") as f:
        f.write("/* Généré par generer.py : ne pas modifier à la main. */\n")
        for cle in sorted(T):
            f.write(f'"{echapper(cle)}" = "{echapper(T[cle][i])}";\n')
print(f"{len(T)} textes × 3 langues")
