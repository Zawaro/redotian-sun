# Adversarial Verification — Core Mechanics Claims

Independent web re-verification of the highest-stakes claims in `ts-core.md`, `ra2-core.md`,
and `yr-core.md`. Method: web only; primary INI files on GitHub, ModEnc, Ares/Phobos docs,
CnCNet/fandom. No local game data read. Two or more independent sources per item where possible.

Confidence: **high** = ≥2 independent authoritative sources agree; **med** = one authoritative
source / wording ambiguity; **low** = unresolved or single weak source.

---

## Conflict Ledger

| Claim | File/ID | Original | Verified | Verdict | Evidence URLs | Confidence |
|---|---|---|---|---|---|---|
| TS armor classes = 5, order `none, wood, light, heavy, concrete` | ts-core.md TS-CORE-015 / TS-CORE-016 | 5 classes; order n,w,l,h,c | ModEnc Armor_types prose says "none, light, wood, heavy and concrete"; ModEnc Verses RA/TS example labels the list `; n , w , l , h , c`; OpenTS `armor.hh` enum = NONE(0), WOOD(1), ALUMINUM/light(2), STEEL/heavy(3), CONCRETE(4) | **confirmed** (count + names); **corrected** (ModEnc prose order is internally inconsistent) | modenc/Armor_types, modenc/Verses, OpenTS armor.hh | high |
| RA2/YR armor classes = 11: `none, flak, plate, light, medium, heavy, wood, steel, concrete, special_1, special_2` | ra2-core.md RA2-CORE-007; ts-core.md TS-CORE-015 | 11 classes, that exact order | ModEnc Armor_types: "RA2 had 11 - none, flak, plate, light, medium, heavy, wood, steel, concrete, special_1 and special_2"; ModEnc Verses gives the same Seq Num 1..11 table | **confirmed** | modenc/Armor_types, modenc/Verses | high |
| RA2/YR Verses = per-index damage multiplier; `Verses` is an editable INI flag | ra2-core.md RA2-CORE-008/009; ts-core.md TS-CORE-016 | `Verses` on warhead, rules(md).ini | ModEnc Verses: File(s)=rules(md).ini, Applicable=Warhead; "percentage of Damage= to be applied" | **confirmed** | modenc/Verses | high |
| TS `Verses` is editable in INI, not hardcoded | ts-core.md TS-CORE-016; focus item 2 | TS order n/w/l/h/c; RA2 0%/1% semantics do not apply to TS | ModEnc Verses explicitly splits "Special Values → In RA/TS" (only heavy=0% infantry rule) vs "In RA2/YR" (0%/1%, 2%=no effect). The special targeting values are RA2/YR-only. Armor *class list* is engine-fixed; the *Verses percentages* are INI-editable | **confirmed** | modenc/Verses, modenc/Armor_types | high |
| TS `heavy=0%` on an infantry weapon: no passive acquire/retaliate vs vehicle/air/building unless Secondary can target that armor | ts-core.md TS-CORE-016 | as written | ModEnc Verses "In RA/TS → heavy=0% (Infantry Only)": infantry weapon dealing 0% to heavy will not passively acquire nor retaliate against vehicle/aircraft/building. Example `HollowPoint Verses=100%,1%,1%,0%,1%` | **confirmed** | modenc/Verses | high |
| RA2/YR 0% = forbidden target (no force-fire/retaliate/passive); 1% = no passive acquire but explicit orders/retaliation allowed; 2% has no effect | ra2-core.md RA2-CORE-008 | as written | ModEnc Verses "In RA2/YR": 0% forbidden; 1% cannot passive acquire but accepts order/force-fire/retaliate; "2% doesn't seem to have any effect" | **confirmed** | modenc/Verses | high |
| `Verses` negative value reverses damage into healing | ra2-core.md RA2-CORE-008/009; ts-core.md TS-CORE-016 | as written | ModEnc Verses "Negative Percentages": effects reversed, restores Strength | **confirmed** | modenc/Verses | high |
| YR MindControl capacity = Primary weapon `Damage`; `ElitePrimary` ignored | yr-core.md YR-CORE-007/006 | as written | ModEnc MindControl: "The Damage value of the Primary weapon determines how many objects total can be controlled... ElitePrimary is ignored even when promoted" | **confirmed** | modenc/MindControl | high |
| YR `InfiniteMindControl` on weapon overrides Damage cap | yr-core.md YR-CORE-007 | as written | ModEnc MindControl: "except in the case that InfiniteMindControl=yes is also set on the warhead"; dedicated InfiniteMindControl page | **confirmed** | modenc/MindControl, modenc/InfiniteMindControl | high |
| Mind control is one-to-one without multi Damage; no CellSpread / no sub-weapon; Secondary-only MC → EIP#00471CA4 | yr-core.md YR-CORE-006 | as written | ModEnc MindControl Bugs: one-to-one, no CellSpread/sub-weapon; Secondary warhead MC while Primary not → EIP#00471CA4 (Ares 0.1 fix) | **confirmed** | modenc/MindControl | high |
| Buildings default `ImmuneToPsionics=yes`; Yuri Prime building capture needs non-zero Verses + `ImmuneToPsionics=no` | yr-core.md YR-CORE-009/012; ts-core.md (n/a) | as written | ModEnc MindControl Notes: buildings default yes; Yuri Prime relies on Verses + broad ImmuneToPsionics=no | **confirmed** | modenc/MindControl, modenc/ImmuneToPsionics | high |
| `ImmuneToPsionics` and `ImmuneToPsionicWeapons` are independent axes | yr-core.md YR-CORE-009 | as written | ModEnc ImmuneToPsionics / ImmuneToPsionicWeapons pages kept separate; 1.001 adds ImmuneToPsionicWeapons=yes to Yuri Prime | **confirmed** | modenc/ImmuneToPsionics, modenc/ImmuneToPsionicWeapons | high |
| PsychicDominator capture is permanent; building capture hardcoded off | yr-core.md YR-CORE-010/021 | as written | ModEnc Type / DominatorCaptureRange; Ares docs: vanilla `Dominator.PermanentCapture=yes`; `Type=PsychicDominator` will not capture buildings | **confirmed** | modenc/Type, modenc/DominatorCaptureRange, Ares psychicdominator | high |
| Gattling: `TurretCount≥1` required (else EIP#0070DF8A); odd WeaponX=AG, even=AA; `WeaponStages`; `(Elite)StageX` are timer endpoints; `RateUp`/`RateDown` per frame; `WeaponCount=WeaponStages*2` (fewer→EIP, more only via NoAmmoWeapon) | yr-core.md YR-CORE-013 | as written | ModEnc Gattling Weapon System repeats every one of these, incl. EIP#0070DF8A, AG/AA parity, endpoint semantics, WeaponCount rule | **confirmed** | modenc/Gattling_Weapon_System, modenc/TurretCount, modenc/WeaponStages, modenc/RateUp | high |
| Gattling Tank numbers: TurretCount=1, WeaponCount=6, WeaponStages=3, Stage1..3=200/400/600, EliteStage1..3=100/200/300, RateUp=1, RateDown=50 | yr-core.md YR-CORE-013 | as written | ModEnc Gattling Weapon System reproduces exactly this block | **confirmed** | modenc/Gattling_Weapon_System | high |
| `StageX` need not be increasing; boundary frame goes to higher stage; `RateDown=0` instant reset; negative RateDown self-winds; first attack always stage 1 | yr-core.md YR-CORE-013 | as written | ModEnc Gattling "Notes" sections describe all four | **confirmed** | modenc/Gattling_Weapon_System | high |
| YR country bonus `YYYZZZMult` where YYY∈{Armor,Cost,Speed,BuildTime}, ZZZ∈{Aircraft,Units,Infantry,Buildings,Defenses}; `IncomeMult` is a special case; `VeteranInfantry/Units/Aircraft` | yr-core.md YR-CORE-005 | as written | ModEnc Countries "VeteranXXX and YYYZZZMult=" lists exactly these sets and calls IncomeMult "a special case that doesn't follow the above logic" | **confirmed** | modenc/Countries | high |
| YR `ThirdSide=YuriCountry`; index 9 = YuriCountry; 9 major houses fixed; index-9 art hardcoded | yr-core.md YR-CORE-004 | as written | ModEnc Countries: `[Countries]` 0..13 with 9=YuriCountry, `[Sides] ThirdSide=YuriCountry`, stock warning not to reorder the major 9; index 9 → yrii.pcx/ls800yuri.shp/mpyls.pal (YR-only per-country palette) | **confirmed** | modenc/Countries | high |
| Veteran/Elite ability token list (TS 18 tokens incl. GUARD_AREA, CRUSHER, C4, TIBERIUM_HEAL) | ts-core.md TS-CORE-033 | 18 tokens | ModEnc VeteranAbilities accepted-values table lists exactly those 18 (Ares ones separate); C4 works only in TS/FS | **confirmed** | modenc/VeteranAbilities | high |
| RA2 ineffective veteran abilities: C4, TIBERIUM_PROOF, VEIN_PROOF, TIBERIUM_HEAL | ra2-core.md RA2-CORE-014 | as written | ModEnc VeteranAbilities "Invalid or Ineffective Abilities in Red Alert 2" = C4, TIBERIUM_PROOF, VEIN_PROOF, TIBERIUM_HEAL | **confirmed** | modenc/VeteranAbilities | high |

---

## Corrections

1. **TS armor order — ModEnc self-contradiction (minor).** `ts-core.md` states the TS order as
   `none, wood, light, heavy, concrete`. ModEnc's `Armor_types` prose line reads
   "none, light, wood, heavy and concrete", but ModEnc's own `Verses` page labels the RA/TS
   example `; n , w , l , h , c`. The OpenTS `armor.hh` enum (`NONE=0, WOOD=1, ALUMINUM=2,
   STEEL=3, CONCRETE=4`) agrees with `ts-core.md`. Verdict: the research file is right; the
   ModEnc `Armor_types` prose ordering is the unreliable one.

### Additional verified rows (damage, timing, power, veterancy, registries)

| Claim | File/ID | Original | Verified | Verdict | Evidence URLs | Confidence |
|---|---|---|---|---|---|---|
| TS armor order `none,wood,light,heavy,concrete` (primary-source check) | ts-core.md TS-CORE-015/016 | n,w,l,h,c | Shipped TS `RULES.INI` `[Unit Statistics]` header comment: "Armor = the armor type of this object **[none,wood,light,heavy,concrete]**"; TS `Verses` samples are 5-tuples in that order (`SA=100,60,40,25,10`) | **confirmed** | raw TS RULES.INI (Vinifera-Developers/Tiberian-Sun-INIs) | high |
| RA2/YR damage = `Damage × Verses`; linear area falloff via `PercentAtMax` | ra2-core.md RA2-CORE-009 | `base = Damage × Verses/100`; `M = 1-(1-P)×(D/S)` | ModEnc PercentAtMax: exact formula `M = 1 - (1-P) × (D/S)`, "adjusted linearly"; ModEnc The_YR_Combat_System confirms Verses is the damage attenuator | **confirmed** | modenc/PercentAtMax, modenc/The_YR_Combat_System | high |
| `0 < Damage × Verses < 1` rounds down to 0 damage | ra2-core.md RA2-CORE-009 | as written | ModEnc Damage: "When 0 < Damage × Verses < 1, no actual damage will be dealt due to rounding down" | **confirmed** | modenc/Damage | high |
| RA2/YR `MaxDamage=10000`, `MinDamage=1` (obsolete) | ra2-core.md RA2-CORE-009/018 | MaxDamage 10000; MinDamage obsolete | YR `rulesmd.ini` `[CombatDamage]`: `MaxDamage=10000 ;gs from 1000`, `MinDamage=1 ;gs obsolete` | **confirmed** | raw YR rulesmd.ini | high |
| CellSpread hits multi-cell buildings per covered cell (3×3 → 9×) | ra2-core.md RA2-CORE-009 | as written | ModEnc The_YR_Combat_System reproduces the exact 3×3 = 900-damage example | **confirmed** | modenc/The_YR_Combat_System | high |
| Negative damage only affects same type; 8-lepton effective radius; strips parasites | ra2-core.md RA2-CORE-009; ts-core.md TS-CORE-020 | as written | ModEnc Damage Bugs: negative Damage affects only same type (until Ares 0.D), 8 leptons even with larger CellSpread, hardcoded parasite removal | **confirmed** | modenc/Damage | high |
| RA2/YR `1% Verses` disallows passive acquire and **retaliation** | ra2-core.md RA2-CORE-008 | "cannot passive-acquire, but will accept explicit order, force-fire, and retaliate" | ModEnc Verses says 1% allows order/force-fire/retaliate; ModEnc The_YR_Combat_System says 1% "disallows both passive acquiring and retaliation". Two ModEnc pages conflict | **conflict** (doc picked one of two disagreeing ModEnc pages) | modenc/Verses, modenc/The_YR_Combat_System | med |
| `ProneDamage` applies **after** `Verses` | ra2-core.md RA2-CORE-008 | flagged as uncertain conflict | ModEnc The_YR_Combat_System: "applied AFTER the Verses"; ModEnc ProneDamage page historically says before. The doc correctly flags this as an open conflict | **confirmed as a conflict** | modenc/The_YR_Combat_System | med |
| Game speed = 7 settings 0–6; SP caps 6=unlimited,5=60,4=30,3=20,2=15,1=12,0=10; MP caps 6=60,5=45,4=30,3=20,2=15,1=12,0=10 | ra2-core.md RA2-CORE-021 | exact lists | ModEnc Game Speed lists the identical SP and MP caps for TS and RA2 | **confirmed** | modenc/Game_Speed | high |
| Baseline 15 fps; 1 game second = 1 real second at 15 fps; 900 frames/minute | ts-core.md TS-CORE-039; ra2-core.md RA2-CORE-021 | 15/900/54000 | ModEnc Game Speed: "at a constant frame rate of 15, one game second equals one real-life second"; YR `SpyPowerBlackout=1000 ; (900 = 1 minute)` | **confirmed** | modenc/Game_Speed, raw YR rulesmd.ini | high |
| TS low-power: `MinProductionSpeed=0.5`; `DamageDelay=1` minute | ts-core.md TS-CORE-031 | as written | TS `RULES.INI` `[General]`: `MinProductionSpeed=.5`, `DamageDelay=1` | **confirmed** | raw TS RULES.INI | high |
| RA2/YR low-power: `MinLowPowerProductionSpeed=.5`, `MaxLowPowerProductionSpeed=.8`, `LowPowerPenaltyModifier=1`, `DamageDelay=1` | ra2-core.md RA2-CORE-013 | as written | YR `rulesmd.ini` `[General]` contains all four with those exact values | **confirmed** | raw YR rulesmd.ini | high |
| TS `WorstLowPowerBuildRateCoefficient`/`BestLowPowerBuildRateCoefficient` parsed but unused | ts-core.md TS-CORE-031 | parsed, never consulted | TS ships `.3`/`.75`; ModEnc has no page; the "unused" claim is OpenTS-reconstructed only | **unverifiable** (web) | raw TS RULES.INI | low |
| TS veteran factors: Ratio 10.0, Combat .25, Speed .30, Sight 0.0, Armor .25, ROF .20 | ts-core.md TS-CORE-032/034 | as written | TS `RULES.INI` `[General]` matches exactly | **confirmed** | raw TS RULES.INI | high |
| FS veteran factors: Ratio 5.0, Combat .50, Speed .30, Sight 0.0, Armor .50, ROF .30 | ts-core.md TS-CORE-032/034 | as written | FS `FIRESTRM.INI` `[General]` matches exactly | **confirmed** | raw FIRESTRM.INI | high |
| RA2/YR veteran factors: Ratio 3.0, Combat 1.1, Speed 1.2, Sight 0.0, Armor 1.5, ROF 0.6, Cap 2 | ra2-core.md RA2-CORE-014; yr-core.md YR-CORE-005 | as written | YR `rulesmd.ini` `[General]` matches exactly | **confirmed** | raw YR rulesmd.ini | high |
| `VeteranCap` engine default with no key = **1** | ts-core.md TS-CORE-032/038 | "Engine default with no key = 1 (so combat cannot reach elite)" | ModEnc VeteranCap: **Default: 2**; both TS and FS INIs explicitly set `VeteranCap=2` | **corrected** (ModEnc + shipped INI say 2; the "default 1" is at most an OpenTS code artifact) | modenc/VeteranCap, raw TS RULES.INI, raw FIRESTRM.INI | med |
| YR `DominatorDamage=1000`, `DominatorFireAtPercentage=20`, `DominatorCaptureRange=1` | yr-core.md YR-CORE-010/015 | as written | YR `rulesmd.ini` `[General]` matches; ModEnc DominatorCaptureRange: permanent MC, effective cap 11 cells, air unaffected | **confirmed** | raw YR rulesmd.ini, modenc/DominatorCaptureRange | high |
| `Type=PsychicDominator` will not capture buildings (hardcoded) | yr-core.md YR-CORE-009/010 | as written | ModEnc DominatorCaptureRange says units only; Ares docs describe vanilla as permanent, buildings excluded | **confirmed** | modenc/DominatorCaptureRange, Ares psychicdominator | high |
| TS `[Warheads]` registry = 24 entries | ts-core.md TS-CORE-021 | 24 numbered entries | Shipped TS `RULES.INI` `[Warheads]` = exactly 24 (`1=EMPuls` … `24=ORCAHE`); TS `Verses` values sampled match the doc | **confirmed** | raw TS RULES.INI | high |
| FS adds `WebMass`, `LIMPY` (and `CoreDefPlasmaWH`) to `[Warheads]` | ts-core.md TS-CORE-021 | WebMass, LIMPY enumerated; CoreDefPlasmaWH "not enumerated" | FS `FIRESTRM.INI` `[Warheads]` registry = 3 entries: `WebMass`, `LIMPY`, `CoreDefPlasmaWH`. FS WebMass `Verses=600%,0,0,0,0`, `WebDuration=600`; LIMPY `LimpetFactor=35`, `Verses=0,100,100,100,100` — all match the doc table | **confirmed** | raw FIRESTRM.INI | high |
| YR `[Warheads]` registry = 105 entries | ra2-core.md RA2-CORE-008/028 | "105 entries" | YR `rulesmd.ini` `[Warheads]` = exactly 105 (`1=EMPuls` … `105=BlimpHEEffect`); the doc's published list matches 1:1 | **confirmed** | raw YR rulesmd.ini | high |
| TS has **no** projectile registry (BulletType created on first use) | ts-core.md TS-CORE-022 | "There is no registry" | Shipped TS `RULES.INI` contains no `[Projectiles]` section; all ~21 projectile section names cited in the doc exist as sections | **confirmed** | raw TS RULES.INI | high |
| RA2/YR has **no** projectile registry; full stock set = 50 named sections | ra2-core.md RA2-CORE-010 | enumerated list | YR `rulesmd.ini` contains no `[Projectiles]` registry; all 50 projectile section names in the doc exist (spot-checked every listed name) | **confirmed** (list); **unverifiable** (whether the enumeration is literally exhaustive of every stock projectile) | raw YR rulesmd.ini | high / med |
| `[JumpjetControls] CloakDetectionRadius` "not present in the shipped `[JumpjetControls]` block" | ts-core.md TS-CORE-028 | default 0; absent from shipped block | Absent from base TS `RULES.INI`, but **present in `FIRESTRM.INI` `[JumpjetControls] CloakDetectionRadius=3`** | **corrected** (true for base TS, false for Firestorm) | raw TS RULES.INI, raw FIRESTRM.INI | high |

---

## Corrections

1. **TS armor order — ModEnc self-contradiction (resolved).** `ts-core.md` states the TS order as
   `none, wood, light, heavy, concrete`. ModEnc's `Armor_types` prose line reads
   "none, light, wood, heavy and concrete", but ModEnc's own `Verses` page labels the RA/TS
   example `; n , w , l , h , c`. The shipped `RULES.INI` `[Unit Statistics]` header comment
   settles it: `Armor = the armor type of this object [none,wood,light,heavy,concrete]`.
   Verdict: the research file is right; ModEnc `Armor_types` prose ordering is the unreliable one.

2. **`VeteranCap` "engine default 1" is wrong per web sources.** `ts-core.md` (TS-CORE-032,
   TS-CORE-038) claims the no-key engine default is 1 and that combat therefore can't reach elite.
   ModEnc documents the default as **2**, and both shipped TS and FS INIs explicitly set
   `VeteranCap=2`. Either the research captured an OpenTS-internal code default, or it is a plain
   error. Treat "default 1" as unverified; use 2 unless the reimplementation can show the
   original engine's unset-key behavior.

3. **FS `[JumpjetControls]` does carry `CloakDetectionRadius`.** `ts-core.md` TS-CORE-028 says the
   key is absent from the shipped block and defaults to 0. That holds for base TS, but
   `FIRESTRM.INI` sets `CloakDetectionRadius=3`. Add the FS value.

4. **FS `[Warheads]` registry is 3, not "WebMass/LIMPY".** The FS file registers exactly
   `WebMass`, `LIMPY`, and `CoreDefPlasmaWH`; `ts-core.md` states the first two and defers the
   third. The count for TS+FS registered warheads is 24 (base) + 3 (FS) = 27.

5. **RA2/YR `1% Verses` retaliation wording is a two-page ModEnc conflict, not a settled fact.**
   `ModEnc/Verses` (2025) says 1% still allows retaliation; `ModEnc/The_YR_Combat_System` says it
   disallows retaliation. `ra2-core.md` presents the first as fact without noting the second.
   Flag the nuance rather than asserting one.

---

## Unresolved / Not Verified in this pass

1. **OpenTS-reconstructed internals.** TS-CORE-014 (exact damage sequence), TS-CORE-018
   (Spread/falloff thresholds), TS-CORE-033 ("first 127 characters parsed"), TS-CORE-031
   (Worst/Best low-power coefficients "never consulted"), TS-CORE-039 (`TICKS_PER_SECOND=15`
   constant name) rest on the OpenTS reconstruction and/or OpenTS manual, not on any independent
   web source. Web-primary checks (MaxDamage/MinDamage, 0<DV<1→0, negative-damage behavior)
   corroborate the *outcomes* but not the *step order*.
2. **RA2 (non-YR) registry counts.** The 105-entry `[Warheads]` and 50-projectile claims were
   checked against YR `rulesmd.ini` (the RA2+Yuri superset). A clean RA2 `rules.ini` (no Yuri
   warheads) was not separately enumerated, so the "RA2" counts could be slightly lower.
3. **ProneDamage order vs Verses** — remains a genuine ModEnc internal conflict (Verses page vs
   YR Combat System page). No tie-breaker found.
4. **TS `Verses` editability nuance.** Confirmed editable (rules.ini flag) and confirmed the
   0%/1% special targeting semantics are RA2/YR-only. The exact TS `heavy=0%` passive-acquire
   behavior is documented single-source (ModEnc) — not independently reproduced.
5. **`CoreDefPlasmaWH` details** remain un-enumerated in `ts-core.md`; the FS registry confirms
   it exists but not its values.
6. **Height-level lepton quantization (RA2-CORE-002 open question)** untouched; no web source
   located in this pass.
