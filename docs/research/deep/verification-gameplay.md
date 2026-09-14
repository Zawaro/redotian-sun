# Adversarial Verification — Gameplay Content Numbers & UI/Campaign Claims

Independent, web-only verification of the highest-stakes / highest-uncertainty claims in the
`docs/research/deep/` catalogs (`ts-gameplay.md`, `ts-uiux.md`, `fs.md`, `ra2-gameplay.md`,
`ra2-uiux.md`, `yr-gameplay.md`, `yr-uiux.md`).

**Method.** Claims were checked against primary/shipped INI data where available (Vinifera TS INIs,
RA2/YR `rules(md).ini` mirrors), engine-modding canon (ModEnc), the C&C Wiki (cnc.fandom), official
patch notes (cnc-comm.com), CnCNZ, DefKey, StrategyWiki, PPM, and CnCNet. No local game data was
read. Where sources conflict the wiki/patch-note consensus is reported and the outlier is named.

**Scope note — patch level matters.** Several YR "cost" values in the catalogs use the retail **1.000**
figure from a `rulesmd.ini` mirror. The only official YR patch, **1.001**, changed several of those
costs. This one mistake accounts for three of the value errors below. A remake should target the
final patched (1.001) values.

**Headline:** the catalogs are substantially accurate. Every roster/campaign/animation count checked
was correct. The errors are concentrated in (a) patch-level unit costs, (b) a few internal IDs, and
(c) one design-relevant engine claim (TS warhead `Verses`) that is simply false. The catalog also
contains two internal self-contradictions.

---

## 1. Conflict Ledger

| Claim | Source file / ID | Original | Verified | Verdict | Evidence URLs | Confidence |
|-------|------------------|----------|----------|---------|---------------|------------|
| RA2/YR sidebar has **4 tabs** | `ra2-uiux.md` RA2-UI-020 | 4 (Q/W/E/R) | 4: buildings, defenses+support powers, infantry, vehicles (incl. air/naval) | **CONFIRMED** | cnc.fandom.com/wiki/Sidebar ; defkey.com/command-conquer-red-alert-2-shortcuts | high |
| RA2 sidebar has **6 tabs** (Structures, Defenses, Infantry, Vehicles, Aircraft, Ships) | `ra2-gameplay.md` RA2-GP-021 | 6 | **4** — 6–7 tabs belong to TW/RA3; no vanilla RA2 "Aircraft"/"Ships" tab | **REFUTED** (internal contradiction with RA2-UI-020) | cnc.fandom.com/wiki/Sidebar ; defkey.com/.../red-alert-2-shortcuts | high |
| RA2 **control groups = 9** (Ctrl+1–9) | `ra2-uiux.md` RA2-UI-061/062 | 9 | 9 (DefKey, Steam in-game hotkey guide); StrategyWiki's `[1-0]` is the outlier | **CONFIRMED** | defkey.com/command-conquer-red-alert-2-shortcuts ; steamcommunity.com/app/2229850/discussions/0/4299320559087086769 | high |
| TS **control groups = 10** | `ts-uiux.md` TS-UI-061 | 10 | 10 | **CONFIRMED** | tiberiansunguide.wixsite.com/tiberiansunguide/hotkeys | high |
| Firestorm = **18 missions (9 GDI + 9 Nod)** | `fs.md` FS-027/028, `ts-uiux.md` TS-UI-132 | 9+9 | 9+9 = 18 | **CONFIRMED** | modenc.renegadeprojects.com/Firestorm | high |
| TS GDI campaign = **15 main missions** (+3 bonus, +2 demo) | `ts-uiux.md` TS-UI-130 | 15 | 15 main; 21 pages incl. bonus/demo/sandbox | **CONFIRMED** | cnc.fandom.com/wiki/Category:Tiberian_Sun_GDI_missions | high |
| TS Nod campaign = **13–14 main missions** | `ts-uiux.md` TS-UI-131 (line 1465) | 13–14 | 13 main (with 2 either/or branches) | **CONFIRMED** | cnc.fandom.com/wiki/Category:Tiberian_Sun_Nod_missions | high |
| TS Nod campaign = **15 main missions** | `ts-uiux.md` line 63 (TS-UI-002) | 15 | **13** — Nod main line is 13, not 15 | **REFUTED** (contradicts TS-UI-131 in same file) | cnc.fandom.com/wiki/Category:Tiberian_Sun_Nod_missions | high |
| RA2 Allied/Soviet campaigns = **12 + 12** | `ra2-uiux.md` RA2-UI-002 | 12+12 | 12+12 (final mission is #12 for each) | **CONFIRMED** | cnc.fandom.com/wiki/Chrono_Storm ; cnc.fandom.com/wiki/Polar_Storm | high |
| YR Allied/Soviet campaigns = **7 + 7** | `yr-uiux.md` YR-UI-100/101, `yr-gameplay.md` §9 | 7+7 | 7+7 ("seventh and final mission") | **CONFIRMED** | cnc.fandom.com/wiki/Brain_Dead ; cnc.fandom.com/wiki/Category:Yuri%27s_Revenge_missions | high |
| TS `[Animations]` = **277 entries (0–276), last = `INVISO`** | `ts-uiux.md` TS-UI-118 | 277 | 0=TWLT100 … 276=INVISO; indices 87/99/171 also match | **CONFIRMED** | modenc.renegadeprojects.com/Animations | high |
| TS warhead `Verses` is **hardcoded / not INI-exposed** | `ts-gameplay.md` TS-GP-042, TS-GP-058 | hardcoded | **False** — TS warheads have editable `Verses=` in `rules.ini` (ModEnc "RA/TS Example") | **REFUTED** | modenc.renegadeprojects.com/Verses | high |
| RA2 Ore Purifier = **$2500, +25% per bail** | `ra2-gameplay.md` RA2-GP-004/035 | $2500 / .25 | $2500; `PurifierBonus=.25` | **CONFIRMED** | modenc.renegadeprojects.com/PurifierBonus ; cnc.fandom.com/wiki/Ore_purifier ; cncnz.com/games/red-alert-2/allied-structures | high |
| RA2 Ore Miners: Chrono/War Miner **$1400**, capacities $500/$1000 and $1000/$2000 | `ra2-gameplay.md` RA2-GP-002 | $1400 | Confirmed values; capacity split confirmed | **CONFIRMED** | cnc.fandom.com/wiki/Chrono_miner ; cncnz.com/games/red-alert-2 | high |
| **Slave Miner = $1500** ("mirror wins over CNCNZ 1750") | `yr-gameplay.md` YR-GP-013/060/roster | 1500 | **$1750** — raised from 1500 to 1750 in YR patch 1.001 (official final) | **CORRECTED** (patch level) | cnc.fandom.com/wiki/Slave_miner ; cncnz.com/games/yuris-revenge/yuris-structures ; cnc-comm.com/red-alert-2/downloads/patches/yuris-revenge-1.001 | high |
| **Slave Miner = $1400** (RA2 roster table) | `ra2-gameplay.md` RA2-GP-002 | 1400 | **$1750** (YR); a $1400 figure is unsourced for the Slave Miner | **CORRECTED** | cnc.fandom.com/wiki/Slave_miner | high |
| **Chaos Drone = $800** ("mirror wins over CNCNZ 600") | `yr-gameplay.md` YR-GP-063/roster | 800 | **$1000** — raised from 800 to 1000 in YR patch 1.001 (final); ROF 30→45 | **CORRECTED** (patch level) | cnc.fandom.com/wiki/Chaos_drone ; cnc-comm.com/.../yuris-revenge-1.001 | high |
| **Siege Chopper = $1400** | `yr-gameplay.md` YR-GP-201, §4 table | 1400 | **$1100** — decreased from 1400 to 1100 in YR patch 1.001 (final) | **CORRECTED** (patch level) | cnc.fandom.com/wiki/Siege_chopper ; cncnz.com/games/yuris-revenge/new-soviet-units | high |
| YR Grinder = **$600, 900 HP, −50 power; vehicles 100% / infantry 50% refund** | `yr-gameplay.md` YR-GP-017/301 | 600 / 100/50 | Confirmed (balance patch confirms base 600, raised to 1000 only by mods) | **CONFIRMED** | cnc.fandom.com/wiki/Grinder_(Yuri%27s_Revenge) ; github.com/CnC-RaVaGe/C-C-YR-Rebalance-Patch | high |
| YR Tanya = **$1000 → $1500, build-limit 1, C4 now on ground vehicles** | `yr-gameplay.md` YR-GP-105, delta | 1500 | Confirmed | **CONFIRMED** | cnc.fandom.com/wiki/Tanya_(Red_Alert_2) ; cncnz.com/games/yuris-revenge/new-allied-units | high |
| Grand Cannon internal id = **`GAGCAN`** | `ra2-gameplay.md` RA2-GP-013, RA2-GP-027 | GAGCAN | **`GTGCAN`** | **REFUTED** (and self-contradicts YR-GP-802 which says GTGCAN) | cnc.fandom.com/wiki/Grand_cannon ; PPM `[GTGCAN]` thread | high |
| Korea's country unique = **(none / standard arsenal)** | `yr-gameplay.md` YR-GP-802 | none | **Black Eagle** (`BEAG`, $1200) in both RA2 and YR | **REFUTED** (self-contradicts RA2-GP-027) | cnc.fandom.com/wiki/Black_Eagle ; cncnz.com/games/red-alert-2/allied-units | high |
| YR Battle Bunker tank multipliers = **1.3 dmg / 1.3 ROF** | `yr-gameplay.md` YR-GP-020 | 1.3/1.3 | 1.3 / 1.3 (global, not INI-tunable per object) | **CONFIRMED** | modenc.renegadeprojects.com/BunkerROFMultiplier ; modenc.renegadeprojects.com/BunkerDamageMultiplier | high |
| YR **IFV = 17 weapon modes (0–16)**, modes 13–16 added | `yr-gameplay.md` YR-GP-106, delta | 17 modes | 17 modes; RA2 had 13 (0–12) | **CONFIRMED** (internally consistent) | cnc.fandom.com/wiki/Infantry_fighting_vehicle ; cncnz.com/games/yuris-revenge | med-high |
| RA2 = 9 countries / YR adds 10th `YuriCountry` (ThirdSide) | `ra2-gameplay.md` RA2-GP-027, `yr-gameplay.md` YR-GP-001 | 9 / 10 | Confirmed | **CONFIRMED** | cnc.fandom.com/wiki/Countries ; rulesmd `[Countries]`/`[Sides]` mirrors | high |
| RA2 has **no ore silos**; refinery absorbs all | `ra2-gameplay.md` RA2-GP-001/008 | no silos | Confirmed | **CONFIRMED** | cnc.fandom.com/wiki/Ore | high |
| Stone/armor-vs-warhead: TS uses hardcoded `Verses` | (same as above) | — | TS armor enum = 5 (none/wood/light/heavy/concrete); RA2/YR = 11; **Verses editable in both** | **REFUTED (design-impacting)** | modenc.renegadeprojects.com/Verses | high |
| `ai.ini` for RA2 / `aimd.ini` for YR | `ra2-gameplay.md` RA2-GP-064 | ai/aimd | Confirmed | **CONFIRMED** | modenc.renegadeprojects.com/TS_vs_RA2 | high |
| TS AI script action numbering (TS-GP-046) | `ts-gameplay.md` TS-GP-046 | TS op list | TS and RA2/YR action IDs diverge (RA2 shifts 11+ by +1; RA2/YR add 26–32) | **PARTIAL — see corrections** | modenc.renegadeprojects.com/TS_vs_RA2 | high |
| AITriggerTypes comparator = "64-hex string, octet0=value, octet1=operator" | `ts-gameplay.md` TS-GP-046 | 64-hex, 0=value/1=op | Byte order (value=byte0, operator=byte1) is correct; length is 8 significant bytes zero-padded, and TS/RA2 read lengths differ | **PARTIAL** | modenc.renegadeprojects.com/AITriggerTypes ; modenc.renegadeprojects.com/TS_vs_RA2 | med |
| YR Genetic Mutator / Psychic Dominator params | `yr-gameplay.md` YR-GP-024/025/402 | 2500/5000, 5/10 min | No contradicting evidence; parameter set plausible and internally consistent | **UNVERIFIED-OK** | cnc.fandom.com/wiki/Genetic_mutator ; cnc.fandom.com/wiki/Psychic_dominator | med |
| RA2/YR superweapon cooldowns: IC 5:00, Chrono 7:00, Nuke 10:00, Weather 10:00 | `ra2-gameplay.md` RA2-GP-047/048/051/052 | 5/7/10/10 min | No contradiction found; consistent with the YR delta table | **UNVERIFIED-OK** | cncnz.com/games/red-alert-2 | med |
| Tanya/SEAL/Boris/Siege Chopper/Battle Fortress behaviors | `ra2-gameplay.md`/`yr-gameplay.md` | — | Confirmed (Battle Fortress 5 open-topped passengers, can crush Tanya; Siege Chopper deploys to 160 mm) | **CONFIRMED** | cncnz.com/games/yuris-revenge/new-allied-units ; cnc.fandom.com/wiki/Battle_Fortress | high |
| RA2/YR spy infiltration effects table | `ra2-gameplay.md` RA2-GP-037 | e.g. refinery steal 50% | Confirmed at 50% (`SpyMoneyStealPercent=.5`); the "wiki says 20%" outlier is the wiki inconsistency already flagged | **CONFIRMED** | modenc.renegadeprojects.com/Agent ; openra-red-alert.fandom.com/wiki/Spy | med-high |
| TS `[InfantryTypes]` 36 / `[VehicleTypes]` ~50 / `[BuildingTypes]` ~150 | `ts-gameplay.md` TS-GP-052 | 36 / 50 / 150 | Not independently counted from a primary INI in this pass | **UNVERIFIED** | — | low |
| RA2 `[InfantryTypes]` 45 / `[VehicleTypes]` 57 | `ra2-gameplay.md` RA2-GP-069 | 45 / 57 | Not independently counted from a primary INI in this pass | **UNVERIFIED** | — | low |
| TS `[AI]`/`[IQ]` constant tables | `ts-gameplay.md` TS-GP-043/044 | many keys | Derived from the same shipped INI the catalog cites; spot-checks found no contradiction | **UNVERIFIED-OK** | modenc.renegadeprojects.com/Rules.ini | low-med |
| FS Elite Cadre cost = **300** (wiki text says 350) | `fs.md` FS-012 | 300 (conflict 300/350) | FIRESTRM.INI value 300 retained; wiki conflict not resolved by a 2nd numeric source | **CONFIRMED-AS-DATA** | cnc.fandom.com/wiki/Elite_cadre | med |

---

## 2. Corrections (exact replacement facts)

1. **`ra2-gameplay.md` RA2-GP-021 — sidebar tabs.** Replace "six tabs: Structures, Defenses,
   Infantry, Vehicles, Aircraft, Ships" with **four tabs** (Structures; Defenses/support powers;
   Infantry; Vehicles — the latter also holds aircraft and naval units). Delete the "Ships" and
   "Aircraft" rows from the mapping table; they are not separate RA2 tabs. The RA2-UI-020 wording
   is the correct one. (6–7 tabs are Tiberium Wars / Red Alert 3.)

2. **`yr-gameplay.md` YR-GP-013, YR-GP-060, and the §2.3 roster table — Slave Miner cost.** Replace
   `1500` with **`1750`** (and drop the "mirror wins" note). Pre-patch 1.000 = 1500; **official
   1.001 = 1750**.

3. **`ra2-gameplay.md` RA2-GP-002 — Slave Miner cost.** Replace `$1400` with **`$1750`**. (The
   $1400 row is simply wrong; RA2 has no Slave Miner at all — it is YR-only.)

4. **`yr-gameplay.md` YR-GP-063 and the §2.3 roster table — Chaos Drone cost.** Replace `800` with
   **`1000`** (1.001). ROF also went 30→45.

5. **`yr-gameplay.md` YR-GP-201 and the §4 Soviet table — Siege Chopper cost.** Replace `1400` with
   **`1100`** (1.001).

6. **Internal ID `GAGCAN` → `GTGCAN`** everywhere: `ra2-gameplay.md` RA2-GP-013 (Grand Cannon row)
   and RA2-GP-027 (France unique column). `yr-gameplay.md` YR-GP-802 already has the correct
   `GTGCAN`.

7. **`yr-gameplay.md` YR-GP-802 — Korea row.** Replace "– (no unique unit; standard arsenal)" with
   **"Black Eagle (`BEAG`), $1200 — replaces Harrier"**. (Only YR's Tech Secret Lab can grant other
   factions' uniques; Korea always has the Black Eagle.)

8. **`ts-gameplay.md` TS-GP-042 (Combat, line ~925) and TS-GP-058 (line ~1284) — Verses.** Delete
   the claim that warhead `Verses` is hardcoded for TS. Replace with: "Warhead `Verses=` are
   editable in TS/Firestorm `rules.ini`, exactly as in RA2/YR. What differs is the **armor-type
   enumeration**: TS = 5 armor classes (`none, wood, light, heavy, concrete`); RA2/YR = 11
   (`none, flak, plate, light, medium, heavy, wood, steel, concrete, special_1, special_2`)." This
   is the single most design-impacting correction — a unified engine must read per-game armor
   tables and `Verses` length, not hardcode TS behavior.

9. **`ts-uiux.md` line 63 (TS-UI-002).** Change "Nod main line: 15 missions" to **13 main
   missions** (2 of which are either/or branch pairs), matching TS-UI-131.

10. **`ts-gameplay.md` TS-GP-046 — AITriggerTypes comparator.** Soften "64-hex string" to: "an
    8-byte comparator (byte 0 = value, byte 1 = operator), zero-padded; TS and RA2/YR differ in the
    parser's handling of trailing bytes." Add a cross-game warning: **script action IDs differ
    between TS and RA2/YR** (RA2/YR insert `Eaten`/`Harvest` at 9/10 and shift every TS action ≥11
    by +1; RA2/YR add 26–32 including YR-only Spyplane actions). A unified engine must key AI
    actions per game, not by a single enum. (Source: ModEnc `TS_vs_RA2`.)

11. **All three YR cost fixes share a root cause** worth recording in the source-key notes: the
    `RULES-MIRROR` used by `yr-gameplay.md` captures retail **1.000**, not the final **1.001**
    patched values. Rule: prefer the patch-note/wiki final value over the raw mirror when the
    mirror predates 1.001.

---

## 3. Completeness Gaps

No **buildable object** was found missing across TS GDI/Nod, RA2 Allied/Soviet + 9 countries, or
YR Yuri + Allied/Soviet additions. Specific checks that passed:

- RA2 defenses/superweapons list (RA2-GP-013) is complete: Pillbox, Patriot, Prism Tower, Grand
  Cannon, Sentry Gun, Flak Cannon, Tesla Coil, SpySat, Gap Generator, Psychic Sensor, Chronosphere,
  Weather Control, Iron Curtain, Nuclear Silo. The 4-tab tab-assignment is the only defect.
- YR Yuri structures/infantry/vehicles/aircraft and the Allied/Soviet addition lists are complete
  relative to wiki categories (Guardian GI, Robot Tank/Center, Battle Fortress, Navy SEAL, Tanya
  change; Boris, Siege Chopper, Industrial Plant, Battle Bunker, Spy Plane; all Yuri content).
- TS `[Animations]` index claims (87 `GACNSTMK`, 99 `NATMPLMK`, 171 `GADPSAMK`) match the ModEnc
  corrected array exactly.

**Genuine gaps / weak spots:**

1. **YR `[Animations]` numbering bug is not documented.** ModEnc shows YR renumbers and Westwood
   "screwed up the list enumeration at #209 by including new entries there, shifting all later
   animations +4". The catalogs document TS `[Animations]` (277, correct) but never mention that
   **YR's array is ~607 entries with a +4 shift bug** — directly relevant to any map-trigger or
   animation-caching port. (`modenc.renegadeprojects.com/Animations`)
2. **Per-game AI action-ID map is missing.** TS-GP-046 lists TS script ops but no RA2/YR delta
   table. Needed for a unified engine's AI data layer. (ModEnc `TS_vs_RA2`.)
3. **Armor-enumeration differences are not stated as a first-class fact anywhere.** The catalogs
   imply it (TS 5 classes, RA2 Verses 11) but never call out the layout contract. Should be a
   named Data-Architecture entry.
4. **Type-list counts are asserted without a primary-source citation** (TS 36/50/150; RA2
   45/57). Either cite a raw INI line range or downgrade confidence to "approx".
5. **RA2/YR "Aircraft/Ships" build-tab confusion is the only place the catalogs mislead on UI
   architecture** — see correction #1.

---

## 4. Coverage Checklist

| # | Priority (from brief) | Verified? | Result |
|---|-----------------------|-----------|--------|
| 1 | Roster completeness (TS/RA2/YR counts, 9 uniques) | Yes (counts + uniques), rosters partially | No buildable missing; Korea unique corrected; country count 9+1 confirmed |
| 2 | Uncertain costs: YR Grinder/Slave/Chaos, RA2 miner/purifier, FS Elite Cadre | Yes | Grinder 600 ✔; Slave 1500→**1750**; Chaos 800→**1000**; RA2 miners/purifier ✔; ELCAD 300 (wiki 300/350 unresolved) |
| 3 | RA2 sidebar tabs (4 vs 6), control groups (9 vs 10) | Yes | **4 tabs**; **9 groups** (RA2), **10** (TS) |
| 4 | Mission lists: TS GDI/Nod, FS 18, RA2 12+12, YR 7+7 | Yes | All confirmed; TS Nod internal 15→**13** |
| 5 | RA2/YR superweapon & support-power params | Partial | No contradictions; many values not independently re-derived |
| 6 | Spy effects; IFV table; Boris/Siege/Tanya/Battle Fortress | Yes | Confirmed; Siege Chopper cost fixed |
| 7 | YR garrison/bunker rules & multipliers | Yes | 1.3/1.3 confirmed; Tank Bunker rules plausible |
| 8 | TS EVA/music/hotkeys; 277-entry [Animations] | Partial | Hotkeys: TS 10 groups confirmed; **277 entries CONFIRMED**; EVA/music not independently checked |
| 9 | RA2/YR defenses list completeness | Yes | Complete; Grand Cannon ID fixed |
| 10 | TS [AI]/[IQ]; RA2/YR aimd | Partial | Structures confirmed; constants not re-derived; action-ID delta added |
| 11 | Map sections / per-map overrides | No (not re-verified this pass) | Catalog architecture plausible; TS map-section list matches known `.MAP` sections |
| 12 | Anything affecting unified-engine design | Yes | **TS Verses correction**; armor-enum + YR animation shift + AI action-ID deltas flagged |

### Counts

- **Claims examined:** 34 in the ledger (+ catalog-wide cross-checks)
- **Confirmed correct:** 20
- **Refuted (claim is false):** 4 — RA2 6-tab sidebar; TS hardcoded `Verses`; TS-UI line 63 Nod=15;
  Grand Cannon id `GAGCAN`
- **Corrected values:** 5 — Slave Miner 1500→1750 (and RA2-GP-002 1400→1750), Chaos Drone 800→1000,
  Siege Chopper 1400→1100, Korea unique "none"→Black Eagle, `GAGCAN`→`GTGCAN`
- **Partial/needs wording fix:** 2 — AITriggerTypes comparator, AI action-ID delta
- **Unverified (no contradicting evidence, not independently derived):** 5 — type-list counts,
  TS [AI]/[IQ] constants, superweapon cooldowns, EVA/music, some internal IDs

---

## 5. Open Questions / Top Unresolved

1. **Type-list counts** (TS 36 inf / ~50 veh / ~150 bldg; RA2 45 inf / 57 veh). Cheap to settle by
   counting raw `[InfantryTypes]`/`[VehicleTypes]`/`[BuildingTypes]` in the Vinifera TS `RULES.INI`
   and a retail `rules(md).ini`. **Action:** count once and cite line ranges.
2. **Elite Cadre cost 300 vs 350.** FIRESTRM.INI says 300; wiki prose says 350. Second numeric
   source (another INI mirror) needed. Confidence stays med.
3. **RA2/YR script action-ID mapping.** Confirm the exact RA2/YR action table from a primary
   `ai(md).ini` rather than ModEnc's summary before encoding it in the unified engine.
4. **YR 1.001** is the arithmetic root of three cost errors. Are there any *other* YR values in
   `yr-gameplay.md` (not in scope here) drawn from the 1.000 mirror that 1.001 changed? The patch
   notes only say "slightly increased/decreased" for the three known units, but a full diff of
   1.000 vs 1.001 `rulesmd.ini` is the definitive check.
5. **TS/RA2/YR armor-enum contracts.** Confirm RA2/YR's 11-class order from a primary `rules(md).ini`
   (`[ArmorTypes]` / hardcoded order) before locking the unified-engine armor table.
6. **StrategyWiki RA2 control groups** (`Ctrl+[1-0]`) contradicts DefKey/Steam (`1–9`). Resolve by
   checking the printed RA2 manual; the catalog's 9 is the safer default.
7. **Internal IDs not re-verified:** `GASAM` (Patriot), `GAPRIS` (Prism Tower), `GAPURP` (Ore
   Purifier), RA2 `MTNK` (Grizzly). Low risk, but a single raw-INI pass would close them.
