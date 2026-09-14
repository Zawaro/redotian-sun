# Red Alert 2 — Gameplay Systems & Content Rosters (Deep Research)

Research-only reference for the unified Redot engine (Tiberian Sun / Firestorm / RA2 / YR).
Primary game: **Command & Conquer: Red Alert 2 (2000, Westwood Pacific / EA)**. Yuri's Revenge (YR) additions are called out where they change a system; the base-game scope is authoritative here.

## Method & Confidence

* **Web only.** No game files on this machine were read. Primary sources: ModEnc flag pages, the archived official Westwood RA2 website (mirrored by CNC Labs), CNCNZ.com arsenal pages, cnc.fandom.com unit pages, the Project Perfect Mod / CnCNet modding forums, and published `rules(md).ini` mirrors on GitHub.
* **Cross-check rule.** Every numeric claim is attested by ≥2 independent sources where possible; single-source numbers are flagged.
* **Confidence legend**
  * **high** — 2+ independent sources agree, or official archived material.
  * **med** — 1 authoritative source, or 2 sources with a minor mismatch.
  * **low** — single community source, inferred, or contested.
* **Conflict policy.** Where sources disagree, all values are listed in **Numbers**, with a note. Do not silently pick one.
* **No code**, no `rules.ini` dumps quoted; keys are named, not pasted.

### Source key

| Tag | Source |
|-----|--------|
| MODENC | `modenc.renegadeprojects.com` (flag pages: BuildCat, RequiredHouses, ForbiddenHouses, Prerequisite, The Prerequisite System, Agent, Locomotor, MovementZone, SpySat, GapGenerator, Shroud, Crate, Powerups, MultipleFactory, MultiplayerDialogSettings, Houses, Tiberium, Powerups) |
| WW-ARCHIVE | Official Westwood RA2 site unit/tech pages, archived and mirrored at `cnclabs.com/redalert2/` |
| CNCNZ | `cncnz.com/games/red-alert-2/*` (allied-units, soviet-units, allied-structures, soviet-structures, tech-buildings, factions) |
| FANDOM | `cnc.fandom.com/wiki/...` (unit pages: Apocalypse, Kirov, Ore, Rules.ini, Garrisoning, Spy, Chrono Miner, War Miner) |
| CNC-CENTRAL | `cnc-central.fandom.com/wiki/Rules.ini` (type lists / side mapping) |
| CNC-NET | `forums.cncnet.org` (Infinite ore; How Does Brutal AI work) |
| PPM | Project Perfect Mod forums (`ppmforums.com`) |
| RULES-MIRROR | `raw.githubusercontent.com/hzhangxyz/rulesmd.ini/master/rules.ini` — the retail RA2 `rules.ini` (a web mirror, not a local file) |
| OPENRA | `forum.openra.net` / OpenRA RA2 data discussions (cross-check only; OpenRA is a reimplementation, not the retail rules) |

---

## 1. Economy

### RA2-GP-001 Ore & Gems (resources)

**What.** RA2's two map resources. Ore (yellow) is common; Gems ("multi-colored jewels") are rarer and worth more. Both are terrain overlay tiles, not entities. Ore and gems are harvested by faction miners and converted to credits at an Ore Refinery. There are **no ore silos** in RA2 — storage capacity was removed; a refinery absorbs all loads (Ore page, FANDOM).

**Data keys.**
* Overlay types in `[OverlayTypes]` / `[Tiberiums]`: ore tiles reuse the TS Tiberium graphics `TIB01`–`TIB12`; gems use `GEM01`–`GEM04` (FANDOM/ModEnc; exact frame counts variant-dependent).
* `GoldValue` — credits per ore bail (see Numbers). `GemValue` — credits per gem bail.
* Growth/spread: `GrowthRate`, `TiberiumGrows`, `TiberiumSpreads`, `OreGrows`, `OreSpreads`, `GrowthPercentage`, `TiberiumLayout` (ModEnc).
* Ore can be destroyed by force-fire when a weapon's warhead has `Tiberium=yes` (ModEnc `Tiberium (INI flag)`).

**Numbers.**
* Per bail: **GoldValue=25**, **GemValue=50** (CnCNet; "goldvalue … changes the value per bail"). Gems are ~2× ore (FANDOM: "gems provide twice the money that ore does" for RA1; RA2 consistent via miner capacities).
* Miner capacities that corroborate this: Chrono Miner **$500 ore / $1000 gems**; War Miner **$1000 ore / $2000 gems** (FANDOM).
* `GrowthRate=5` minutes between growth in the retail RA2 `rules.ini` (RULES-MIRROR). A CnCNet modding post quotes `GrowthRate=2` and `BailCount=28 / GemValue=50 / GoldValue=25` "from rules.ini" — that set matches **RA1/TS**, not RA2; treat the 2-minute / 28-bail numbers as invalid for RA2 (conflict noted).
* `TiberiumGrows=yes`, `TiberiumSpreads=yes` in retail RA2 (RULES-MIRROR).

**Edge cases.**
* Gems do not spread and cannot be regrown from an empty field (FANDOM: RA1 gems don't spread; RA2 gems likewise finite).
* An ore patch can be exhausted; miners then wander (CnCNet "Infinite ore": "a truck cannot harvest more than 10 bails [per cell], otherwise it exhausts the ore cell").
* RA2 `TiberiumHeal=.010` minutes — units with `TiberiumHeal=yes` (none in vanilla) regen in ore.
* `OreTwinkleChance=30`, `OreTwinkle=TWNK1` (RULES-MIRROR) — cosmetic.

**Kind.** Core economy resource.

**Sources.** FANDOM (Ore), CNC-NET (Infinite ore), RULES-MIRROR, MODENC (Tiberium/OverlayTypes), WW-ARCHIVE (Chrono Miner).

**Confidence.** high (values), high (miner capacities), medium (exact per-bail value, since the primary flag is a forum quote not seen in the RA2 `[General]` dump).

---

### RA2-GP-002 Ore Miners (full list)

**What.** Mobile harvesters. Each is produced by / delivered with an Ore Refinery; each refinery delivers one free miner on completion. Ore is loaded in "bails" per cell; when full the miner returns (or teleports) to the nearest refinery and unloads.

**Data keys.** `Harvester=yes`, `Storage` (capacity), `Teleporter=yes` (Chrono Miner), `Dock=` (refinery), `HarvesterUnit=HARV,CMIN` (preferred-harvester list in `[General]`), `HarvestersPerRefinery=2` (RULES-MIRROR, controls AI build-next logic). Slave Miner (YR) uses a slave entity.

**Numbers.**

| Name | Internal id | Cost | Armor | Prereq | Weapon(s) | Role | Notable logic |
|------|-------------|------|-------|--------|-----------|------|---------------|
| Chrono Miner (Allied) | `CMIN` | $1400 | Medium | Allied Ore Refinery | none | Ore hauler | Teleports (Chrono Locomotor) from field to Refinery on full load; capacity $500 ore / $1000 gems; unarmed; can be erased only by special means; ejecting Parasites kicks them |
| War Miner (Soviet) | `HARV` | $1400 | Medium | Soviet Ore Refinery | 20 mm MG (anti-infantry) | Ore hauler + light self-defense | Full $1000 ore / $2000 gems; no teleport; can crush infantry; higher capacity |
| Slave Miner (Yuri, YR) | `SMIN` | $1400 | Medium | Yuri Ore Refinery | none | Ore hauler | Deploys into a stationary mining rig and spawns Slave Miner slaves (`SLAV`) that carry ore; slaves replaced for free when killed |

**Edge cases.**
* Chrono Miner teleports only to a *vacant* refinery docking pad; otherwise it drives (CNCNZ).
* If a Chrono Miner is killed mid-teleport it can be lost (no special rule).
* `Jumpjet`/`MovementZone=Fly` harvesters cannot manually dock (ModEnc MovementZone bugs, fixed in Phobos).
* On `HarvesterTruce=yes` MP option, harvesters are not auto-attacked (ModEnc MultiplayerDialogSettings).
* `Cruise`/allied Chrono Miner is *half* the War Miner's capacity by design (FANDOM).

**Kind.** Economy unit.

**Sources.** FANDOM (Chrono Miner, War Miner), CNCNZ (Allied/Soviet Units), WW-ARCHIVE (Chrono Miner), MODENC (Locomotor/Teleport, MultiplayerDialogSettings).

**Confidence.** high.

---

### RA2-GP-003 Ore Refinery & Docking

**What.** Processes miner loads into credits; also the tech prerequisite for the War Factory. Comes with one free miner. Docking is a physical pad; one miner at a time (vanilla) occupies the pad.

**Data keys.** `Refinery=yes`, `Storage=` (RA2 refineries use `Storage` internally but no visible silo), `Dock=`, `FreeUnit=`/delivery of the miner, `NumberOfDocks`. Ore Purifier multiplies value via `PurifierBonus`.

**Numbers.**
* Ore Refinery cost **$2000**, power **−50**, prereq Power Plant / Tesla Reactor (WW-ARCHIVE).
* Free unit on completion: 1 Chrono Miner (Allied) or 1 War Miner (Soviet).
* `HarvestersPerRefinery=2` default (RULES-MIRROR; not a hard cap, just an AI hint).

**Edge cases.**
* Refinery can be infiltrated by a Spy for a cash steal (see RA2-GP-040).
* Selling a refinery leaves the delivered miner alive.
* Refineries are `Spyable=yes` and capturable by Engineers.

**Kind.** Economy structure.

**Sources.** WW-ARCHIVE (structures), CNCNZ (structures), RULES-MIRROR.

**Confidence.** high.

---

### RA2-GP-004 Ore Purifier

**What.** Allied-only support building. Every ore/gem bail a miner delivers is worth **+25%**.

**Data keys.** `Purifier=yes`, `PurifierBonus=.25` (`[General]`, RULES-MIRROR). Limit-one-per-player is a hard-coded special-case (CNCNZ note).

**Numbers.**
* Cost **$2500**, power **−200**, prereq Ore Refinery + Battle Lab (WW-ARCHIVE).
* `PurifierBonus=.25` = +25% credits per bail (RULES-MIRROR).

**Edge cases.**
* Only one Ore Purifier per player can exist (CNCNZ).
* Ore Purifier **cannot be infiltrated by a Spy nor captured by an Engineer** (FANDOM Ore purifier, community corroboration) — unlike a Refinery.
* Applies to gems as well as ore (it scales the bail value).

**Kind.** Economy structure (Allied unique-ish; buildable by all Allied countries).

**Sources.** MODENC (General flags), RULES-MIRROR, WW-ARCHIVE, CNCNZ, FANDOM.

**Confidence.** high.

---

### RA2-GP-005 Oil Derrick & Capture Income

**What.** Neutral "tech building" placed on maps. An Engineer captures it; the capturing player receives an instant bonus then a trickle of income.

**Data keys.** Tech building sections `[CAOILD]` (Oil Derrick), `Capturable=yes`, `Engineer=yes`-style capture, `ProduceCashStartup=`, `ProduceCashAmount=`, `ProduceCashDelay=` (ModEnc/Guide naming; exact RA2 keys).

**Numbers.**
* Instant bonus on first capture: **$1000** (CNCNZ).
* Ongoing income: **$20 per second** while owned (CNCNZ). Some sources phrase it as a fixed `ProduceCashAmount` per interval.
* Sale/destruction ends the income.

**Edge cases.**
* Re-capturing by an enemy keeps the structure and flips income.
* Multiple derricks stack; a map may have many.
* AI does not actively seek derricks as strongly as humans (community observation, low confidence).

**Kind.** Economy tech building.

**Sources.** CNCNZ (tech-buildings), WW-ARCHIVE (Engineer text), MODENC (tech-building keys).

**Confidence.** med-high.

---

### RA2-GP-006 Tech Buildings (full list)

**What.** Neutral capturable structures that grant effects when an Engineer enters. All are capture-only (not buildable).

**Numbers / list.**

| Name | Effect | Notes |
|------|--------|-------|
| Tech Oil Derrick | +$1000 on capture, then $20/s | continuous income |
| Tech Hospital | heals infantry ordered to enter it | heals only that player's infantry |
| Tech Outpost | repairs vehicles ordered to enter it | armed with a modified Patriot (ground + air) |
| Tech Airport | grants the Paradrop support power | 6 GIs (Allied) / 9 Conscripts (Soviet) per drop |
| Tech Power Plant / other | varies per map | RA2 ships a small neutral set; maps add more via scripts |

**Edge cases.**
* Multiple Tech Airports do **not** stack Paradrop (CNCNZ).
* Hospital/Outpost are healing/repair points, not repair-bays in the Service Depot sense.
* Captured tech buildings remain `Civilian`-owned if not recaptured? No — they become owned by the capturer.
* Outpost's Patriot can shoot ground (CNCNZ).

**Kind.** Neutral tech / capture.

**Sources.** CNCNZ (tech-buildings), WW-ARCHIVE (Engineer description).

**Confidence.** high (list), med (exact neutral set per map).

---

### RA2-GP-007 Crates (full powerup list)

**What.** Random map pickups. In RA2 a collected crate is removed and a new crate is placed elsewhere. Contents are defined in `[Powerups]` in `rules(md).ini`; frequency in `[CrateRules]`.

**Data keys.**
* `[Powerups]` entries `Name = <chance>,<anim>,<water?>,<special>` (ModEnc Powerups).
* `[CrateRules]`: `CrateMaximum=255`, `CrateMinimum=1`, `CrateRadius=3.0`, `CrateRegen=3` minutes, `SilverCrate=HealBase`, `WoodCrate=Money`, `WaterCrate=Money`, `SoloCrateMoney=5000`, `UnitCrateType=none`, `FreeMCV=yes`, `CrateImg=CRATE`, `WaterCrateImg=WCRATE`, `HealCrateSound=HealCrate` (RULES-MIRROR).
* Related flags: `Crate=yes` (OverlayType), `CrateGoodie=yes` (units eligible for unit crates), `CrateTrigger`.

**Numbers.** Default YR shares (chance = x/**110** in RA2/YR; x/**441** TS/FS; x/**146** RA):

| CrateType (FA2 id) | Powerup | Chance | Animation | Water? | Special | Effect |
|----|---------|--------|-----------|--------|---------|--------|
| 0 | Money | 20 | MONEY | yes | 2000 | credits (2000 + random 0–900) |
| 1 | Unit | 20 | none | no | — | one free `CrateGoodie=yes` vehicle |
| 2 | HealBase | 10 | HEALALL | yes | — | full-heal all owner's units; forces low-IQ scatter |
| 3 | Cloak | 0 | CLOAK | yes | — | `Cloakable` to all in `CrateRadius` |
| 4 | Explosion | 0 | none | yes | 500 | C4Warhead blast on the collector only |
| 5 | Napalm | 0 | none | no | 600 | FlameDamage blast on the collector only |
| 6 | Squad | 0 | none | no | — | forced to Money behaviour in TS–YR |
| 7 | Darkness | 0 | SHROUDX | yes | — | shrouds entire map (beats SpySat) |
| 8 | Reveal | 10 | REVEAL | yes | — | reveals map except Gap Generator fields |
| 9 | Armor | 10 | ARMOR | yes | 1.5 | ×1.5 Strength (once) |
| 10 | Speed | 10 | SPEED | yes | 1.2 | ×1.2 Speed (once) |
| 11 | Firepower | 10 | FIREPOWR | yes | 2.0 | ×2.0 weapon damage (once) |
| 12 | ICBM | 0 | CHEMISLE | yes | — | one free Nuke shot (no-op if Nuke already built) |
| 13 | Invulnerability | 0 | ARMOR | yes | 1.0 | no-op in TS+ (plays anim) |
| 14 | Veteran | 20 | VETERAN | yes | 1 | instant promotion (once; money if maxed) |
| 15 | IonStorm | 0 | none | yes | — | no-op (plays anim) |
| 16 | Gas | 0 | none | yes | 100 | `[Gas]` warhead to cell + 8 neighbours |
| 17 | Tiberium | 0 | none | no | — | spawns an ore/Tiberium patch |
| 18 | Pod | 0 | none | no | — | no-op (Drop Pod scrapped) |
| 19+ | random skirmish crates | — | — | — | — | per `rules.ini` chance |

* ModEnc note: Armor/Speed/Firepower/Veteran each give Money on a duplicate pickup.
* `CrateRadius=3.0` cells for AoE crate effects.

**Edge cases.**
* Darkness overrides SpySat; you must collect a Reveal, or sell and rebuild the SpySat building, to restore full view (ModEnc Shroud/Powerups).
* Explosion/Napalm/Gas crates damage only the registered receiver in a squad (ModEnc note).
* Unit crate can spawn a naval/land mismatch → Internal Error if crate wrongly flagged water (ModEnc).
* Money crate amount is random (+0–900) in vanilla; Ares adds `RandomCrateMoney` (ModEnc).

**Kind.** Economy / powerup system.

**Sources.** MODENC (Crate, Powerups, Shroud), RULES-MIRROR (CrateRules).

**Confidence.** high (list & mechanics), med (exact YR share table).

---

### RA2-GP-008 No Ore Silos / Storage change

**What.** Unlike RA1/TS, RA2 **removed ore silos and per-structure storage caps**. Refineries hold unlimited pending ore; credits are a single per-player pool. (FANDOM Ore: "Storing additional ore in structures is no longer necessary.")

**Data keys.** Legacy `Storage=` still parsed on `[BuildingTypes]` in AI/refinery contexts but no player-facing silo exists in RA2.

**Numbers.** Credit cap is effectively per-player (no silo gating); observed standard values in MP are MinMoney=2500, Money=10000, MaxMoney=10000 (`[MultiplayerDialogSettings]`, MODENC).

**Edge cases.** Spy refinery infiltration steals a percentage of the *stored pool* — see RA2-GP-040.

**Kind.** Economy rule.

**Sources.** FANDOM (Ore), MODENC (MultiplayerDialogSettings).

**Confidence.** high.

---

### RA2-GP-009 Power system

**What.** Most structures require power; low power slows production and disables powered defenses. Power is per-player supply minus demand.

**Data keys.** `Power=` (on buildings), `Powered=yes`, `PowerPlant`/`PowerDrain` semantics in RA2 are `Power=` values (positive = generation, negative = drain). `[General]` low-power coefficients.

**Numbers.**
* Allied Power Plant **+200**, $600. Soviet Tesla Reactor **+150**, $600. Soviet Nuclear Reactor **+1000**, $1000, prereq Battle Lab (WW-ARCHIVE/CNCNZ).
* Low-power production: `MinLowPowerProductionSpeed=.5`, `MaxLowPowerProductionSpeed=.8`, `LowPowerPenaltyModifier=1`, `WorstLowPowerBuildRateCoefficient=.1`, `BestLowPowerBuildRateCoefficient=.2` (RULES-MIRROR).
* Damage: `DamageDelay=1` minute between trivial structure damage when low on power (RULES-MIRROR).

**Edge cases.**
* Powered defenses (Patriot, Prism Tower, Flak Cannon, Tesla Coil, Grand Cannon) deactivate at low power; Tesla Coil can be kept online by ≥3 Tesla Troopers (CNCNZ).
* Nuclear Reactor destruction produces a nuclear explosion + fallout killing infantry/light vehicles (CNCNZ).
* ConYard and some buildings provide their own power (WW-ARCHIVE).

**Kind.** Core system.

**Sources.** WW-ARCHIVE/CNCNZ (structures), RULES-MIRROR.

**Confidence.** high.

---

## 2. Construction & Base

### RA2-GP-010 Construction Yard

**What.** The root structure. MCV deploys into a ConYard; the ConYard is the factory for all buildings and a prerequisite for everything.

**Data keys.** `ConstructionYard=yes`, `UndeploysInto=`/`DeploysInto=AMCV/SMCV`, `BaseUnit=AMCV,SMCV` (`[General]`). Selling a ConYard refunds (unless the last building, which ends base presence).

**Numbers.**
* MCV cost **$3000**, prereq Service Depot (Allied/Soviet); ConYard provides **0** power (WW-ARCHIVE/CNCNZ).
* Deploy requires clear ground (golden deploy cursor); blocked cells cancel (CNCNZ MCV text).
* `PlacementDelay=.05` min retry delay for temporary placement blockage (RULES-MIRROR).

**Edge cases.**
* An MCV is a `BaseUnit`; AI "home" logic uses it when no buildings remain (RULES-MIRROR).
* YR `MCVRedeploys=yes` default: deployed MCVs can re-deploy (MODENC MultiplayerDialogSettings).
* Selling the ConYard removes build access until a new one is deployed.

**Kind.** Core structure.

**Sources.** WW-ARCHIVE, CNCNZ, RULES-MIRROR, MODENC.

**Confidence.** high.

---

### RA2-GP-011 Build radius / adjacency / placement

**What.** New buildings must be placed on clear terrain **adjacent to an existing owned structure** (the "base build radius" — there is no free placement far from base in vanilla). Walls extend adjacency for wall placement.

**Data keys.** `Adjacent=`/`BaseNormal=` style flags in RA2 are implicit: the engine requires cells adjacent to existing structures. `BaseBias`, `AISafeDistance` for AI. `PlacementDelay`. Naval yards use `WaterBound=yes`/`Naval=yes` and require water.

**Numbers.**
* Placement must be within the base perimeter; buildings cannot be placed on ore, cliffs, or occupied cells.
* Up to **4 wall segments** can be placed per click if adjacent to an existing wall (WW-ARCHIVE).
* `MaximumBuildingPlacementFailures=3` for the AI (RULES-MIRROR).

**Edge cases.**
* Selling a building can orphan later placements if adjacency is lost? No — adjacency is checked at placement time only.
* Naval Yard must be placed entirely in water (WW-ARCHIVE).
* Build-up animation (`BuildupTime=.06` avg minutes) plays when placed; it can be sold mid-build for a partial refund.

**Kind.** Construction rule.

**Sources.** WW-ARCHIVE, MODENC (BuildCat/placement), RULES-MIRROR.

**Confidence.** high.

---

### RA2-GP-012 Walls

**What.** Fortress Wall — a cheap passive barrier blocking infantry and vehicles. No gates in RA2 base (TS had gates; RA2 removed them).

**Data keys.** `Wall=yes`, `WallOwner=yes`, `WallBuildSpeedCoefficient=3.0` (walls build slower multiplier, RULES-MIRROR). `GDIGateOne`/`NodGateOne` etc. exist only as TS left-overs (RULES-MIRROR hack section) and are unused by RA2 content.

**Numbers.**
* Wall cost **$100** per segment, prereq Barracks, 0 power (WW-ARCHIVE).
* Up to 4 segments per placement adjacent to a wall (WW-ARCHIVE).

**Edge cases.**
* Walls block pathing but can be destroyed; `WallPenetratorThreshold=50%` — a unit dealing ≥ that fraction of wall HP in one shot fires *through* walls (RULES-MIRROR).
* `AlliedWallTransparency=no` — allied walls still block allied shots unless set yes (RULES-MIRROR).
* Walls cannot be placed on water.

**Kind.** Support structure.

**Sources.** WW-ARCHIVE, RULES-MIRROR.

**Confidence.** high.

---

### RA2-GP-013 Defenses (full buildable list)

**What.** Base defenses. Split by `BuildCat` (defense tab) and side.

**Data keys.** `BuildCat=Combat` (defense tab), `Power=`, `Primary`/`Secondary` weapons, `Powered=yes`, `IsBaseDefense=yes`, `Gattling`/`IsGattling` (YR Gattling), Tesla charge keys.

**Numbers / roster.**

| Name | Side | Internal id | Cost | Power | Prereq | Weapon | Role | Logic |
|------|------|-------------|------|-------|--------|--------|------|-------|
| Pillbox | Allied | `GAPILL` | $500 | 0 | Barracks | MG | anti-infantry | cannot shoot through walls; weak vs vehicles |
| Patriot Missile System | Allied | `GASAM` | $1000 | −50 | Barracks | SAM | anti-air / anti-missile | deactivates at low power |
| Prism Tower | Allied | `GAPRIS` | $1500 | −75 | Airforce Command HQ | Prism beam | anti-ground | support beams: nearby towers combine fire (see RA2-GP-033) |
| Grand Cannon | France only | `GAGCAN` | $2000 | −100 | Airforce Command HQ | Concussion shell | long-range anti-armor | splash; deactivates at low power; weak to air |
| Sentry Gun | Soviet | `NAPILL` | $500 | 0 | Barracks | MG | anti-infantry | cannot shoot through walls |
| Flak Cannon | Soviet | `NAFLAK` | $1000 | −50 | Barracks | Flak | anti-air / anti-missile | deactivates at low power |
| Tesla Coil | Soviet | `TESLA` | $1500 | −75 | Radar Tower | Tesla bolt | anti-ground | chargeable by Tesla Troopers (range/damage; 3+ = power-independent) |
| SpySat Uplink | Allied | `GASAT` | $1000 | −100 | Battle Lab | — | reveals map | `SpySat=yes`; not a weapon |
| Gap Generator | Allied | `GAGAP` | $1000 | −100 | Battle Lab | — | hides base | `GapGenerator=yes`; see RA2-GP-043 |
| Psychic Sensor | Soviet | `NAPSIS` | $1000 | −50 | Battle Lab | — | reveals attacker orders; detects spies | RA2-only (YR uses different) |
| Chronosphere | Allied | `GACSPH` | $2500 | −200 | Battle Lab | — | superweapon | `SuperWeapon=Chronosphere` |
| Weather Control Device | Allied | `GAWEAT` | $5000 | −200 | Battle Lab | — | superweapon | `SuperWeapon=WeatherControl` |
| Iron Curtain Device | Soviet | `NAIRON` | $2500 | −200 | Battle Lab | — | superweapon | `SuperWeapon=IronCurtain` |
| Nuclear Missile Silo | Soviet | `NAMISL` | $5000 | −200 | Battle Lab | — | superweapon | `SuperWeapon=Nuke` |

**Edge cases.**
* Only **one** Chronosphere / Weather Control / Iron Curtain / Nuclear Silo per player at a time (WW-ARCHIVE notes).
* Superweapon structures announce globally and reveal their own shroud when built (WW-ARCHIVE).
* Sensor reveals *orders* (attack lines), not just units; also uncovers enemy spies (WW-ARCHIVE).
* Grand Cannon's slow reload favors spreading multiple cannons.

**Kind.** Defenses & superweapons.

**Sources.** WW-ARCHIVE (Allied/Soviet structures), CNCNZ (structures), RULES-MIRROR (Prism/IC/Radiation), FANDOM.

**Confidence.** high (list/costs), med (a few internal ids inferred).

---

### RA2-GP-014 Sell / Repair / Refund

**What.** Buildings can be sold for a partial refund; damaged structures can be repaired by a global repair cursor that drains credits until healed.

**Data keys.** `RefundPercent`, `RepairPercent`, `RepairRate`, `RepairStep`, `URepairRate`, `IRepairRate`, `IRepairStep` (`[General]`). Repair is a sidebar action, not a building.

**Numbers.**
* `RefundPercent=50%` — sell refund is half original cost (RULES-MIRROR).
* `RepairPercent=15%` — cost to fully repair = 15% of full cost (RULES-MIRROR).
* `RepairRate=.016` min per repair tick; `RepairStep=8` HP per tick (structures). `URepairRate=.016` (units). `IRepairRate=.001` / `IRepairStep=20` (infantry) (RULES-MIRROR).
* `BuildupTime=.06` avg minutes for the construction animation (RULES-MIRROR).

**Edge cases.**
* Selling a building mid-build refunds proportionally; selling the last ConYard forfeits the base.
* Repairing while low on power still works but production suffers; repair cost is proportional to missing HP.
* `SurvivorRate=.4`, `AlliedSurvivorDivisor=500`, `SovietSurvivorDivisor=250` govern crew spawns from destroyed/sold buildings (RULES-MIRROR) — see RA2-GP-015.

**Kind.** Economy / construction rule.

**Sources.** RULES-MIRROR, MODENC, WW-ARCHIVE.

**Confidence.** high.

---

### RA2-GP-015 Survivors / Crew / Occupants

**What.** When a vehicle or building is destroyed, a crew infantry may emerge. This is the RA2 replacement for RA1's building survivors.

**Data keys.** `CrewEscape=50%` (percent chance a vehicle's crew escapes), `AlliedCrew=E1`, `SovietCrew=E2`, `Technician=CTECH`, `Engineer=ENGINEER`, `Pilot=E1`, `AlliedSurvivorDivisor`/`SovietSurvivorDivisor` (RULES-MIRROR). `OccupyWeapon` for garrisoned infantry (ModEnc).

**Numbers.**
* `CrewEscape=50%` chance per destroyed vehicle (RULES-MIRROR).
* Engineers can exit from Construction Yards / MCVs as a limited survivor (RULES-MIRROR comments).
* `ThreatPerOccupant=10` — occupied buildings gain threat per garrisoned infantry (RULES-MIRROR).

**Edge cases.**
* Survivors spawn only if there is free adjacent ground; otherwise they are lost.
* Garrisoned civilians emerge as the owning player's crew? No — garrison occupants are simply ejected on building death (see RA2-GP-016).

**Kind.** Combat / construction rule.

**Sources.** RULES-MIRROR, MODENC.

**Confidence.** med-high.

---

### RA2-GP-016 Civilian Building Garrisoning

**What.** Basic infantry (GI, Conscript) can enter civilian/marked buildings and fire from them; this gives protection and usually a range/damage boost. Engineers/Tanya/SEAL cannot garrison as a weapon (they enter by their own logic).

**Data keys.** `CanBeOccupied=yes` (building), `Occupier=yes` (infantry), `OccupyWeapon=` (infantry weapon while occupying), `MaxOccupants=` (capacity), `CanOccupyFire=yes`, `OccupyDamageMultiplier`, `OccupyROFMultiplier`, `OccupyRangeBonus` (ModEnc OccupyWeapon / community). Buildings with `CanBeOccupied` show a yellow/blue entry cursor.

**Numbers.**
* GI is the canonical occupier; Conscript also occupies (CNCNZ). Advanced infantry generally cannot occupy.
* Occupancy gives increased range and power (WW-ARCHIVE GI description).
* `ThreatPerOccupant=10` (RULES-MIRROR).
* Garrisoned units leave the building if it is destroyed or the player evicts.

**Edge cases.**
* Attack Dogs cannot enter buildings.
* A garrisoned infantry inside a *vehicle* (IFV/Battle Fortress) is a different mechanic (transport, not occupy) — see RA2-GP-041.
* Occupation counts for veterancy; clearing with a dog is a common counter (WW-ARCHIVE).

**Kind.** Infantry mechanic.

**Sources.** WW-ARCHIVE, CNCNZ, MODENC (OccupyWeapon/Occupier), FANDOM (Garrisoning), RULES-MIRROR.

**Confidence.** high.

---

### RA2-GP-017 Engineer Capture & Repair

**What.** Engineers are consumable: entering a structure repairs friendly structures, captures enemy/neutral structures, repairs bridges (via bridge huts), or defuses Crazy Ivan bombs. Capturing flips ownership; repairing yours consumes the engineer.

**Data keys.** `Engineer=yes`, `Capturable=yes` (building), `CanC4`/`C4=yes`, `Infiltrate`. Bridge huts `BridgeRepairHut=yes`. `MultiEngineer` MP option.

**Numbers.**
* Engineer cost **$500**, no prerequisites (both sides) (CNCNZ/WW-ARCHIVE).
* Capture requires the engineer to reach the structure; it is consumed (CNCNZ).
* With `MultiEngineer=yes` (MP only), more than one engineer may be needed to capture a structure (MODENC MultiplayerDialogSettings default 0/off).

**Edge cases.**
* Cannot capture the enemy Construction Yard? Actually it **can** capture ConYards and MCVs (standard RA2 play).
* Cannot capture Ore Purifiers (community, high consistency).
* Repairing your own building with an engineer consumes the engineer.
* Defusing an Ivan bomb does **not** consume the engineer (CNCNZ).

**Kind.** Infantry / capture.

**Sources.** WW-ARCHIVE, CNCNZ, MODENC (MultiplayerDialogSettings).

**Confidence.** high.

---

### RA2-GP-018 Service Depot & Vehicle Repairs

**What.** A structure that repairs vehicles (and the War Factory's aircraft) for a proportional credit cost; also clears Terror Drones from infected vehicles.

**Data keys.** `UnitRepair=yes`, `RepairBay=GADEPT,NADEPT` (`[General]` list, RULES-MIRROR), `Dock=`. `MovementZone=Amphibious` lets amphibs dock any repair building (ModEnc).

**Numbers.**
* Cost **$800**, prereq War Factory (Allied), power **−25**; Soviet −20 (WW-ARCHIVE/CNCNZ).
* Repair cost proportional to missing HP; `RepairPercent=15%` for structures is separate from unit repair math (RULES-MIRROR).
* `URepairRate=.016` per unit repair tick (RULES-MIRROR).

**Edge cases.**
* Allied Service Depot could **sell vehicles** in RA2; Soviet could not. This asymmetry was removed in YR patch 1.001 (WW-ARCHIVE note).
* A Terror Drone is removed when the vehicle docks; an Outpost or an IFV with an Engineer can also remove it (CNCNZ).
* Air Force HQ also services aircraft; aircraft without a home pad crash after firing (WW-ARCHIVE).

**Kind.** Support structure.

**Sources.** WW-ARCHIVE, CNCNZ, RULES-MIRROR, MODENC (MovementZone).

**Confidence.** high.

---

### RA2-GP-019 Cloning Vats (RA2 only)

**What.** Soviet structure that duplicates any infantry produced by the owner for free. Infantry can also be sent in to be sold. YR replaced it in content with the Industrial Plant (cost reduction) for most factions.

**Data keys.** `CloningVat=yes`, `CloneIncoming=yes`; limit-one hard-coded.

**Numbers.**
* Cost **$2500**, power **−200**, prereq Battle Lab (CNCNZ).
* Only **one** per player (CNCNZ).
* Duplicates every infantry produced for free; selling infantry into it returns a percentage of cost.

**Edge cases.**
* Only applies to the owner's own Barracks production; the free duplicate is a full unit.
* `Yuri Prime` limit-one-per-player is lifted while a Cloning Vat exists (CNCNZ Yuri Prime note).
* Not present in YR Soviet roster (YR Industrial Plant replaces the cost role).

**Kind.** Production structure.

**Sources.** CNCNZ (Soviet structures, units), FANDOM nav (Cloning vat RA2-only).

**Confidence.** high.

---

### RA2-GP-020 Build-up Animation

**What.** Placed buildings play a short "rising from the ground" animation before becoming active. `BuildupTime` controls duration.

**Data keys.** `BuildupTime=.06` avg minutes (`[General]`). Per-art `Buildup` frames in `art(md).ini`. Selling during build-up cancels it.

**Numbers.** `BuildupTime=.06` (~3.6 s at 1×) (RULES-MIRROR).

**Edge cases.**
* Build-up can be interrupted by the building being destroyed; no partial structure remains.
* Naval yards/buildings on water use the same animation.

**Kind.** Visual/construction rule.

**Sources.** RULES-MIRROR.

**Confidence.** high.

---

## 3. Production & Tech

### RA2-GP-021 Build Categories (`BuildCat`) & 6-tab UI

**What.** `BuildCat` assigns a structure to a sidebar category. The sidebar has **six tabs** in RA2: Structures, Defenses, Infantry, Vehicles, Aircraft, Ships.

**Data keys.** `BuildCat=` values (ModEnc): `Combat`, `Infrastructure`, `Resource`, `Power`, `Tech`, `DontCare`. Only `BuildCat=Combat` visibly moves a structure to the **Defenses** tab; every other value keeps it on the **Structures** tab (ModEnc). No vanilla building uses `Infrastructure` (ModEnc). `BuildCat=DontCare` shows the icon as partly built (ModEnc bug).

**Numbers / mapping.**

| Tab | Driven by |
|-----|-----------|
| Structures | all BuildingTypes except `BuildCat=Combat` |
| Defenses | BuildingTypes with `BuildCat=Combat` |
| Infantry | `[InfantryTypes]` |
| Vehicles | `[VehicleTypes]` (land + naval share the Vehicles list; naval appear at a Naval Yard) |
| Aircraft | `[AircraftTypes]` (Air Force HQ / pad) |
| Ships | naval VehicleTypes (produced at Naval Yard) |

**Edge cases.**
* Sidebar tabs grey out when no factory of the matching type exists (NCO bug when prerequisites met but no factory — ModEnc).
* `BuildCat=DontCare` is a bug; avoid.

**Kind.** UI / production.

**Sources.** MODENC (BuildCat), WW-ARCHIVE.

**Confidence.** high.

---

### RA2-GP-022 Prerequisite System

**What.** An object is buildable only if: TechLevel valid, house not in `ForbiddenHouses`, house in `RequiredHouses`, all structures in `Prerequisite` owned, stolen-tech flags satisfied (YR), and a factory of the right type owned.

**Data keys.** `TechLevel`, `Prerequisite`, `PrerequisiteOverride`, `RequiredHouses`, `ForbiddenHouses`, `RequiresStolenAlliedTech`/`RequiresStolenSovietTech`/`RequiresStolenThirdTech` (YR), `Owner`, `Factory=`, `Naval=`, `SecretLab`, `AIBuildThis`, `BuildTech`, `PrerequisitePower/Proc/ProcAlternate/Barracks/Factory/Radar/Tech` (`[General]`).

**Prerequisite groups (RA2).** Any one member of a group satisfies it:
* `POWER` → `PrerequisitePower=GAPOWR,NAPOWR,NANRCT` (RULES-MIRROR)
* `PROC` → `PrerequisiteProc=GAREFN,NAREFN`
* `BARRACKS` → `PrerequisiteBarracks=NAHAND,GAPILE`
* `FACTORY` → `PrerequisiteFactory=GAWEAP,NAWEAP`
* `RADAR` → `PrerequisiteRadar=GAAIRC,NARADR,AMRADR`
* `TECH` → `PrerequisiteTech=GATECH,NATECH`

(TS/Firestorm additionally had `GDIFACTORY`/`NODFACTORY`; RA2 dropped them — ModEnc Prerequisite System.)

**Numbers.** Repeating a BuildingType in `Prerequisite` does **not** require owning multiple copies (ModEnc Prerequisite).

**Edge cases.**
* AI ignores `Prerequisite` and `TechLevel` for AI base building, using `ai(md).ini` order and `AIBuildThis` instead (ModEnc) — a major design consideration for a data-driven remake.
* `PrerequisiteOverride` lets a single listed building bypass all normal prereqs (ModEnc).
* Stolen-tech objects become buildable immediately on infiltration and may be `TechLevel=11` (ModEnc).
* `ForbiddenHouses=<none>` unset works; empty does not; `RequiredHouses=<none>` does **not** unset (must list all countries) (ModEnc).

**Kind.** Tech tree system.

**Sources.** MODENC (Prerequisite, The Prerequisite System, RequiredHouses, ForbiddenHouses), RULES-MIRROR.

**Confidence.** high.

---

### RA2-GP-023 Multiple-Factory Production Bonus

**What.** Owning multiple factories of the same production category speeds up production multiplicatively.

**Data keys.** `MultipleFactory` (`[General]`). `BuildTime.MultipleFactory` (Ares extension).

**Numbers.**
* Retail RA2/YR `MultipleFactory=0.8` (RULES-MIRROR; ModEnc). Build rate factors: 1 factory = 1.0; 2 = 0.8; 3 = 0.64; 4 = 0.512 (each extra factory ×0.8). Lower is faster.
* `BuildSpeed=.7` — minutes to produce a 1000-credit item at base (RULES-MIRROR).
* `HarvestersPerRefinery=2`, `WeaponsFactory` interactions govern which factory gets the order.

**Edge cases.**
* The bonus applies per *category* (Barracks, War Factory, ConYard for buildings), not per individual unit.
* In TS the formula was different (non-cumulative); RA2 made it a straight cumulative discount (ModEnc).
* Low-power penalty multiplies on top (see RA2-GP-009).

**Kind.** Production rule.

**Sources.** MODENC (MultipleFactory), RULES-MIRROR, CNC-NET/Reddit corroboration.

**Confidence.** high.

---

### RA2-GP-024 Exits, Rally Points, Queues

**What.** Produced units emerge from the factory exit cell and auto-move to a rally point if set. Buildings produce to the sidebar; units to the map.

**Data keys.** `ExitCoord`/`ExitList` (art or rules), `NumberOfDocks`, rally point is a player action (`RallyPoint`), `CanBeBuiltOnCount`. `MaximumQueuedObjects=29`, `MaxWaypointPathLength=15` (RULES-MIRROR).

**Numbers.**
* **29** maximum queued objects (sidebar queue depth) (RULES-MIRROR).
* **15** waypoint path length limit (RULES-MIRROR).
* Factory exit blocked → production retries with `PlacementDelay=.05` (RULES-MIRROR).

**Edge cases.**
* Aircraft emerge from the Air Force HQ / pad, return to rearm; without a pad they crash after firing (WW-ARCHIVE).
* Naval units emerge from the Naval Yard's water exit.
* Multi-factory players can set separate rally points? Vanilla uses one rally per factory.

**Kind.** Production UI.

**Sources.** RULES-MIRROR, WW-ARCHIVE.

**Confidence.** med-high.

---

### RA2-GP-025 Naval Yard

**What.** Water-only factory for ships; also repairs naval units. Produced ships use `Naval=yes` mapping to the Ships tab.

**Data keys.** `Naval=yes`, `WaterBound=yes`, `Shipyard=GAYARD,NAYARD` (`[General]`, RULES-MIRROR), `UnitRepair=yes`.

**Numbers.**
* Cost **$1000**, power **−25** (Allied) / **−20** (Soviet), prereq Ore Refinery (WW-ARCHIVE/CNCNZ).
* Must be placed entirely in water (WW-ARCHIVE).
* Ship-repair cost proportional to damage; amphibious units dock any repair building (`MovementZone=Amphibious`, ModEnc).

**Edge cases.**
* `Naval=no` vehicles cannot be built at a Shipyard and vice-versa (ModEnc Prerequisite System).
* Selling the Shipyard with ships docked does not destroy them.
* GI/Tanya can swim but are not produced at the Yard.

**Kind.** Production structure.

**Sources.** WW-ARCHIVE, CNCNZ, MODENC (Prerequisite System/MovementZone), RULES-MIRROR.

**Confidence.** high.

---

### RA2-GP-026 Air Force HQ / Helipad & Ammo/Reload

**What.** Allied Air Force Command HQ provides radar and 4 aircraft pads; jets sortie, fire, and must return to rearm/reload. Soviet aircraft come from the War Factory (Kirov) and there is no jet pad in base RA2.

**Data keys.** `Helipad=yes`, `NumberOfDocks=4`, `PadAircraft=ORCA,BEAG` (`[General]`), `Ammo`, `ReloadRate=.3` minutes per ammo point, `SeparateAircraft=yes` (`[General]`), `Dock=` for landing.

**Numbers.**
* AFCHQ cost **$1000**, power **−50**, prereq Ore Refinery; 4 pads (WW-ARCHIVE).
* `ReloadRate=.3` minutes per ammo point (RULES-MIRROR).
* `SeparateAircraft=yes` — first helicopter bought separately from the helipad (RULES-MIRROR).
* Aircraft without a pad after firing crash (WW-ARCHIVE).
* Rocketeer/Black Eagle/IFV are separate; only `PadAircraft` list uses pads.

**Edge cases.**
* Destroying the AFCHQ while planes are airborne → planes crash (no home pad).
* `CurleyShuffle=yes` makes helicopters shuffle position between shots (RULES-MIRROR).
* YR adds MiG / Spy Plane / Siege Chopper with altered pad rules.

**Kind.** Production & air system.

**Sources.** WW-ARCHIVE, MODENC (General/Air), RULES-MIRROR, FANDOM (Kirov/Black Eagle).

**Confidence.** high.

---

## 4. Full Rosters

> All costs in credits. Armor classes: None / Flak (infantry), Heavy / Light / Medium (vehicles, buildings). Stats for Allied units are from the archived official Westwood site (WW-ARCHIVE); Soviet stats from CNCNZ + FANDOM unit pages where shown. Internal IDs: confident ones are shown; inferred IDs marked `?`.

### RA2-GP-027 Countries (9 base houses) & Unique Units

**What.** RA2 ships **9 countries** across 2 sides, plus Neutral/Special. Each country is a `[Countries]` entry with a `UIName`, `Side`, `Multiplay=yes`, and country modifiers. Each has exactly one unique buildable (except America's support power).

**Data keys.** `[Countries]`, `[Sides]`, `Side=`, `Multiplay=yes`, `MultiplayPassive=`, `ParentCountry=`, `WallOwner=`, cost/build-time/armor multipliers (`CostUnitsMult`, `ArmorBuildingsMult`, `BuildTimeUnitsMult`, `IncomeMult`, …), `VeteranInfantry/Units/Aircraft`, `Color`, `PercentBuilt`.

**Numbers / list.**

| Country | Side | Internal id | Unique | Unique internal id | Cost | Prereq | Effect |
|---------|------|-------------|--------|--------------------|------|--------|--------|
| America | Allied | `Americans` | Airborne (Paradrop) | support power | free | Airforce Command HQ | drops **8 GIs**, cooldown 4:00 |
| Great Britain | Allied | `British` | Sniper | `SNIPE` | $600 | Airforce Command HQ | one-shot-kill vs infantry, long range |
| France | Allied | `French` | Grand Cannon | `GAGCAN` | $2000 | Airforce Command HQ | long-range splash AA-immune (actually anti-ground) defense |
| Germany | Allied | `Germans` | Tank Destroyer | `TNKD` | $1000 | Airforce Command HQ | AP gun, devastating vs vehicles, weak vs infantry/structures |
| Korea | Allied | `Alliance` | Black Eagle | `BEAG` | $1200 | Airforce Command HQ | stronger Harrier (replaces it fully) |
| Russia | Soviet | `Russians` | Tesla Tank | `TTNK` | $1200 | Radar Tower | electric discharge, fires over walls |
| Cuba | Soviet | `Confederation` | Terrorist | `TERROR` | $200 | Radar Tower | suicide bomber, splash |
| Iraq | Soviet | `Arabs` | Desolator | `DESO` | $600 | Radar Tower | radiation cannon; deploy irradiates ground |
| Libya | Soviet | `Africans` | Demolition Truck | `DTRUCK` | $1500 | Radar Tower | mobile nuke, huge blast on death |

* `[Sides]`: `GDI=British,French,Germans,Americans,Alliance`; `Nod=Russians,Africans,Confederation,Arabs`; `Civilian=Neutral`; `Mutant=Special` (RULES-MIRROR).
* YR adds the 10th house `YuriCountry` on `ThirdSide`; the raw RA2 list also reserves `9=GDI`, `10=Nod`, `11=Neutral`, `12=Special` (RULES-MIRROR), with the 9 playable houses kept first for skirmish stability.
* `MultiplayPassive=yes` for Neutral/Special; Neutral hostile to all, Special allied to all (ModEnc Houses).

**Edge cases.**
* Removing/reordering the 9 skirmish houses crashes the game (RULES-MIRROR warning).
* Country unique units use `RequiredHouses`/`ForbiddenHouses`; the object can be captured but not built by others (ModEnc RequiredHouses).
* Navy SEAL / Chrono Commando / Psi Commando / Chrono Ivan / Yuri Prime are campaign or stolen-tech, not country uniques.

**Kind.** Faction system.

**Sources.** RULES-MIRROR (`[Countries]`/`[Sides]`), CNC-CENTRAL, CNCNZ (factions), WW-ARCHIVE.

**Confidence.** high.

---

### RA2-GP-028 Allied Infantry

| Name | Internal id | Cost | Armor | Prereq | Weapon(s)/Warhead | Role | Notable logic |
|------|-------------|------|-------|--------|-------------------|------|---------------|
| G.I. | `E1` | $200 | None | none | M60 MG; sandbag MG | basic infantry | deploy to sandbag bunker (more range/power, immobile); garrison |
| Engineer | `ENGINEER` | $500 | None | none | Defuse kit | capture/repair | consumed on capture/repair; defuses Ivan bombs; repairs bridges |
| Attack Dog | `DOG`/`ADOG`? | $200 | None | none | Teeth | anti-infantry | kills infantry in one lunge; detects & kills spies; useless vs vehicles |
| Rocketeer | `JUMPJET` | $600 | None | Airforce Command HQ | 20 mm | air-to-ground/air | jetpack hover; anti-air capable; fast scout |
| Spy | `SPY` | $1000 | Flak | Battle Lab | Makeup kit | infiltration | disguise; dog-detected; infiltrates for bonuses |
| Tanya | `TANY` | $1000 | Flak | Battle Lab | Dual pistols, C4, Sapper | commando | one-shot infantry; C4 destroys buildings/ships/bridge huts; can swim |
| Sniper (Britain) | `SNIPE` | $600 | None | Airforce Command HQ | AWP rifle | anti-infantry | one-shot kill, outranges infantry; weak vs vehicles |
| Navy SEAL (campaign) | `GHOST`? | $1000 | Flak | Airforce Command HQ | MP5, C4 | commando | land+water; C4; campaign-only |
| Chrono Legionnaire | `CLEG` | $1500 | None | Battle Lab | Neutron rifle | eraser | teleports; erases units (invulnerable while erasing); target returns if interrupted |
| Chrono Commando (stolen) | `CCOMAND` | $2000 | Flak | Spy on Allied Battle Lab | MP5, C4, chrono | commando | SEAL + teleport; cannot swim |
| Psi Commando (stolen) | `PTROOP`? | $1000 | Flak | Spy on Soviet Battle Lab | mind control + C4 | commando | mind control + C4; cannot swim |

**Numbers.** Strength/Speed from WW-ARCHIVE: GI 125/4; Engineer 75/4; Rocketeer 125/8; Spy 100/4; Tanya 125/5; Sniper 125/4; SEAL 125/5; Chrono Legionnaire 125/5. (Dog 125/5, CNCNZ.)

**Edge cases.**
* Tanya/SEAL C4 on bridge repair huts destroys bridges (CNCNZ/WW-ARCHIVE).
* Spy causes a dog to attack; disguised Spy is only detected by dogs and (partly) by the Psychic Sensor.
* Chrono Legionnaire cannot attack while phasing in; multiple Legionnaires erase faster; the target is invulnerable to normal damage during erasure.

**Kind.** Infantry roster.

**Sources.** WW-ARCHIVE (Allied units), CNCNZ (Allied units), FANDOM (Spy), MODENC (Agent).

**Confidence.** high.

---

### RA2-GP-029 Allied Vehicles

| Name | Internal id | Cost | Armor | Prereq | Weapon(s)/Warhead | Role | Notable logic |
|------|-------------|------|-------|--------|-------------------|------|---------------|
| Chrono Miner | `CMIN` | $1400 | Medium | Allied Ore Refinery | none | economy | teleports full loads; $500/1000 capacity |
| Grizzly Battle Tank | `MTNK`? | $700 | Heavy | none | 105 mm cannon | main tank | crushes infantry; fast/cheap; weaker than Rhino |
| Infantry Fighting Vehicle | `FV` | $600 | Light | none | Hover missile + passenger weapon | transport/AA | weapon changes with passenger (see RA2-GP-041); repairs with Engineer |
| Mirage Tank | `MGTK` | $1000 | Light | Battle Lab | Mirage gun | ambush | disguises as tree when idle; reveals briefly when firing; force-fire only |
| Prism Tank | `SREF` | $1200 | Heavy | Battle Lab | Comet (prism beam) | artillery | beam refracts to nearby targets; slow, weak vs vehicles |
| Mobile Construction Vehicle | `AMCV` | $3000 | Medium | Service Depot | none | base | deploys into ConYard |
| Tank Destroyer (Germany) | `TNKD` | $1000 | Heavy | Airforce Command HQ | AP cannon, SABOT | anti-armor | devastating vs vehicles, useless vs infantry/structures |

**Numbers.** WW-ARCHIVE: Grizzly 300/7; IFV 200/8; Mirage 200/7; Prism 150/4; Chrono Miner 1000/4. Tank Destroyer 400/5 (WW-ARCHIVE; CNCNZ says cost $1000, WW-ARCHIVE says $900 — conflict, use $1000 from CNCNZ/current manuals).

**Edge cases.**
* Mirage disguise list `DefaultMirageDisguises=TREE01,TREE02,TREE03,TREE04`; `InfantryBlinkDisguiseTime=20` (RULES-MIRROR).
* Prism Tank beam is single-target in vanilla (refraction is the Prism Tower's support-beam mechanic; see RA2-GP-033).
* IFV weapon table in RA2-GP-041.

**Kind.** Vehicle roster.

**Sources.** WW-ARCHIVE (Allied units), CNCNZ, RULES-MIRROR (Mirage).

**Confidence.** high (cost/armor/role), med (some internal ids).

---

### RA2-GP-030 Allied Aircraft

| Name | Internal id | Cost | Armor | Prereq | Weapon(s)/Warhead | Role | Notable logic |
|------|-------------|------|-------|--------|-------------------|------|---------------|
| Nighthawk Transport | `SHAD` | $1000 | Light | none (War Factory) | Blackhawk cannon | transport | carries 5 infantry; invisible to radar; MG |
| Harrier | `ORCA` | $1200 | Light | none (Airforce HQ) | Maverick missile | ground attack | one-pass strike; must rearm at pad |
| Black Eagle (Korea) | `BEAG` | $1200 | Light | none (Airforce HQ) | Maverick II | ground attack | stronger Harrier, replaces it |

**Numbers.** WW-ARCHIVE: Nighthawk 125/7; Harrier 150/8; Black Eagle 200/8. `PadAircraft=ORCA,BEAG` (RULES-MIRROR).

**Edge cases.**
* Nighthawk is a vehicle produced at the War Factory, not a pad aircraft (WW-ARCHIVE).
* Harrier/Black Eagle ammo-limited; `ReloadRate=.3` min per point.

**Kind.** Aircraft roster.

**Sources.** WW-ARCHIVE, CNCNZ, RULES-MIRROR.

**Confidence.** high.

---

### RA2-GP-031 Allied Navy

| Name | Internal id | Cost | Armor | Prereq | Weapon(s)/Warhead | Role | Notable logic |
|------|-------------|------|-------|--------|-------------------|------|---------------|
| Amphibious Transport | `SAPC` | $900 | Light | none | none | transport | 12 slots (infantry+vehicles); hovers land/water |
| Destroyer | `DEST` | $1200 | Heavy | none | 155 mm cannon, ASW Osprey | anti-sub/escort | detects submerged; launches Osprey (auto-replaced free) |
| Aegis Cruiser | `AEGIS` | $1000 | Light | Airforce Command HQ | Medusa missiles | anti-air/anti-missile | protects against missiles |
| Dolphin | `DLPH` | $500 | Light | Battle Lab | Sonar amplification | anti-naval | submerged, invisible to radar; detects subs/squid; surfaces when hurt |
| Aircraft Carrier | `CARRIER` | $2000 | Heavy | Battle Lab | Hornet launcher (3) | siege | launches 3 free Hornets; lost Hornets auto-replaced |

**Numbers.** WW-ARCHIVE: Destroyer 600/6; Aegis 800/4; Carrier 800/4; Dolphin 200/4. (WW-ARCHIVE lists Destroyer $100; CNCNZ/current data say $1200 — conflict; use $1200.)

**Edge cases.**
* Destroyer's Osprey is a spawned aircraft; if killed it is replaced free (WW-ARCHIVE).
* Dolphin and submarines surface when damaged/attacked (CNCNZ).
* Transports can carry MCVs and Engineers for beachhead drops.

**Kind.** Naval roster.

**Sources.** WW-ARCHIVE, CNCNZ.

**Confidence.** high.

---

### RA2-GP-032 Soviet Infantry

| Name | Internal id | Cost | Armor | Prereq | Weapon(s)/Warhead | Role | Notable logic |
|------|-------------|------|-------|--------|-------------------|------|---------------|
| Conscript | `E2` | $100 | None | none | Assault rifle | basic infantry | cheapest; can garrison; cannot deploy |
| Engineer | `ENGINEER` | $500 | None | none | Defuse kit | capture/repair | same as Allied |
| Attack Dog | `ADOG` | $200 | None | none | Teeth | anti-infantry | same role |
| Flak Trooper | `FLAKT` | $300 | None | Radar Tower | Flak cannon | anti-air/vehicle | splash; weak vs infantry |
| Tesla Trooper | `SHK` | $600 | None | none | Tesla bolt | anti-ground | immune to crush; charges Tesla Coils |
| Crazy Ivan | `IVAN` | $600 | None | Radar Tower | Ivan bomb | demolition | places timed bombs on units/buildings/cows; not on transports |
| Terrorist (Cuba) | `TERROR` | $200 | None | Radar Tower | suicide charge | demolition | runs at target, splash explosion |
| Desolator (Iraq) | `DESO` | $600 | None | Radar Tower | Radiation cannon | area denial | deploy irradiates ground (infantry/light vehicles); mobile melts infantry |
| Psi-Corps Trooper / Yuri (campaign/MP) | `YURI` | $1200 | None | Battle Lab | Mind control / psychic blast | support | controls organic units/vehicles; blast kills surrounding infantry; cannot control miners/dogs/air/mind units |
| Chrono Ivan (stolen) | `CIVAN` | $1000 | None | Soviet Spy on Allied Battle Lab | Ivan bomb + chrono | demolition | Ivan + teleport |
| Yuri Prime (stolen) | `YURIPR` | $2000 | None | Soviet Spy on Soviet Battle Lab | long-range mind control | support | controls from greater range; one at a time (two with Cloning Vat) |
| Boris (campaign) | `BORIS`? | — | — | — | AK + airstrike | commando | calls MiG airstrike on buildings |

**Numbers.** Dog 125/5, Conscript 100/4-ish, Flak Trooper 100-ish, Tesla Trooper 100-ish (CNCNZ gives costs; FANDOM has per-unit HP). Ivan bomb `IvanDamage=400`, `IvanTimedDelay=450` frames (~30 s) (RULES-MIRROR).

**Edge cases.**
* Ivan bombs cannot be placed on transports (CNCNZ). `CanDetonateTimeBomb=no`, `CanDetonateDeathBomb=no` by default (RULES-MIRROR).
* Desolator radiation keys under `[Radiation]` (RULES-MIRROR).
* Tesla Trooper cannot be crushed; charges Tesla Coils.
* Psi-Corps cannot control miners, dogs, aircraft, or other mind-control units (CNCNZ).

**Kind.** Infantry roster.

**Sources.** CNCNZ (Soviet units), RULES-MIRROR (Ivan/Radiation), FANDOM.

**Confidence.** high.

---

### RA2-GP-033 Soviet Vehicles

| Name | Internal id | Cost | Armor | Prereq | Weapon(s)/Warhead | Role | Notable logic |
|------|-------------|------|-------|--------|-------------------|------|---------------|
| War Miner | `HARV` | $1400 | Medium | Soviet Ore Refinery | MG | economy | $1000/2000 capacity; crushes infantry |
| Rhino Heavy Tank | `HTNK` | $900 | Heavy | none | 120 mm cannon | main tank | tougher/slightly longer range than Grizzly, slower |
| Flak Track | `HTK` | $500 | Light | none | Flak | AA/transport | carries 5 infantry; anti-air/light ground |
| Terror Drone | `DRON` | $500 | Light | none | Dismantle | anti-vehicle | leaps onto vehicles, dismantles from inside; removed by Depot/Outpost/IFV-Engineer |
| V3 Rocket Launcher | `V3` | $800 | Light | Radar Tower | V3 rocket | artillery | long-range rocket, shootable in air; splash |
| Tesla Tank (Russia) | `TTNK` | $1200 | Heavy | Radar Tower | Tesla bolt | anti-ground | fires over walls; cannot charge Coils |
| Demolition Truck (Libya) | `DTRUCK` | $1500 | Light | Radar Tower | Nuclear charge | suicide | tactical nuke blast on death/arrival |
| Apocalypse Tank | `APOC` | $1750 | Heavy | Battle Lab | Twin 120 mm + AA missiles | super-heavy | HP 800, self-repair, elite 4-shot burst |
| Mobile Construction Vehicle | `SMCV` | $3000 | Medium | Service Depot | none | base | deploys into ConYard |

**Numbers.** FANDOM Apocalypse: HP 800, Heavy, tech 7, cost 1750, build 1:10, ground atk 100, air atk 50, cooldown 80, speed 4, range 5.75/8, sight 6, self-repair. V3 rocket `V3RocketDamage=200`, `V3RocketEliteDamage=400` (RULES-MIRROR).

**Edge cases.**
* Terror Drone: only Depot/Outpost/IFV-Engineer removes it; if the vehicle dies before the drone finishes, the drone dies with it (CNCNZ).
* V3 rockets and Dreadnought missiles can be shot down by AA (CNCNZ). `DMislDamage=300`, elite 600 (RULES-MIRROR).
* Apocalypse AA missiles cannot target ground in RA2 (FANDOM trivia).

**Kind.** Vehicle roster.

**Sources.** CNCNZ, FANDOM (Apocalypse), RULES-MIRROR (V3/Dreadnought).

**Confidence.** high.

---

### RA2-GP-034 Soviet Aircraft & Navy

**Aircraft**

| Name | Internal id | Cost | Armor | Prereq | Weapon | Role | Logic |
|------|-------------|------|-------|--------|--------|------|-------|
| Kirov Airship | `ZEP` | $2000 | Medium (Light in RA2?) | Battle Lab | Bombs (Tesla bombs elite) | heavy bomber | HP 2000, speed 5, range 1.5, one bomb destroys most structures; only drops directly underneath |

**Navy**

| Name | Internal id | Cost | Armor | Prereq | Weapon(s) | Role | Logic |
|------|-------------|------|-------|--------|-----------|------|-------|
| Amphibious Transport | `SAPC` | $900 | Light | none | none | transport | 12 slots, stronger armor than Allied |
| Typhoon Attack Sub | `SUB` | $1000 | Light | none | Torpedoes | anti-ship | submerged/stealth; cannot hit land; surfaces when hurt |
| Sea Scorpion | `HOVR`? | $600 | Light | Radar Tower | Flak + anti-missile | AA/anti-missile | fastest ship; hits ground/sea/air |
| Giant Squid | `SQD` | $1000 | Light | Battle Lab | Tentacles | anti-ship | grapples and crushes ships; submerged |
| Dreadnought | `DRED` | $2000 | Heavy | Battle Lab | 2 long-range missiles | siege | missiles shootable; long range |

**Numbers.** FANDOM Kirov: HP 2000, Medium, tech 10, cost 2000, build 1:20, atk 250, cooldown 50, speed 5, range 1.5, sight 8.

**Edge cases.**
* Kirov cannot attack air, is very slow, and its splash (`CellSpread=2` on `BlimpBomb`) makes it strong vs multi-cell buildings but weak vs 1×1 defenses (FANDOM).
* A grounded Kirov (sold War Factory before ascent) becomes mind-controllable (FANDOM).
* Squid grapples; the grappled ship is disabled until the squid is killed or it dies.

**Kind.** Aircraft/naval roster.

**Sources.** CNCNZ, FANDOM (Kirov), RULES-MIRROR (Dreadnought missile).

**Confidence.** high.

---

### RA2-GP-035 Allied Structures (buildable)

| Name | Internal id | Cost | Power | Prereq | Role | Logic |
|------|-------------|------|-------|--------|------|-------|
| Construction Yard | `GACNST` | $3000 (MCV) | 0 | none | base root | builds all structures |
| Power Plant | `GAPOWR` | $600 | +200 | none | power | weak |
| Ore Refinery | `GAREFN` | $2000 | −50 | Power Plant | economy | free Chrono Miner |
| Barracks | `GAPILE` | $500 | −10 | Power Plant | infantry | |
| War Factory | `GAWEAP` | $2000 | −25 | Ore Refinery, Barracks | vehicles | also Nighthawk |
| Naval Shipyard | `GAYARD` | $1000 | −25 | Ore Refinery | navy | water-only |
| Airforce Command HQ | `GAAIRC` | $1000 | −50 | Ore Refinery | radar + air | 4 pads; radar |
| Service Depot | `GADEPT` | $800 | −25 | War Factory | repairs | can sell vehicles (RA2 only) |
| Battle Lab | `GATECH` | $2000 | −100 | War Factory, Airforce HQ | tech | unlocks high tier |
| Ore Purifier | `GAPURP` | $2500 | −200 | Ore Refinery, Battle Lab | economy | +25%, limit 1 |

**Kind.** Structure roster. **Sources.** WW-ARCHIVE, CNCNZ. **Confidence.** high (internal ids med).

---

### RA2-GP-036 Soviet Structures (buildable)

| Name | Internal id | Cost | Power | Prereq | Role | Logic |
|------|-------------|------|-------|--------|------|-------|
| Construction Yard | `NACNST` | $3000 (MCV) | 0 | none | base root | |
| Tesla Reactor | `NAPOWR` | $600 | +150 | none | power | |
| Ore Refinery | `NAREFN` | $2000 | −50 | Tesla Reactor | economy | free War Miner |
| Barracks | `NAHAND` | $500 | −10 | Tesla Reactor | infantry | |
| War Factory | `NAWEAP` | $2000 | −25 | Ore Refinery, Barracks | vehicles | also Kirov |
| Naval Shipyard | `NAYARD` | $1000 | −20 | Ore Refinery | navy | water-only |
| Radar Tower | `NARADR` | $1000 | −50 | Ore Refinery | radar | no aircraft |
| Service Depot | `NADEPT` | $800 | −20 | War Factory | repairs | cannot sell vehicles (RA2) |
| Battle Lab | `NATECH` | $2000 | −100 | War Factory, Radar Tower | tech | |
| Nuclear Reactor | `NANRCT` | $1000 | +1000 | Battle Lab | power | explodes + fallout on death; can replace Tesla Reactor in tech tree |
| Cloning Vats | `NACLON` | $2500 | −200 | Battle Lab | production | free infantry duplicates; limit 1; RA2-only |

**Kind.** Structure roster. **Sources.** WW-ARCHIVE, CNCNZ. **Confidence.** high.

---

## 5. Abilities & Special Mechanics

### RA2-GP-037 Spy Infiltration (full effect table)

**What.** An Agent (`Agent=yes` + `Infiltrate=yes`) with a disguise enters enemy buildings. Effect depends on the building category, gated by `Spyable=yes`.

**Data keys.** `Agent=yes`, `Infiltrate=yes`, `Spyable=yes` (building), `Thief=yes` (steal), `SpyPowerBlackout`, `SpyMoneyStealPercent`, `RequiresStolen*Tech` (YR stolen tech), `Disguise=`/`MakeupKit`.

**Numbers.** `SpyPowerBlackout=1000` frames (~66 s at 15 fps; ~55 s at 18 fps) (RULES-MIRROR). `SpyMoneyStealPercent=.5` = steals **50%** of the target's credits (RULES-MIRROR).

**Effect table.**

| Building category | Effect on target | Effect on spy owner |
|-------------------|------------------|---------------------|
| Power Plant (`Power>0`) | power generation stops for `SpyPowerBlackout` | — |
| Refinery (`Refinery=yes` or `Storage>0`, `Thief=yes`) | loses 50% credits | gains 50% |
| Barracks (`Factory=InfantryType`) | — | all own infantry build as Veterans (`AltCameo` shown) |
| War Factory / factory (`Factory=UnitType`) | — | all own vehicles build as Veterans (not Naval Yards) |
| Radar (`Radar=yes`, not SpySat) | — | sees target's discovered terrain, *and future discoveries* |
| Battle Lab / tech (`BuildTech`) | — | unlocks stolen-tech units (YR) |
| Super weapon | superweapon deactivates for a time | — |

**Edge cases.**
* Disguise fails vs Attack Dogs and can be revealed by the Psychic Sensor (CNCNZ/ModEnc).
* If `Agent=yes` and the unit also has a weapon with `IvanBomb=yes`, it prefers attacking over infiltrating (ModEnc).
* If `Agent=yes` and `C4=yes`, it tries C4 before infiltrating (ModEnc).
* Spy + Engineer/C4/Thief on one unit can cause Internal Errors (ModEnc).
* Radar infiltration in RA2 shows future discoveries; a known bug also reveals other players' discoveries (ModEnc).

**Kind.** Infantry infiltration system.

**Sources.** MODENC (Agent), RULES-MIRROR (SpyPowerBlackout/MoneySteal), CNCNZ (Spy), FANDOM.

**Confidence.** high (mechanics), med-high (exact frame duration).

---

### RA2-GP-038 Engineer (capture/repair/defuse)

Covered in RA2-GP-017. **Key numbers:** $500, consumed on capture/repair, not consumed on defuse; can capture tech buildings and enemy structures; `MultiEngineer` MP option changes capture to require multiple engineers. **Sources.** CNCNZ, WW-ARCHIVE, MODENC. **Confidence.** high.

---

### RA2-GP-039 Attack Dog

**What.** Cheap anti-infantry animal. One lunge kills any infantry; also detects and kills Spies; cannot attack vehicles or structures.

**Data keys.** `Dog=yes`, `Fraidycat=yes` (some civilians), `DetectDisguise=yes`, `Sight=`, `Speed=`. **Numbers.** $200, strength ~125, speed 5 (CNCNZ). **Edge cases.** Dogs die to any vehicle/fire; can be crushed by vehicles? Dogs are not crushable by their own; enemy dogs kill each other. **Sources.** CNCNZ, WW-ARCHIVE. **Confidence.** high.

---

### RA2-GP-040 Tanya / Navy SEAL C4

**What.** Commandos place C4 on buildings/ships/bridge huts for guaranteed destruction; Tanya (and SEAL) kill infantry in one shot.

**Data keys.** `C4=yes`, `CanC4=yes` (building), `C4Delay=.03` minutes, `C4Warhead=Super` (absolute-damage warhead == "C4 sets a timer that forces destruction") (RULES-MIRROR). Bridge huts `BridgeRepairHut=yes`/`BridgeRepairHut`.

**Numbers.** `C4Delay=.03` minutes (~1.8 s) (RULES-MIRROR). Tanya/SEAL cost $1000. **Edge cases.** Cannot C4 a `CanC4=no` building; Tanya can swim, SEAL can swim, Chrono Commando cannot. **Sources.** RULES-MIRROR, CNCNZ. **Confidence.** high.

---

### RA2-GP-041 IFV Passenger Weapon Modes

**What.** The Allied IFV's turret weapon changes with the passenger. This is the canonical "variable weapon" table.

**Data keys.** Passenger-driven: `Gunner=`/turret-swap via passenger `IFVMode` (`rules.ini` per-infantry `IFVMode=`), and IFV weapon definitions keyed by mode.

**Numbers / full table (CNCNZ).**

| Passenger | IFV weapon |
|-----------|-----------|
| (empty) / Attack Dog | missile launcher (AA) |
| G.I. / Conscript / Spy | machine gun |
| Flak Trooper | flak cannon |
| Engineer | repair crane |
| Sniper | sniper gun |
| Navy SEAL / Tanya / Chrono Commando / Psi Commando | advanced machine gun |
| Desolator | advanced rad cannon |
| Crazy Ivan / Chrono Ivan / Terrorist | suicide bomb |
| Tesla Trooper | Tesla cannon |
| Psi-Corps Trooper / Yuri | psychic blast dome |
| President / neutral animals | prism cannon |

**Edge cases.**
* An Engineer inside an IFV makes it a mobile repair unit and clears Terror Drones (CNCNZ).
* The IFV turret transforms with a sound; passenger must be infantry.
* YR adds Battle Fortress with a different (multi-passenger) weapon model.

**Kind.** IFV mechanic.

**Sources.** CNCNZ (Allied units / IFV), WW-ARCHIVE (IFV).

**Confidence.** high.

---

### RA2-GP-042 GI / Guardian GI Deploy

**What.** GI deploys into a sandbag MG emplacement (more range/power, immobile); undeploys back. Guardian GI (YR) deploys into an anti-tank/anti-air position. Conscripts cannot deploy.

**Data keys.** `Deployer=yes`, `DeployedWeapon`/`DeployFire`, `IsSimpleDeployer`, `DeployToLand`, `UndeployDelay`. GI deploy uses `Deploy` sequence in art.

**Numbers.** GI cost $200; deployed weapon has greater range and damage (WW-ARCHIVE). `AIAutoDeployFrameDelay=15,25,100` (RULES-MIRROR) governs AI GI deploy timing. **Edge cases.** deployed GIs can't move; dogs are a hard counter; garrison is better in urban maps. **Sources.** WW-ARCHIVE, CNCNZ, RULES-MIRROR. **Confidence.** high.

---

### RA2-GP-043 Mirage Disguise

**What.** Idle Mirage Tanks appear as trees; they can fire from disguise; they briefly blink to their true form when firing (and enemies near them may then detect). Force-fire only when disguised.

**Data keys.** `DefaultMirageDisguises=TREE01,TREE02,TREE03,TREE04`, `InfantryBlinkDisguiseTime=20`, `DisabledDisguiseDetectionPercent=15,5,2` (per-unit detection chance per blink; the numbers are h, m, e), `AttackCursorOnDisguise=no` (RULES-MIRROR).

**Numbers.** Detection chances 15%/5%/2% per nearby unit per blink (RULES-MIRROR). **Edge cases.** disguise is a *terrain* disguise (must be trees/boxes, not rocks); moving reveals it; Axis pets/units see through it in some cases. **Sources.** RULES-MIRROR, CNCNZ, WW-ARCHIVE. **Confidence.** high.

---

### RA2-GP-044 Terror Drone

Covered in RA2-GP-033. **Key logic.** Leaps onto vehicles and dismantles them; removed only by Service Depot/Outpost/IFV-Engineer; if the host vehicle dies first the drone dies too; acts like a dog vs infantry (no spy detection). **Sources.** CNCNZ. **Confidence.** high.

---

### RA2-GP-045 Tesla Chain / Tesla Supercharge

**What.** Tesla Coil is a Soviet defense that can be "charged" by nearby Tesla Troopers: each adds range/damage; 3+ Troopers make it function without base power. Tesla Tank fires over walls but cannot charge coils.

**Data keys.** `Tesla=yes`, `ChargedBy=`? (Tesla trooper `Tesla=yes` and coil `ETesla=yes`/`IsBaseDefense=yes`), `TeslaCharge` anim/sound (`TeslaCharge=TeslaCoilPowerUp`), `IsTeslaCoil`. Wireless/chain visuals in art.

**Numbers.** Tesla Coil $1500, power −75, prereq Radar Tower (CNCNZ); 3 Troopers = power-independent. **Edge cases.** Charging is automatic on proximity; Troopers are crush-immune; Tesla Tank cannot charge. **Sources.** CNCNZ, RULES-MIRROR (sound). **Confidence.** high.

---

### RA2-GP-046 Prism Refraction / Support Beams

**What.** Prism Towers near each other combine their beams into one stronger beam by targeting a friendly tower. Prism Tank's beam bounces to nearby targets.

**Data keys.** `PrismType=ATESLA` (hard-coded "is this a prism cannon?"), `PrismSupportModifier=150%` (each support beam adds 150% of the firing beam's damage), `PrismSupportMax=8`, `PrismSupportDelay=60`, `PrismSupportDuration=15`, `PrismSupportHeight=420` (RULES-MIRROR). `IsPrism`.

**Numbers.** Each support beam +150% damage, up to **8** support beams; a supporting tower goes offline for 60 frames; beam visible 15 frames, aimed 420 leptons above target (RULES-MIRROR). **Edge cases.** Prism Towers must be within support range and owned; tanks' refraction is a separate weapon/art behaviour, not `PrismSupport`. **Sources.** RULES-MIRROR, WW-ARCHIVE. **Confidence.** high.

---

### RA2-GP-047 Chrono (Chronosphere, Chrono Miner, Chrono Legionnaire)

**What.** Time-teleport family. Chrono Miner teleports to refineries; Chrono Legionnaire teleports and erases; Chronosphere is an Allied superweapon that moves units (and kills infantry).

**Data keys.** `Teleporter=yes`, `ChronoTrigger=yes`, `ChronoDistanceFactor=48`, `ChronoMinimumDelay=16`, `ChronoRangeMinimum=0`, `ChronoDelay=60`, `ChronoReinfDelay=180`, `WarpOut=WARPOUT`/`WarpIn=WARPIN`/`ChronoSparkle1=CHRONOSK`, `ChronoBeamColor=128,200,255` (RULES-MIRROR). `SuperWeapon=Chronosphere`.

**Numbers.** `ChronoDistanceFactor=48` → ~256/48 ≈ 5.3 frames delay per cell; `ChronoMinimumDelay=16` frames floor (RULES-MIRROR). Chronosphere cooldown **7:00** (CNCNZ). Applying it to infantry kills them; ships can be dropped on land and killed; enemy vehicles can be moved (CNCNZ). **Edge cases.** Chrono units are vulnerable while phasing in; Chrono Legionnaire's partially-erased target reverts if he stops. **Sources.** RULES-MIRROR, CNCNZ, MODENC (Locomotor/Teleport). **Confidence.** high.

---

### RA2-GP-048 Iron Curtain

**What.** Soviet superweapon making an area of units/structures invulnerable. Kills infantry caught in it; invulnerable units can't be Terror-Droned or mind-controlled.

**Data keys.** `SuperWeapon=IronCurtain`, `IronCurtainDuration=750` frames, `IronCurtainInvokeAnim=IRONBLST`, `WeaponNullifyAnim=IRONFX` (RULES-MIRROR). `AIMinorSuperReadyPercent=.7` (AI uses at 70%).

**Numbers.** Duration **750 frames** (~50 s at 15 fps; ~41 s at 18 fps) (RULES-MIRROR; CNCNZ says "50 seconds"). Cooldown **5:00** (CNCNZ). **Edge cases.** Infantry dies instantly; Terror Drones/mind control no-op on affected units. **Sources.** RULES-MIRROR, CNCNZ. **Confidence.** high.

---

### RA2-GP-049 Gap Generator

**What.** Shrouds a radius around itself for all non-allied players, even those with a Spy Satellite.

**Data keys.** `GapGenerator=yes`, `GapRadiusInCells`, `SuperGapRadiusInCells`, `ExtraPower` (RULES-MIRROR/ModEnc). Deployed high-power mode if surplus power > `ExtraPower`.

**Numbers.** Cost $1000, power −100, prereq Battle Lab (CNCNZ). Radius in `GapRadiusInCells` (exact cells not exposed in the retail `[General]` dump; `[GAGAP]` rules value). High-power mode needs 9000 surplus power (CNCNZ note) and in retail only spends it (broken). **Edge cases.** AI is unaffected by the shroud (ModEnc); SpySat+Gap is desync-prone (ModEnc, fixed in Phobos). **Sources.** MODENC (GapGenerator), CNCNZ. **Confidence.** high (mechanic), low (exact cell radius).

---

### RA2-GP-050 Spy Satellite Uplink

**What.** Reveals the whole map for its owner, except Gap Generator fields. Independent radar source. Does **not** stack with Fog of War/ShroudGrow.

**Data keys.** `SpySat=yes`, `SpySatActivationSound`, `SpySatDeactivationSound`, `CameraRange=9` (spy-camera reveal radius, RULES-MIRROR). **Numbers.** Cost $1000, power −100, prereq Battle Lab (CNCNZ). **Edge cases.** Not affected by Powered/TogglePower (ModEnc); selling it resets shroud; Darkness crate overrides it (ModEnc). **Sources.** MODENC (SpySat), CNCNZ, RULES-MIRROR. **Confidence.** high.

---

### RA2-GP-051 Nuclear Missile / Fallout

**What.** Soviet superweapon. `SuperWeapon=Nuke`, projectile `NukeUp`, down animation `NukeDown`, warhead `Nuke`, `AtomDamage=1000`, and post-impact radiation (2000 units).

**Data keys.** `[SpecialWeapons] NukeWarhead=Nuke; NukeDown; NukeProjectile=NukeUp`; `AtomDamage=1000`; `[Radiation] RadDurationMultiple=1`, `RadLevelMax=500`, `RadSiteWarhead=RadSite`, `RadColor=0,255,0`, Nuke puts 2000 rad units (RULES-MIRROR). `AIIonCannon*Value` for AI targeting of the equivalent (RA2 uses Nuke).

**Numbers.** Nuke cooldown **10:00** (CNCNZ); `AtomDamage=1000` direct; radiation 2000 units, `RadLevelMax=500` cap per cell; nuclear reactor death also causes a nuclear explosion (CNCNZ). **Edge cases.** Radiation kills infantry and damages light vehicles; persists and decays by `RadLevelDelay=90` frames. **Sources.** RULES-MIRROR, CNCNZ, MODENC. **Confidence.** high.

---

### RA2-GP-052 Weather Control Device / Lightning Storm

**What.** Allied superweapon summoning a lightning storm over a large area.

**Data keys.** `[General] LightningDeferment=250`, `LightningDamage=250`, `LightningStormDuration=180` frames, `LightningWarhead=IonWH`, `LightningHitDelay=10`, `LightningScatterDelay=5`, `LightningCellSpread=10`, `LightningSeparation=3`; `WeatherConClouds`, `WeatherConBolts`, `WeatherConBoltExplosion` (RULES-MIRROR). `SuperWeapon=WeatherControl`.

**Numbers.** `LightningDamage=250` per bolt; duration 180 frames; spread 10 cells; cooldown **10:00** (CNCNZ). **Edge cases.** `LightningDeferment=250` frames between announcement and strike. **Sources.** RULES-MIRROR, CNCNZ. **Confidence.** high.

---

### RA2-GP-053 Paradrop / Airborne

**What.** America's support power (free with AFCHQ) drops 8 GIs; Tech Airport gives a 6-GI (Allied) / 9-Conscript (Soviet) drop.

**Data keys.** `[General] AmerParaDropInf=E1; AmerParaDropNum=8; AllyParaDropInf=E1; AllyParaDropNum=6; SovParaDropInf=E2; SovParaDropNum=9; ParadropRadius=1024` (RULES-MIRROR). `SuperWeapon=ParaDrop` variants. Drop plane `PDPLANE`.

**Numbers.** America: **8 GIs**, cooldown **4:00** (WW-ARCHIVE); Tech Airport: 6 GIs / 9 Conscripts, cooldown 4:00, non-stacking. `ParadropRadius=1024` leptons (RULES-MIRROR). **Edge cases.** If the transport plane is shot down, troops are lost; multiple AFCHQs don't stack (WW-ARCHIVE). **Sources.** RULES-MIRROR, WW-ARCHIVE, CNCNZ. **Confidence.** high.

---

### RA2-GP-054 Mind Control (base RA2)

**What.** Psi-Corps Trooper / Yuri and (stolen-tech) Yuri Prime can mind-control organic units and vehicles. The controlled unit is effectively yours; control breaks on the controller's death.

**Data keys.** `MindControl=yes`/`PsychicControl`, `CanBeControlled=`, `Controllable=no` (for immune types), `MindControlRange`, projectile `PsychicControl` (targets surface only). Yuri Prime one-at-a-time unless Cloning Vat.

**Numbers.** Psi-Corps/Yuri cost $1200, prereq Battle Lab (CNCNZ). Cannot control: miners, Attack Dogs, aircraft, other mind-control units (CNCNZ). Yuri Prime $2000, longer range. **Edge cases.** A grounded Kirov can be mind-controlled (FANDOM); Iron-Curtrained units are immune; if the controller dies the unit reverts. **Sources.** CNCNZ, RULES-MIRROR (YuriMindControlSound). **Confidence.** high.

---

## 6. Movement

### RA2-GP-055 Locomotors (movement modes)

**What.** `Locomotor` selects the movement class/CLSID. Invalid/omitted → Teleport default.

**Data keys.** CLSIDs (ModEnc Locomotor):

| Alias | CLSID | Used by | Default SpeedType |
|-------|-------|---------|-------------------|
| Levitate | `{3DC0B295-6546-11D3-80B0-00902792494C}` | FS vehicles | Hover |
| Drive | `{4A582741-9839-11d1-B709-00A024DDAFD1}` | ground vehicles | Track (Crusher) / Wheel |
| Hover | `{4A582742-9839-11d1-B709-00A024DDAFD1}` | hover vehicles (Robot Tank, Hover MLRS) | Hover |
| Tunnel | `{4A582743-9839-11d1-B709-00A024DDAFD1}` | burrowers | Drive-like |
| Walk | `{4A582744-9839-11d1-B709-00A024DDAFD1}` | infantry | Drive-like |
| DropPod | `{4A582745-9839-11d1-B709-00A024DDAFD1}` | falling pods (temporary) | Hover |
| Fly | `{4A582746-9839-11d1-B709-00A024DDAFD1}` | aircraft | Winged |
| Teleport | `{4A582747-9839-11d1-B709-00A024DDAFD1}` | chrono (default) | Drive |
| Mech | `{55D141B8-DB94-11d1-AC98-006008055BB5}` | walkers | Drive |
| Ship | `{2BEA74E1-7CCA-11d3-BE14-00104B62A16C}` | ships | Float |
| Jumpjet | `{92612C46-F71F-11d1-AC9F-006008055BB5}` | jumpjet infantry/vehicles | Hover |
| Rocket | `{B7B49766-E576-11d3-9BD9-00104B972FE8}` | spawned missiles (V3/Dread) | Winged |

**Numbers.** Hover is ~35% slower than Drive; Mech ~40% slower; Walk/Mech unstable above Speed 13–14 (ModEnc). `JumpjetControls TurnRate=4, Speed=14, Climb=5, CruiseHeight=500, Acceleration=2, WobblesPerSecond=.15, WobbleDeviation=40` (RULES-MIRROR).

**Edge cases.**
* Infantry always default `SpeedType=Foot` regardless of Locomotor (ModEnc).
* `Teleporter=yes` units use Drive normally and Teleport only to `Dock=` buildings (e.g., Chrono Miner) (ModEnc).
* `Locomotor` on BuildingTypes has no effect (ModEnc).
* Flight: `FlightLevel=1500` leptons typical; `LeptonsPerSightIncrease=2000`; `LeptonsPerFireIncrease=2000` (RULES-MIRROR).

**Kind.** Movement system.

**Sources.** MODENC (Locomotor), RULES-MIRROR.

**Confidence.** high.

---

### RA2-GP-056 SpeedType

**What.** Terrain affinities. Values: `Foot`, `Track`, `Wheel`, `Hover`, `Winged`, `Float`, plus (firestorm) etc. ModEnc lists `Foot/Track/Wheel/Hover/Winged/Float`. There is **no** `Underground` SpeedType (a common modding myth; ModEnc footnote).

**Data keys.** `SpeedType=`, per-theater `[LandTypes]`/`[SpeedType]` modifiers in `rules(md).ini` and `.ini` land tables. `TrackedUphill/Downhill`, `WheeledUphill/Downhill` (RULES-MIRROR).

**Numbers.** `TrackedUphill=1.0`, `TrackedDownhill=1.2`, `WheeledUphill=1.0`, `WheeledDownhill=1.2` (RULES-MIRROR) — terrain speed multipliers.

**Edge cases.** SpeedType controls *terrain legality*; `MovementZone` controls *pathfinding legality*. Both must allow a cell (ModEnc MovementZone notes).

**Kind.** Movement system. **Sources.** MODENC (SpeedType/MovementZone), RULES-MIRROR. **Confidence.** high.

---

### RA2-GP-057 MovementZone (naval / amphibious / hover)

**What.** Pathfinding domain: Normal, Crusher, Destroyer, AmphibiousDestroyer, AmphibiousCrusher, Amphibious, Subterranean, Infantry, InfantryDestroyer, Fly, Water, WaterBeach, CrusherAll (YR).

**Data keys.** `MovementZone=` (ModEnc).

**Edge cases.**
* `Amphibious` is the only zone allowing amphibs to dock **all** `UnitRepair=yes` buildings (land Depot and water Yard) (ModEnc).
* `WaterBeach` exists but RA2 tilesets don't use Beach properly (ModEnc).
* `Fly` cannot enter buildings; `Subterranean` is misspelled but functional (ModEnc).
* `Crusher` assumes it can crush infantry but needs `Crusher=yes`; `CrusherAll` + `OmniCrusher=yes` to crush vehicles (ModEnc).

**Kind.** Movement/pathing.

**Sources.** MODENC (MovementZone).

**Confidence.** high.

---

### RA2-GP-058 Amphibious Transport

**What.** Both factions' naval transport (`SAPC`), 12 slots, can carry infantry + vehicles across land/water (hover over land, boat on water). No weapon.

**Numbers.** $900; Allied Light armor / Soviet stronger; `MovementZone=Amphibious` (CNCNZ). **Edge cases.** Ivan cannot bomb a transport (CNCNZ). Transports can carry MCVs to build forward bases. **Sources.** CNCNZ, WW-ARCHIVE, MODENC. **Confidence.** high.

---

### RA2-GP-059 Jumpjet / Hover / Teleport specifics

Covered across RA2-GP-055/047. Key shipped units: Rocketeer (Jumpjet), Robot Tank (Hover, TS), Kirov (Fly), Chrono Miner/Legionnaire (Teleport). **Numbers.** `HoverHeight=120`, `HoverBob=.04`, `HoverBoost=150%`, `BalloonHoverHeight=1000` (RULES-MIRROR). **Confidence.** high.

---

## 7. Vision

### RA2-GP-060 Shroud vs Fog of War

**What.** RA2 has **Shroud** (never-seen black) and **Fog of War** (seen-but-not-visible, multiplayer option). They are separate objects (ModEnc).

**Data keys.** `Shroud` (MP option, default yes), `FogOfWar=no` (`[General]` default), `ShroudGrow=no` (`[AudioVisual]`), `ShroudRate=4` minutes (bounds creep), `FogRate=.01`, `BlendedFog=yes`, `ShadowGrow`, `AlphaImage` (ModEnc/RULES-MIRROR). `Sight=` per unit; `AircraftFogReveal=6` (RULES-MIRROR).

**Numbers.** `Sight=` in cells per unit (GI 6, etc.); `AircraftFogReveal=6`; `CameraRange=9`; `RevealTriggerRadius=9` (RULES-MIRROR). `Sight` rendered via `shroud.shp` frames.

**Edge cases.**
* `Shroud=no` inverts the effect on some weapons (`RevealOnFire` shroud-fills) (ModEnc).
* Fog of War is a skirmish option; campaign often uses shroud only.
* SpySat incompatible with FogOfWar in vanilla (ModEnc).

**Kind.** Vision system.

**Sources.** MODENC (Shroud), RULES-MIRROR.

**Confidence.** high.

---

### RA2-GP-061 Radar & Destructibility

**What.** Radar minimap requires a Radar building (Allied Airforce HQ, Soviet Radar Tower, or SpySat Uplink). Losing the radar structure disables the minimap for that player. Radar is a common Spy target.

**Data keys.** `Radar=yes` (Allied AFCHQ `GAAIRC`, Soviet `NARADR`, America `AMRADR`), `SpySat=yes` as an alternate radar source (ModEnc SpySat: "not inclusive with Radar=yes"). Radar render: `schematic`/radar art per theater.

**Numbers.** Allied AFCHQ $1000 / −50; Soviet Radar Tower $1000 / −50 (WW-ARCHIVE). `LocalRadarColor=0,255,0` (RULES-MIRROR). `RadarEvent*` durations (RULES-MIRROR).

**Edge cases.**
* Destroying all radar sources removes the minimap but not shroud coverage.
* SpySat Uplink supplies radar independently of AFCHQ/Radar Tower (WW-ARCHIVE).
* Radar towers show `RadarEvent`s (combat marks) with `RadarEventVisibilityDurations=200`, etc. (RULES-MIRROR).

**Kind.** Vision/radar system.

**Sources.** WW-ARCHIVE, MODENC (SpySat), RULES-MIRROR.

**Confidence.** high.

---

### RA2-GP-062 Cloak / Stealth

**What.** Cloaking units (submarines, dolphins, Giant Squid; temporarily via Cloak crate) are invisible except under certain conditions (attacking, damaged, detected).

**Data keys.** `Cloakable=yes`, `CloakingStages=9`, `CloakDelay=.02`, `CloakSound=NavalUnitEmerge`, `Sensors=`, `DetectDisguise`. Submerge surface delay `CloakDelay=.02` (`[General]` min forced surfaced delay for subs) (RULES-MIRROR).

**Numbers.** `CloakingStages=9`; `CloakDelay=.02` minutes. Submarines/dolphins surface when badly damaged (CNCNZ). **Edge cases.** Hidden units are visible to detectors (Destroyer, Aegis? no; Destroyer + Dolphin + Squid detect subs). **Sources.** RULES-MIRROR, CNCNZ, MODENC. **Confidence.** high.

---

### RA2-GP-063 Spy Camera / Reveal triggers

**What.** Waypoint "reveal" triggers and the spy camera reveal a radius. **Data keys.** `RevealTriggerRadius=9`, `CameraRange=9`, `RevealOnFire`. **Numbers.** 9-cell camera/reveal radius (RULES-MIRROR). **Sources.** RULES-MIRROR. **Confidence.** med-high.

---

## 8. Skirmish AI

### RA2-GP-064 `ai(md).ini` structure

**What.** AI behaviour is authored in `ai(md).ini`; the four interlocking section types are `[TaskForces]`, `[TeamTypes]`, `[ScriptTypes]`, `[AITriggerTypes]`.

**Data keys / relationship (ModEnc AI programming, PPM).**
* `[TaskForces]` — lists of unit types (what).
* `[TeamTypes]` — links a TaskForce + Script + house/side + grouping (who).
* `[ScriptTypes]` — ordered action list (what to do).
* `[AITriggerTypes]` — condition → team, with weights (when).
* `[AITriggerTypesEnable]` and trigger weights: `AITriggerSuccessWeightDelta=20`, `AITriggerFailureWeightDelta=-50`, `AITriggerTrackRecordCoefficient=1` (RULES-MIRROR).
* Base building order is controlled by `[BuildingTypes]` order and a hard-coded `AIBuildThis`/`AI` rules list; AI ignores `Prerequisite`/`TechLevel` (ModEnc) and builds the power plants in `GDIPowerPlant`/`NodRegularPower`/`ThirdPowerPlant` unconditionally (ModEnc).

**Numbers.**
* `TeamDelays=2000,2500,3500` frames (easy, medium, hard) (RULES-MIRROR) — interval between AI team creation checks.
* `AIHateDelays=30,50,70`; `TotalAITeamCap=30,30,30`; `MinimumAIDefensiveTeams=1,1,1`; `MaximumAIDefensiveTeams=2,2,2`; `DissolveUnfilledTeamDelay=5000`; `MultiplayerAICM=400,0,0` (multiplayer AI coefficient of money); `AIVirtualPurifiers=4,2,0` (h,m,e); `AlliedBaseDefenseCounts=25,20,6`; `SovietBaseDefenseCounts=25,22,6`; `AIPickWallDefensePercent=50,25,10`; `AISafeDistance=20`; `AIRestrictReplaceTime=400`; `MaximumBuildingPlacementFailures=3` (RULES-MIRROR).
* `AIIonCannon*Value` (RULES-MIRROR) is the target-scoring table (25–100 weights).

**Edge cases.**
* AITriggerTypes ignore `Prerequisite` and `TechLevel` (ModEnc).
* `ai.ini` for base RA2; `aimd.ini` for YR (the `md` file suffix follows the game's master-disk convention).
* Brutal AI is a CnCNet map-injected cheat preset, not a `rules.ini` difficulty: it injects `TeamDelays=1000,1500,2500`, `AIVirtualPurifiers=8,4,2`, `MinimumAIDefensiveTeams=0,0,0`, `MaximumAIDefensiveTeams=0,0,0`, `DissolveUnfilledTeamDelay=7500`, `[Easy] BuildTime=.6` (CNC-NET). Difficulty-section naming is counter-intuitive: `[Easy]` affects Hard, `[Normal]` affects Medium, `[Difficult]` affects Easy (CNC-NET).

**Kind.** AI system.

**Sources.** MODENC (AI programming, AITriggerTypes), PPM, CNC-NET, RULES-MIRROR.

**Confidence.** high (structure & constants), med (which constants are live in RA2 vs TS).

---

### RA2-GP-065 Skirmish difficulty & economy cheats

**What.** Three difficulties (Easy/Medium/Brutal, labelled Hard in some UIs). The AI receives bonuses rather than smarter play.

**Numbers.**
* `TeamDelays` and `AIVirtualPurifiers` are the dominant difficulty levers (CNC-NET).
* Retail `AIVirtualPurifiers=4,2,0` (h, m, e) → hard AI gets 4 virtual purifiers of extra harvest income (RULES-MIRROR).
* CnCNet "Brutal" injects `AIVirtualPurifiers=8,4,2` and faster team delays, effectively ~2× attack frequency and more money (CNC-NET).
* `FineDiffControl=no` — only 3 difficulty settings unless enabled (RULES-MIRROR).
* Campaign money deltas: `CampaignMoneyDeltaEasy=50`, `CampaignMoneyDeltaHard=-50` (RULES-MIRROR).

**Edge cases.** Brutal also cuts hard-AI build time via `[Easy] BuildTime=.6` (CNC-NET note). AI never cheats in campaign by default. **Kind.** AI difficulty. **Sources.** RULES-MIRROR, CNC-NET. **Confidence.** high.

---

## 9. Multiplayer / Meta

### RA2-GP-066 Game modes & options

**What.** Skirmish and LAN/online. Options live in `[MultiplayerDialogSettings]`.

**Data keys & defaults (MODENC MultiplayerDialogSettings, YR-accurate):**

| Option | Default |
|--------|---------|
| `MinMoney` / `Money` / `MaxMoney` | 2500 / 10000 / 10000 |
| `MoneyIncrement` | 100 |
| `MinUnitCount` / `UnitCount` / `MaxUnitCount` | 1 / 10 / 20 |
| `TechLevel` | 10 |
| `GameSpeed` | 6 |
| `AIDifficulty` | 1 |
| `AIPlayers` | 1 |
| `BridgeDestruction` | 1 |
| `ShadowGrow` | 0 |
| `Shroud` | 1 |
| `Bases` | 1 |
| `TiberiumGrows` | 1 |
| `Crates` | 1 |
| `CaptureTheFlag` | 0 |
| `HarvesterTruce` | 0 |
| `MultiEngineer` | 0 |
| `AlliesAllowed` | 0 |
| `AllyChangeAllowed` | 1 |
| `ShortGame` | 0 |
| `SuperWeaponsAllowed` | 1 |
| `BuildOffAlly` | 1 |
| `FogOfWar` | 0 |
| `MCVRedeploys` | 1 |

**Numbers.** Max players is set by the shell (RA2 supports up to 8 in retail; CnCNet extends it). `MaximumQueuedObjects=29`. `MaxWaypointPathLength=15`.

**Edge cases.**
* `ShortGame=yes` ends the match when all buildings are destroyed (no rebuilding from MCV).
* `BuildOffAlly=yes` allows building in allied base radius.
* `HarvestersPerRefinery=2` is overridable per map (RULES-MIRROR).
* Starting unit count (`UnitCount`) applies to initial forces.

**Kind.** Meta / MP.

**Sources.** MODENC (MultiplayerDialogSettings), RULES-MIRROR.

**Confidence.** high (options/defaults), med (max players across clients).

---

### RA2-GP-067 Houses / Colors / Teams / Random start

**What.** A player picks a country (house) and a color; teams can be set in-game; random start assigns positions.

**Data keys.** `[Countries]`, `[Sides]`, `Color=` per country, `Multiplay=yes`, `MultiplayPassive`, `PlayerControl`, `Credits=` (map), `PercentBuilt`, `NodeCount`, `Edge`, `TechLevel` (map house), `IQ` (map house), `Allies` (map). `AllowedToStartInMultiplayer=yes` on units controls start forces.

**Numbers.** 9 base playable countries; 8 retail MP slots. Colors are per-country defaults but player-selectable (ModEnc Houses). `AllowedToStartInMultiplayer` gates MCVs/miners in starting forces.

**Edge cases.**
* Neutral is hostile to all but player units only retaliate; Special is allied to all (ModEnc).
* A map's `[Houses]` section appends to the rules list and must keep indexes stable (ModEnc).
* `AllowedToStartInMultiplayer=no` on civilians prevents them spawning in start forces (rules.md excerpt).

**Kind.** Meta / lobby.

**Sources.** MODENC (Houses), RULES-MIRROR (`[Countries]`/`[Sides]`).

**Confidence.** high.

---

## 10. Data Architecture

### RA2-GP-068 INI file set

**What.** RA2 is fully data-driven through text INIs inside `.mix` archives; the same schema serves RA2 (`rules.ini`) and YR (`rulesmd.ini`).

**Data keys / files.**
* `rules(md).ini` — all object stats, weapons, warheads, projectiles, countries, general rules.
* `art(md).ini` — visuals: `Image=`, animation sequences, cameos (`Cameo`, `AltCameo`), voxel/SHP references, `Buildup`.
* `ai(md).ini` — TaskForces/TeamTypes/ScriptTypes/AITriggerTypes.
* `sound(md).ini`, `theme(md).ini`, `eva(md).ini`, `ra2(md).mix` — audio/EVA.
* String table `ra2.csf` / `ra2md.csf` for localized names; rules `UIName=Name:...`, `Name=` (ModEnc Rules.ini).
* ModEnc warns some INIs need dummy trailing lines due to a parser bug (ModEnc INI-Editing).

**Kind.** Data architecture. **Sources.** MODENC (Rules.ini, Art.ini, INI-Editing), FANDOM (Rules.ini/Art.ini). **Confidence.** high.

---

### RA2-GP-069 Section objects & type lists

**What.** An object's section is its internal ID (e.g. `[HTNK]`, `[APOC]`). Type-list sections register it for the engine.

**Data keys.**
* `[InfantryTypes]`, `[VehicleTypes]`, `[AircraftTypes]`, `[BuildingTypes]` — registration lists (must be unique IDs; ranges 1..N).
* `[WeaponTypes]`, `[WarheadTypes]`, `[ProjectileTypes]`, `[SuperWeaponTypes]`, `[OverlayTypes]`, `[Tiberiums]`, `[Animations]`, `[VoxelAnims]`.
* `[General]`, `[AudioVisual]`, `[CombatDamage]`, `[Radiation]`, `[ElevationModel]`, `[WallModel]`, `[JumpjetControls]`, `[SpecialWeapons]`, `[CrateRules]`, `[Powerups]`, `[MultiplayerDialogSettings]`, `[Countries]`, `[Sides]`.

**Numbers.** RA2 base `[InfantryTypes]` has 45 entries; `[VehicleTypes]` 57; `[AircraftTypes]` 8 (RULES-MIRROR). IDs are 1-based and unique.

**Edge cases.**
* Adding entries can break `SetTechLevel`/`FlashCameo` triggers (RULES-MIRROR comment).
* Sections can `#include` with Ares; vanilla has one global file plus map overrides.

**Kind.** Data architecture. **Sources.** RULES-MIRROR, MODENC (Rules.ini). **Confidence.** high.

---

### RA2-GP-070 `Image=` art reuse

**What.** Logic lives in `rules` under the object ID; its art is looked up by the same ID in `art.ini`, unless `Image=` points to another art section. Also used to share art between variants and for damaged-state virtual sections.

**Data keys.** `Image=` (per object in `rules.ini`), `Cameo=`, `AltCameo=`, `Voxel=`, `Sequence=`, `Buildup=`, `Crate=` (Overlay alignment). ModEnc: if a BuildingType uses `Image=`, flags like `CanBeHidden` come from the referenced art section (ModEnc Image).

**Numbers.** Apocalypse: `APOC` in rules, `MTNK` in art (FANDOM infobox) — a concrete `Image=`-style split. Kirov: `ZEP` in both.

**Edge cases.**
* Confusing rules-ID vs art-ID is a top modding error; the engine looks up art by the object ID, then `Image=`.
* Voxel `.vxl` bodies use `Voxel=yes` and a matching `.hva`; SHP infantry use `Sequence=`.

**Kind.** Data architecture. **Sources.** MODENC (Image), FANDOM (Apocalypse/Kirov). **Confidence.** high.

---

### RA2-GP-071 Country/House system in data

**What.** `[Countries]` defines playable houses; the engine creates a `[Houses]` list on the fly; maps append houses.

**Data keys.** `[Countries]` keys `Name`, `UIName`, `Suffix`, `Prefix`, `Side`, `Multiplay`, `MultiplayPassive`, `Color`, `ParentCountry`, `WallOwner`, armor/cost/speed/build-time `*Mult` and `IncomeMult`, `VeteranInfantry/Units/Aircraft` (ModEnc Countries/Houses). Map `[Houses]`: `Country`, `ActsLike`, `Credits`, `IQ`, `Edge`, `PlayerControl`, `Allies`, `PercentBuilt`, `NodeCount`, `TechLevel`.

**Numbers.** `[Sides]` order is mandatory: GDI (Allied) first, Nod (Soviet) second; playable 9 must be first, uninterrupted (RULES-MIRROR). Max 32 houses (ModEnc Houses).

**Edge cases.**
* `ParentCountry=` lets a house inherit another's units; used for Yuri sub-houses.
* Country `*Mult` values let a house have cheaper/stronger units without duplicating object entries — a key data-driven mechanism to reproduce.

**Kind.** Data architecture / factions. **Sources.** MODENC (Countries/Houses), RULES-MIRROR. **Confidence.** high.

---

### RA2-GP-072 Maps, theaters, tilesets, localization

**What.** Maps are `.map` files edited in FinalAlert 2 (FA2). Each map has a theater (tileset family) and an `[IsoMapPack]`/terrain overlay; localization is via `.csf` string tables.

**Data keys.** `[Theater]` (`TEMPERATE`, `SNOW`, `URBAN`, `DESERT`, `LUNAR` in RA2); `[TileSet]`, `[IsoMapPack5]`, `[OverlayPack]`, `[Terrain]`; map `[Basic]` (`Theater=`, `Waypoint` count, `[Map]` dims); `NewTheater`/`Theater` art variants (`Image=`/`NewTheater=`); `.csf` strings referenced by `UIName=` and CSF labels.

**Numbers.** RA2 theaters: Temperate, Snow, Urban (desert introduced in YR maps); `TileSet` `TIB01` etc. for ore. `TiberiumLayout=0–100` for patch size; `Tiberium` (RMG) 0–3 (Low→Extreme) (ModEnc TiberiumLayout/RMG).

**Edge cases.**
* `NewTheater=yes` on art sections loads `<theater>.<name>.shp` variants (ModEnc Art.ini).
* Maps can override rules via embedded sections (map `[General]`, house `[Houses]`, object tweaks) — mods use this for balance maps.
* FA2 "CrateType" ids (0–18) spawn powerup crates via trigger action 108 (ModEnc Powerups).

**Kind.** Data architecture / content pipeline. **Sources.** MODENC (Art.ini, Powerups, TiberiumLayout), FANDOM. **Confidence.** high.

---

## Coverage Checklist

| # | Scope item | Covered by | Status |
|---|-----------|------------|--------|
| 1 | Ore & gem values | RA2-GP-001, 002 | ✅ |
| 1 | Full miner list (basic/chrono/war/slave) | RA2-GP-002 | ✅ (Slave = YR) |
| 1 | Refinery docking | RA2-GP-003 | ✅ |
| 1 | Ore purifier | RA2-GP-004 | ✅ |
| 1 | Oil derricks / tech buildings | RA2-GP-005, 006 | ✅ |
| 1 | Crates full list | RA2-GP-007 | ✅ |
| 1 | No silos | RA2-GP-008 | ✅ |
| 1 | Growth/spread | RA2-GP-001, 009 | ✅ |
| 2 | ConYard | RA2-GP-010 | ✅ |
| 2 | Build radius/adjacency/placement | RA2-GP-011 | ✅ |
| 2 | Walls/gates | RA2-GP-012 | ✅ (no gates in RA2) |
| 2 | FULL defense list | RA2-GP-013 | ✅ |
| 2 | Sell/repair/refund/survivors | RA2-GP-014, 015 | ✅ |
| 2 | Service depot | RA2-GP-018 | ✅ |
| 2 | Civilian-building garrisoning | RA2-GP-016 | ✅ |
| 2 | Engineer capture | RA2-GP-017 | ✅ |
| 2 | Build-up animation | RA2-GP-020 | ✅ |
| 2 | Cloning vats | RA2-GP-019 | ✅ (RA2-only) |
| 3 | BuildCat categories | RA2-GP-021 | ✅ |
| 3 | 6-tab UI mapping | RA2-GP-021 | ✅ |
| 3 | Prerequisite system + buckets | RA2-GP-022 | ✅ |
| 3 | RequiredHouses/ForbiddenHouses | RA2-GP-022, 027 | ✅ |
| 3 | Multiple-factory bonus | RA2-GP-023 | ✅ |
| 3 | Exits/rally | RA2-GP-024 | ✅ |
| 3 | Naval yard | RA2-GP-025 | ✅ |
| 3 | Airforce HQ/helipad, ammo/reload | RA2-GP-026 | ✅ |
| 4 | 9 country uniques | RA2-GP-027 | ✅ |
| 4 | Complete Allied rosters | RA2-GP-028–031, 035 | ✅ |
| 4 | Complete Soviet rosters | RA2-GP-032–034, 036 | ✅ |
| 5 | Spy full effects | RA2-GP-037 | ✅ |
| 5 | Engineer / Attack Dog / Tanya C4 / Crazy Ivan | RA2-GP-017, 038, 039, 040 | ✅ |
| 5 | Boris airstrike | RA2-GP-032 | ✅ (campaign) |
| 5 | Desolator radiation | RA2-GP-032, 051 | ✅ |
| 5 | Mirage disguise | RA2-GP-043 | ✅ |
| 5 | Terror Drone | RA2-GP-044 | ✅ |
| 5 | IFV passenger modes | RA2-GP-041 | ✅ |
| 5 | GI/Guardian deploy | RA2-GP-042 | ✅ |
| 5 | Tesla chain/supercharge | RA2-GP-045 | ✅ |
| 5 | Prism refraction/support | RA2-GP-046 | ✅ |
| 5 | Chrono | RA2-GP-047 | ✅ |
| 5 | Iron Curtain | RA2-GP-048 | ✅ |
| 5 | Gap Generator | RA2-GP-049 | ✅ |
| 5 | Spy Satellite | RA2-GP-050 | ✅ |
| 5 | Nuke | RA2-GP-051 | ✅ |
| 5 | Weather Control | RA2-GP-052 | ✅ |
| 5 | Paradrop | RA2-GP-053 | ✅ |
| 5 | Mind control in base RA2 | RA2-GP-054 | ✅ |
| 6 | Locomotors | RA2-GP-055 | ✅ |
| 6 | Speed types | RA2-GP-056 | ✅ |
| 6 | Movement zones | RA2-GP-057 | ✅ |
| 6 | Naval/amphibious transport/hover/jumpjet/teleport | RA2-GP-055, 058, 059 | ✅ |
| 7 | Shroud/fog params | RA2-GP-060 | ✅ |
| 7 | Radar dependency/destructibility | RA2-GP-061 | ✅ |
| 7 | Gap generator / spy satellite | RA2-GP-049, 050 | ✅ |
| 7 | Cloak/stealth | RA2-GP-062 | ✅ |
| 7 | Spy camera | RA2-GP-063 | ✅ |
| 8 | `aimd.ini` structure | RA2-GP-064 | ✅ |
| 8 | Difficulty & economy cheats | RA2-GP-065 | ✅ |
| 9 | Modes/options | RA2-GP-066 | ✅ |
| 9 | Houses/colors/teams/max players/random start | RA2-GP-067 | ✅ |
| 10 | rulesmd/artmd/aimd | RA2-GP-068 | ✅ |
| 10 | Section objects | RA2-GP-069 | ✅ |
| 10 | `Image=` reuse | RA2-GP-070 | ✅ |
| 10 | Country/house system | RA2-GP-071 | ✅ |
| 10 | Maps/theaters/localization | RA2-GP-072 | ✅ |

---

## Open Questions / Top Uncertainties

1. **Per-bail ore/gem value.** `GoldValue=25` / `GemValue=50` is community-attested (CnCNet) and consistent with Chrono/War Miner capacities, but I did not see these keys in the mirrored RA2 `[General]` block. **Action:** verify against `[Tiberiums]`/overlay sections of a retail `rules.ini` and `art.ini`. (Confidence: med.)
2. **Exact `BailCount` semantics.** The "28 bails" figure is RA1/TS. RA2 harvester capacity appears per-unit via `Storage` ($500/$1000 Chrono, $1000/$2000 War). Confirm whether RA2 uses `Storage` or a hard-coded bail count. (Confidence: med.)
3. **Internal IDs.** Display-name↔ID mappings for several units/structures are inferred from abbreviations (e.g. Grizzly `MTNK`, IFV `FV`, Prism `SREF`, Patriot `GASAM`). Apocalypse `APOC`/`MTNK`, Kirov `ZEP` are confirmed. **Action:** extract the full `[InfantryTypes]/[VehicleTypes]/[BuildingTypes]` ordering from retail rules to lock IDs. (Confidence: med.)
4. **Gap Generator radius.** `GapRadiusInCells` value not exposed in the retail `[General]` dump; needs the `[GAGAP]` section / Ares docs. (Confidence: low.)
5. **Spy blackout duration basis.** `SpyPowerBlackout=1000` frames depends on FPS (15 vs 18 vs 30). RA2 runs ~15 fps; YR/ModEnc imply ~66 s. Confirm frame rate convention for a Redot port. (Confidence: med.)
6. **Iron Curtain / C4 / Ivan durations in real seconds.** Same FPS dependency (`IronCurtainDuration=750`, `IvanTimedDelay=450`, `C4Delay=.03` min). (Confidence: med.)
7. **Defense build tab rule.** `BuildCat` only meaningfully toggles Combat→Defenses; confirm the exact tab each vanilla defense uses and how the Ships vs Vehicles tab split is driven for naval `VehicleTypes`. (Confidence: med.)
8. **RA2 vs YR differences.** This doc is base-RA2 primarily; YR adds Yuri faction, Battle Fortress, Gattling, Industrial Plant (replacing Cloning Vats content), more aircraft, and different balance constants. **Action:** produce a separate YR delta pass. (Confidence: high that deltas exist; low on complete list.)
9. **Neutral tech-building full set.** RA2 maps ship a specific small neutral set (Oil Derrick, Hospital, Outpost, Airport); other "tech" buildings are map-scripted. Confirm the canonical RA2 neutral list vs YR. (Confidence: med.)
10. **AI constants liveness.** Several `[General]` AI keys (`MultiplayerAICM`, `AIVirtualPurifiers`, `TeamDelays`) are documented for TS and reused; confirm which are actually read by the RA2 binary vs dead. (Confidence: med.)
