#!/usr/bin/env python3
"""Régénère les CodingKeys et le décodage tolérant de `Design` (LaFleurCore/Jaquette.swift)
à partir de la liste de ses propriétés. À lancer après avoir ajouté un champ à `Design`."""
import os, re
p = os.path.join(os.path.dirname(__file__), "..", "Sources", "LaFleurCore", "Jaquette.swift")
s = open(p).read()
debut = s.index("public struct Design: Codable")
cles = s.index("    enum CodingKeys: String, CodingKey {", debut)
noms = re.findall(r"^    public var (\w+)\b(?![^\n]*\{)", s[debut:cles], re.M)
fin_init = s.index("    public init() {}", cles)
bloc = "    enum CodingKeys: String, CodingKey {\n        case " + ", ".join(noms) + "\n    }\n\n" \
    "    /// Décodage tolérant : un champ absent ou illisible prend sa valeur par défaut (les anciennes cassettes restent lisibles).\n" \
    "    /// Généré par outils/regenerer-design.py.\n" \
    "    public init(from decoder: Decoder) throws {\n" \
    "        let c = try decoder.container(keyedBy: CodingKeys.self)\n" \
    "        let d = Design()\n" \
    "        func v<T: Decodable>(_ k: CodingKeys, _ defaut: T) -> T { ((try? c.decodeIfPresent(T.self, forKey: k)) ?? nil) ?? defaut }\n" \
    + "".join(f"        {n} = v(.{n}, d.{n})\n" for n in noms) + "    }\n\n"
s = s[:cles] + bloc + s[fin_init:]
open(p, "w").write(s)
print(f"{len(noms)} champs : " + ", ".join(noms))
