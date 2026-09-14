# Yuri's Revenge — Gameplay Content & Rosters (Deep Research, Delta vs Red Alert 2)

Research-only reference for the unified Redot engine (Tiberian Sun / Firestorm / RA2 / YR).
Primary game: **Command & Conquer: Red Alert 2 – Yuri's Revenge (2001, Westwood Pacific / EA)**.
This document is a **delta** reference: it enumerates everything YR adds or changes relative to RA2.
The RA2 baseline lives in `ra2-gameplay.md` and `ra2-core.md`; do not duplicate it here except where YR mutates it.

## Method & Confidence

* **Web only.** No game files on this machine were read. Primary sources: a web mirror of the retail
  `rulesmd.ini`, ModEnc flag pages, cnc.fandom.com unit/structure/mission pages, CNCNZ.com YR arsenal
  pages, CnCNet/Project Perfect Mod discussions, and the Mental Omega wiki (used only for cross-checks).
* **Cross-check rule.** Every numeric claim is attested by ≥2 independent sources where possible;
  single-source numbers are flagged in **Confidence** / **Edge cases**.
* **Conflict policy.** Where sources disagree, all values are listed in **Numbers**, with a note.
  The retail `rulesmd.ini` mirror is treated as the tie-breaker for numeric values, because it is the
  shipped game data (it carries Westwood developer comments such as `GEF`/`SJM`/`gs`).
* **No code / no INI dumps.** Section names and keys are named in prose and tables; nothing is pasted.

### Source key

| Tag | Source |
|-----|--------|
| RULES-MIRROR | `raw.githubusercontent.com/hzhangxyz/rulesmd.ini/master/rulesmd.ini` — retail YR `rulesmd.ini` mirror (web, not local). Tie-breaker for numbers. |
| MODENC | `modenc.renegadeprojects.com` (GameModes, Secret Lab System, Theater, Theaters, Bunkers, Rules.ini, flag pages) |
| FANDOM | `cnc.fandom.com/wiki/...` (YR page, unit/building/mission pages, Tech secret lab, Cosmonaut, Yuri faction) |
| CNC-CENTRAL | `cnc-central.fandom.com/wiki/...` (mirror of FANDOM; used for availability cross-check) |
| CNCNZ | `cncnz.com/games/yuris-revenge/*` (Yuri's units, Yuri's structures, new Allied/Soviet units, new tech buildings) |
| MOAPYR | `moapyr.fandom.com/wiki/...` (Mental Omega "YR Comparison" pages; cross-check only) |
| CNC-NET | `forums.cncnet.org`, `forums.cncnz.com` (mechanics threads, Secret Lab keys) |

### Internal-id conventions

* Side ids: `GDI` = Allies, `Nod` = Soviets, `ThirdSide` = Yuri (`YuriCountry`).
* YR id prefixes: `YA…` = Yuri structures; `Y…` = Yuri units; `NA…` = Soviet; `GA…`/`CA…` = Allied/neutral.
* `armor=` classes seen: `none`, `plate`, `flak`, `light`, `medium`, `heavy`, `wood`, `steel`, `concrete`.
* `Strength=` is hit points (HP). `Cost=` is credits. `Prerequisite=` lists internal building ids.

---

## 1. Side / faction model (YR change)

### YR-GP-001 ThirdSide (Yuri) faction

**What.** YR adds the first fully distinct third faction in C&C. In the side list, Yuri is a single
country (`YuriCountry`) belonging to the new `ThirdSide`. Allies keep the `GDI` side group
(Americans, Alliance/Korea, French, Germans, British); Soviets keep `Nod` (Russians, Africans/Libya,
Confederation/Cuba, Arabs/Iraq). `Civilian` and `Mutant` remain non-playable.

**Data keys.** `[Sides]` (side→country map), `[Countries]` (index→country), `[InfantryTypes]`,
`[VehicleTypes]`, `[AircraftTypes]`, `[BuildingTypes]`, `[SuperWeaponTypes]`, per-object `Owner=`,
`RequiredHouses=`, `ForbiddenHouses=`, `SecretHouses=`.

**Numbers.** Country index 9 = `YuriCountry`; `ThirdSide=YuriCountry`. `YuriCountry` is folded into the
`Owner=` list of most *neutral* and some dual-purpose objects (e.g. it can capture/own Tech structures),
but Yuri-specific objects use `Owner=YuriCountry` only.

**Edge cases.** Yuri is not a house that can be re-skinned into an Allied/Soviet country; ThirdSide has
its own base-defense AI profile (`AIBasePlanningSide=2`) and its own base-defense count
(`ThirdBaseDefenseCounts`). Yuri has **no** country-specific sub-units — the whole faction is the
"country bonus".

**Kind.** Faction model.
**Sources.** RULES-MIRROR `[Sides]`/`[Countries]`; FANDOM "Yuri (faction)".
**Confidence.** high.

---

## 2. FULL Yuri faction

### 2.1 Structures

| Name | Internal id | Cost | Armor | Prereq | Weapon(s)/Warhead | Role | Notable logic |
|------|-------------|------|-------|--------|-------------------|------|---------------|
| Yuri Construction Yard | YACNST | 3000 (from MCV) | concrete | none | – | Base core | Deploys from PCV; Power 0; `ConstructionYard=yes`; capturable |
| Bio Reactor | YAPOWR | 600 | wood | YACNST | – | Power | +150 power; `Passengers=5` each adds `ExtraPower=100`; infantry absorb |
| Yuri Barracks | YABRCK | 500 | steel | POWER + YACNST | – | Infantry production | `YuriBarracks=yes`; Power −10 |
| Yuri Ore Refinery (deployed Slave Miner) | YAREFN | 1500 | medium | POWER + YACNST | 20mmRapid / HARVWH | Resource | `UndeploysInto=SMIN`; `Enslaves=SLAV`; `SlavesNumber=5`; Storage 200 |
| Yuri War Factory | YAWEAP | 2000 | wood | PROC + YABRCK + YACNST | – | Vehicle production | `WeaponsFactory=yes`; also makes Floating Disc; Power −25 |
| Yuri Submarine Pen | YAYARD | 1000 | concrete | YACNST + POWER + PROC | – | Naval production/repair | `Naval=yes`, `WaterBound=yes`, `UnitRepair=yes`, `NumberOfDocks=1`; Power −25 |
| Psychic Radar | NAPSIS | 1000 | wood | YACNST + PROC | – | Radar + detection | `Radar=yes`, `PsychicDetectionRadius=15`, `SensorArray`, `DetectDisguise`; grants Psychic Reveal; Power −50 |
| Grinder | YAGRND | 600 | wood | YAWEAP + YACNST | – | Recycling econ | `Grinding=yes`; refunds units; Power −50; not capturable |
| Battle Lab | YATECH | 2000 | wood | YAWEAP + YACNST + RADAR | – | Tech unlock | `SuperWeapon=ForceShieldSpecial`; Power −100 |
| Citadel Wall | GAFWLL | 100 | concrete | YABRCK | – | Wall | `Wall=yes`; Strength 300; `Adjacent=8` |
| Tank Bunker | NATBNK | 400 | steel | YACNST | – | Vehicle garrison | `Bunker=yes`, `NumberOfDocks=1`; holds one turreted non-artillery vehicle; Power 0 |
| Gattling Cannon | YAGGUN | 1000 | steel | BARRACKS + YACNST | AGGattling/AAGattCann (3-stage) | Anti-air/anti-infantry defense | `IsGattling=yes`; Powered; Power −50 |
| Psychic Tower | YAPSYT | 1500 | steel | NAPSIS + YACNST | MultipleMindControlTower / Controller | Mind-control defense | Controls up to 3 units; `PipScale=MindControl`; Power −100 |
| Cloning Vats | NACLON | 2500 | wood | YATECH + YACNST | – | Infantry duplication | `Cloning=yes`; `BuildLimit=1`; Power −200 |
| Genetic Mutator | YAGNTC | 2500 | concrete | YATECH + YACNST | SuperWeapon=GeneticConverterSpecial | Superweapon | `BuildLimit=1`; `RevealToAll=yes`; Power −200 |
| Psychic Dominator | YAPPET | 5000 | concrete | YATECH + YACNST | SuperWeapon=PsychicDominatorSpecial | Superweapon | `BuildLimit=1`; Power −200 |
| Psychic Beacon (campaign) | NAPSYA/NAPSYB | n/a | – | – | – | Scripted control | Campaign-only; mind-controls a whole base until destroyed |
| Yuri Command Center (campaign) | YACOMD | 3000 | concrete | – | – | Scripted base | Campaign/story structure; not a real ConYard (`ConstructionYard` commented out) |
| Yuri Rocket Launch Pad (campaign) | YAROCK | 600 | wood | – | – | Moon launch | Campaign-only; no power output |

**Blocks.**

### YR-GP-010 Yuri Construction Yard (YACNST)

**What.** Yuri's MCV deployment target and base root; functionally identical to Allied/Soviet ConYards.
**Data keys.** `ConstructionYard`, `UndeploysInto=PCV`, `Factory=BuildingType`, `ProtectWithWall`.
**Numbers.** Cost 3000 (via PCV), HP 1000, armor concrete, Power 0, Sight 10.
**Edge cases.** `ImmuneToPsionics=no` (default for buildings is yes; this is explicitly not immune).
**Kind.** Structure.
**Sources.** RULES-MIRROR `[YACNST]`, `[PCV]`; FANDOM "Yuri construction yard".
**Confidence.** high.

### YR-GP-011 Bio Reactor (YAPOWR)

**What.** Yuri's sole power plant. Instead of a Tesla reactor/nuclear reactor it burns "bio" power and
can hold **five infantry**, each raising output. It also acts as a disposal/siphon for mind-controlled
units the AI does not want to keep.
**Data keys.** `Power`, `ExtraPower`, `Passengers`, `PipScale`, `InfantryAbsorb`, `UnitAbsorb`,
`Drainable`, `PoweredSpecial`, `Capturable`.
**Numbers.** Cost 600, HP 700, armor wood, base Power +150, `ExtraPower=100` per garrisoned infantry,
5 slots, `SizeLimit=15`.
**Edge cases.** A mind-controlled infantry placed in a reactor returns to its original owner if the
controlling unit/structure dies (the control link is what holds it, not the reactor). `Drainable=yes`
means it can be drained by a Floating Disc. The AI sends captured infantry here per
`AICaptureLowPower`/`AICaptureNormal`.
**Kind.** Structure / power / economy-sink.
**Sources.** RULES-MIRROR `[YAPOWR]`; CNCNZ "Yuri's structures"; FANDOM "Bio reactor".
**Confidence.** high.

### YR-GP-012 Yuri Barracks (YABRCK)

**What.** Yuri infantry production. Also a prerequisite for Gattling Cannon, and one of the two
"barracks categories" that let the `YuriBarracks` production flag work.
**Data keys.** `Factory=InfantryType`, `YuriBarracks`, `Prerequisite`, `Power`.
**Numbers.** Cost 500, HP 500, armor steel, Power −10, TechLevel 2.
**Edge cases.** The global prereq category `PrerequisiteBarracks` = NAHAND, GAPILE, YABRCK, so objects
that list "BARRACKS" accept any of the three.
**Kind.** Structure / production.
**Sources.** RULES-MIRROR `[YABRCK]`; CNCNZ.
**Confidence.** high.

### YR-GP-013 Slave Miner / Yuri Ore Refinery (SMIN / YAREFN)

**What.** Yuri's harvester is a **mobile refinery**. The Slave Miner drives to ore, deploys into the Yuri
Ore Refinery, and releases up to **five free Slaves** that mine with shovels. When mobile, damaged Slave
Miners self-repair; when deployed, send an Engineer in to repair the refinery. Built from both the
Construction Yard and the War Factory.
**Data keys.** `DeploysInto=YAREFN` (SMIN) / `UndeploysInto=SMIN` (YAREFN), `Enslaves=SLAV`,
`SlavesNumber=5`, `SlaveRegenRate=500`, `SlaveReloadRate=25`, `Harvester=yes`, `Storage`, `SelfHealing`,
`ImmuneToPsionics`, `ImmuneToRadiation`, `ResourceGatherer`, `ResourceDestination`,
`UndeploysInto`, `DeployFacing`, `ClickRepairable=no` (SMIN), `Unsellable=yes`.
**Numbers.** Cost 1500 (mobile) — see conflict; HP 2000; armor medium; Sight 4; Speed 3; SMIN Storage 20,
YAREFN Storage 200; `SlavesNumber=5`; `Harvester=` yield. **Conflict:** CNCNZ lists the Slave Miner at
$1750; RULES-MIRROR lists 1500. The retail-id mirror value (1500) is used here.
**Edge cases.** If the Slave Miner is destroyed, surviving Slaves join their "liberators" (the killer's
side) as weak melee units, or go neutral if the owner surrendered. Slaves are not directly
controllable. Because Slave Miner is listed in `HarvesterUnit` as `CMIN` (the Allied/Soviet chrono miner
id) and the AI `AISlaveMinerNumber` controls its count, the AI budgets Slave Miners separately from
refineries. Ore is still processed at the mobile refinery (it is both harvester and refinery).
**Kind.** Vehicle/structure, economy.
**Sources.** RULES-MIRROR `[SMIN]`/`[YAREFN]`; CNCNZ "Yuri's units"/"Yuri's structures"; FANDOM "Slave miner".
**Confidence.** high on mechanics; med on cost (conflict).

### YR-GP-014 Yuri War Factory (YAWEAP)

**What.** Vehicle production; uniquely also produces the air unit Floating Disc (Yuri has no airfield).
**Data keys.** `WeaponsFactory`, `Factory=UnitType`, `NumberImpassableRows=1`.
**Numbers.** Cost 2000, HP 1000, armor wood, Power −25, TechLevel 2.
**Edge cases.** Axis-aligned exit only; `ExitCoord=512,256,0`. Because Yuri has no separate helipad, the
Disc rolls out of the War Factory.
**Kind.** Structure / production.
**Sources.** RULES-MIRROR `[YAWEAP]`; CNCNZ.
**Confidence.** high.

### YR-GP-015 Yuri Submarine Pen (YAYARD)

**What.** Yuri's naval yard. Builds and repairs Amphibious Transport and Boomer.
**Data keys.** `Naval`, `WaterBound`, `WeaponsFactory`, `UnitRepair`, `NumberOfDocks=1`.
**Numbers.** Cost 1000, HP 1500, armor concrete, Power −25, TechLevel 4.
**Edge cases.** Must be placed entirely on water; `NumberOfDocks=1` serializes docking/repair.
**Kind.** Structure / naval production.
**Sources.** RULES-MIRROR `[YAYARD]`; CNCNZ; FANDOM "Submarine pen".
**Confidence.** high.

### YR-GP-016 Psychic Radar (NAPSIS)

**What.** Yuri's radar-equivalent, repurposed from the RA2 **Soviet Psychic Sensor**. It shows enemy
attack orders within a radius, detects disguised units, is a sensor array, and charges the Psychic
Reveal support power. It is also the prerequisite for Yuri Clone and Psychic Tower.
**Data keys.** `Radar`, `PsychicDetectionRadius`, `SensorArray`, `DetectDisguise`,
`DetectDisguiseRange`, `HasRadialIndicator`, `ConcentricRadialIndicator`,
`SuperWeapon=PsychicRevealSpecial`.
**Numbers.** Cost 1000, HP 750, armor wood, Power −50, `PsychicDetectionRadius=15`,
`DetectDisguiseRange=15`, SensorsSight 15.
**Edge cases.** Shows enemy targeting lines, not just stealth. In RA2 the Soviet Psychic Sensor existed;
in YR it is removed from the Soviets and becomes this Yuri radar.
**Kind.** Structure / support / detection.
**Sources.** RULES-MIRROR `[NAPSIS]`; CNCNZ; FANDOM "Psychic radar".
**Confidence.** high.

### YR-GP-017 Grinder (YAGRND)

**What.** Yuri recycling structure. Any ground unit under Yuri's control (including mind-controlled
enemies) driven into it is destroyed and partially refunded; infantry refund is reduced because of the
Cloning Vats. The AI sends unwanted captures here.
**Data keys.** `Grinding`, `CreateUnitSound`, `Capturable=false`.
**Numbers.** Cost 600 (RULES-MIRROR; CNCNZ says $1000 — mirror wins), HP 900, armor wood, Power −50,
TechLevel 9. Refund: **vehicles 100%**, **infantry 50%** of build cost.
**Edge cases.** Anything with no cost (Slaves, free units) refunds nothing meaningful. Sending a loaded
transport's cargo to the Grinder is the standard way to dispose of mind-controlled passengers. Mind
control link loss on grinder entry destroys the controlled unit.
**Kind.** Structure / economy.
**Sources.** RULES-MIRROR `[YAGRND]`; FANDOM "Grinder (Yuri's Revenge)"; Baidu Baike (refund split);
CNCNZ (conflicting cost).
**Confidence.** high on mechanics; med on refund split (2 community sources, not direct data); med on cost.

### YR-GP-018 Battle Lab (YATECH)

**What.** Yuri tech building. Unlocks Yuri Prime, Magnetron/Mastermind/Floating Disc, Cloning Vats,
Genetic Mutator, Psychic Dominator, and (globally) the Force Shield.
**Data keys.** `SuperWeapon=ForceShieldSpecial`, `ProtectWithWall`.
**Numbers.** Cost 2000, HP 500, armor wood, Power −100, TechLevel 8.
**Edge cases.** Force Shield is granted to **all** sides by *their* Battle Lab; Yuri's Battle Lab lists
the same superweapon id.
**Kind.** Structure / tech.
**Sources.** RULES-MIRROR `[YATECH]`; CNCNZ; FANDOM "Yuri battle lab".
**Confidence.** high.

### YR-GP-019 Citadel Wall (GAFWLL)

**What.** Yuri's wall, misleadingly using the temp internal id `GAFWLL`. Named Citadel Wall.
**Data keys.** `Wall=yes`, `Adjacent=8`.
**Numbers.** Cost 100, HP 300, armor concrete, TechLevel 2.
**Edge cases.** `Selectable=no` is per-section in the data but walls are selectable as a group in play;
four wall segments can be dragged near an existing segment.
**Kind.** Structure / defense.
**Sources.** RULES-MIRROR `[GAFWLL]`; FANDOM "Fortress walls".
**Confidence.** high.

### YR-GP-020 Tank Bunker (NATBNK)

**What.** Yuri's garrisonable bunker for **vehicles**. One turreted, non-artillery vehicle can enter and
fire with bonuses; the vehicle is immobilized. This is the Yuri twin of the Soviet Battle Bunker
(`NABNKR`, infantry only). Yuri's is named "Tank Bunker" despite the shared `NATBNK` id with RA2's
neutral/unused entry.
**Data keys.** `Bunker=yes`, `NumberOfDocks=1`, `NumberImpassableRows=0`, `Powered=false`.
Global bunker bonuses: `BunkerDamageMultiplier=1.3`, `BunkerROFMultiplier=1.3`,
`BunkerWeaponRangeBonus=2`.
**Numbers.** Cost 400, HP 1000, armor steel, Power 0, TechLevel 3.
**Edge cases.** Only one occupant. Artillery/turretless vehicles cannot enter. Damage can penetrate to
the vehicle based on `PenetratesBunker`.
**Kind.** Structure / defense / garrison.
**Sources.** RULES-MIRROR `[NATBNK]`, bunker globals; FANDOM "Tank bunker"; MODENC "Bunkers".
**Confidence.** high.

### YR-GP-021 Gattling Cannon (YAGGUN)

**What.** Yuri base defense with a spin-up gattling gun that hits ground and air, rising through three
fire stages.
**Data keys.** `IsGattling=yes`, `WeaponStages=3`, `Stage1/2/3`, `EliteStage1/2/3`, `RateUp=1`,
`RateDown=50`, `Weapon1..6`, `AntiInfantryValue`, `AntiArmorValue`, `AntiAirValue`, `Powered`.
**Numbers.** Cost 1000, HP 810, armor steel, Power −50, TechLevel 4, Sight 10, `ROT=10`.
Weapons: stage 1 `AGGattling` 25 dmg / `AAGattCann` 30 dmg; stage 2 `AGGattling2` 25 /
`AAGattCann2` 30; stage 3 `AGGattling3` 25 / `AAGattCann3` 30. (`AAGattling2/3` 30/40 are the *tank*
AA values.)
**Edge cases.** Powered: goes offline without power. Speed-up is per-target; losing the target rotates
the timer down at `RateDown=50` frames, so it decays slowly rather than instantly.
**Kind.** Structure / base defense.
**Sources.** RULES-MIRROR `[YAGGUN]`, `[AGGattling*]`, `[AAGattCann*]`; FANDOM "Gattling cannon (Yuri's Revenge)".
**Confidence.** high.

### YR-GP-022 Psychic Tower (YAPSYT)

**What.** Mind-control defense. Automatically captures up to three enemy units entering range; once
full it has no weapon and can be attacked freely.
**Data keys.** `MultipleMindControlTower` (range 7, `Controller` warhead), `PipScale=MindControl`,
`PipsDrawForAll`, `Powered`, `Drainable`.
**Numbers.** Cost 1500, HP 455, armor steel, Power −100, TechLevel 7.
**Edge cases.** Powered: releases all controlled units if it loses power or dies. Yuri's AI can direct
captured units to the Grinder/Bio Reactor. Cannot capture aircraft, dogs, miners, or mind-control-immune
units.
**Kind.** Structure / base defense.
**Sources.** RULES-MIRROR `[YAPSYT]`, `[MultipleMindControlTower]`; FANDOM "Psychic tower".
**Confidence.** high.

### YR-GP-023 Cloning Vats (NACLON)

**What.** Duplicates every infantry produced by a Yuri Barracks at no extra cost. In RA2 this was a
**Soviet** building (also able to recycle infantry); in YR it moves to Yuri, and the recycling function
moves to the Grinder. One per player.
**Data keys.** `Cloning=yes`, `YuriBarracks`, `BuildLimit=1`, `CreateUnitSound`.
**Numbers.** Cost 2500, HP 1000, armor wood, Power −200, TechLevel 9.
**Edge cases.** Does not duplicate; it spawns a free copy at the barracks exit. Because Yuri's entry has
no recycle flag, the Grinder is the sole refund path. `BuildLimit=1` is enforced per player.
**Kind.** Structure / economy / production modifier.
**Sources.** RULES-MIRROR `[NACLON]`; FANDOM "Cloning vat"; CNC-CENTRAL (Soviet RA2-only note).
**Confidence.** high.

### YR-GP-024 Genetic Mutator (YAGNTC)

**What.** Yuri superweapon that converts all infantry in a target area into player-controlled Brutes;
animals are simply killed.
**Data keys.** `SuperWeapon=GeneticConverterSpecial`, `BuildLimit=1`, `RevealToAll`, `ChargedAnimTime`.
Global controls: `MutateExplosion=yes`, `MutateWarhead=Mutate`, `MutateExplosionWarhead=MutateExplosion`,
`AnimToInfantry=BRUTE`.
**Numbers.** Cost 2500, HP 1000, armor concrete, Power −200, TechLevel 10; recharge 5 min; range 5.
`MutateExplosion=yes` means it uses the explosion warhead instead of a fixed 3×3 area.
**Edge cases.** Affects friendly infantry too. Works on Slaves (a common combo: mutate slaves → Brutes →
Grinder). Brutes produced count as the Mutator owner. Cannot affect non-infantry.
**Kind.** Structure / superweapon.
**Sources.** RULES-MIRROR `[YAGNTC]`, `[GeneticConverterSpecial]`, `[General]`; CNCNZ; FANDOM "Genetic mutator".
**Confidence.** high.

### YR-GP-025 Psychic Dominator (YAPPET)

**What.** Yuri's ultimate superweapon. Fires a psychic burst that mind-controls all units in the area,
damages nearby structures heavily, and permanently converts the captured units.
**Data keys.** `SuperWeapon=PsychicDominatorSpecial`, `BuildLimit=1`, `RevealToAll`. Global:
`DominatorWarhead`, `DominatorDamage`, `DominatorCaptureRange`, `DominatorFirstAnim`,
`DominatorSecondAnim`, `DominatorFireAtPercentage`.
**Numbers.** Cost 5000, HP 1000, armor concrete, Power −200, TechLevel 10; recharge 10 min; range 1.4
cells (targeting ring). `DominatorDamage=1000`; `DominatorCaptureRange=1`.
**Edge cases.** Units immune to mind control (dogs, robot tanks, miners, other MC units) are unaffected;
garrisoned units are immune. Unlike Psychic Tower control, a Dominator capture is **permanent** and
cannot be released or re-controlled. The structure named `PsychicDominatorSpecial` internally carries
the display name "Lightning Storm" (a Westwood copy-paste bug) — cosmetic only.
**Kind.** Structure / superweapon.
**Sources.** RULES-MIRROR `[YAPPET]`/`[PsychicDominatorSpecial]`, `[General]`; CNCNZ; FANDOM "Psychic dominator".
**Confidence.** high.

### YR-GP-026 Psychic Beacon (campaign)

**What.** A campaign-only building that mind-controls an entire pre-placed base until destroyed. Used in
the Soviet final mission (Transylvania) to hold one Allied and one Soviet base, and in other scripted
maps.
**Data keys.** Building types `NAPSYA`/`NAPSYB`; trigger-driven control.
**Numbers.** Not buildable; stats are map-defined. Destroying the beacon frees its base.
**Edge cases.** In Head Games there are exactly two beacons (one per captured base); destroying them
frees the respective faction. They are heavily defended by the controlled bases.
**Kind.** Campaign structure / scripted logic.
**Sources.** FANDOM "Psychic beacon"; FANDOM "Head Games".
**Confidence.** med (single authoritative source for specifics).

### YR-GP-027 Yuri Command Center / Rocket Launch Pad (campaign)

**What.** Campaign/scenario buildings. `YACOMD` (Yuri Command Center) is a scripted base structure used
in YR Yuri-allied coop/campaign maps; `YAROCK` (Rocket Launch Pad) launches the Soviet lunar expedition.
Neither is player-buildable.
**Data keys.** `YACOMD` (no `ConstructionYard`, no `Factory`); `YAROCK` (no Power listed).
**Numbers.** `YACOMD` cost 3000 (editor), HP 1000, concrete; `YAROCK` cost 600, HP 700, wood.
**Edge cases.** `YAROCK` is decorative/scripted — it has no working superweapon; the Moon mission
transition is trigger-driven.
**Kind.** Campaign structures.
**Sources.** RULES-MIRROR `[YACOMD]`/`[YAROCK]`; FANDOM "To the Moon".
**Confidence.** med.

### 2.2 Yuri infantry

| Name | Internal id | Cost | Armor | Prereq | Weapon(s)/Warhead | Role | Notable logic |
|------|-------------|------|-------|--------|-------------------|------|---------------|
| Initiate | INIT | 200 | none | YABRCK | PsychicJab / SAFlame (occupy: UCPsychicJab / SSABFlame) | Basic infantry | IFVMode 13; garrisons UC; `UseOwnName=true` |
| Engineer | YENGINEER | 500 | none | Barracks | DefuseKit, capture | Capture/repair | Standard engineer kit; `ForbiddenHouses` = all non-Yuri |
| Brute | BRUTE | 500 | plate | YABRCK | Punch / Battering; Smash / Smashing | Melee anti-armor | Untrainable, uncrushable, self-healing, immune psionics; Size 2 |
| Virus | VIRUS | 700 | none | YABRCK + RADAR | Virusgun / Virus | Anti-infantry sniper | Poison cloud persists; immune to own gas; IFVMode 14 |
| Yuri Clone | YURI | 800 | none | YABRCK + NAPSIS | MindControl / Controller; PsiWave / PsiPulse | Mind control | Deployer (PsiWave), `SecretHouses=YuriCountry`; IFVMode 8 |
| Yuri Prime | YURIPR | 1500 | flak | YABRCK + YATECH | SuperMindControl / ControllerBuilding; SuperPsiWave / SuperPsiPulse | Hero / mind control | BuildLimit 1; amphibious; self-heal; immune psionics; deploys; IFVMode 15 |
| Slave | SLAV | 10 (free) | none | Slave Miner | SHOVEL | Miner (forced) | `Slaved=yes`, Storage 4, HarvestRate 150; uncontrollable; not selectable |
| Cosmonaut (campaign) | LUNR | 600 | none | none (map-granted) | Lunarlaser / LUNARWH | Lunar flying infantry | Jumpjet like Rocketeer; Moon mission only; Soviet-owned id but also usable by Yuri |
| Yuri Attack Dog | YDOG / YADOG | 200 | none | NAHAND / GAPILE | GoodTeeth/BadTeeth + VirtualScanner | Anti-infantry scout | Yuri-specific dog; `RequiredHouses=YuriCountry` |

**Blocks.**

### YR-GP-040 Initiate (INIT)

**What.** Yuri's basic infantry. Attacks with a short-range psychic bolt; extremely strong vs infantry,
weak vs armor/buildings. Can garrison civilian/UC structures.
**Data keys.** `Primary=PsychicJab`, `OccupyWeapon=UCPsychicJab`, `EliteOccupyWeapon=UCElitePsychicJab`,
`Occupier=yes`, `IFVMode=13`, `UseOwnName`.
**Numbers.** Cost 200, HP 100, armor none, TechLevel 1, Sight 9, Speed 4, range 4.5, ROF 15, damage 25
(`SAFlame`); occupied fire `UCPsychicJab` 63 dmg (`SSABFlame`).
**Edge cases.** The flame warheads are why Initiates can hit structures from garrison and why they
ignite infantry; the "combust" visual is the SAFlame warhead, not a script.
**Kind.** Infantry.
**Sources.** RULES-MIRROR `[INIT]`, `[PsychicJab]`, `[UCPsychicJab]`; CNCNZ.
**Confidence.** high.

### YR-GP-041 Yuri Engineer (YENGINEER)

**What.** Yuri's engineer. Same capture/repair/defuse kit as the other factions; only the voice set and
ownership differ (`ForbiddenHouses` blocks the other sides).
**Data keys.** `Engineer=yes`, `Primary=DefuseKit`, `Secondary=VirtualScanner`, `IFVMode=1`.
**Numbers.** Cost 500, HP 75, armor none, TechLevel 1, Speed 4, Sight 4.
**Edge cases.** Can repair/steal buildings, repair bridges via bridge huts, defuse Crazy Ivan bombs
(consumed on capture/repair, not on defuse).
**Kind.** Infantry.
**Sources.** RULES-MIRROR `[YENGINEER]`; CNCNZ.
**Confidence.** high.

### YR-GP-042 Brute (BRUTE)

**What.** Genetically engineered melee anti-armor infantry. Immune to dogs (dogs avoid it) and mind
control; self-heals; cannot be crushed by vehicles.
**Data keys.** `Primary=Punch`/`Battering`, `Secondary=Smash`/`Smashing`, `Crushable=no`,
`Unnatural`, `SelfHealing`, `ImmuneToPsionics`, `CloseRange`, `DefaultToGuardArea`, `GuardRange=2`,
`Size=2`.
**Numbers.** Cost 500, HP 200, armor plate, TechLevel 5, Sight 8, Speed 6, Punch range 1.4 / 100 dmg
`Battering`, Smash range 1.1 / 100 dmg `Smashing`.
**Edge cases.** Cannot fire from a Battle Fortress (`FireInTransport=no`), and its `Size=2` makes it too
big for an IFV. Weak in practice because it must close to melee under fire. Virus's gas does not affect
it (it is `Unnatural`/immune) — verify on encounter.
**Kind.** Infantry.
**Sources.** RULES-MIRROR `[BRUTE]`, `[Punch]`, `[Smash]`; CNCNZ; FANDOM "Brute".
**Confidence.** high.

### YR-GP-043 Virus (VIRUS)

**What.** Yuri's anti-infantry sniper. Every kill leaves a lingering poison cloud that damages other
infantry walking through it; Virus herself is immune.
**Data keys.** `Primary=Virusgun` / `Virus` warhead, `VirusgunE` for elite, `RevealOnFire=no`,
`ImmuneToPoison=yes`, `IFVMode=14`.
**Numbers.** Cost 700, HP 100, armor none, TechLevel 1, Sight 9, Speed 4, range 10, ROF 100, damage 125;
elite range 16, ROF 80.
**Edge cases.** `RevealOnFire=no` means firing does not clear the shroud. The gas is a warhead-created
area effect, so the residue damages friendly infantry too unless immune.
**Kind.** Infantry.
**Sources.** RULES-MIRROR `[VIRUS]`, `[Virusgun]`; CNCNZ; FANDOM "Virus".
**Confidence.** high.

### YR-GP-044 Yuri Clone (YURI)

**What.** Basic mind-control infantry (the YR successor to the RA2 Soviet Psi-Corps trooper / "Yuri").
Controls one organic unit/vehicle; if killed, control breaks. Can deploy a PsiWave that kills surrounding
infantry (friend or foe). Detects disguises.
**Data keys.** `Primary=MindControl` (`Controller`, range 7, `FireOnce`), `Secondary=PsiWave`
(`PsiPulse`, range 1, area fire, `FireOnce`), `Deployer=yes`, `UndeployDelay=150`,
`PrerequisiteOverride=CARUS03` (Kremlin Palace campaign), `SecretHouses=YuriCountry`,
`DetectDisguise=yes`, `IFVMode=8`.
**Numbers.** Cost 800, HP 100, armor none, TechLevel 10, Sight 12, Speed 4, `LeadershipRating=8`.
**Edge cases.** Cannot control miners, dogs, aircraft, or other MC units. PsiWave damages friendly
infantry standing next to the Clone. In campaign, available for all sides via the Kremlin Palace. In YR,
Yuri Clone was moved from the Soviet tech tree to Yuri; the old Soviet `Psi-Corps trooper` is gone.
**Kind.** Infantry / mind control.
**Sources.** RULES-MIRROR `[YURI]`, `[MindControl]`, `[PsiWave]`; CNCNZ; FANDOM "Yuri clone".
**Confidence.** high.

### YR-GP-045 Yuri Prime (YURIPR)

**What.** Yuri's hero. A stronger Clone on a hover platform: controls units *and* buildings, immune to
mind control and crushing, self-heals, amphibious, and has a stronger area psychic blast that spares
friendlies.
**Data keys.** `Primary=SuperMindControl` (`ControllerBuilding`), `Secondary=SuperPsiWave`
(`SuperPsiPulse`), `BuildLimit=1`, `SpeedType=Amphibious`, `MovementZone=AmphibiousDestroyer`,
`Crushable=no`, `ImmuneToPsionics`, `SelfHealing`, `Deployer=yes`, `UndeployDelay=75`,
`OpenTransportWeapon=1`, `IFVMode=15`.
**Numbers.** Cost 1500, HP 150, armor flak, TechLevel 10, Sight 9, Speed 6, range 7, `Points=50`.
**Edge cases.** BuildLimit 1 — only one at a time **unless** a Cloning Vat is present (which duplicates
infantry, circumventing the limit). `SuperMindControl` uses the building-controller warhead, so it can
capture structures.
**Kind.** Infantry / hero / mind control.
**Sources.** RULES-MIRROR `[YURIPR]`, `[SuperMindControl]`, `[SuperPsiWave]`; CNCNZ; FANDOM "Yuri Prime".
**Confidence.** high.

### YR-GP-046 Slave (SLAV)

**What.** Free, uncontrollable miner spawned by a deployed Slave Miner. Shovels ore back to the miner.
**Data keys.** `Slaved=yes`, `Primary=SHOVEL`, `Storage=4`, `HarvestRate=150`, `PipScale=Tiberium`,
`IsSelectableCombatant=no`, `DontScore=yes`, `SpeakerSelectEnslaved`/`VoiceSelect` alternates.
**Numbers.** Cost 10 (not player-paid), HP 125, armor none, Sight 5, Speed 3, Storage 4 (SMIN holds 20).
**Edge cases.** Slaves are re-created free at `SlaveRegenRate` when killed. On miner death they defect
to the killer (or go neutral). They cannot be ordered; only the miner moves them.
**Kind.** Infantry / economy.
**Sources.** RULES-MIRROR `[SLAV]`; FANDOM "Slave (Yuri's Revenge)"; CNCNZ.
**Confidence.** high.

### YR-GP-047 Cosmonaut (LUNR)

**What.** Campaign-only lunar infantry for the Soviet **and** Yuri. A Rocketeer analogue with a jumpjet
and a laser effective vs vehicles, aircraft, and (in groups) structures. Survives vacuum; Desolators are
the only other lunar-capable infantry.
**Data keys.** `Primary=Lunarlaser` (`LUNARWH`), `JumpJet=yes`, `BalloonHover=yes`, `ConsideredAircraft`,
`MovementZone=Fly`, `SpeedType=Hover`, `TechLevel=11`, `Owner=Russians,Confederation,Africans,Arabs`.
**Numbers.** Cost 600, HP 125, armor none, Sight 8, Speed 9 (air), range 7, ROF 20, damage 25; jumpjet
height 500, speed 30, climb 20. Internal UI name `LUNR`, voice `LaserCosmo*`.
**Edge cases.** Not available in normal play (map-granted only). Prereq in data lists `NAPILE` (a
nonexistent id), effectively unreachable except via triggers. The wiki calls them "Cosmonaut"; original
name "Lunar Rocketeer". Dominator/MC immune? No — but usually irrelevant.
**Kind.** Infantry / campaign.
**Sources.** RULES-MIRROR `[LUNR]`, `[Lunarlaser]`; FANDOM "Cosmonaut"; CNCNZ "New Soviet units".
**Confidence.** high.

### YR-GP-048 Yuri Attack Dog (YDOG / YADOG)

**What.** Yuri's dog. Internally two variants that share the dog image, gated by `RequiredHouses=YuriCountry`
so that the "only one dog on the sidebar" rule holds. Anti-infantry, detects disguises, cannot be mind
controlled.
**Data keys.** `GoodTeeth`/`BadTeeth` + `VirtualScanner`, `DetectDisguise=yes`, `ImmuneToPsionics`,
`Trainable=no`, `Natural=yes`.
**Numbers.** Cost 200, HP 100, armor none, Sight 9, Speed 8.
**Edge cases.** The two-id trick (YADOG/YDOG) exists purely because of the shared sidebar-slot rule; both
are Yuri-only. Dogs avoid Brutes.
**Kind.** Infantry / scout.
**Sources.** RULES-MIRROR `[YDOG]`/`[YADOG]`.
**Confidence.** high.

### 2.3 Yuri vehicles

| Name | Internal id | Cost | Armor | Prereq | Weapon(s)/Warhead | Role | Notable logic |
|------|-------------|------|-------|--------|-------------------|------|---------------|
| Slave Miner | SMIN | 1500 (CNCNZ: 1750) | medium | YAWEAP | 20mmRapid / HARVWH | Mobile refinery | Deploys to YAREFN; 5 slaves; self-heal; immune psionics/radiation |
| Lasher Light Tank | LTNK | 700 | heavy | YAWEAP | ATGUN / AP | Main tank | Crusher; BuildTimeMultiplier 1.5 |
| Gattling Tank | YTNK | 600 | light | YAWEAP | AGGattling / AAGattling (3-stage) | Anti-air/anti-infantry | Spin-up stages; weak vs tanks |
| Chaos Drone | CAOS | 800 (CNCNZ: 600) | light | YAWEAP | ChaosAttack (deploy gas) | Disruption | Deployer; makes enemies berserk; immune psionics/radiation |
| Magnetron | TELE | 1000 | light | YAWEAP + NAPSIS | MagneticBeam / LocomotorBeam; MagneShake / MagneShakeWH | Anti-vehicle tractor | Levitates vehicles toward it; can't target infantry |
| Yuri MCV | PCV | 3000 | heavy | YAWEAP + YAGRND | – | Base expansion | Deploys to YACNST |
| Mastermind | MIND | 1750 | heavy | YAWEAP + YATECH | MultipleMindControlTank / Controller | Multi-capture | Infinite MC; overheats and self-destructs past 3; immune psionics |
| Amphibious Transport | YHVR | 900 | heavy | YAYARD | – | Transport | 12 passengers; hover/amphibious; no weapon |
| Boomer | BSUB | 2000 | heavy | YAYARD + RADAR | BoomerTorpedo / APSplash2; CruiseLauncher / Special | Sub + missile ship | Submerged/cloaked; spawns 2 cruise missiles; missiles interceptable |

**Blocks.**

### YR-GP-060 Slave Miner (SMIN)

See YR-GP-013 (vehicle/structure pair). Key vehicle-specific points: it has a `20mmRapid` turret for
self-defense (`HARVWH`, 30 dmg, ROF 20, range 5.5), `SelfHealing=yes` while mobile, and `Size=3`.
**Sources.** RULES-MIRROR `[SMIN]`.
**Confidence.** high.

### YR-GP-061 Lasher Light Tank (LTNK)

**What.** Yuri's main battle tank. Cheaper and lighter than a Grizzly/Rhino but with heavy armor class
and a decent cannon; can crush infantry.
**Data keys.** `Primary=ATGUN` (`AP`), `Crusher=yes`, `BuildTimeMultiplier=1.5`.
**Numbers.** Cost 700, HP 300, armor heavy, Sight 8, Speed 7, range 5, ROF 60, damage 65; build time ×1.5.
**Edge cases.** `BuildTimeMultiplier=1.5` makes it take 50% longer to build than its cost implies,
balancing its low price. Weakest armor among the three main battle tanks despite the heavy class.
**Kind.** Vehicle.
**Sources.** RULES-MIRROR `[LTNK]`, `[ATGUN]`; CNCNZ; FANDOM "Lasher light tank".
**Confidence.** high.

### YR-GP-062 Gattling Tank (YTNK)

**What.** Yuri's light AA/anti-infantry vehicle with a 3-stage spin-up gattling gun that alternates
anti-ground and anti-air weapons.
**Data keys.** `IsGattling=yes`, `WeaponCount=6`, `WeaponStages=3`, `Stage1/2/3`, `RateUp=1`,
`RateDown=50`, `Weapon1..6`.
**Numbers.** Cost 600, HP 210, armor light, Sight 10, Speed 6, range 5 ground / 8 air, ROF 16 (2-shot
bursts). Stage damages 25 (ground all stages; stage 3 warhead `SSA`), 30→40 (air, ROF 16→8→4).
**Edge cases.** Very weak against tanks; spin-up persists between targets but decays slowly
(`RateDown=50`). Its AA is the main counter to Rocketeers and Floating Discs.
**Kind.** Vehicle.
**Sources.** RULES-MIRROR `[YTNK]`, `[AGGattling*]`, `[AAGattling*]`; CNCNZ; FANDOM "Gattling tank".
**Confidence.** high.

### YR-GP-063 Chaos Drone (CAOS)

**What.** Small unmanned drone that deploys hallucinatory gas, driving enemy units berserk — they gain
attack power and preferentially target their own side. No conventional weapon.
**Data keys.** `Primary=ChaosAttack`, `Deployer=yes`, `DeployFire=yes`, `BerserkFriendly=yes`,
`CanPassiveAquire=no`, `CanRetaliate=no`, `ImmuneToPsionics`, `ImmuneToRadiation`, `Trainable=no`,
`Parasiteable=yes`, `Explodes=no`.
**Numbers.** Cost 800 (RULES-MIRROR; CNCNZ says 600 — mirror wins), HP 200, armor light, Sight 6, Speed 8.
**Edge cases.** Deploys into a stationary gas cloud; the berserk timer resets while in contact. The
drone itself does not attack and will not retaliate, so it is harmless once the gas is down. Not
trainable, so it never becomes veteran.
**Kind.** Vehicle / support.
**Sources.** RULES-MIRROR `[CAOS]`, `[ChaosAttack]`; CNCNZ; FANDOM "Chaos drone".
**Confidence.** high on mechanics; med on cost (conflict).

### YR-GP-064 Magnetron (TELE)

**What.** Support AFV that fires a magnetic beam to levitate and drag enemy vehicles toward itself, and a
shaking beam to damage structures. It cannot attack infantry and cannot crush them.
**Data keys.** `Primary=MagneticBeam` (`LocomotorBeam`, damage 5000 but used as a tractor, range 12,
MinimumRange 3), `Secondary=MagneShake` (`MagneShakeWH`, 80 dmg, range 10), `CanPassiveAquire=no`,
`Bunkerable=no`.
**Numbers.** Cost 1000, HP 150, armor light, Sight 10, Speed 5, ROT 5.
**Edge cases.** `MagneticBeam`'s damage value is a tractor mechanic, not real damage; `MagneShake` is the
real building attack. `CanPassiveAquire=no` prevents it from auto-attacking allies. Because it cannot
hit infantry, it must be screened by Lashers/Gattling Tanks. The beam is drawn via `IsMagBeam` and the
global `MagnaBeamColor`.
**Kind.** Vehicle / support.
**Sources.** RULES-MIRROR `[TELE]`, `[MagneticBeam]`, `[MagneShake]`, `[AudioVisual]`; CNCNZ; FANDOM "Magnetron".
**Confidence.** high.

### YR-GP-065 Yuri MCV (PCV)

**What.** Yuri's Mobile Construction Vehicle; deploys into the Yuri Construction Yard.
**Data keys.** `DeploysInto=YACNST`, `Crusher=yes`, `OmniCrushResistant=yes`.
**Numbers.** Cost 3000, HP 1000, armor heavy, Sight 8, Speed 4.
**Edge cases.** Prereq `YAWEAP + YAGRND` — note it requires the **Grinder**, not just the War Factory,
making Yuri expansion slightly slower. (CNCNZ says "Prerequisites: Grinder".)
**Kind.** Vehicle.
**Sources.** RULES-MIRROR `[PCV]`; CNCNZ.
**Confidence.** high.

### YR-GP-066 Mastermind (MIND)

**What.** Big multi-mind-control vehicle. Can hold up to 3 enemy units safely; if it exceeds the limit,
the control core overloads and destroys itself, releasing all controlled units.
**Data keys.** `Primary=MultipleMindControlTank` (`InfiniteMindControl=yes`, `Controller`, range 6,
`OmniFire`), `PipScale=MindControl`, `ImmuneToPsionics`, `SelfHealing`, `Trainable=no`.
**Numbers.** Cost 1750, HP 500, armor heavy, Sight 9, Speed 4.
**Edge cases.** Damage value in the weapon is only pip bookkeeping (`Damage=3`); the real limit is the
hardcoded "MasterMind Overload" table. `Trainable=no`. It can control miners? No — same restrictions as
other MC. Control breaks when the Mastermind dies or overloads.
**Kind.** Vehicle / mind control.
**Sources.** RULES-MIRROR `[MIND]`, `[MultipleMindControlTank]`; CNCNZ; FANDOM "Mastermind".
**Confidence.** high.

### YR-GP-067 Amphibious Transport / Hover Transport (YHVR)

**What.** Yuri's 12-slot transport. Unlike the Allied Landing Craft it is a **hover** craft that crosses
land and water, though it is radar-visible and unarmed.
**Data keys.** `Naval=yes`, `SpeedType=Hover`, `MovementZone=Amphibious`, `Passengers=12`,
`SizeLimit=6`, `PipScale=Passengers`.
**Numbers.** Cost 900, HP 300, armor heavy, Sight 6, Speed 6.
**Edge cases.** More resilient than the Allied landing craft. `TooBigToFitUnderBridge=true`. In-game
name shown as the generic transport; CNCNZ calls it "Amphibious Transport".
**Kind.** Vehicle / naval transport.
**Sources.** RULES-MIRROR `[YHVR]`; CNCNZ; FANDOM "Amphibious transport".
**Confidence.** high.

### YR-GP-068 Boomer (BSUB)

**What.** Yuri's submarine/missile ship. Submerged and cloaked, it torpedoes other ships and launches
ballistic cruise missiles at ground targets via a spawner.
**Data keys.** `Primary=BoomerTorpedo` (`APSplash2`, range 7, Burst 2), `Secondary=CruiseLauncher`
(`Spawner=yes`, range 20, MinimumRange 8), `Cloakable=yes`, `Underwater=yes`, `Spawns=CMISL`,
`SpawnsNumber=2`, `SpawnRegenRate=80`, `SpawnReloadRate=0`, `NavalTargeting=7`, `LandTargeting=2`.
**Numbers.** Cost 2000, HP 1200, armor heavy, Sight 8, Speed 5, ROT 2; torpedo 60 dmg, ROF 120; cruise
missile 25 dmg (spawned `CMISL` warhead `CMISLWH`/`Special`).
**Edge cases.** Missiles can be shot down by AA. `Unnatural=yes` means a Giant Squid punches rather than
grabs it. It surfaces when damaged, revealing itself. The two missiles do not return (`SpawnReloadRate=0`
means the spawn doesn't reload after firing? — in practice the Boomer counts as having spent its salvo).
Cruise missile units are `CMISL` aircraft.
**Kind.** Naval vehicle.
**Sources.** RULES-MIRROR `[BSUB]`, `[BoomerTorpedo]`, `[CruiseLauncher]`; CNCNZ; FANDOM "Boomer".
**Confidence.** high.

### 2.4 Yuri aircraft

### YR-GP-080 Floating Disc (DISK)

**What.** Yuri's only aircraft, built at the War Factory. A hovering saucer with a small anti-infantry
laser. Its signature ability: hovering over an enemy power plant shuts down the base's power; hovering
over a refinery/Slave Miner siphons credits; hovering over a powered defensive structure disables it.
**Data keys.** `Primary=DiskLaser` (`DiskWH`, range 7, `OmniFire`), `Secondary=DiskDrain` (`AntiB`,
`DrainWeapon=yes`, range 1.5, `CellRangefinding`, `FireOnce`), `BalloonHover=yes`,
`ConsideredAircraft=yes`, `MovementZone=Fly`, `SpeedType=Hover`, `SelfHealing`, `DeathWeapon`,
`JumpjetHeight=750`.
**Numbers.** Cost 1750, HP 600, armor light, Sight 9, Speed 15, ROT 100; laser 90 dmg, ROF 80.
**Edge cases.** `DiskDrain` is a drain weapon, not damage — it drains power from a target structure
(powering down the grid) or credits from an economy building. It is `FireOnce` per hover. Death weapon
`BlimpBombEffect` is scaled by `DeathWeaponDamageModifier=.1`. `DiskLaser=yes` uses the special ring
draw. Prereq `YAWEAP + YATECH`.
**Kind.** Aircraft.
**Sources.** RULES-MIRROR `[DISK]`, `[DiskLaser]`, `[DiskDrain]`; CNCNZ; FANDOM "Floating disc".
**Confidence.** high.

### 2.5 Yuri navy / shared hulls

Yuri naval roster = Boomer (YR-GP-068) + Amphibious Transport (YR-GP-067), both built at the Submarine
Pen. There is no Yuri capital ship. The Allied **Landing Craft** (`LCRF`) remains Allied-only despite
both sides' vessels appearing in the wiki's "Amphibious transport" page.

### YR-GP-081 Landing Craft (LCRF, Allied; context)

**What.** The RA2 Allied transport, retained unchanged in YR; included here only to disambiguate from
Yuri's hover transport. `SpeedType=Hover`, `MovementZone=Amphibious`, 12 passengers, no weapon.
**Numbers.** Cost 900, HP 300, armor light.
**Sources.** RULES-MIRROR `[LCRF]`.
**Confidence.** high.

---

## 3. Allied additions & changes (YR)

| Name | Internal id | Cost | Armor | Prereq | Weapon(s)/Warhead | Role | Notable logic |
|------|-------------|------|-------|--------|-------------------|------|---------------|
| Guardian GI | GGI | 400 | none | GAPILE | M60 / SA; MissileLauncher / GUARDWH | Deployable AT/AA infantry | Deploy to fire rockets; IFVMode 16 |
| Robot Tank | ROBO | 600 | heavy | GAWEAP + GAROBO | Robogun / AP | Unmanned amphibious tank | Powered by a powered Robot Control Center; immune psionics/radiation |
| Robot Control Center | GAROBO | 600 | wood | GAWEAP + GACNST | – | Support structure | `PowersUnit=ROBO`; Power −100 |
| Battle Fortress | BFRT | 2000 | heavy | GAWEAP + GATECH | 20mmRapid / HARVWH | Armed APC | 5 open-topped infantry fire out; OmniCrusher |
| Navy SEAL (promoted) | SEAL | 1000 | flak | GAPILE + RADAR | MP5 / HollowPoint; Sapper | Commando/amphibious | Now buildable in skirmish/MP (was campaign-only) |
| Tanya (changed) | TANY | 1500 | flak | GAPILE + GATECH | DoublePistols / HollowPoint2; Sapper | Hero | Cost 1000→1500; C4 works on vehicles now; still BuildLimit 1 |
| IFV passenger modes (added) | FV | 600 | light | GAWEAP | 17 modes total | Transport | Modes 13–16 added: Initiate, Virus, Yuri Prime, Guardian GI |

**Blocks.**

### YR-GP-100 Guardian GI (GGI)

**What.** Heavy Allied infantry that can deploy to fire an anti-vehicle/anti-air rocket. Adds the
Allies' answer to Soviet armor/air without a vehicle.
**Data keys.** `Primary=M60` (`SA`), `Secondary=MissileLauncher` (`GUARDWH`), `Deployer=yes`,
`DeployFire=yes`, `DeployedCrushable=no`, `IFVMode=16`, `OpenTransportWeapon=1`.
**Numbers.** Cost 400, HP 100, armor none, TechLevel 2, Sight 6, Speed 3; M60 15 dmg / ROF 20 / range 4;
MissileLauncher 40 dmg / ROF 40 / range 8 / `GUARDWH`.
**Edge cases.** Cannot occupy UC buildings (`Occupier=no`). Deployed form cannot be crushed while
deployed (`DeployedCrushable=no`) but the unit cannot move. Its IFV mode 16 gives the IFV a missile.
**Kind.** Infantry.
**Sources.** RULES-MIRROR `[GGI]`, `[MissileLauncher]`; FANDOM "Guardian GI"; CNCNZ "New Allied units".
**Confidence.** high.

### YR-GP-101 Robot Tank (ROBO)

**What.** Unmanned amphibious hover tank. Strong vs vehicles and structures; **cannot be mind
controlled** and is immune to radiation. It is powered: at least one powered Robot Control Center must
exist or all Robot Tanks shut down. Carries no crew.
**Data keys.** `Primary=Robogun` (`AP`), `PoweredUnit=yes`, `ImmuneToPsionics`, `ImmuneToRadiation`,
`SpeedType=Hover`, `MovementZone=AmphibiousDestroyer`, `ActivateSound`/`DeactivateSound`,
`Trainable=no`, `BuildTimeMultiplier=1.3`, `Size=3`.
**Numbers.** Cost 600, HP 180, armor heavy, Sight 6, Speed 10, range 5, ROF 60, damage 65.
**Edge cases.** Losing all powered control centers disables (not destroys) the tanks — they cannot move
or fire until power is restored. `Trainable=no`. `BuildTimeMultiplier=1.3`.
**Kind.** Vehicle.
**Sources.** RULES-MIRROR `[ROBO]`, `[Robogun]`; FANDOM "Robot tank".
**Confidence.** high.

### YR-GP-102 Robot Control Center (GAROBO)

**What.** Support building required to keep Robot Tanks active. Must be powered.
**Data keys.** `PowersUnit=ROBO`, `TogglePower=yes`, `Powered=true`, `Capturable=true`.
**Numbers.** Cost 600, HP 600, armor wood, Power −100, TechLevel 10.
**Edge cases.** Multiple centers do not stack; one suffices. Destroying the last one deactivates all
Robot Tanks globally for that player.
**Kind.** Structure / support.
**Sources.** RULES-MIRROR `[GAROBO]`; FANDOM "Robot Control Center".
**Confidence.** high.

### YR-GP-103 Battle Fortress (BFRT)

**What.** Heavily armored Allied APC. Holds **five** infantry and is **open-topped**, so each
passenger fires its own weapon out. Can crush other vehicles (`OmniCrusher`) and walls.
**Data keys.** `Passengers=5`, `OpenTopped=yes`, `SizeLimit=2`, `OmniCrusher=yes`,
`OmniCrushResistant=yes`, `MovementZone=CrusherAll`, `Primary=20mmRapid` (`HARVWH`).
**Numbers.** Cost 2000, HP 600, armor heavy, Sight 6, Speed 4; self-gun 30 dmg / ROF 20 / range 5.5.
**Edge cases.** `SizeLimit=2` lets even Brutes/Terror Drones board (but Brutes cannot fire from
transport). Passenger weapons differ against air/ground and use per-unit `OpenTransportWeapon`.
`OmniCrushResistant` means other Battle Fortresses cannot crush it.
**Kind.** Vehicle / transport.
**Sources.** RULES-MIRROR `[BFRT]`; FANDOM "Battle Fortress"; CNC-NET (passenger analyses).
**Confidence.** high.

### YR-GP-104 Navy SEAL (SEAL)

**What.** In RA2 the Navy SEAL was campaign-only; in YR it is **promoted to a normal buildable unit**
(GAPILE + Radar Tower) for skirmish/multiplayer. Amphibious commando with an MP5 that kills infantry
instantly and a Sapper charge for structures.
**Data keys.** `Primary=MP5` (`HollowPoint`), `Secondary=Sapper`, `C4=yes`, `SpeedType=Amphibious`,
`MovementZone=AmphibiousDestroyer`, `AlternateArcticArt=yes`, `IFVMode=4`,
`PrerequisiteOverride` (campaign Pentagon buildings).
**Numbers.** Cost 1000, HP 125, armor flak, TechLevel 9, Sight 8, Speed 5; MP5 125 dmg / ROF 10 / range 6.
**Edge cases.** Can cross water and plant C4 (on land and on ships). In campaign it remains gated by
Pentagon `PrerequisiteOverride`. It is one of the best Battle Fortress passengers.
**Kind.** Infantry / commando.
**Sources.** RULES-MIRROR `[SEAL]`, `[MP5]`; FANDOM YR page ("previously campaign-only, now skirmish").
**Confidence.** high.

### YR-GP-105 Tanya (changed)

**What.** Allied commando hero, changed in YR: cost rose from $1000 to **$1500**, only one at a time,
and her C4 can now be planted on **land vehicles** (not just structures/ships).
**Data keys.** `Primary=DoublePistols` (`HollowPoint2`), `Secondary=Sapper`, `C4=yes`, `BuildLimit`
(enforced by sidebar/`AllowedToStartInMultiplayer=no`), `SpeedType=Amphibious`, `IFVMode=4`,
`OpenTransportWeapon=0`.
**Numbers.** Cost 1500, HP 200, armor flak, TechLevel 9, Sight 8, Speed 6; pistols 125 dmg / ROF 5 /
range 6.
**Edge cases.** The vehicle-C4 change is the key YR buff: Tanya can now delete tanks directly. She is
still not crusable and Tiberium-proof.
**Kind.** Infantry / hero.
**Sources.** RULES-MIRROR `[TANY]`, `[DoublePistols]`; FANDOM YR page.
**Confidence.** high.

### YR-GP-106 IFV passenger table (YR additions)

**What.** The Allied IFV (`FV`) was rebuilt in YR with **17 weapon modes** (0–16) selected by the
passenger's `IFVMode`. YR adds modes 13–16 for the new Yuri/Allied infantry.
**Data keys.** `WeaponCount=17`, `Weapon1..17`, `TurretCount=4`, and the `*TurretWeapon` map.
**Numbers / mapping (mode → weapon → unit):**
0 HoverMissile (empty), 1 RepairBullet (Engineer), 2 CRM60 (GI), 3 CRFlakGuyGun (Flak Trooper),
4 CRMP5 (SEAL/Tanya/Boris), 5 AWPE (Sniper), 6 CRElectricBolt (Tesla Trooper),
7 CRNuke (Crazy Ivan), 8 CRMindControl (Yuri), 9 CRRadBeamWeapon (Desolator),
10 CRNeutronRifle (Chrono Legionnaire), 11 CRTerrorBomb (Terrorist), 12 CowShot (Cow),
**13 CRPsychicJab (Initiate)**, **14 CRVirusGun (Virus)**, **15 CRSuperMindBlast (Yuri Prime)**,
**16 CRMissileLauncher (Guardian GI)**.
**Edge cases.** `TurretCount=4` caps simultaneous turret art; the weapon list is longer than the turret
count and uses index remapping. If `TurretCount`/`WeaponCount` is edited, the hardcoded
`OBJTYPE_DIM_TurretMax` (15) must be respected.
**Kind.** Transport / data table.
**Sources.** RULES-MIRROR `[FV]`; FANDOM "IFV".
**Confidence.** high.

---

## 4. Soviet additions, changes & removals (YR)

| Name | Internal id | Cost | Armor | Prereq | Weapon(s)/Warhead | Role | Notable logic |
|------|-------------|------|-------|--------|-------------------|------|---------------|
| Boris | BORIS | 1500 | flak | NAHAND + NATECH | AKM; Flare (→ MiG airstrike) | Commando/hero | Calls 2 MiGs (4 elite); target must be a structure; BuildLimit 1 |
| Siege Chopper | SCHP | 1400 | light | NAWEAP + TECH | BlackHawkCannon; 160mm | Air/siege | Deploys (land) into SCHD with a 160mm cannon; jumpjet |
| Industrial Plant | NAINDP | 2500 | wood | NATECH + PROC + NACNST | – | Production discount | `UnitsCostBonus=0.75`; BuildLimit 1; Power −200 |
| Battle Bunker | NABNKR | 500 | steel | NACNST | – | Infantry garrison | Holds 5 infantry; no power; `CanOccupyFire` |
| Spy Plane | SPYP (aircraft) / SpyPlaneSpecial | free power | – | NARADR | – | Recon support power | Reveals a straight line of shroud; recharge 4 min |
| Psi-Corps trooper | (removed) | – | – | – | – | – | Transferred to Yuri as Yuri Clone ($800) |
| Psychic Sensor | (removed) | – | – | – | – | – | Repurposed as Yuri Psychic Radar |
| Cloning Vats | NACLON (moved) | 2500 | wood | YATECH | – | – | Now Yuri-only; Soviet version removed |

**Blocks.**

### YR-GP-200 Boris (BORIS)

**What.** Soviet hero. Fires an AKM at infantry and uses a laser designator ("Flare") to call in a
squadron of **two MiG bombers** (four when elite) against a target **structure**. He must stay still and
vulnerable while designating.
**Data keys.** `Primary=AKM` (`none`), `Secondary=Flare` (`AirstrikeFlare`), `AirstrikeTeam=2`,
`EliteAirstrikeTeam=4`, `AirstrikeTeamType=BPLN` (MiG aircraft id), `AirstrikeRechargeTime=100`,
`EliteAirstrikeRechargeTime=50`, `BuildLimit=1`, `SelfHealing`, `ImmuneToPsionics`, `IFVMode=4`,
`VoiceSecondaryWeaponAttack`.
**Numbers.** Cost 1500, HP 200, armor flak, TechLevel 9, Sight 9, Speed 5; AKM 65 dmg / ROF 20 / range 7;
Flare range 12, damage 1 (designator).
**Edge cases.** Only works on buildings (target must be a structure, or the cursor will not allow the
airstrike). Boris is immobile/vulnerable during designation; if given another order the strike is
cancelled. MiGs can be shot down by AA en route.
**Kind.** Infantry / hero.
**Sources.** RULES-MIRROR `[BORIS]`, `[AKM]`, `[Flare]`; FANDOM YR page; CNCNZ "New Soviet units".
**Confidence.** high.

### YR-GP-201 Siege Chopper (SCHP)

**What.** Soviet helicopter with dual roles: a Nighthawk-style machine gun while airborne, and a powerful
160mm siege cannon when deployed on the ground. New in YR.
**Data keys.** `Primary=BlackHawkCannon` (air, `QuadShell`), `Secondary=160mm` (siege), `JumpJet=yes`,
`HoverAttack=yes`, `IsSimpleDeployer=yes`, `UnloadingClass=SCHD`, `DeployToLand=yes`, `DeployFire=yes`,
`DeployingAnim=SCHPDEPL`, `Turret=yes`, `PreventAttackMove=yes`, `Size=15`, `SizeLimit=2`,
`Prereq=NAWEAP,TECH`.
**Numbers.** Cost 1400, HP 300, armor light, Sight 7, Speed 12; machine gun 35 dmg / ROF 40 / range 6;
jumpjet height 500.
**Edge cases.** Deployment transforms it into the land unit `SCHD` (a ground-only artillery state);
undeploy returns it to the air. It cannot attack-move (deploy required for the cannon). It can carry/
enter transports? `EnterTransportSound` is present but `Size=15` makes it too big for most transports.
**Kind.** Aircraft / deployable siege.
**Sources.** RULES-MIRROR `[SCHP]`, `[BlackHawkCannon]`; FANDOM "Siege chopper"; CNCNZ.
**Confidence.** high.

### YR-GP-202 Industrial Plant (NAINDP)

**What.** Soviet support structure that discounts vehicle production (and, by its `BuildCat=Resource`
and listed bonuses, the price of units). One per player.
**Data keys.** `FactoryPlant=yes`, `UnitsCostBonus=0.75`, `InfantryCostBonus=1`,
`AircraftCostBonus=1`, `BuildingsCostBonus=1`, `DefensesCostBonus=1`, `BuildLimit=1`, `Powered`.
**Numbers.** Cost 2500, HP 1000, armor wood, Power −200, TechLevel 10. Vehicle cost ×0.75.
**Edge cases.** The bonuses are multipliers where <1 is a discount; the industrial plant's value is only
on `UnitsCostBonus` in practice (the others are 1). It stacks with the multiple-factory production-speed
discount (`MultipleFactory`) but is a *cost* bonus, not a speed bonus. `BuildLimit=1`.
**Kind.** Structure / economy.
**Sources.** RULES-MIRROR `[NAINDP]`; FANDOM YR page; CNCNZ.
**Confidence.** high.

### YR-GP-203 Battle Bunker (NABNKR)

**What.** Soviet garrison structure for **infantry** (five slots), functioning like a civilian UC but
buyable. No power required.
**Data keys.** `CanBeOccupied=yes`, `MaxNumberOccupants=5`, `CanOccupyFire=yes`, `IsBaseDefense=yes`,
`Powered=no`, `Prerequisite=NACNST`.
**Numbers.** Cost 500, HP 600, armor steel, TechLevel 1, Sight 6.
**Edge cases.** Any friendly infantry that can garrison UC buildings can enter; occupants fire out with
`CanOccupyFire`. Contrast with Yuri's Tank Bunker (`NATBNK`) which takes one vehicle.
**Kind.** Structure / defense / garrison.
**Sources.** RULES-MIRROR `[NABNKR]`; FANDOM "Battle bunker (Yuri's Revenge)".
**Confidence.** high.

### YR-GP-204 Spy Plane (SpyPlaneSpecial)

**What.** Soviet support power unlocked by the Radar Tower. Flies a plane across the map, revealing the
shroud in a straight line.
**Data keys.** `SuperWeapon=SpyPlaneSpecial` on the Radar Tower; `Type=SpyPlane`, `RechargeTime=4`,
`ShowTimer=no`, `FlashSidebarTabFrames`.
**Numbers.** Free power; recharge 4 minutes; `DisabledDisguise` not applicable.
**Edge cases.** Reveals a line, not an area; shroud returns afterwards. It is not a "spy" in the
infiltration sense — purely reconnaissance.
**Kind.** Support power.
**Sources.** RULES-MIRROR `[SpyPlaneSpecial]`; FANDOM "Spy plane (Yuri's Revenge)".
**Confidence.** high.

### YR-GP-205 Soviet removals (Psi-Corps, Psychic Sensor, Cloning Vats)

**What.** Three RA2 Soviet items leave the Soviet roster in YR:
1. **Psi-Corps trooper / Yuri** → becomes Yuri's **Yuri Clone** (cost 800, Psychic Radar prereq).
2. **Psychic Sensor** → becomes Yuri's **Psychic Radar** (`NAPSIS`), repurposed as the radar and
   Psychic Reveal source.
3. **Cloning Vats** → becomes a Yuri building only (`NACLON`); the Soviet version is gone.
**Data keys.** Ownership/prereq changes only; the objects themselves are reused.
**Numbers.** See YR-GP-044 (clone), YR-GP-016 (radar), YR-GP-023 (cloning).
**Edge cases.** Campaign maps and mods that reference the old Soviet ownership must be updated; in YR
these are hard requirements for the new faction.
**Kind.** Roster change.
**Sources.** FANDOM YR page (explicit list); RULES-MIRROR ownership fields.
**Confidence.** high.

---

## 5. Slave economy, Grinder, credit siphon, Bio Reactor, Ore Purifier

### YR-GP-300 Slave economy loop

**What.** Yuri has **no conventional ore refinery + miner**. The Slave Miner both mines and refines:
deploy → 5 Slaves dig for free → ore is stored in the deployed refinery → credits tick in. Slaves are
replaced free; an Engineer repairs the deployed refinery; mobile miners self-repair.
**Data keys.** `Enslaves`, `SlavesNumber`, `SlaveRegenRate`, `SlaveReloadRate`, `Harvester`, `Storage`,
`HarvestRate`, `ResourceGatherer`, `SlaveMinerShortScan`, `SlaveMinerSlaveScan`, `SlaveMinerLongScan`,
`SlaveMinerScanCorrection`, `SlaveMinerKickFrameDelay`, `AISlaveMinerNumber`, `HarvesterUnit`.
**Numbers.** Slaves 5; regen 500 frames; reload 25; Slave storage 4, miner storage 20, refinery storage
200; slave harvest rate 150 frames/bale; AI slave-miner counts 4/3/2 (hard/normal/easy); scan radii 8 /
14 / 48 cells, correction 3 cells, kick delay 150 frames.
**Edge cases.**
* The deployed refinery is repaired by an Engineer (enter it), unlike normal repair.
* Slaves are `DontScore` and non-selectable; killing the miner makes them defect to the attacker.
* Because the miner doubles as refinery, losing it loses both income and stored ore.
* The AI treats the miner as a `ResourceGatherer` with `ResourceDestination`.
**Kind.** Economy system.
**Sources.** RULES-MIRROR `[SMIN]`/`[YAREFN]` + `[General]` scan keys; FANDOM "Slave miner", "Slave";
CNCNZ.
**Confidence.** high.

### YR-GP-301 Grinder refund

**What.** Recycling structure for excess/mind-controlled units. Vehicles refund 100% of build cost;
infantry refund 50% (reduced because the Cloning Vats already duplicates infantry for free).
**Data keys.** `Grinding=yes`.
**Numbers.** Vehicle 100%, infantry 50%. Cost 600, HP 900, Power −50.
**Edge cases.** Mind-controlled enemies can be ground for cash; a captured enemy vehicle thus converts
directly to credits. Selling a structure uses the global `RefundPercent=50%` instead — different system.
**Kind.** Economy.
**Sources.** RULES-MIRROR `[YAGRND]` + `RefundPercent`; FANDOM "Grinder"; Baidu Baike (refund split).
**Confidence.** med (refund split is community-attested, not raw data).

### YR-GP-302 Credit siphon & power-down (Floating Disc)

**What.** The Floating Disc's `DiskDrain` secondary drains either power (shutting down a base/grid) or
credits (from refineries/Slave Miners) while hovering over the target.
**Data keys.** `DiskDrain` (`DrainWeapon=yes`, `AntiB` warhead, `FireOnce`).
**Numbers.** No damage listed; range 1.5 cells, must hover directly over the target.
**Edge cases.** Draining a power plant cuts base power, which also disables powered defenses. The drain
is per hover; moving off stops it. It does not destroy; it only drains. Exact credit-drain rate is not
in the visible stats (engine-internal) — flagged low confidence.
**Kind.** Economy / support mechanic.
**Sources.** RULES-MIRROR `[DiskDrain]`; CNCNZ "Floating Disc".
**Confidence.** high on existence; low on exact drain rate.

### YR-GP-303 Bio Reactor internment

**What.** A Bio Reactor holds up to five infantry for bonus power (+100 each) and as a disposal sink for
unwanted mind-controlled units. Interned *controlled* units revert if their controller dies.
**Data keys.** `Passengers=5`, `ExtraPower=100`, `InfantryAbsorb`, `UnitAbsorb=no`, `PipScale`,
`Drainable`.
**Numbers.** Base +150, +100 per occupant (max +650).
**Edge cases.** Because `UnitAbsorb=no`, vehicles cannot be interned. The AI sends captures here per
`AICaptureLowPower=15,5,75,5` (the 75% column) and `AICaptureWounded`.
**Kind.** Power / economy sink.
**Sources.** RULES-MIRROR `[YAPOWR]`, `AICapture*` keys; CNCNZ.
**Confidence.** high.

### YR-GP-304 Ore, Gems & Purifier bonus

**What.** YR keeps RA2's resources (Ore = `Riparius` value 25; Gems = `Cruentus` value 50; `Vinifera` and
`Aboreus` also exist as variants). The **ore purifier** bonus (`PurifierBonus=.25`) is an Allied
(`GAOREP`) function; **Yuri has no purifier building** — its offset is the free Slave labour and the
Slave Miner's refinery.
**Data keys.** `Tiberiums` list; per-resource `Value`, `Growth`, `Spread`; `PurifierBonus`,
`Purifiers`/`AIVirtualPurifiers`, `TiberiumGrows`, `TiberiumSpreads`, `GrowthRate`.
**Numbers.** Ore 25/bail, Gems 50/bail, Purifier +25%, growth every 5 min (`GrowthRate=5`),
AI virtual purifiers 4/2/0 (h/m/e; campaign 8/4/2), `AIVirtualPurifiers` affects harvested money bonus.
**Edge cases.** `PurifierBonus` only applies to buildings flagged as purifiers. Yuri cannot build one, so
its income ceiling is lower per refinery — offset by slaves' free labour.
**Kind.** Economy.
**Sources.** RULES-MIRROR `[Tiberiums]`, `[Riparius]`, `[Cruentus]`, `PurifierBonus`, `AIVirtualPurifiers`;
FANDOM "Ore".
**Confidence.** high.

---

## 6. Support powers & superweapons (full parameters)

### YR-GP-400 Superweapon parameter table

| Name | Internal id | Granted by | Powered | Recharge | Range | Key params |
|------|-------------|-----------|---------|----------|-------|-----------|
| Nuclear Missile | NukeSpecial | Soviet Nuclear Silo | yes | 10 min | 7 / ×2 lines | `AIDefendAgainst`, `DisableableFromShell` |
| Iron Curtain | IronCurtainSpecial | Soviet Iron Curtain | yes | 5 min | 1.4 / ×3 | invulnerability |
| Lightning Storm | LightningStormSpecial | Soviet Weather Control | yes | 10 min | 7 / ×2 | 250 dmg/bolt; duration 180 frames |
| Chrono Sphere | ChronoSphereSpecial | Allied Chronosphere | yes | 7 min | 1.4 / ×3 | `PreClick` |
| Chrono Warp | ChronoWarpSpecial | (dependent) | no | 1 min | 1.4 / ×3 | `PreDependent=ChronoSphere` |
| Paratroopers | ParaDropSpecial / AmericanParaDropSpecial | Tech Airport / America | no | 4 min | – | 9× E2 (Sov), 6× E1 (Ally), 8× E1 (USA), 6× INIT (Yuri) |
| Force Shield | ForceShieldSpecial | Battle Lab (all sides) | yes | 5 min | 3.4 / ×3 | radius 4 cells, duration 500 frames, blackout 1000 frames |
| Psychic Reveal | PsychicRevealSpecial | Yuri Psychic Radar | no | 4 min | – | reveal area; `FlashSidebarTabFrames` |
| Spy Plane | SpyPlaneSpecial | Soviet Radar Tower | no | 4 min | – | reveal a line |
| Psychic Dominator | PsychicDominatorSpecial | Yuri Psychic Dominator | yes | 10 min | 1.4 / ×3 | capt 1000 dmg; capture range 1; permanent MC |
| Genetic Converter (Mutation) | GeneticConverterSpecial | Yuri Genetic Mutator | yes | 5 min | 5 / ×3 | Mutate warhead; explosion mode on |

### YR-GP-401 Force Shield (ForceShieldSpecial)

**What.** YR's new global support power. Available to **all** sides from their Battle Lab. Makes all
friendly structures in a radius invulnerable for a short time, even against superweapons, at the cost of
a base-wide power blackout afterward.
**Data keys.** `Type=ForceShield`, `ForceShieldRadius=4`, `ForceShieldDuration=500`,
`ForceShieldBlackoutDuration=1000`, `ForceShieldPlayFadeSoundTime=75`,
`StartSound`/`SpecialSound`, `ForceShieldInvokeAnim=FORCSHLD`, `FlashSidebarTabFrames=120`.
**Numbers.** Recharge 5 min; radius 4 cells; duration 500 frames (~8.3 s at 60 fps); blackout 1000 frames
(~16.7 s); targeting range 3.4.
**Edge cases.** Shield is on **structures**, not units (the Iron Curtain covers units). The blackout is
longer than the shield, so using it defensively can leave you vulnerable after. The AI uses it
defensively per `AISuperDefenseProbability=90,50,10`, `AISuperDefenseFrames=50`,
`AISuperDefenseDistance=12`.
**Kind.** Support power.
**Sources.** RULES-MIRROR `[ForceShieldSpecial]`, `[General]` ForceShield keys; FANDOM YR page.
**Confidence.** high.

### YR-GP-402 Psychic Dominator / Domination (PsychicDominatorSpecial)

**What.** Yuri's ultimate. A map-wide psychic burst centered on the target area: mind-controls all
eligible units (permanently), deals `DominatorDamage` to nearby structures.
**Data keys.** `DominatorWarhead=DominatorWH`, `DominatorDamage=1000`, `DominatorCaptureRange=1`,
`DominatorFirstAnim=PDFXCLD`, `DominatorSecondAnim=PDFXLOC`, `DominatorFireAtPercentage=20`,
`SuperWeapon=PsychicDominatorSpecial`.
**Numbers.** Cost 5000, recharge 10 min, `DominatorDamage=1000`, capture range 1 cell around the impact.
**Edge cases.** MC-immune units (dogs, robot tanks, miners, MC units) and garrisoned units are immune.
Captured units can never be released or re-controlled (permanent). Building it reveals it to all players
(`RevealToAll`) with a visible timer. The internal display name is wrongly "Lightning Storm".
**Kind.** Superweapon.
**Sources.** RULES-MIRROR `[YAPPET]`/`[PsychicDominatorSpecial]`, `[General]`; FANDOM "Psychic dominator".
**Confidence.** high.

### YR-GP-403 Genetic Mutator / Mutation (GeneticConverterSpecial)

**What.** Converts infantry in the target area into player-controlled Brutes; animals are killed. Can be
fired on friendlies (deliberately, to convert your own Slaves etc.).
**Data keys.** `MutateWarhead=Mutate`, `MutateExplosionWarhead=MutateExplosion`,
`MutateExplosion=yes`, `AnimToInfantry=BRUTE`, `SuperWeapon=GeneticConverterSpecial`.
**Numbers.** Cost 2500, recharge 5 min, range 5.
**Edge cases.** With `MutateExplosion=yes` the effect is an explosion warhead rather than a fixed 3×3
area. Mutated Brutes belong to the Mutator owner. Works on Slaves (classic slave→Brute→Grinder combo).
**Kind.** Superweapon.
**Sources.** RULES-MIRROR `[YAGNTC]`/`[GeneticConverterSpecial]`, `[SpecialWeapons]`, `[General]`; CNCNZ.
**Confidence.** high.

### YR-GP-404 Paratroopers (ParaDropSpecial / AmericanParaDropSpecial)

**What.** Airdrop support power. The **Tech Airport** grants the generic version; **America** has its own
variant with a larger drop.
**Data keys.** `ParaDropSpecial` (`Type=ParaDrop`, recharge 4, not disableable), `AmericanParaDropSpecial`
(`Type=AmerParaDrop`), and the drop tables: `AmerParaDropInf=E1`/`Num=8`, `AllyParaDropInf=E1`/`Num=6`,
`SovParaDropInf=E2`/`Num=9`, `YuriParaDropInf=INIT`/`Num=6`, `ParadropRadius=1024`.
**Numbers.** Recharge 4 min; drop counts as above; drop radius 1024 leptons (4 cells).
**Edge cases.** Drops are per faction, not per player country (America excepted). Planes can be shot
down. `DisableableFromShell=no` means crate/shell options do not turn it off.
**Kind.** Support power.
**Sources.** RULES-MIRROR `[ParaDropSpecial]`/`[AmericanParaDropSpecial]`, `[General]` paradrop keys.
**Confidence.** high.

### YR-GP-405 Spy Plane (SpyPlaneSpecial)

See YR-GP-204. Recharge 4 min; reveals a line; granted by the Soviet Radar Tower.

### YR-GP-406 Unchanged RA2 superweapons (context)

Nuke (Soviet), Iron Curtain (Soviet), Lightning Storm (Soviet), Chronosphere (Allied), plus the Paratrooper
power, carry over with the params in the table. YR does not fundamentally rework them; it adds Force
Shield to every side and the two Yuri superweapons.

---

## 7. Tech buildings & their YR changes

| Name | Internal id | HP | Armor | Key effect | YR change |
|------|-------------|----|-------|-----------|-----------|
| Tech Hospital | CATHOSP / CAHOSP | 800 | concrete | `InfantryGainSelfHeal=1` | **Changed**: auto-heals all owner infantry map-wide (RA2 required entering) |
| Tech Machine Shop | CAMACH | 800 | concrete | `UnitsGainSelfHeal=1` | **New** in YR: auto-repairs all owner vehicles map-wide |
| Tech Civilian Power Plant | CAPOWR | 800 | concrete | `Power=200` | **New** usable tech power in YR |
| Tech Secret Lab | CASLAB | 1000 | steel | `SecretLab=yes` | **New** in YR; grants one random country unit/building |
| Tech Oil Derrick | CAOILD | 1000 | steel | $1000 on capture + $20/100 frames | Unchanged |
| Tech Outpost | CAOUTP | 2000 | concrete | `UnitRepair`, HoverMissile turret | Unchanged |
| Civilian Airport | CAAIRP | – | – | ParaDrop power | Unchanged |

**Blocks.**

### YR-GP-500 Tech Hospital (CATHOSP)

**What.** Capturable neutral hospital. YR changes it from an enter-to-heal building to a **global
auto-heal** aura for the owner: `InfantryGainSelfHeal=1` plus the global
`SelfHealInfantryFrames=50`, `SelfHealInfantryAmount=20`.
**Data keys.** `InfantryGainSelfHeal`, `NeedsEngineer=yes`, `Capturable=yes`, `RadarVisible=yes`,
`Hospital` (old TS flag, commented).
**Numbers.** HP 800, armor concrete, heal 20 HP per 50 frames for all owner infantry.
**Edge cases.** `RadarVisible=yes` keeps it on radar even when unowned. The old `CAHOSP` "old civilian
hospital" is a duplicate with the same heal flag.
**Kind.** Tech building.
**Sources.** RULES-MIRROR `[CATHOSP]`, `[CAHOSP]`, `[General]`; FANDOM YR page.
**Confidence.** high.

### YR-GP-501 Tech Machine Shop (CAMACH)

**What.** New in YR. Capturing it auto-repairs all of the owner's vehicles anywhere on the map
(including ships and aircraft per the wiki).
**Data keys.** `UnitsGainSelfHeal=1`, `NeedsEngineer=yes`, `Capturable=yes`, `RadarVisible=yes`.
**Numbers.** HP 800, armor concrete; `SelfHealUnitFrames=75`, `SelfHealUnitAmount=5`.
**Edge cases.** Repairs are free and global. It does not repair buildings.
**Kind.** Tech building.
**Sources.** RULES-MIRROR `[CAMACH]`, `[General]`; FANDOM YR page.
**Confidence.** high.

### YR-GP-502 Tech Civilian Power Plant (CAPOWR)

**What.** New in YR. A neutral, capturable power plant worth 200 power — effectively a free third-side
power source for whoever engineers it.
**Data keys.** `Power=200`, `NeedsEngineer=yes`, `Capturable=yes`, `Ammo=5`, `RadarVisible=yes`,
`LeaveRubble=yes`.
**Numbers.** HP 800, armor concrete, Power +200.
**Edge cases.** Low HP for its value; often a contested early objective. It does not count as a base
building for victory purposes? (It is `Insignificant`, so it should not.)
**Kind.** Tech building.
**Sources.** RULES-MIRROR `[CAPOWR]`; FANDOM YR page.
**Confidence.** high.

### YR-GP-503 Tech Secret Lab (CASLAB)

**What.** New in YR. Capturing it grants the ability to build **one** semi-random object the owner
otherwise cannot, drawn from a shared pool. (The game selects the reward at **map load**, not at
capture; see Edge cases.)
**Data keys.** `SecretLab=yes`, `NeedsEngineer=yes`, `Capturable=yes`; global pool `SecretInfantry=SNIPE,TERROR,DESO,YURI`,
`SecretUnits=TNKD,TTNK,DTRUCK`, `SecretBuildings=GTGCAN`.
**Numbers.** HP 1000, armor steel. Pool: Sniper, Terrorist, Desolator, Yuri (clone); Tank Destroyer,
Tesla Tank, Demolition Truck; Grand Cannon.
**Edge cases.**
* The reward is decided at map load and is the same for every player who captures that lab; capturing
  multiple labs does not grant multiple rewards. In fact if the map has more labs than pool entries,
  **none** grant anything (vanilla bug, fixed by Ares).
* The vanilla draw order is biased toward earlier pool entries (acknowledged engine bug; ModEnc
  documents the index/number mismatch).
* Ares changes it to per-capture, owner-filtered selection. Mods/Ares may extend the pool.
* Campaign maps can script a specific reward: Escape Velocity → Desolator; Head Games → Grand Cannon;
  Allied Coop 1 → Desolator; Allied Coop 3 → Demolition Truck; Soviet Coop 1 → Sniper;
  Soviet Coop 3 → Chrono Legionnaire; Alliance Coop → Virus; Yuri Coop 1 → Tesla Tank;
  Yuri Coop 2 → Sniper; Yuri Coop 3 → Battle Bunker.
**Kind.** Tech building / production unlock.
**Sources.** RULES-MIRROR `Secret*` keys; MODENC "Secret Lab System"; FANDOM "Tech secret lab".
**Confidence.** high.

### YR-GP-504 Tech changes summary

Hospitals (globalize heal), Machine Shop (new), Civilian Power Plant (new), Secret Lab (new) are the four
YR tech changes. The Oil Derrick and Tech Outpost are unchanged. See the table above.

---

## 8. Movement, navy, amphibious & siege states

### YR-GP-600 Amphibious units

**What.** YR adds real amphibious mobility to several units, via `SpeedType=Hover`/`Amphibious` and
`MovementZone=Amphibious*`.
**Data keys.** `SpeedType`, `MovementZone`, `Locomotor`, `BalloonHover`, `HoverAttack`, `Naval`,
`WaterBound`, `CanBeach` (commented in places).
**Numbers / units:**
* **Robot Tank** — `SpeedType=Hover`, `MovementZone=AmphibiousDestroyer`; crosses water.
* **Yuri Prime** — `SpeedType=Amphibious`, `MovementZone=AmphibiousDestroyer`; walks on water.
* **Amphibious/Hover Transport** — `SpeedType=Hover`, `MovementZone=Amphibious`; carries 12 across
  land/water.
* **Landing Craft (Allied)** — `SpeedType=Hover`, `MovementZone=Amphibious`, 12.
* **Battle Fortress** — `MovementZone=CrusherAll` (not amphibious; crushes walls).
* **Tanya/SEAL/Boris** — infantry with `SpeedType=Amphibious`, `MovementZone=AmphibiousDestroyer`.
**Edge cases.** Hover locomotor (`4A582742-…`) differs from drive (`4A582741-…`); hover ignores the drive
`Force Track` that can get stuck on factory exits (hence Yuri War Factory comments about hover getting
stuck). Float/underwater units use the float locomotor (`2BEA74E1-…`).
**Kind.** Movement system.
**Sources.** RULES-MIRROR locomotion/zone fields across `[ROBO]`, `[YURIPR]`, `[YHVR]`, `[LCRF]`,
`[BFRT]`, `[TANY]`, `[SEAL]`; MODENC "Locomotor"/"MovementZone".
**Confidence.** high.

### YR-GP-601 Navy & submarine states

**What.** Naval units have surface/submerged and cloak states. The **Boomer** is `Underwater=yes` and
`Cloakable=yes`; submerging is delayed by `CloakDelay=.02` min. Surface ships with `Weight >= 3` sink
rather than explode (`ShipSinkingWeight=3.0`).
**Data keys.** `Underwater`, `Cloakable`, `CloakingSpeed`, `CloakingStages=9`, `CloakDelay`, `Naval`,
`Weight`, `Unnatural`, `Sensors`, `SensorsSight`.
**Numbers.** Boomer weight 4; `CloakDelay=.02`; `CloakingStages=9`; Destroyer/`Sensors` still detect
subs.
**Edge cases.** Attacking or taking heavy damage reveals a sub. `Unnatural=yes` makes the Giant Squid
punch rather than grab. Aircraft/sub detection uses `Sensors`/`SensorsSight`.
**Kind.** Navy system.
**Sources.** RULES-MIRROR `[BSUB]`, `[General]` (CloakDelay, ShipSinkingWeight, CloakingStages).
**Confidence.** high.

### YR-GP-602 Siege Chopper states

**What.** The Siege Chopper is a deployable aircraft: it flies with a machine gun and **deploys to land**
as `SCHD` with a 160mm cannon; undeploy returns it to the air.
**Data keys.** `IsSimpleDeployer=yes`, `UnloadingClass=SCHD`, `DeployToLand=yes`, `DeployFire=yes`,
`DeployingAnim=SCHPDEPL`, `PreventAttackMove=yes`, `Turret=yes`, `JumpJet=yes`, `HoverAttack=yes`.
**Numbers.** Air: 35 dmg MG. Ground siege: `160mm` cannon (high per-shot damage vs buildings).
**Edge cases.** It cannot attack-move (`PreventAttackMove`), so the cannon requires a manual deploy.
Deploy/undeploy swaps the entity class; a deployed chopper cannot fly until undeployed. Only available at
the Battle Lab tier (`NAWEAP + TECH`).
**Kind.** Aircraft / siege state machine.
**Sources.** RULES-MIRROR `[SCHP]`; FANDOM "Siege chopper".
**Confidence.** high.

### YR-GP-603 Deploy/undeploy mechanics (GGF, Mastermind, etc.)

**What.** Several YR units are `Deployer=yes`: Guardian GI (rocket), Yuri Clone (PsiWave), Yuri Prime
(blast), Chaos Drone (gas), Siege Chopper (siege), and the Slave Miner (refinery). Some use
`UndeployDelay`.
**Data keys.** `Deployer`, `DeployFire`, `UndeployDelay`, `IsSimpleDeployer`, `UnloadingClass`.
**Numbers.** Yuri Clone `UndeployDelay=150`; Yuri Prime `UndeployDelay=75`.
**Edge cases.** `DeployFire` means deploying itself fires the special weapon (PsiWave/gas); others
deploy into a different class. Deployed units can have different crush/self-heal rules (e.g. Guardian
GI `DeployedCrushable=no`).
**Kind.** Movement/state system.
**Sources.** RULES-MIRROR per-unit fields; MODENC.
**Confidence.** high.

---

## 9. Campaigns

### 9.1 Allied campaign (7 missions)

| # | Name | Mission id (map) | Objectives | Scripted events / special map logic |
|---|------|------------------|------------|-------------------------------------|
| 1 | **Time Lapse** | all01 | Destroy the under-construction Psychic Dominator on Alcatraz; protect the time machine | Intro; Einstein's time travel; San Francisco; campaign starts with limited forces |
| 2 | **Hollywood and Vain** | all02 | Destroy Yuri's Hollywood base / Grinder operation | Mind-controlled civilians fed to Grinders; Hollywood set pieces; Grinders are the econ target |
| 3 | **Power Play** | all03 | Destroy the nuclear missile silo threatening Seattle; rescue Massivesoft | Massivesoft/Chairman Bing; Genetic Mutator R&D revealed; silo is the primary objective |
| 4 | **Tomb Raided** | all04 | Rescue Einstein from the Egyptian pyramid; destroy Yuri's Egypt base | Captured Psychic Dominator usable against Yuri; desert theater; Tanya rescue |
| 5 | **Clones Down Under** | all05 | Destroy the Sydney cloning facility | Spy-satellite recon; Yuri planned to replace Allied leaders with clones |
| 6 | **Trick or Treaty** | all06 | Protect the London Houses of Parliament until the treaty is ratified | Mind-controlled Eva; waves of Yuri attacks; Soviet assistance arrives |
| 7 | **Brain Dead** | all07 | Destroy Yuri's Antarctic base and the final Psychic Dominator | Capture abandoned Soviet base in Tierra del Fuego; Radar Tower; Allied MCV chronoshifted in; ending merges timelines |

**Blocks.**

### YR-GP-700 Allied campaign arc

**What.** Seven missions following Einstein's time-travel fix. The campaign's through-line is
destroying each Psychic Dominator and its support infrastructure (Grinders, nuclear silo, cloning
facility) before Yuri can complete his psychic network.
**Data keys.** Campaign map files are `.map`; mission scripting via triggers and the `VariableNames`
list (e.g. `Smithsonian Destroyed`, `Prisoners Freed`, `Train Stolen`, `Machineshop`, `Hospital`).
**Numbers.** No numeric progression; each mission grants a fixed starting force/credits.
**Edge cases.**
* Mission 1 is a set-piece defense of the Alcatraz dominator/time machine.
* Missions 4 and 7 allow using a captured Psychic Dominator or chronoshifted MCV.
* Mission 7's ending merges the two timelines (Carville appears instead of Yuri).
* "Clones Down Under" is mission 5 (per the wiki navbox); some fan sources number it differently.
**Kind.** Campaign.
**Sources.** FANDOM "Command & Conquer: Red Alert 2 - Yuri's Revenge" plot section; FANDOM mission
category; RULES-MIRROR `[VariableNames]`.
**Confidence.** high on names/order; med on per-mission objective details (single-source).

### 9.2 Soviet campaign (7 missions)

| # | Name | Objectives | Scripted events / special map logic |
|---|------|------------|-------------------------------------|
| 1 | **Time Shift** | Capture the Allied time machine in San Francisco | Overshoots to the Cretaceous; survive/wait out the error |
| 2 | **Deja Vu** | Destroy Einstein's Black Forest lab and the Chronosphere | **T-Rex** enemies in the dinosaur segment of the time jump; mirrored RA2 "Mirage" |
| 3 | **Brain Wash** | Destroy Yuri's London Psychic Dominator; liberate the mind-controlled Allied base | Allies surrender and join the Soviets afterward |
| 4 | **Romanov on the Run** | Rescue Premier Romanov in Morocco; clear Yuri's airport forces | Romanov found partying with locals |
| 5 | **Escape Velocity** | Destroy Yuri's South Pacific submarine HQ and capture the launch facility | Secret Lab grants **Desolator**; finds the Moon rocket |
| 6 | **To the Moon** | Destroy Yuri's lunar complex and Lunar Command | **Lunar theater**; only Cosmonauts (and Iraq's Desolators) usable as infantry; no ore, finite credits (55k/70k/85k by difficulty); crates worth 5k; Floating Discs, Magnetrons, Masterminds; separate power grids per outpost |
| 7 | **Head Games** | Destroy the Transylvanian castle; free the mind-controlled Allied and Soviet bases | **Two Psychic Beacons** control one Allied and one Soviet base; Secret Lab grants **Grand Cannon**; Grinder-fed civilian economy; castle has one of the highest HP totals in C&C; Yuri escapes via time machine to the Cretaceous |

**Blocks.**

### YR-GP-701 Soviet campaign arc

**What.** Seven missions in which the Soviets hijack the time machine, accidentally visit the
Cretaceous, then return to hunt Yuri across San Francisco, London, Morocco, the South Pacific, the Moon,
and finally Transylvania.
**Data keys.** `.map` campaign files; triggers; `VariableNames`.
**Numbers.** To the Moon gives 55,000 / 70,000 / 85,000 credits by difficulty; two 5,000-credit crates
from Yuri outposts; no ore harvesting (no income beyond crates). Head Games' castle is extremely tanky
(cited as second-highest HP in C&C history, after the Scrin towers).
**Edge cases.**
* **Deja Vu** is the only mission with T-Rex enemies (time-jump segment).
* **To the Moon** restricts infantry to Cosmonaut + Desolator; air units unusable (vacuum); floating
  discs still present for Yuri.
* **Head Games** is the only final mission not in snow, and cannot build a naval yard; the Chronosphere
  is unavailable because Einstein's prototype was destroyed in Deja Vu.
* Yuri is not killed but time-stranded; the ending has communism expanding into space.
**Kind.** Campaign.
**Sources.** FANDOM YR plot + "To the Moon" + "Head Games" pages; FANDOM mission category.
**Confidence.** high on names/order; med on per-mission details.

### 9.3 Cooperative / bonus missions

**What.** YR ships cooperative campaign maps (for two players over CnCNet/network): Allied Coop 1–3,
Alliance Coop, Soviet Coop 1–3, Yuri Coop 1–3, plus the eight-mission Alliance campaign family. Several
grant scripted Secret Lab rewards (listed in YR-GP-503).
**Edge cases.** Coop maps may not work correctly in standard multiplayer (`GameModes` notes
`cooperative`).
**Kind.** Campaign / coop.
**Sources.** FANDOM mission navbox; RULES-MIRROR/`Secret*`; MODENC "GameModes".
**Confidence.** med.

---

## 10. Skirmish / multiplayer modes & options

### YR-GP-800 Game modes

**What.** YR (and RA2) multiplayer supports several named modes, defined per-map via the `GameModes`
flag. ModEnc lists the supported set.
**Data keys.** Map flag `GameModes` (comma-separated); default mode via `GameMode=`.
**Numbers / supported modes:**
* `standard` — normal "Battle" (free-for-all).
* `teamgame` — Team Alliance (**YR only**).
* `megawealth` — Megawealth (high starting credits/economy).
* `duel` — Land Rush (fast, rush-oriented).
* `meatgrind` — Meat Grinder (attrition, high unit counts).
* `navalwar` — Naval War (naval focus).
* `cooperative` — Co-Op campaign (may misbehave on standard MP maps).
* `siege` — obsolete Siege mode (RA2), replaced by Team Alliance in YR.
Plus community/umbrella modes: **Unholy Alliance** (all players share a side/allow-all-arsenal sandbox
vs AI), **Free For All**, and **Tournament** (CnCNet map packs).
**Edge cases.** `Unholy Alliance` is a mode/umbrella rather than a `GameModes` token in vanilla data
(Mental Omega documents it as a shared-arsenal sandbox; CnCNet ships "Unholy Alliance" maps). "Siege"
is deprecated in YR. A map is only selectable in modes its `GameModes` list includes.
**Kind.** Multiplayer modes.
**Sources.** MODENC "GameModes", "GameMode"; CNC-NET map packs; MOAPYR "Unholy Alliance".
**Confidence.** high on the ModEnc token list; med on Unholy Alliance semantics.

### YR-GP-801 Skirmish options

**What.** Standard RA2/YR skirmish/shell options. Superweapons individually disableable
(`DisableableFromShell`) and short-game, crates, etc.
**Data keys.** Superweapon `DisableableFromShell` (Nuke/Iron Curtain/Lightning Storm/Chronosphere/Force
Shield/Dominator/Mutator = yes; Paratroopers/Spy Plane/Psychic Reveal/Chrono Warp = no). `MultiplayerAICM`
(AI money), `AIVirtualPurifiers`, `HarvestersPerRefinery`, `AIExtraRefineries`, difficulty via
`TeamDelays`, `AIHateDelays`.
**Numbers.** AI money coefficient 400/0/0 (hard/normal/easy in this build); virtual purifiers 4/2/0;
harvesters per refinery 2/2/1; extra AI refineries 2/1/0; AI slave-miner counts 4/3/2.
**Edge cases.** Disabling a superweapon is per-side-agnostic (the shell check). `FineDiffControl=no`
means only three difficulty levels by default. `MultiplayerAICM=400,0,0` means the AI is not given a
harvest/economy shortcut on normal/easy in this build — a balance choice, not a bug.
**Kind.** Skirmish options.
**Sources.** RULES-MIRROR `[General]`, `[MultiplayerDialogSettings]`, `DisableableFromShell` fields.
**Confidence.** high.

### YR-GP-802 Multiplayer country selection

**What.** In MP each player picks a country (10 total). Countries are cosmetic except for the unique
unit/bonus.
**Data keys.** `RequiredHouses`, `SecretHouses`, country-specific `SuperWeapon`.
**Numbers / country bonuses (YR, base RA2 set):**
| Country | Side | Unique |
|---------|------|--------|
| America | Allied | American Paratroopers (8× GI, free power) |
| Korea (Alliance) | Allied | – (no unique unit; standard arsenal) |
| France | Allied | Grand Cannon (`GTGCAN`) |
| Germany | Allied | Tank Destroyer (`TNKD`) |
| Britain | Allied | Sniper (`SNIPE`) |
| Russia | Soviet | Tesla Tank (`TTNK`) |
| Cuba (Confederation) | Soviet | Terrorist (`TERROR`) |
| Iraq (Arabs) | Soviet | Desolator (`DESO`) |
| Libya (Africans) | Soviet | Demolition Truck (`DTRUCK`) |
| Yuri (YuriCountry) | ThirdSide | Whole faction is the "bonus" |

**Edge cases.** YR did not remove these; the unique units can also be granted to other factions by the
Tech Secret Lab. Korea's lack of a unique is a known RA2 quirk. Some fan mods reassign these.
**Kind.** Multiplayer rosters.
**Sources.** RULES-MIRROR `RequiredHouses=` fields (`SNIPE`→British, `TNKD`→Germans, `TTNK`→Russians,
`TERROR`→Confederation, `DESO`→Arabs, `DTRUCK`→Africans, Grand Cannon→French); FANDOM Tech secret lab;
FANDOM YR page.
**Confidence.** high.

---

## 11. Maps, theaters & palettes

### YR-GP-900 Map formats

**What.** YR uses `.yrm` for player maps and `.map` for campaign missions; RA2 uses `.mpr`. `.mpr`
maps can be renamed to `.yrm` to play in YR (common community practice).
**Data keys.** Map file extension; `[Map]` `Theater=`, `GameModes=`, `GameMode=`.
**Numbers.** `.yrm` = YR multiplayer/skirmish; `.map` = single-player missions; `.mpr` = RA2 maps.
**Edge cases.** Renaming `.mpr`→`.yrm` works because the formats are compatible; the map's theater
must exist in YR.
**Kind.** Map data.
**Sources.** MODENC "Theater"; community/Steam guidance; CnCNet forums.
**Confidence.** high.

### YR-GP-901 Theaters

**What.** Theaters select the tileset and palette for a map. The set is **hardcoded**; mods add tiles to
existing theaters rather than new theaters. YR adds **Desert**, **NewUrban**, and **Lunar** relative to
RA2's Temperate/Snow/Urban (+Generic).
**Data keys.** `Theater=` on maps; theater INI files; `NewTheater=yes` on building art selects the
alternate-suffix art.
**Numbers / valid theaters:**

| Theater | Abbrev | NewTheater char | Tile ext | Works in |
|---------|--------|-----------------|----------|----------|
| Generic/Marble | – | G | – | RA2/YR |
| Temperate | T | T | TEM/MMT | RA2/YR |
| Snow (arctic) | A | A | SNO/MMS | RA2/YR |
| Urban | U | U | URB/MMU | RA2/YR |
| Desert | D | D | DES/MMD | **YR only** |
| NewUrban | N | N | UBN/MMT | **YR only** |
| Lunar | L | L | LUN/MML | **YR only** |

**Edge cases.** Changing a map's theater can cause graphical errors if the tileset has no equivalent
tiles. `Theater=yes` on an object hardcodes it as a terrain object (ore can grow in its foundation).
Lunar is used by the Soviet Moon mission (`To the Moon`).
**Kind.** Map/theater system.
**Sources.** MODENC "Theaters", "Theater"; FANDOM "To the Moon".
**Confidence.** high.

### YR-GP-902 Palettes

**What.** Each theater and each unit type uses palette files (`.pal`). Theater palettes drive terrain;
unit palettes drive SHP/voxel remaps; house colors come from house-color palettes applied at draw time.
Per-country appearance differences in vanilla YR are limited to house color and the alternate arctic art
flag (`AlternateArcticArt=yes`, e.g. SEAL/SEALA), not a per-country palette file.
**Data keys.** `Palette=` (art), `AlternateArcticArt`, `Theater=` (object art), house color.
**Numbers.** Palette files are per theater (temperate/snow/urban/desert/newurban/lunar) and per side
(unit…). Exact filenames are variant-specific and not enumerated here.
**Edge cases.** "Per-country palettes" in the sense of full separate rosters does not exist in vanilla
YR — each country shares its side's art, differing only by unique unit and house remap. The community
**Terrain Expansion** (OmegaBolt) later adds many more tiles/palettes per theater but is not vanilla.
**Kind.** Art/palette system.
**Sources.** MODENC "Theater"/"Theaters"; RULES-MIRROR `AlternateArcticArt`; community Terrain Expansion.
**Confidence.** med (the "per-country palette" phrasing is not a vanilla concept; flagged).

---

## 12. Complete YR-vs-RA2 delta list

### Added — Yuri (ThirdSide), new faction
* Structures: Construction Yard, Bio Reactor, Barracks, War Factory, Submarine Pen, Psychic Radar,
  Grinder, Battle Lab, Citadel Wall, Tank Bunker, Gattling Cannon, Psychic Tower, Cloning Vats,
  Genetic Mutator, Psychic Dominator; campaign Psychic Beacon, Command Center, Rocket Launch Pad.
* Infantry: Initiate, Engineer, Brute, Virus, Yuri Clone, Yuri Prime, Slave, Attack Dog (Yuri),
  campaign Cosmonaut.
* Vehicles: Slave Miner (+ deployed Ore Refinery), Lasher, Gattling Tank, Chaos Drone, Magnetron, MCV,
  Mastermind, Amphibious/Hover Transport, Boomer.
* Aircraft: Floating Disc.
* Support/super: Psychic Reveal, Mutation (Genetic Converter), Domination (Psychic Dominator).

### Added — Allies
* Guardian GI; Robot Tank; Robot Control Center; Battle Fortress; Navy SEAL promoted to buildable;
  IFV modes 13–16 (Initiate, Virus, Yuri Prime, Guardian GI).

### Changed — Allies
* Tanya: $1000 → $1500, one at a time, C4 now works on land vehicles.
* IFV weapon/turret table expanded to 17 modes.

### Added — Soviets
* Boris; Siege Chopper (deployable to 160mm siege); Industrial Plant (vehicle cost ×0.75);
  Battle Bunker (5 infantry); Spy Plane support power.

### Removed / moved — Soviets
* Psi-Corps trooper / Yuri → Yuri Clone (ThirdSide, $800).
* Psychic Sensor → Yuri Psychic Radar (+ Psychic Reveal).
* Cloning Vats → Yuri only (Soviet version removed; recycling moved to the Grinder).

### Added / changed — Global
* Force Shield support power (all sides via Battle Lab).
* Tech Hospital globalized auto-heal; Tech Machine Shop (new); Tech Civilian Power Plant (new);
  Tech Secret Lab (new, random country unlock).
* Deserts, NewUrban, Lunar theaters; `.yrm` map format.
* New skirmish mode: Team Alliance (replaces Siege).

### Unchanged
* Base RA2 units/structures that carry over; Ore/Gems; Nuke/Iron Curtain/Lightning Storm/Chronosphere;
  Paratroopers; Oil Derrick; Tech Outpost; base skirmish modes.

---

## 13. Coverage checklist

| Scope item | Covered | Where |
|-----------|---------|-------|
| Yuri ConYard / Bio Reactor / Barracks / War Factory / Sub Pen | yes | YR-GP-010..015, table 2.1 |
| Yuri Psychic Radar / Grinder / Battle Lab / Citadel Wall / Tank Bunker | yes | YR-GP-016..021 |
| Yuri Gattling Cannon / Psychic Tower / Cloning Vats / Genetic Mutator / Psychic Dominator | yes | YR-GP-021..025 |
| Yuri campaign Psychic Beacon | yes | YR-GP-026 |
| Yuri infantry: Initiate, Engineer, Brute, Virus, Yuri Clone, Yuri Prime, Slave, Cosmonaut | yes | YR-GP-040..047 |
| Yuri vehicles: Slave Miner, Lasher, Gattling Tank, Chaos Drone, Magnetron, MCV, Mastermind | yes | YR-GP-060..066 |
| Yuri aircraft: Floating Disc | yes | YR-GP-080 |
| Yuri ships: Amphibious Transport, Boomer | yes | YR-GP-067, YR-GP-068 |
| Allied: Guardian GI | yes | YR-GP-100 |
| Allied: Robot Tank, Robot Control Center | yes | YR-GP-101, YR-GP-102 |
| Allied: Battle Fortress | yes | YR-GP-103 |
| Allied: Navy SEAL promoted, Tanya changes | yes | YR-GP-104, YR-GP-105 |
| Allied: IFV passenger-table additions | yes | YR-GP-106 |
| Soviet: Boris | yes | YR-GP-200 |
| Soviet: Siege Chopper | yes | YR-GP-201 |
| Soviet: Industrial Plant | yes | YR-GP-202 |
| Soviet: Battle Bunker | yes | YR-GP-203 |
| Soviet: Spy Plane | yes | YR-GP-204 |
| Soviet removals: Psi-Corps, Psychic Sensor, Cloning Vats | yes | YR-GP-205 |
| Slave economy (deploy/repair/replace, defection) | yes | YR-GP-300 |
| Grinder refund | yes | YR-GP-301 |
| Credit siphon (Floating Disc) | yes | YR-GP-302 |
| Ore purifier / income multipliers | yes | YR-GP-304 |
| Bio Reactor internment | yes | YR-GP-303 |
| Support powers/superweapons full params (Domination, Mutation, Force Shield, Psychic Reveal, Paratroopers) | yes | YR-GP-400..406 |
| Tech buildings & YR changes (Hospital, Machine Shop, Civ Power Plant, Secret Lab; Oil Derrick/Outpost) | yes | YR-GP-500..504 |
| Movements: amphibious, navy, siege chopper states, deploy/undeploy | yes | YR-GP-600..603 |
| Campaigns: Allied 7 + Soviet 7, objectives, Moon/Transylvania/T-Rex | yes | YR-GP-700, YR-GP-701, tables 9.1/9.2 |
| Skirmish/multiplayer modes & options | yes | YR-GP-800..801 |
| Maps (.yrm), theaters (Lunar), palettes, country rosters | yes | YR-GP-900..902, YR-GP-802 |
| Complete YR-vs-RA2 delta list | yes | section 12 |

---

## 14. Open questions / top uncertainties

1. **Grinder cost** — RULES-MIRROR says 600; CNCNZ says 1000. Mirror used; verify against a second
   retail dump before encoding a constant.
2. **Slave Miner cost** — mirror 1500 vs CNCNZ 1750. Mirror used; verify.
3. **Chaos Drone cost** — mirror 800 vs CNCNZ 600. Mirror used; verify.
4. **Grinder refund split** — vehicles 100% / infantry 50% is community-attested (wiki/Baidu) but the
   exact engine flags that implement it are not visible in the stats; confirm from pseudocode/source.
5. **Floating Disc credit-siphon rate** — existence is certain; the drain rate is engine-internal and
   not in the visible data.
6. **Psychic Dominator internal display name** — the data wrongly names it "Lightning Storm"; confirm
   whether the UI actually shows the bug in vanilla or fixes it via CSF strings.
7. **Per-country palettes** — vanilla YR does not have per-country palette files; the request phrasing
   may intend per-country *rosters* (covered) rather than palettes. Confirm intent.
8. **Unholy Alliance semantics** — whether it is a first-class `GameModes` token or only a map
   pack/umbrella (CnCNet) in vanilla YR.
9. **Alcatraz mission numbering / name variants** — some fan sources number allied missions differently
   (mission 1 "Time Lapse" is stable, order 4–5 occasionally swapped). Confirm against the mission
   loader's internal order.
10. **Yuri Command Center / Rocket Launch Pad stats** — campaign/editor-only; stats are editor-defined
    and may not match shipped maps.
11. **Cosmonaut availability** — the wiki and the data agree it is campaign-only and map-granted; confirm
    there is no skirmish path (the data prereq `NAPILE` is a placeholder).
12. **Yuri cost/HP values generally** — the mirror is retail but verifying each against a second
    independent retail `rulesmd.ini` dump would raise confidence from high to certain.
