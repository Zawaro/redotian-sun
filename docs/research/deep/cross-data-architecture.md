# Cross-Title Data Architecture & Unified Data Model — Deep Research Reference

Exhaustive, web-sourced comparison of the **data/configuration layer** of
**Command & Conquer: Tiberian Sun (TS) + Firestorm (FS)** and **Red Alert 2 (RA2) +
Yuri's Revenge (YR)**, written to inform a single data-driven Redot engine that can load all
four titles (and, later, RA2/YR mods built on Ares/Phobos).

## Scope, method, and authority

- **Web only.** Ground truth is ModEnc (`modenc.renegadeprojects.com`), the command-line
  INI headers shipped by CnCNet, the Ares documentation
  (`ares-developers.github.io/Ares-docs`), the Phobos documentation
  (`phobos.readthedocs.io`), cnc.fandom.com, Project Perfect Mod / CnCNet forums, and
  XCC-era file-format write-ups. **No local game files were read.**
- **Cross-checked** against at least two sources per mechanic where possible. Where a single
  source is authoritative (ModEnc flag tables), that is called out.
- **Version basis.** TS `RULES.INI` + FS `FIRESTRM.INI` (TS 2.03 / Firestorm); RA2
  `RULES.INI` + YR `RULESMD.INI` (1.001, stored in `expandmd01.mix`). Inline "was" comments
  are Westwood's own tuning history. Where Firestorm overrides a TS value, both are noted.
- **No code snippets.** This document describes keys, shapes, and relationships only.
- Quotes of internal identifiers (`Verses`, `SpeedType`, `MovementZone`) are verbatim.

Confidence scale: **high** = multiple independent authoritative sources agree; **med** =
single authoritative source or a known-ambiguous/reverse-engineered mechanic; **low** =
inferred, dead code, or unresolved conflict.

Conflicts are marked ⚠.

Primary source shortcuts used throughout:

| Short name | URL |
|---|---|
| ModEnc `INI` | https://modenc.renegadeprojects.com/INI |
| ModEnc `Rules.ini` | https://modenc.renegadeprojects.com/Rules.ini |
| ModEnc `Art.ini` | https://modenc.renegadeprojects.com/Art.ini |
| ModEnc `Ai.ini` | https://modenc.renegadeprojects.com/Ai.ini |
| ModEnc `How Object Arrays Work` | https://modenc.renegadeprojects.com/How_Object_Arrays_Work |
| ModEnc `TS vs RA2` | https://modenc.renegadeprojects.com/TS_vs_RA2 |
| ModEnc `Armor types` | https://modenc.renegadeprojects.com/Armor_types |
| ModEnc `The YR Combat System` | https://modenc.renegadeprojects.com/The_YR_Combat_System |
| ModEnc `Maps` | https://modenc.renegadeprojects.com/Maps |
| ModEnc `Theaters` | https://modenc.renegadeprojects.com/Theaters |
| ModEnc `CSF File Format` | https://modenc.renegadeprojects.com/CSF_File_Format |
| ModEnc `MIX` | https://modenc.renegadeprojects.com/MIX |
| ModEnc `SHP` / `Voxel` / `HVA` | https://modenc.renegadeprojects.com/SHP |
| TS `ART.INI` (commented) | https://downloads.cncnet.org/updates/games/ts/dev/INI/Art.ini |
| Ares docs | https://ares-developers.github.io/Ares-docs/ |
| Phobos docs | https://phobos.readthedocs.io/en/latest/ |

**Caveat on the flag tables.** ModEnc's "Applicable INI Flags" tables are explicitly
annotated *"accurate only for Yuri's Revenge. All other C&C games use different sets of
flags."* The class shape (which classes inherit which keys) is stable across titles; the
exact key inventory is not. Per-title key deltas below are therefore noted as deltas, not
as exhaustive lists.

---

### X-DATA-001 — INI File Family, Naming, and Overlay Semantics

**What** — The entire data layer is a set of plain-text INI files extracted from MIX
archives at runtime. Filenames encode title and expansion via a suffix: TS uses bare names,
FS uses an `fs` / `01` variant, RA2 uses bare names, YR uses an `md` (mission disk) suffix.
The loader merges base + expansion rather than replacing wholesale.

**Keys/structure** — INI syntax is `[Section]`, `Key=Value`, `;` line comments. There is no
official include statement in the shipped engines; Ares adds `[$Include]` / inheritance.
Per-title file families:

- **RA1/CS/AM:** `rules.ini`, `aftrmath.ini`, `mission.ini`, `mplayer.ini`, `tutorial.ini`.
- **TS/FS:** `rules.ini`, `art{fs}.ini`, `ai{fs}.ini`, `battle{fs}.ini`, `sound{01}.ini`,
  `theme{01}.ini`, `mapsel{01}.ini`, `mission{1}.ini`, `keyboard.ini`, `langrule.ini` /
  `langfs.ini` (the "scrambled" string INIs), `key.ini`, plus environment INIs
  (`temperat.ini`, `snow.ini`, `day.ini`, `dusk.ini`, `night.ini`, `morning.ini`,
  `sun.ini`, `ion.ini`), `firestrm.ini` (FS rules), `tmcj4f.ini`, `tutorial.ini`.
- **RA2/YR:** `rules(md).ini`, `art(md).ini`, `ai(md).ini`, `battle(md).ini`,
  `eva(md).ini`, `sound(md).ini`, `theme(md).ini`, `mission(md).ini`, `mapsel(md).ini`,
  `keyboard(md).ini`, `coopcamp(md).ini`, `mpbattle/mpcoop/mpduel/mpfree/mpmeat/mpmodes/
  mpmw/mpnaval/mpsiege/mpunholy(md).ini`, `ra2(md).ini`, `rmg(md).ini`,
  `temperat/desertmd/snow/urban/urbannmd/lunarmd(md).ini`, `ui(md).ini`.

**Per-title differences**
- **TS → FS is an overlay.** FS adds `expand01.mix`, which contains `firestrm.ini`
  (the FS "rules.ini") *and* a fresh `rules.ini` "completely consistent with the rules.ini
  in patch.mix" for plain TS. Presence of `expand01.mix` is how the engine detects FS at
  all; if `firestrm.ini` is also present the game is treated as FS, at which point
  `sound01.ini` replaces `sound.ini` and `theme01.ini` is loaded and merged on top of
  `theme.ini`. Same pattern for `artfs.ini`, `aifs.ini`, `battlefs.ini`, `langfs.ini`,
  `mapsel01.ini`, `mission1.ini`.
- **RA2 → YR is a rename, not just an overlay.** YR modding *must* use `*md.ini`
  (`rulesmd.ini`, `artmd.ini`, `aimd.ini`); the non-md RA2 files are also present but are
  not the YR data. YR 1.000 keeps `rulesmd.ini` in `ra2md.mix → localmd.mix`, but the
  1.001 patch value lives in `ra2md.mix → localmd.mix` for 1.000 and the real 1.001 fix is
  in `expandmd01.mix`. Novices who extract from `localmd.mix` lose the 1.001 balance pass.
- **`fs` vs `01`:** ModEnc writes the FS suffix as `{fs}` for art/ai/battle and `{01}` for
  sound/theme/mapsel (i.e. the numeric second expansion slot). `langrule.ini` /
  `langfs.ini` are the correct names; XCC reported them under scrambled hashes
  (`B3C17994`, `51A25286`).
- Per-map INI: TS reads an extra INI named after each map (same basename, `.INI`) for
  localization strings.

**Unified-model implication** — The loader must be a three-layer **overlay chain**
(`base → expansion → map/mod`), not a filename switch. Represent a *title profile*
(`game.tres`) that declares: base INI set, overlay INI set, expansion mix load order,
suffix rule (`fs`/`01`/`md`), and which `[Section]` families are authoritative for that
title. Mods then layer arbitrary INI packs on top of a profile. The project already models
this as `games/<id>/game.tres`; the research confirms the merge order is semantically
required (theme merges, sound replaces, rules overlay).

**Sources** — ModEnc `INI`; ModEnc `Rules.ini` (footnotes 2–4); ModEnc `Art.ini`;
ModEnc `Ai.ini`.

**Confidence** — high.

---

### X-DATA-002 — Section-List Registration Architecture (Object Arrays)

**What** — Every object class that can be spawned, referenced by AI/scripts, or targeted by
map triggers is registered in a **section array** (e.g. `[InfantryTypes]`,
`[VehicleTypes]`, `[AircraftTypes]`, `[BuildingTypes]`, `[WeaponTypes]` (Ares),
`[SuperWeaponTypes]`, `[Animations]`, `[VoxelAnims]`, `[Tiberiums]`, `[OverlayTypes]`,
`[SmudgeTypes]`, `[TerrainTypes]`, `[Warheads]`, `[Particles]`, `[ParticleSystems]`).
An object defined as a section but *not* listed in its array "does not exist" to the game,
with narrow exceptions (objects parsed via another object's reference get implicitly
appended, e.g. `DeploysInto`, `Enslaves`, `PrismType`, `AnimToInfantry` — but this is
explicitly unreliable and load order is not guaranteed).

**Keys/structure** — The list is `[ArrayName]` with `index = ObjectID` lines. Crucially,
**the text to the left of `=` is ignored**:

- Internal index is **0-based and assigned in file-read order**, not by the number typed.
  `a^2+b^2=CSQUARED` is a valid entry whose internal index is its position.
- New entries from game-mode INIs and map files are **appended** to the end of the array,
  provided the object is not already present.
- Duplicate entries: the first is loaded, later duplicates are discarded.
- Capitalization must be identical between the array entry and the object section, and
  between `Image=` and the art-file section.
- Adding to the middle or reordering **breaks** every consumer that references by index
  (map triggers, AI scripts, hardcoded overlay/Tiberium indices). Always append.

**Per-title differences**
- The array *set* is largely the same TS → YR. YR adds `[Countries]` as the house registry
  (see X-DATA-019). `[WeaponTypes]` does **not** exist in the shipped engine — weapons are
  parsed on reference (see X-DATA-020); it is an Ares addition.
- `[BuildingTypes]` order is called out as especially dangerous: "AI Scripts can only
  attack a specific BuildingType via its index in this array." Westwood's own arrays
  contain errors (duplicates / misindexing) that community-derived corrected arrays exist
  for.
- `[OverlayTypes]` and `[Tiberiums]` have **hardcoded** index→behaviour bindings and are
  capped at 255 entries; the first ~180 slots are mostly unused RA1/TS leftovers. Insertion
  into the middle is effectively forbidden.

**Unified-model implication** — Model every class as a registry with:
(1) a stable **logical ID** (the section name), (2) a per-title **stable numeric index**
captured at load time and never recomputed, and (3) a **reference-resolution pass** that
adds implicitly-referenced objects to the end exactly as the engine does. Keep the original
numeric index for compatibility with map triggers, AI script arguments, and hardcoded
tables, even though the engine ignores the literal number. This is the single most
important invariant for save/load, map import, and AI script fidelity.

**Sources** — ModEnc `How Object Arrays Work`; ModEnc `VehicleTypes`; ModEnc
`InfantryTypes`; ModEnc `AircraftTypes`; ModEnc `BuildingTypes`; ModEnc `OverlayTypes`;
ModEnc `Tiberiums`.

**Confidence** — high.

---

### X-DATA-003 — Common Object Class Hierarchy (Abstract → Object → Techno)

**What** — The rules layer is organised as an inheritance chain of internal C++ classes.
Each level adds keys; every concrete object inherits all of them. The chain (YR flag
ordering) is: `AbstractType → ObjectType → TechnoType → {InfantryType, VehicleType,
AircraftType, BuildingType}`, with `WarheadType`, `WeaponType`, `SuperWeaponType`,
`Projectile`, `Animation`, `OverlayType`, `Tiberium`, `HouseType` as sibling roots.

**Keys/structure** — Simplified inheritance map:

- **AbstractType:** `Name`, `UIName`.
- **ObjectType:** `Image`, `AlphaImage`, `CrushSound`, `AmbientSound`, `Crushable`,
  `Bombable`, `NoSpawnAlt`, `AlternateArcticArt`, `RadarInvisible`, `Selectable`,
  `LegalTarget`, `Armor`, `Strength`, `Immune`, `Insignificant`, `HasRadialIndicator`,
  `RadialColor`, `IgnoresFirestorm`, `UseLineTrail`, `LineTrailColor`,
  `LineTrailColorDecrement`, `Theater`, `NewTheater`, `Voxel`.
- **TechnoType** adds (huge): targeting (`LandTargeting`, `NavalTargeting`), movement
  (`SpeedType`, `WalkRate`, `MoveRate`, `Weight`, `PhysicalSize`, `Size`, `SizeLimit`,
  `Locomotor`, `Speed`, `MovementZone`), combat (`Primary`, `Secondary`, `ElitePrimary`,
  `EliteSecondary`, `WeaponX`/`EliteWeaponX`, `TurretCount`, `WeaponCount`, `GuardRange`,
  `DeathWeapon`, `Explodes`), economy (`Cost`, `BuildTime`, `BuildLimit`, `Storage`,
  `ResourceGatherer`, `ResourceDestination`), ownership/tech (`Owner`, `RequiredHouses`,
  `ForbiddenHouses`, `Prerequisite`, `PrerequisiteOverride`, `TechLevel`), UI/sound
  (`Voice*`, `MoveSound`, `DieSound`, `CreateSound`), visuals/particles (`Explosion`,
  `DestroyAnim`, `NaturalParticleSystem`, `DamageParticleSystems`), and special
  behaviour flags (`Cloakable`, `GapGenerator`, `Teleporter`, `Sensors`, `IsGattling`,
  `CanDisguise`, `OpenTopped`, `Drainable`, `PipScale`, `Sight`, `SensorsSight`).
- **Class-specific** additions:
  - `InfantryType`: `Sequence`, `Crawls`, `FireUp`, `FireProne`, `PipScale`, `Voice*`.
  - `VehicleType`: `Turret`, `TurretOffset`, `TurretSpins`, `ManualReload`, `DeploysInto`,
    `UndeploysInto`, `PowersUnit`, `PoweredUnit`, `Passengers`, `SizeLimit`.
  - `AircraftType`: `FlightLevel`, `PitchAngle`, `RollAngle`, `PitchSpeed`, `IsDropship`,
    `HoverAttack`, `PadAircraft`, `Ammo`, `Reload`, `AirRangeBonus`.
  - `BuildingType`: `Foundation`, `Height`, `Power`, `Powered`, `ExtraPower`,
    `PowerBonus`, `ConstructionYard`, `WeaponsFactory`, `Factory`, `Refinery`,
    `Dock`, `NumberImpassableRows`, `IsBaseDefense`, `BaseNormal`, `EligibleForDelayKill`,
    `CloakGenerator`, `GapGenerator`, `LightningRod`, `Buildup`, `UndeploysInto`,
    `CanBeOccupied`, `MaxNumberOccupants`, `IsTemple`, `IsPlug`, `HoverPad`, `ToOverlay`.

**Per-title differences**
- Inherited *shape* is consistent TS→YR, but **key sets differ**: ModEnc's flag tables are
  YR-specific. TS has no `[WeaponTypes]`, lacks the YR `Napalm`/`Gattling` stage keys in the
  same form, and some YR-only keys (`DoubleOwned`, `IsChargeTurret`, `WeaponStages`,
  `RateUp`/`RateDown`, `PipWrap`, `HasTurretTooltips`) do not parse in TS.
- TS-specific keys survive into YR but change meaning or are dead: `EMEffect`, `Deform`/
  `DeformThreshhold`, `Veinhole`, `Culling`, `Tiberium` (warhead) are TS-functional and
  no-ops in RA2/YR. Conversely, RA2/YR adds `Gunner`, `IsGattling`, `Spawns`,
  `Spawned`, `Passengers`, `OpenTopped`, `MindControl`, `IvanBomb`, `Airstrike`, `Temporal`,
  `Culling` reuse.
- FS adds almost no new classes; it adds objects and a few values on top of TS
  (`FTNK`, `Firestorm Wall` logic, `GAFSDF`).

**Unified-model implication** — Use **compositional components** rather than an inheritance
tree, but map every classic key onto a component property so INI import is mechanical. The
component set mirrors the class levels: `Identity`, `Stats`, `Ownership`, `Build`,
`Movement`, `Combat/WeaponSlots`, `Turret`, `Art/Visuals`, `Voice`, `SpecialFlags`. Keep a
per-title **key dictionary** that says which component property a key feeds and whether it
is active, dead, or absent in that title. Do not fork component code per title; fork only
the key dictionary.

**Sources** — ModEnc `VehicleTypes`, `InfantryTypes`, `AircraftTypes`, `BuildingTypes`
(Applicable INI Flags tables, YR); ModEnc `General`; ModEnc `TS vs RA2`.

**Confidence** — high for the shape; med for exact per-title key membership.

---

### X-DATA-004 — Identity, Image Linkage, and Visual/Cameo Keys

**What** — Every rules object has a logical `Name` (its section ID) and a display `UIName`
(CSF label). The `Image=` key points to the **art.ini section** that holds its graphics;
when omitted, it defaults to the object's own ID. This is the sole bridge between the rules
layer and the art layer.

**Keys/structure**
- `Name=<string≤48>` — internal ID, defaults to the section name.
- `UIName=<CSF label>` — sidebar/selection display string; resolved through CSF
  (`Name:XXX`, `stt:...`).
- `Image=<art section id>` — defaults to the object's own section name.
- `AlphaImage=<shp>` — alpha/overlay image.
- `Cameo=<shp>` (art side) — sidebar icon; `CameoPCX` for PCX cameos under Ares.

**Per-title differences**
- `Image=` semantics are identical TS→YR. The *art* file it points into differs by name
  (`art.ini` / `artfs.ini` / `artmd.ini`).
- Cameos live in `cameo.mix` (RA2) / `cameomd.mix` (YR) / `local.mix` (TS); formats are SHP
  (and PCX only with Ares/Phobos). The cameo *palette* / country-art binding is
  index-driven (see X-DATA-019).

**Unified-model implication** — Split each entity into a **rules sheet** and an **art
sheet** keyed by the same logical ID, exactly as the originals do. `Image` is a
many-to-one alias (several rules objects may share one art sheet, e.g. `[PROC] Image=NAREFN`).
The unified model needs an `art_alias` resolution step and must tolerate a missing art
sheet (headless/tests).

**Sources** — ModEnc `Image`; ModEnc `Art.ini`; ModEnc `Cameo`; TS `ART.INI` header
(commented).

**Confidence** — high.

---

### X-DATA-005 — Build Prerequisites, Tech Level, Owners, and Tech Gates

**What** — Buildability is a funnel: **Owner/House gate → RequiredHouses/ForbiddenHouses →
TechLevel → Prerequisite (+ PrerequisiteOverride) → factory/dock routing**. The AI ignores
most of this by design ("AI cheats"), which must be modelled explicitly.

**Keys/structure**
- `Owner=<house list>` — which houses may own/build; `RequiredHouses=<house list, ≤32>` —
  exclusive build rights; `ForbiddenHouses=<house list>` — explicit deny. `<none>` clears a
  `ForbiddenHouses` list but does *not* clear `RequiredHouses` (must list all countries).
- `TechLevel=<int>` — minimum tech level; gated again by
  `[MultiplayerDialogSettings] TechLevel=` at match start.
- `Prerequisite=<object list>` — usually building type IDs (e.g. `GAPILE`, `NAWEAP`).
- `PrerequisiteOverride=<object list>` — alternative prerequisites.
- Generic groups in `[General]`: `PrerequisitePower`, `PrerequisiteFactory`,
  `PrerequisiteBarracks`, `PrerequisiteRadar`, `PrerequisiteTech`, `PrerequisiteProc`.
- Factory routing: `Factory=<BuildingType>`, `WeaponsFactory=yes`, `ConstructionYard=yes`,
  `Dock=<BuildingType>` vector, `DeploysInto`, `UndeploysInto`.

**Per-title differences**
- TS and RA2/YR both use `Prerequisite=`, `TechLevel=`, `Owner=`. RA2/YR additionally relies
  heavily on `RequiredHouses=`/`ForbiddenHouses=` for country-specific units; in TS the
  equivalent gating is done more through `Owner=` and `Houses`/`ActsLike`, since TS has no
  `[Countries]`.
- Ares extends the model with `Prerequisite.Negative`, multiple alternative prerequisite
  lists, `Prerequisite.Lists`, generic prerequisite groups, `RequireTheater=`, and
  `Prerequisite.StolenTechs` (spy infiltration).

**Unified-model implication** — A single **TechTree** service with composable predicates:
`owns_house`, `exclusive_to_house`, `denied_to_house`, `min_tech_level`, `requires(all)`,
`requires_any(alternatives)`, `requires_negative`, `requires_factory(type)`. Keep the
generic `[General]` prerequisite groups as named sets so data never hardcodes building IDs.
Expose an `ai_ignores_prerequisites` mode for AI houses.

**Sources** — ModEnc `RequiredHouses`; ModEnc `Owner`; ModEnc `Prerequisite`;
Ares docs → New & Enhanced In-Game Logic → Prerequisites; ModEnc `BuildingTypes`.

**Confidence** — high.

---

### X-DATA-006 — Power, Foundation, Cost, Strength, Armor

**What** — The economic/stats quartet is uniform across titles: `Cost`, `Strength`
(hit points), `Armor` (armor class), and for buildings `Power`/`Powered`/`Foundation`/
`Height`. Foundations occupy a rectangular footprint; power is a per-house grid.

**Keys/structure**
- `Cost=<int>` (credits), `Strength=<int>` (HP), `Armor=<class name>`.
- Buildings: `Power=<int>` (positive = generate, negative = drain), `Powered=<bool>`,
  `PowerBonus=<int>`, `Foundation=<WxH>` (e.g. `4x3`, `1x1`), `Height=<levels, 200 leptons
  each>`, `NumberImpassableRows`, `BibShape`, `BaseNormal`.
- `BuildTimeMultiplier=<float>`, `BuildLimit=<int>`.
- `Sight`, `SensorsSight`, `GuardRange`.

**Per-title differences**
- Cost/Strength/Armor shapes identical. `Armor` accepts a **different enum** per title:
  TS = `none, light, wood, heavy, concrete` (5); RA2/YR = `none, flak, plate, light,
  medium, heavy, wood, steel, concrete, special_1, special_2` (11). See X-DATA-009.
- `Foundation` is a TS→YR building concept; TS foundations include irregular/`1x1` and
  multi-part structures (component towers). RA2/YR adds `CanBeOccupied`/`MaxNumberOccupants`
  and `IsPlug`/`HoverPad`/`IsTemple` categories used by AI targeting values.
- Nuclear/`ThirdPowerPlant` categories and `PowerUp1/2/3Anim` building upgrade animations
  are present in TS and RA2/YR, with YR adding `PowerUpNAnim` custom upgrades (Phobos fixes
  the fallback to building image).

**Unified-model implication** — Store stats as numbers with **display units derived from
title constants** (leptons per cell, cell render size). Power must be a per-house grid
resource with supply/demand and low-power production penalty. Foundation is a footprint
mask on the cell grid, not a width/height pair — TS has multi-tile and component
buildings. Keep an **armor-class registry** per title (X-DATA-009).

**Sources** — ModEnc `VehicleTypes`/`BuildingTypes`; ModEnc `General` (`MultipleFactory`,
`MinLowPowerProductionSpeed`, `LowPowerPenaltyModifier`); ModEnc `Strength`; ModEnc `Power`.

**Confidence** — high.

---

### X-DATA-007 — Weapon Slot Model and Turrets

**What** — A unit/building references weapons by name through a fixed slot list. Slots are
resolved at parse time; weapons are not centrally registered in the shipped engine.

**Keys/structure**
- `Primary=`, `Secondary=`, `ElitePrimary=`, `EliteSecondary=`, `WeaponX`/`EliteWeaponX`
  (`X` = 1..n), `WeaponCount=<int>`, `TurretCount=<int>`, `IsChargeTurret`.
- Turret/barrel art keys (art file): `TurretOffset`, `BarrelLength` / `PBarrelLength` /
  `SBarrelLength`, `BarrelOffset`, `FireAngle`, `PrimaryFireFLH`, `SecondaryFireFLH`,
  `PrimaryFirePixelOffset`, `SecondaryFirePixelOffset`, `TurretRotateSound`.
- Targeting selection: `LandTargeting` (0 OK, 1 forbidden, 2 use secondary), `NavalTargeting`
  (enum 0–7 incl. `UNDERWATER_ONLY`, `ORGANIC_SECONDARY`, `SEAL_SPECIAL`, `NAVAL_ALL`),
  `CanPassiveAquire`, `CanRetaliate`, `CanApproachTarget`.

**Per-title differences**
- TS has no `[WeaponTypes]` array — a weapon section is parsed when referenced. RA2/YR same.
  Ares introduces `[WeaponTypes]` so weapons can exist without a dummy unit carrier.
- `WeaponX`/elite slots exist TS→YR; `Gunner` mode (IFV) is RA2/YR-specific.
- `IsGattling` stage machine (`WeaponStages`, `RateUp`, `RateDown`, `StageX`,
  `EliteStageX`) is RA2/YR; Ares adds cycle controls.
- YR adds `IsChargeTurret` (animated charge turret) and `HasTurretTooltips`.

**Unified-model implication** — A `WeaponSlotSet` component: ordered slots
(`primary`, `secondary`, `elite_primary`, `elite_secondary`, `weapon_1..n`) plus a
**slot state machine** for gattling/charge/gunner. Slot resolution must ask the warhead
`Verses` matrix and `LandTargeting`/`NavalTargeting` (see X-DATA-009/010) *before*
projectile checks. Turret is a separate articulated sub-entity with its own art sheet and
FLH offsets.

**Sources** — ModEnc `VehicleTypes`; ModEnc `BuildingTypes`; ModEnc `The YR Combat System`
(Primary vs Secondary, Land/Naval targeting, Gunner, IsGattling); ModEnc `WeaponTypes`
(Ares).

**Confidence** — high.

---

### X-DATA-008 — Movement, Locomotion, and Movement Zones

**What** — Movement is selected through a `SpeedType`/`Locomotor` pair plus a
`MovementZone` class; terrain passability is computed from `SpeedType` + tile `LandType`.

**Keys/structure**
- `Speed=<float>`, `WalkRate=<float>`, `MoveRate`, `AccelerationFactor`,
  `DeaccelerationFactor`, `SlowdownDistance`, `Weight`, `PhysicalSize`, `Size`,
  `SizeLimit`.
- `SpeedType=<enum>` — foot/track/wheel/float/hover/amphibious/air/subterranean.
- `Locomotor=<CLSID>` — drop-in replacement movement class (default `Teleport`).
- `MovementZone=<enum>` — normal/crusher/infantry/amphibious/subterranean.
- `IsTrain`, `DoubleOwned`, `HoverAttack`, `CloakingSpeed`.
- Terrain side: `[LandTypes]` (in the terrain-control INI) maps tile classes to
  passability/speed for each `SpeedType`.

**Per-title differences**
- TS has full subterranean, hover, and train (monorail) locomotion; RA2/YR keeps hover
  (Kirov/Siege Chopper jumpjet), navals, and amphibious but repurposes/removes some TS
  terrain-specific behaviours.
- TS `[General]` hover tuning (`HoverHeight`, `HoverBob`, `HoverDampen`, `HoverBoost`,
  `HoverAcceleration`, `HoverBrake`, `HoverBob`) is TS-specific and largely dead in RA2/YR.
- RA2/YR adds `JumpjetControls` (`[JumpjetControls]`) and `FlightLevel`.
- `Per-cell` movement costs are title/terrain specific (`TrackedUphill`/`WheeledDownhill`
  etc. exist across titles).

**Unified-model implication** — Define `SpeedType` as an open registry; each tile declares
a per-SpeedType cost/forbidden bitmask. Keep `MovementZone` as a policy class on top.
Separate the **grid cost model** (data) from the **steering/locomotor** (code), so hover,
subterranean, jumpjet, and train are locomotor strategies, not title branches.

**Sources** — ModEnc `VehicleTypes`; ModEnc `General`; ModEnc `Locomotor`; ModEnc
`JumpjetControls`; ModEnc `TS vs RA2`.

**Confidence** — high for shape; med for exact per-title enum membership.

---

### X-DATA-009 — Combat Resolution: Armor Classes, Verses, and Targeting

**What** — The damage pipeline is: `Land/Naval Targeting → Warhead → Projectile →
Primary/Secondary order`. The warhead's `Verses` vector attenuates `Damage=` per armor
class and decides whether a weapon may engage a target at all.

**Keys/structure**
- `Armor=<class>` on every `TechnoType`.
- `Verses=<percent list>` on every `WarheadType`, ordered by armor class.
- Special Verses semantics (RA2/YR): >3% normal; 1% disables passive-acquire and
  retaliation unless the opposite slot can engage; 0% forbids all action including force
  fire (the weapon passes to `Secondary` or another slot).
- Projectile gates: `AA=`, `AG=`, `AN=` (air/ground/naval), plus `LandTargeting`/
  `NavalTargeting` which override everything except air.
- `PercentAtMax` for CellSpread falloff; damage applied per-cell to buildings.

**Per-title differences**
- **Armor class count differs:** TS 5 (`none, light, wood, heavy, concrete`); RA2/YR 11
  (`none, flak, plate, light, medium, heavy, wood, steel, concrete, special_1,
  special_2`). `Verses` therefore has length 5 (TS) vs 11 (RA2/YR). Ares introduces a new
  `[ArmorTypes]` section to add classes beyond the hardcoded 11, with matching Verses.
- RA2/YR uses armor structurally to route targeting (sniper → infantry only); TS uses it
  more loosely.
- RA2/YR adds `ProneDamage`, `AffectsAllies`, and many warhead effect flags not in TS.
- ⚠ ModEnc documents the 2% special case as "broken" (behaves like normal). The Rules.ini
  comments about 1%/2% are inaccurate to engine behaviour.

**Unified-model implication** — Build an **ArmorTable** per title: ordered list of class
names, with an import adaptation that **pads/aligns length-5 TS Verses into the 11-slot
RA2/YR order** when normalising to the unified (superset) order, or keeps per-title order
and a lookup map. The unified order should be the 11-class order plus Ares extensions;
TS armor names map onto it (`light→light`, `wood→wood`, `heavy→heavy`, `concrete→concrete`,
`none→none`). Combat resolution must consult targeting before Verses and Verses before
projectile.

**Sources** — ModEnc `Armor types`; ModEnc `The YR Combat System`; ModEnc `Verses`;
ModEnc `Warheads`; Ares docs → `Additional ArmorTypes and Verses`.

**Confidence** — high.

---

### X-DATA-010 — Warhead Schema

**What** — Warheads own the damage application, impact animations, and status effects. They
are the "strongest general tag" in combat.

**Keys/structure**
- Area/damage: `CellSpread`, `CellInset`, `PercentAtMax`, `Verses`, `ProneDamage`.
- Visual/audio: `AnimList`, `Bright`, `CombatLightSize`, `CLDisableRed/Green/Blue`,
  `Particle`, `ShakeXlo/Xhi/Ylo/Yhi`, `MinDebris`/`MaxDebris`, `DebrisTypes`,
  `DebrisMaximums`.
- Material interaction: `Wall`, `WallAbsoluteDestroyer`, `PenetratesBunker`, `Wood`,
  `Tiberium`, `Conventional`.
- Status/effect flags: `EMEffect`, `MindControl`, `Poison`, `IvanBomb`, `ElectricAssault`,
  `Parasite`, `Temporal`, `IsLocomotor`, `Locomotor`, `Airstrike`, `Psychedelic`,
  `BombDisarm`, `Paralyzes`, `Culling`, `MakesDisguise`, `NukeMaker`, `Radiation`,
  `PsychicDamage`, `AffectsAllies`, `Bullets`, `Veinhole`, `Sparky`, `Rocker`,
  `DirectRocker`, `Sonic`, `Fire`, `Deform`/`DeformThreshhold` (TS), `CausesDelayKill`/
  `DelayKillFrames`/`DelayKillAtMax`.
- `[Warheads]` array registers all warheads (recommended, though "rumored" to work without).

**Per-title differences**
- TS-only functional: `Deform`, `DeformThreshhold`, `EMEffect` (EMP), `Veinhole`,
  `Tiberium`, `Culling` (partial). RA2/YR-only functional: `IvanBomb`, `Airstrike`,
  `Temporal`, `PsychicDamage`, `MakesDisguise`, `ProneDamage`, `AffectsAllies`,
  `PenetratesBunker`, `BombDisarm`.
- FS adds the Firestorm-wall interaction (`IgnoresFirestorm` on objects, wall warheads).
- Ares extends warheads with per-effect caps/durations (`EMP.Cap`, `EMP.Duration`,
  `IronCurtain.Cap/Duration`, `Temporal.WarpAway`, `MindControl.Permanent`) and many
  `Convert`, `Crit`, `Shield`, `KillWeapon` sub-namespaces.
- Phobos adds even more (criticals, shields, AttachEffects, damage multipliers).

**Unified-model implication** — A **StatusEffectRegistry**: each warhead flag maps to a
named status effect (`emp`, `mind_control`, `parasite`, `temporal`, `radiation`, `poison`,
`berserk`, `disguise`, `delay_kill`, ...) with a duration/cap and stacking rule. Keep the
raw flag→effect mapping per title in the key dictionary; the effect system itself is shared.
Impact animations resolve through the animation registry, not hardcoded names.

**Sources** — ModEnc `Warheads`; ModEnc `The YR Combat System` (Related Tags); Ares docs →
Warheads; Phobos docs → New/Enhanced Logics.

**Confidence** — high.

---

### X-DATA-011 — Projectile Schema

**What** — Projectiles carry damage from shooter to target and gate air/ground/naval
eligibility.

**Keys/structure**
- `AA`, `AG`, `AN` (air/ground/naval engagement), `AS` (RA2, redundant).
- Flight: `Arcing`, `ROT`, `Speed`, `Acceleration`, `High`, `Airburst`/`AirburstWeapon`,
  `Cluster`, `ShrapnelCount`, `ShrapnelWeapon`, `Bouncy`, `Elasticity`, `Proximity`,
  `Inaccurate`, `Vertical`.
- Visuals: `Image`, `AlphaImage`, `AnimPalette`, `FirersPalette`, `UseLineTrail`,
  `LineTrailColor`, `LineTrailColorDecrement`, `NewTheater`, `Theater`,
  `AlternateArcticArt`.
- Constraints: `SubjectToCliffs`, `SubjectToElevation`, `SubjectToWalls`.

**Per-title differences**
- TS projectiles include TS-only behaviours (`Arcing` etc. exist in both but tuning
  differs). RA2/YR adds `Ranged` (Ares/Phobos), `AirburstWeapon`/`Cluster` usage, and
  `Splits`/`Trajectory` under extensions.
- Ares adds `ProjectileRange`, `BallisticScatter`, `Ranged`, `Splits`, `AttachedSystem`
  trailers; Phobos adds new trajectories (`Straight`, `Parabola`, `Bombard`).

**Unified-model implication** — A **ProjectileBehavior** strategy with an engagement mask
and a flight model. The engagement mask belongs to the unified "can this weapon hit
domain X" check shared with targeting.

**Sources** — ModEnc `Projectile`; ModEnc `The YR Combat System` (Projectiles);
Ares docs → Projectiles; Phobos docs → New/Enhanced Logics.

**Confidence** — high for RA2/YR; med for exact TS key parity.

---

### X-DATA-012 — Superweapon Registry

**What** — Superweapons are their own section type with a charge model and a UI entry,
plus a `Type` that maps to a hardcoded action.

**Keys/structure** (`[SuperWeaponTypes]`)
- `WeaponType`, `Action` (hardcoded action enum, e.g. nuke, ion, chrono, iron curtain,
  weather, spy plane, para-drop), `Type`, `PreDependent`.
- Charge: `RechargeTime` (minutes), `UseChargeDrain`, `ManualControl`,
  `AIDefendAgainst`, `IsPowered`, `DisableableFromShell`.
- UI: `SidebarImage`, `ShowTimer`, `FlashSidebarTabFrames`, `SpecialSound`, `StartSound`.
- Building binding: `AuxBuilding`, and building-side `SuperWeapon=`, `SuperWeapon2=`,
  `HasSpotlight`, `IsTemple`, `IsPlug`.
- `[General]` cross-refs: `AIIonCannon*Value` targeting valuations, `AIMinorSuperReadyPercent`.

**Per-title differences**
- TS superweapons: Ion Cannon, Hunter-Seeker/EMP (FS), MultiMissile (Nod), ChemMissile,
  Firestorm Wall (FS), Drop Pod. RA2/YR: Nuke, Weather Storm, Chronosphere, Iron Curtain,
  Force Shield, Psychic Dominator, Genetic Mutator, Spy Plane, ParaDrop, etc.
- YR adds `[AITriggerTypes]` superweapon conditions (Iron Curtain / Chrono ready), which
  TS lacks.
- Ares significantly extends the model (`SW.*` namespace: `SW.AutoFire`, `SW.ManualFire`,
  `SW.ShowCameo`, availability, targeting, range, charge/drain, messages, lighting, EVA).
- `AuxBuilding` lets a superweapon be granted by a building type without a dedicated
  `SuperWeapon=` field.

**Unified-model implication** — A **SuperweaponRegistry** with declarative charge state,
UI metadata, and an effect hook. The effect hook should call into the same effect system
warheads use. Per-map/tech gates (`DisableableFromShell`, `TechLevel`, `RequiredHouses`)
apply to superweapons as they do to units.

**Sources** — ModEnc `SuperWeaponTypes`; ModEnc `AITriggerTypes` (conditions 5–6);
Ares docs → Super Weapons; ModEnc `AI`.

**Confidence** — high for YR; med for TS-specific superweapon set.

---

### X-DATA-013 — Resource / Tiberium Registry

**What** — Harvestable resources are special overlay-driven types. TS calls them Tiberium
variants; RA2/YR internally still do but display ore/gems.

**Keys/structure** (`[Tiberiums]`)
- `Name`, `Image` (1–4, **not** a filename — selects a hardcoded overlay set), `Value`
  (credits per unit), `Power` (harvester power), `Color` (palette colour name),
  `Spread`/`SpreadPercentage` (growth), `Growth`/`GrowthPercentage`, `Debris`.
- `[OverlayTypes]` holds the actual ore/gem/vein tiles; indices are hardcoded.

**Per-title differences**
- TS has 4 types: **Riparius** (green, basic), **Vinifera** (blue, more valuable),
  **Cruentus** (large dark-blue crystal, destructible but not harvestable), **Aboreus**
  (listed but unused; mods repurpose as red). TS supports veins and Blossom Trees.
- RA2/YR uses only 2 functionally: ore = Riparius, gems = Cruentus. Vinifera/Aboreus
  overlay slots still exist (hardcoded) but are unused.
- FS adds nothing to the resource set; TS-specific `VeinGrowthEnabled` /
  `IceGrowthEnabled` / `TiberiumDeathToVisceroid` map flags do not exist in RA2/YR.
- Ares extends Tiberium (storage, spill, heal, damage, visceroids, explosive, chain
  reactions); Phobos dehardcodes growth and slope spread.

**Unified-model implication** — A **ResourceTable** independent of overlay indices: each
resource has value, colour, growth rule, harvester power, and an **overlay tile-set
binding** resolved per title/theater. The hardcoded overlay indices must live in a
compatibility table. Veins, blossom trees, and ice are TS-only resource/special systems
that can be modelled as optional resource-growth strategies.

**Sources** — ModEnc `Tiberiums`; ModEnc `OverlayTypes`; Ares docs → Tiberium; ModEnc
`Basic` (`VeinGrowthEnabled`, `TiberiumGrowthEnabled`, `TiberiumDeathToVisceroid`).

**Confidence** — high.

---

### X-DATA-014 — Overlay, Terrain, and Smudge Types

**What** — Non-entity map contents: walls/sandbags, bridges, crates, rocks, ore tiles,
veins, and scorch marks. `[OverlayTypes]` is one of the most index-sensitive registries.

**Keys/structure**
- `[OverlayTypes]` — ordered, hardcoded index→behaviour, hard cap 255. Entries include
  `GASAND`, `GAWALL`, `NAWALL`, `BRIDGE1/2`, `GEM01..12`, `TIB01..20`, `TRACKS*`,
  `CRATE`, `LOBRDG*`, `SROCK*`, `TROCK*`, `VEINHOLEDUMMY`, `USELESS`.
- `[TerrainTypes]` — trees, rocks, and other cell occupants (bind to art via `Image`).
- `[SmudgeTypes]` — scorch/crater decals.
- Objects may convert to overlays on placement: `ToOverlay=<overlay>`, `DamageLevels=`
  (walls).
- Wall/sandbag/bridge physics are largely hardcoded per index (`Hardcoded` / `Do Not Add`
  markers in the official dump).

**Per-title differences**
- The first ~180 YR overlay slots are inherited RA1/TS leftovers; only some are "used but
  editable", many are "hardcoded", and two indices are missing entries that must not be
  added. TS's list is shorter and lacks the RA2/YR-specific French wall, fence, and later
  gem/tiberium slots.
- RA2/YR uses `GEM*` for gems; TS uses `GEM*` too but with TS crystal semantics.
- Theaters provide the tile art; `Theater=yes` art objects are treated as terrain by the
  engine and interact with ore growth.

**Unified-model implication** — Treat overlay/terrain/smudge as **map-cell layers** with a
data registry and a per-title index compatibility map. Never assume index stability across
titles; import each title's array verbatim and tag hardcoded behaviour by index. Bridges
and walls are a separate passability/integrity subsystem.

**Sources** — ModEnc `OverlayTypes`; ModEnc `TerrainTypes`; ModEnc `SmudgeTypes`;
ModEnc `Theater`; ModEnc `Map`.

**Confidence** — high.

---

### X-DATA-015 — Art Schema (`Image=`, SHP/Voxel, Cameo, Turret, Build-up, Remap, Palettes)

**What** — `art.ini`/`artmd.ini` maps each `Image=`/rule ID to an art sheet describing
sprite/voxel selection, cameo, turret/barrel, build-up animation, and palette/remap
behaviour. The TS `ART.INI` header is the authoritative key legend.

**Keys/structure** (header comments, verbatim intent)
- Common: `Cameo`, `Voxel`, `Remapable`, `Normalized`, `Theater`, `NewTheater`,
  `RotCount` (old rot system), `ShadowIndex`, `UseTurretShadow`, `TertiaryFireFLH`.
- Turret/barrel: `TurretOffset`, `FireAngle`, `BarrelLength` (1.5-inch increments),
  `BarrelOffset`, `PrimaryFireFLH`, `SecondaryFireFLH`.
- Infantry: `Sequence` (required), `Crawls`, `FireUp`, `FireProne`.
- Vehicles: `VisibleLoad`, `UseTurretShadow`, `PBarrelLength`, `SBarrelLength`.
- Buildings: `Foundation`, `Height`, `PrimaryFirePixelOffset`, `SecondaryFirePixelOffset`,
  `SimpleDamage`, `Buildup`, `AuxAnim`, `AltImage`, `ChargeAnim`, `SiloDamage`, `Flat`,
  `Recoilless`, `ToOverlay`, `DamageLevels`, `PowerUp1/2/3Anim(+Damaged/LocX/Y/Z/YSort)`,
  `ActiveAnim`/`ActiveAnimTwo`/`ActiveAnimThree` (+`Damaged`, `X`, `Y`, `YSort`,
  `ZAdjust`, `Powered`), `TerrainPalette`, `SpecialAnim*`, `ProductionAnim*`,
  `PreProductionAnim*`, `DoorAnim`/`DoorStages`/`UnderDoorAnim`/`DamagedDoor`, `BibShape`,
  `DeployingAnim`, `SpecialZOverlay`, `GateStages`, `MidPoint`, `ExtraLight`,
  `NormalZAdjust`, `ZShapePointMove`, `ExtraDamageStage`, `DemandLoadBuildup`,
  `FreeBuildup`.
- Vessels: `Rotates`. Aircraft: `Rotors`, `CustomRotor`, `WalkFrames`, `FacingFrames`,
  `FiringFrames`, `Facings`.
- Animations: `Image`, `LoopStart`, `LoopEnd`, `LoopCount`, `Rate`, `Report`,
  `ShouldUseCellDrawer`, `Surface`, `YDrawOffset`.
- `Image=<other art section>` is an alias (e.g. `[PROC] Image=NAREFN`).

**Per-title differences**
- TS uses SHP for infantry/buildings and VXL+HVA for vehicles/aircraft; RA2/YR the same.
  The exact key set drifts: RA2/YR introduces `CameoPCX` (Ares), more power-up levels, and
  voxel turret/barrel naming changes (`PBarrelLength`/`SBarrelLength` vs `BarrelLength`).
- FS's `artfs.ini` overlays TS art with Firestorm objects (`GAFIRE`, `GAFSDF`, `FSIDLE`,
  `FSAIR`, `FSGRND`).
- `Theater=yes` on an art sheet hardcodes terrain behaviour in RA2/YR (ore growth in
  foundation range, `SpawnsTiberium`/`IsAnimated`/`AnimationRate`/`AnimationProbability`),
  and disables normal building art keys; TS is close but less strict.
- `NewTheater=yes` changes the **second filename character** to a theater letter
  (`g` generic fallback); palettes are per-theater and per-remap (XCC/`unittem.pal` etc.).

**Unified-model implication** — An **ArtSheet** component: asset kind (sprite-sheet vs
voxel), animation state table (idle/active/damaged/build-up/door/production), turret/barrel
sub-assets, cameo, palette/remap policy, and theater substitution rule. The unified engine
is fully 3D, so SHP/voxel are *source formats to import*, but the **state machine and key
semantics** should be preserved so mods load unchanged. `Image=` aliasing is required.

**Sources** — TS `ART.INI` (commented header); ModEnc `Art.ini`; ModEnc `Theater`; ModEnc
`NewTheater`; ModEnc `Voxel`; ModEnc `SHP`; ModEnc `HVA`.

**Confidence** — high.

---

### X-DATA-016 — Asset Formats: SHP, VXL/HVA, Palettes

**What** — Sprite and voxel formats feed the art layer; palettes are external and
theater/remap dependent.

**Keys/structure**
- **SHP (TS):** file header (reserved, width, height, frame count) then per-frame headers
  (X, Y, W, H, flags, align, colour, reserved, data offset) then frame data. Frame data is
  raw palette indices unless the flag's second bit is set, in which case RLE with `0x00`
  run-length runs. 256-colour external palette.
- **VXL:** voxels are 5-tuples (X, Y, Z, colour index, normal index); max 255³; normally
  paired with an **HVA** (Hierarchical Voxel Animation) giving per-section position/
  rotation matrices and frame count for animation. Missing HVA = internal error. 32,768
  facings (32/axis), cached on demand.
- **HVA:** transform matrix per frame per section (width/height/length, three shears,
  X/Y/Z offsets in voxels). Necessary for turret/barrel alignment and multi-section
  animation.
- **Palettes:** external `.pal` files; per-theater and per-remap variants. Remap maps a
  index range to house colour; `Remapable=yes` enables it. RA2/YR cameos/buildings can
  use different palettes (`TerrainPalette`, `AnimPalette`, `FirersPalette`).

**Per-title differences**
- SHP format is shared across TS/RA2/YR. Voxel scale differs: a flat square voxel of
  **34** units fits one TS cell vs **43** for RA2/YR (1 voxel ≈ 6.03397 leptons in both).
- RA2/YR uses `unit*.pal` from cache mixes; TS uses its own. YR country palettes
  (`mpls*.pal`) are per-country; RA2 shares one (`mpls.pal`).

**Unified-model implication** — An **AssetImporter** subsystem: SHP→texture atlas frames,
VXL+HVA→mesh + animation clips, PAL→palette. The engine should cache imported assets and
keep a stable frame/animation ID mapping so data references remain valid. Voxel scale and
lepton conversion must be title constants.

**Sources** — ModEnc `SHP`; ModEnc `Voxel`; ModEnc `HVA`; ModEnc `Palette`; ModEnc
`Theaters`.

**Confidence** — high for formats; med for exact palette filenames per build.

---

### X-DATA-017 — AI File Family and Global `[AI]` Section

**What** — Two layers: the global AI economy/base tuning in `rules.ini [AI]`, and the
scripted AI in `ai(md).ini` (TaskForces/TeamTypes/ScriptTypes/AITriggerTypes). The AI is a
scripted trigger system with weights, not a planner.

**Keys/structure** (`[AI]` and `[General]`)
- Build category vectors (ordered priority lists): `BuildConst`, `BuildPower`,
  `BuildRefinery`, `BuildBarracks`, `BuildTech`, `BuildWeapons`, `BuildRadar`,
  `BuildHelipad`, `BuildNavalYard`, `BuildDefense`, `BuildPDefense`, `BuildAA`,
  `ConcreteWalls`, `Allied/Soviet/ThirdBaseDefenses`, `NeutralTechBuildings`.
- Ratios/limits: `RefineryRatio`/`Limit`, `BarracksRatio`/`Limit`, `WarRatio`/`Limit`,
  `DefenseRatio`/`Limit`, `AARatio`/`Limit`, `TeslaRatio`/`Limit`, `HelipadRatio`/`Limit`,
  `AirstripRatio`/`Limit`.
- Economy/base: `CreditReserve`, `PowerSurplus`, `PowerEmergency`, `BaseSizeAdd`,
  `AIBaseSpacing`, `MaximumBaseDefenseValue`, `AIForcePredictionFudge`,
  `AIVirtualPurifiers`, `MultiplayerAICM`, `HarvestersPerRefinery`, `AIExtraRefineries`.
- Teams/timing (`[General]`): `TeamDelays`, `AIHateDelays`, `AISafeDistance`,
  `AIMinorSuperReadyPercent`, `Minimum/MaximumAIDefensiveTeams`, `TotalAITeamCap`,
  `DissolveUnfilledTeamDelay`, `AutocreateTime`, `Paranoid`.
- Superweapon target values: `AIIonCannonConYardValue`, `...WarFactoryValue`,
  `...PowerValue`, `...TechCenterValue`, `...EngineerValue`, `...HarvesterValue`,
  `...MCVValue`, `...APCValue`, `...BaseDefenseValue`, `...PlugValue`, `...HelipadValue`,
  `...TempleValue`.

**Per-title differences**
- The `[AI]` shape is shared and TS's ai.ini is **far richer** than YR's
  ("13,600 characters of AI code per YR house vs 137,500 per TS side"). RA2/YR adds
  `MultiplayerAICM`, `AIVirtualPurifiers`, and third-side categories; TS has
  `GDIWallDefense`, `NodGDIBaseDefenseCoefficient`, etc.
- `[AI]`/`[General]` key availability differs per title and ModEnc tables are YR-only.
- The AI deliberately ignores `Owner=`, `Prerequisite=`, `TechLevel=`, shroud, and
  cloaking; this is a title-wide behaviour, not a data flag.

**Unified-model implication** — Model the AI as a **data-driven production planner** plus a
**script interpreter**. The build category vectors are ordered priorities (keep as ordered
lists with per-side variants). Expose a per-house `ai_cheats` policy. Do not bake the
scripted team system into the planner; keep them separate (production planning vs team
scheduling) because the originals do.

**Sources** — ModEnc `AI`; ModEnc `General`; ModEnc `Ai.ini`; ModEnc `AITriggerTypes`;
ModEnc `AITriggerSuccessWeightDelta` / `AITriggerTrackRecordCoefficient`
(weight formulas).

**Confidence** — high for YR; med for TS key parity.

---

### X-DATA-018 — AI Scripting: TaskForces / TeamTypes / ScriptTypes / AITriggerTypes

**What** — Four interlocking sections, read from `ai(md).ini` **and** the current map, then
merged. They are the AI's "program".

**Keys/structure**
- `[TaskForces]` — registry list. Each task force section: up to **6** entries
  `Index = count,unittype`, **read in ascending index order 0–5** (unlike normal arrays),
  plus `Group`. IDs are hex-prefixed GUID-like strings with a `-G` suffix for global
  (ai.ini) vs local (map). Reusing the same unit twice in one task force triggers an
  internal error if the duplicate is last. A `Strength=0`/missing-strength unit also
  triggers it.
- `[ScriptTypes]` — registry list. Each script section: up to **50** actions
  `Index = action, argument`, read ascending 0–49. Actions are numbers with per-action
  arguments; supports two loop kinds, no conditionals. IDs hex-prefixed, `-G` suffix
  has no effect. Ares/Phobos add script actions (53+).
- `[TeamTypes]` — registry list. Each team section links one `TaskForce` + one `Script`
  plus params (`Name`, `Recruiter`, `Autocreate`, `Max`, `Min`, `Priority`, `IsBaseDefense`,
  `MindControlDecision` (YR), `UseTransportOrigin`, `Group`, `Tag`, ...). The `-G` suffix
  has no effect.
- `[AITriggerTypes]` — the condition→team scheduler. Line format:
  `ID=Name,Team1,OwnerHouse,TechLevel,ConditionType,ConditionObject,Comparator,
  StartingWeight,MinimumWeight,MaximumWeight,IsForSkirmish,unused,Side,IsBaseDefense,
  Team2,EnabledInE,EnabledInM,EnabledInH`.
  - `ConditionType`: −1 always; 0 enemy owns; 1 owner owns; 2/3 enemy low power; 4 enemy
    credits; **5/6 Iron Curtain / ChronoSphere charged (RA2/YR only)**; **7 neutral house
    owns (RA2/YR only)**.
  - `Comparator`: 64-char / 8-octet little-endian hex blob; octet 1 = second operand,
    octet 2 = operator (`0 <`, `1 <=`, `2 =`, `3 >=`, `4 >`, `5 !=`).
  - Weights: `StartingWeight`, `MinimumWeight`, `MaximumWeight`; weight 0 disables,
    weight 5000 = "fire immediately" (RA2/YR).
  - `Side`: in **TS** this is the house's `ActsLike` value **+1**; in RA2/YR it is the side
    index (0 = all, 1/2/3 = Allied/Soviet/Yuri).
- `[AITriggerTypesEnable]` — map section to enable map-local AI triggers.
- Map `[Basic] IgnoreGlobalAITriggers=` disables all ai.ini triggers.

**Per-title differences** (ModEnc `TS vs RA2`)
- **TaskForces:** no changes.
- **ScriptTypes:** TS action 11 (`Return`) and its params shift by +1 in RA2/YR; actions
  53–59 (RA2) and 60–64 (YR) are RA2/YR-only; YR adds parachute/spyplane approach/overfly
  and wait/attack actions; TS action 0 has fewer alternative params.
- **TeamTypes:** RA2/YR adds `MindControlDecision` (YR) and `UseTransportOrigin`; `Group`
  is always −1 in RA2.
- **AITriggerTypes:** the unused comparison blob is zeroed in RA2 but sometimes random hex
  in TS; RA2/YR adds conditions 5/6/7; the `Side` field meaning changes (ActsLike+1 vs side
  index).
- AITriggerTypes are **scope-aware** (global enabled by default, local require
  `[AITriggerTypesEnable]`); TaskForces/ScriptTypes/TeamTypes are scope-agnostic after
  merge.

**Unified-model implication** — A **two-layer AI VM**:
1. A *team scheduler* evaluating weighted conditions each tick, producing team instances.
2. A *script interpreter* executing numbered actions with arguments, supporting loops.
Keep the exact section shapes and numeric indices for import. Normalise the script action
**numbering** across titles via a per-title opcode map (the TS↔RA2 +1 shift is a concrete
example), and keep the `Side` semantics as a resolver (`ts_acts_like` vs `ra2_side_index`).
Scripts and triggers reference object **registry indices** (see X-DATA-002), so the
registry must preserve order. `-G` suffixes and hex prefixes are non-semantic and can be
preserved as opaque IDs.

**Sources** — ModEnc `TaskForces`; ModEnc `TeamTypes`; ModEnc `ScriptTypes`; ModEnc
`AITriggerTypes`; ModEnc `AITriggerTypesEnable`; ModEnc `TS vs RA2`; Ares docs → Script
Actions / AITriggerTypes.

**Confidence** — high.

---

### X-DATA-019 — Houses / Sides / Countries Registry

**What** — The faction registry. TS/FS use `[Houses]`; RA2/YR renamed it to `[Countries]`
and added an explicit `[Sides]` grouping. Both add map-local houses.

**Keys/structure**
- **TS/FS `[Houses]`** — zero-based list, e.g. `0=GDI, 1=Nod, 2=Neutral, 3=Special`.
  Each house section: `Name`, `UIName`, `Side`, `Color`, `Multiplay`, `MultiplayPassive`,
  `SmartAI`, `WallOwner`, `Suffix`, `Prefix`, `ParentCountry`, plus multiplier keys
  (`Armor*Mult`, `Cost*Mult`, `Speed*Mult`, `BuildTime*Mult`, `IncomeMult`) and veteran
  grants (`VeteranInfantry`, `VeteranUnits`, `VeteranAircraft`).
  Map-local houses add: `ActsLike=<house index>`, `Country`, `TechLevel`, `Credits`, `IQ`,
  `Edge`, `PlayerControl`, `Color`, `Allies`, `PercentBuilt`, `NodeCount`.
- **RA2/YR `[Countries]`** — zero-based list. The **first nine must be the skirmish majors
  in order and uninterrupted** or the game crashes. `[Sides]` groups countries:
  `GDI=British,French,Germans,Americans,Alliance`, `Nod=Russians,Africans,Confederation,
  Arabs`, `ThirdSide=YuriCountry` (YR only), `Civilian=Neutral`, `Mutant=Special`. Side
  order GDI/Nod/ThirdSide is mandatory and names are fixed.
- Country sections: `UIName`, `Name`, `Suffix`, `Prefix`, `Color`, `Multiplay`,
  `MultiplayPassive`, `Side`, `SmartAI`, `WallOwner`, `ParentCountry`, multiplier keys,
  `Veteran*`.
- **Index-bound assets:** country flags (`usai.pcx`, `japi.pcx`, ...), loading screens
  (`ls800*.shp`), palettes (`mpls*.pal`), and EVA/UI text are bound to the **country's
  index**, not its name. Side maps to GUI mixes: GDI→`sidec01.mix`, Nod→`sidec02.mix`,
  ThirdSide→`sidec02md.mix`; GDI uses Allied EVA, Nod Russian, ThirdSide Yuri.
- TS: side index selects `sidec01.mix`/`speech01.mix`; side name used by map `SpeechSide`.
- **Map-local houses:** singleplayer maps can append houses after the rules houses (in the
  same order); skirmish/MP maps cannot. Total houses ≤ 32. In MP, Neutral is hostile to all
  (but not auto-engaged) and Special is allied to all; their colour is hardcoded LightGrey.

**Per-title differences**
- **TS/FS:** `[Houses]`; no `[Countries]`/`[Sides]` in the same form; `ActsLike` semantics;
  `Side` section exists (`GDI=GDI`, `Nod=Nod`, `Civilian=Neutral`, `Mutant=Special`) and the
  game auto-creates sides for unknown `Side=` values.
- **RA2:** `[Countries]` with 9 majors (no Yuri); `[Sides]` with GDI/Nod/Civilian/Mutant.
- **YR:** adds index 9 `YuriCountry`, `ThirdSide`, and the third-side GUI/EVA; adds
  `ThirdBaseDefenseCounts`/`ThirdBaseDefenses` etc.
- RA2/YR country-specific units are gated by `RequiredHouses`/`ForbiddenHouses`; TS lacks
  the explicit country concept so equivalent gating is via `Owner=`/`Side`.

**Unified-model implication** — A **FactionRegistry** with three entities: *Side*,
*Country/House*, and *Player*. Rules objects reference countries/houses; maps instantiate
players as houses bound to countries. Keep:
- the mandatory **index order** for majors,
- the **index→asset** binding (flag/loading/EVA/palette), and
- a resolver for `Owner=`, `RequiredHouses=`, `ForbiddenHouses=`, `Side=`, `ActsLike`.
Model side-specific mix/GUI/EVA as side metadata, not hardcoded paths. Ares extends the
registry (new sides/countries, `ParentCountry`, per-country `Side`, UI side mixing);
Phobos adds country-based crew/effects.

**Sources** — ModEnc `Countries`; ModEnc `Sides`; ModEnc `Houses`; ModEnc `RequiredHouses`;
Ares docs → Sides & Countries; Phobos docs → country features.

**Confidence** — high.

---

### X-DATA-020 — Theaters, Tilesets, and Terrain Control

**What** — A map declares a `Theater`; the engine loads that theater's tileset (TMP tiles
with a theater-specific extension) and terrain-control INIs. Theater letters also drive art
substitution (`NewTheater`).

**Keys/structure**
- Theater list / `NewTheater` character / tile extension / mixes:
  | Theater | char | TS ext | RA2/YR ext | Notes |
  |---|---|---|---|---|
  | Temperate | T | `.tem` | `.tem` | all titles |
  | Snow (arctic) | A | `.sno` | `.sno` | all titles |
  | Urban | U | — | `.urb` | RA2/YR only |
  | NewUrban | N | — | `.ubn` | YR only |
  | Desert | D | — | `.des` | YR only |
  | Lunar | L | — | `.lun` | YR only |
  | Generic/Marble | G | — | — | fallback/second char |
- Mixes (YR): `TEMPERATMD.MIX`+`TEM.MIX`+`ISOTEMP(MD).MIX`; `SNOWMD.MIX`+`SNO.MIX`+
  `ISOSNOW(MD).MIX`; `URBANMD.MIX`+`URB.MIX`+`ISOURB(MD).MIX`; `DESERTMD.MIX`+`DES.MIX`;
  `URBANNMD.MIX`+`UBN.MIX`; `LUNARMD.MIX`+`LUN.MIX`; `GENER(MD).MIX`+`ISOGEN(MD).MIX`.
- Tile control INIs (`temperat.ini`, `snow.ini`, `urban.ini`, `lunarmd.ini`, ...) declare
  tile counts and per-tile properties (passability, land type, burrowability for
  subterranean, slope).
- `[LandTypes]` in the terrain-control INI defines the `SpeedType` passability matrix.
- `Theater=` (map) selects the theater; `NewTheater=yes` (art) substitutes the second
  filename character; `Theater=yes` (art) hardcodes terrain-object behaviour.

**Per-title differences**
- TS has Temperate + Snow; RA2 adds Urban; YR adds NewUrban, Desert, Lunar. Theater set is
  **hardcoded** — new theaters cannot be added, only tiles to existing ones. The Terrain
  Expansion adds tiles to existing sets.
- RA2/YR `lunarmd.ini` is the Lunar tileset control; Phobos dehardcodes Lunar parsing
  behind `[General] ApplyLunarFixes`.
- Cell render size differs: TS 48×24 px; RA2/YR 60×30 px (implied by editor texture limits).
- Ares adds `RequireTheater` prerequisites and alternate theater art.

**Unified-model implication** — A **TheaterProfile**: tile-set registry, terrain-control
INI, palette set, and art-substitution letter. `Theater` is a per-map enum, not free text.
The tile/passability system must be data-driven off `[LandTypes]`; an unimplemented theater
should degrade gracefully. Keep the theater letter substitution rule for mod compatibility.

**Sources** — ModEnc `Theaters`; ModEnc `Theater`; ModEnc `Map`; ModEnc `LandTypes`;
ModEnc `MIX`; Ares docs.

**Confidence** — high.

---

### X-DATA-021 — Map Formats and Embedded Sections

**What** — All maps are plain INI except Tiberian Dawn's separate `.BIN`. Extensions
encode scope (official vs custom, single- vs multiplayer) but the inner format is shared.

**Formats**
- `.map` — official maps, TS onward.
- `.mpr` — custom RA multiplayer maps (RA/CS/AM), require `[Basic] Official=no`.
- `.mmx` — RA2 map-pack MIX containing a `.map` + `.pkt`.
- `.yrm` — YR custom multiplayer map (behaves like `.mpr`).
- `.yro` — YR official map-pack MIX containing a `.map` + `.pkt`.
- `.pkt` — map list; only one loose `.pkt` allowed.
- Per-map localization INI (TS): same basename, `.INI`.

**Embedded sections (full map vocabulary)**
- Basic: `[Basic]`, `[Briefing]` (implied), `[Digest]`, `[Houses]`, `[Map]`,
  `[Preview]`, `[PreviewPack]`, `[SpecialFlags]`.
- Terrain: `[IsoMapPack5]`, `[Lighting]`, `[OverlayDataPack]`, `[OverlayPack]`,
  `[Smudge]`, `[Terrain]`, `[Tubes]`, `[Waypoints]`.
- Preplaced: `[Infantry]`, `[Units]`, `[Aircraft]`, `[Structures]`.
- Scripting: `[Tags]`, `[CellTags]`, `[Triggers]`, `[Events]`, `[Actions]`,
  `[VariableNames]`, `[AITriggerTypesEnable]`.
- AI: `[TaskForces]`, `[ScriptTypes]`, `[TeamTypes]`, `[AITriggerTypes]`,
  `[AITriggerTypesEnable]` (all also mergeable from ai.ini).

**`[Basic]` keys** — `Name`, `Official`, `NewINIFormat` (coordinate system version),
`RequiredAddOn` (FS), `FreeRadar`, `SpeechSide`, `NextScenario`, `AltNextScenario`,
`EndOfGame`, `SkipScore`, `OneTimeOnly`, `SkipMapSelect`, `IgnoreGlobalAITriggers`,
`TruckCrate`, `TrainCrate`, `StartingDropships` (TS), `AllowableUnits`(Maximums) (TS),
`Player`, `Briefing`, `TimerInherit`, `InitTime`, `Intro`/`Brief`/`Action`/`Win`/`Lose`/
`PostScore`/`PreMapSelect` (movies), `Theme`, `CarryOverMoney`, `CarryOverCap`,
`FillSilos`, `HomeCell`, `AltHomeCell`, `CivEvac`, `MultiplayerOnly`,
`TiberiumGrowthEnabled`, `VeinGrowthEnabled` (TS), `IceGrowthEnabled` (TS),
`TiberiumDeathToVisceroid` (TS).
- **Coordinate encoding:** `[CellTags]`/`[Waypoints]` encode `Y*Coefficient + X`.
  Coefficient: 64 (TD), 128 (RA) or 1000 (TS/FS/RA2/YR); or `Y*1000+X` for
  `NewINIFormat ≥ 4`. `[CellTags]` uses `NewINIFormat < 4 → Y*128+X`, `≥4 → Y*1000+X`.

**`[Map]` keys** — `Size=0,0,W,H`, `Theater=`, `LocalSize=L,T,VW,VH`. Max size constraint:
`Width + Height ≤ 512` (OverlayPack 256 KB fixed offsets); largest is 256×256.

**`[SpecialFlags]` keys** — `TiberiumGrows`, `TiberiumExplosive`, `TiberiumSpreads`,
`DestroyableBridges`, `MCVDeploy`, `InitialVeteran`, `FixedAlliance`, `HarvesterImmune`,
`FogOfWar`, `Inert`, `IonStorms`, `Meteorites`, `Visceroids`.

**`[Waypoints]` keys** — `Index=COORDS`; index semantic (allocated array). Waypoints 0–7
are player starts. Capacity: 101 (TS/RA2, 0–100), **702 (YR, 0–701)**; Vinifera raises TS
to 32767; Phobos raises YR to int max. Letter addressing (A, B, ..., Z, AA, ...).

**Per-map overrides** — A map may redefine rules sections (e.g. a unit's `Primary=`), add
types to arrays, add AI objects, define houses, and set `IgnoreGlobalAITriggers`. Array
additions are appended (X-DATA-002). Singleplayer maps may append houses; MP maps cannot.

**Unified-model implication** — A **MapDocument** model: metadata (`[Basic]`), cell grid
(`[IsoMapPack5]` + overlays), entities, waypoints, houses, scripting (tags/triggers/
events/actions), AI overrides, and lighting. The coordinate encoding is a **per-map
version** property, not a global constant. Map import must append to registries, not
replace them, and must support full rules overrides.

**Sources** — ModEnc `Maps`; ModEnc `Map`; ModEnc `Basic`; ModEnc `SpecialFlags`;
ModEnc `Waypoints`; ModEnc `CellTags`; ModEnc `Structures (maps)`; ModEnc `MIX`.

**Confidence** — high.

---

### X-DATA-022 — Map Scripting: Tags, CellTags, Triggers, Events, Actions

**What** — The map scripting system is an event→action engine with a tag indirection layer
so triggers can attach to cells/objects and have persistence.

**Hierarchy** — `CellTag → Tag → Trigger → {Events, Actions}`. Every trigger must be
referenced by at least one tag to "exist"; a tag may be unattached but still registers the
trigger.

**Keys/structure** (TS/FS/RA2/YR)
- `[Triggers]`: `ID=HOUSE,LINKED_TRIGGER,NAME,DISABLED,EASY,NORMAL,HARD,PERSISTENCE`.
  Events and Actions sections use the same ID automatically. `PERSISTENCE` is obsolete in
  TS→YR (superseded by tag persistence).
- `[Events]`: `ID=event,param...` (per-event parameter arity).
- `[Actions]`: `ID=action,param...` (per-action arity; e.g. 125 BuildAt).
- `[Tags]`: `ID=PERSISTENCE,NAME,TRIGGER_ID`; persistence `0` volatile (OR one-shot),
  `1` semi-persistent (AND all attached), `2` persistent (OR repeating).
- `[CellTags]`: `COORDS=TAG_INDEX`.
- `[VariableNames]`: local/global variable name table.
- Legacy RA/TD formats (`[Trigs]` with packed 17-field tuples; TD `[Triggers]` with
  6-field tuples) exist but are out of scope for the four target titles.

**Per-title differences**
- TS/FS and RA2/YR share the format. YR adds triggers/actions/AI events (superweapon
  activation, abduction, etc.). ModEnc notes TS `PERSISTENCE` in `[Triggers]` is
  ignored/obsolete.
- CellTags in TS are not triggered by cloaked units entering/leaving; hovering/flying
  units may not trigger some events.
- Ares adds trigger actions 92–93 (Firestorm), 146–149, and trigger events 62–88
  (EMP, spotlight, kill driver, abduction, superweapon, reverse-engineer, house owns
  type, etc.). Phobos adds local/global variable events and actions, banners, and
  many more.

**Unified-model implication** — A **Scripting VM** with tags as attachable trigger
handles, persistence semantics, and an event/action dispatch table. Keep event/action IDs
numeric and expose per-title/ext opcode maps. Triggers reference houses and objects by
**registry index**; variables are typed (local/global) and referenced by index. This is the
same VM family as AI scripts and should share the object-index resolver.

**Sources** — ModEnc `Triggers`; ModEnc `Tags`; ModEnc `CellTags`; ModEnc `Events`;
ModEnc `Actions (maps)`; Ares docs → Trigger Events / Trigger Actions; Phobos docs →
AI Scripting and Mapping.

**Confidence** — high.

---

### X-DATA-023 — Localization: CSF String Tables and `UIName`

**What** — All user-visible strings live in CSF binary string tables (not INI). INI
objects reference CSF labels via `UIName=` / `Name:` / UI keys. RA2/YR, Generals, ZH, and
BFME use CSF v3.

**Keys/structure**
- Header: `" FSC"` magic, version DWORD (3 for RA2/YR/Generals), label count, string count,
  unused DWORD, language DWORD (0 US, 1 UK, 2 German, 3 French, 4 Spanish, 5 Italian,
  6 Japanese, 7 Jabberwockie, 8 Korean, 9 Chinese).
- Labels: `" LBL"` + pair count + name length + name; then values:
  `" RTS"` (string) or `"WRTS"` (string + extra value) + length + encoded value.
- Value encoding: UTF-16-LE with **inverse (`~`) bytes** (bitwise NOT per byte).
- Label names are case-insensitive; later duplicates override earlier.
- **RA2/YR quirk:** `game.fnt` treats code points 0x80–0x9F as Windows-1252; save as proper
  Unicode but tolerate the mistaken CP1252 bytes on read.
- Localized files live in `language.mix` / `langmd.mix` (RA2/YR) and the TS `langrule.ini` /
  `langfs.ini` string INIs; loose `.csf` is also valid.

**Per-title differences**
- TS/FS predate CSF and use the scrambled `langrule.ini` / `langfs.ini` (plus per-map
  `.INI`). RA2/YR use `ra2.csf` / `ra2md.csf` (version 3). Ares/Phobos add string-table
  enhancements and `$Include`-driven string overrides.

**Unified-model implication** — A **StringTable** keyed by label, loaded from CSF (RA2/YR)
and TS string INIs, with a unified label namespace. `UIName` resolves to a StringTable
entry; the per-map TS `.INI` is an overlay layer. Support the inverse-byte UTF-16 decode
and the CP1252 quirk on import; store as proper Unicode internally.

**Sources** — ModEnc `CSF File Format`; ModEnc `CSF`; ModEnc `INI` (scrambled TS INIs);
Ares docs → String Table Enhancements.

**Confidence** — high.

---

### X-DATA-024 — Asset Packaging: MIX Archives and Loose Files

**What** — Game assets are packed in `.mix` archives with a strict, title-specific loading
hierarchy; loose files and expansion mixes override. `.mmx`/`.yro` are MIX with renamed
extensions for map packs. Generals+ use BIG instead.

**Loading hierarchy (highest priority first; first hit wins)** — YR:
`LANGMD.MIX → LANGUAGE.MIX → EXPANDMD##.MIX → ECACHE*.MIX → RA2MD.MIX → RA2.MIX →
CACHEMD.MIX → CACHE.MIX → LOCALMD.MIX → LOCAL.MIX → AUDIOMD.MIX → ELOCAL*.MIX →
CONQMD.MIX → GENERMD.MIX → ISOGENMD.MIX → CONQUER.MIX → CAMEOMD.MIX → CAMEO.MIX →
… → THEMEMD.MIX → MOVMD03.MIX → SIDEC##.MIX → SIDENC##.MIX → …`
TS: `PATCH.MIX → PCACHE.MIX → EXPAND##.MIX → ECACHE##.MIX → TIBSUN.MIX → …`.
- `EXPAND##.MIX` / `EXPANDMD##.MIX`: `##` 00–99, higher numbers loaded first; catch-all for
  mods.
- `ECACHE*.MIX`: cached SHP/palettes; lower priority. In RA2, moving a default SHP into
  `EXPAND##.MIX` makes it invisible; use `ECACHE*.MIX`.
- `ELOCAL*.MIX`: local.mix-equivalent expansion (Ares/Vinifera).
- `.mmx`/`.yro`: official map packs.
- **Loose files** (not normally in MIX): `CSF`, `PKT` (only one), `BAG`, `IDX`, `WAV`,
  `BIK`.
- INIs live in `ra2.mix → local.mix` / `ra2md.mix → localmd.mix`; YR 1.001 rulesmd/soundmd
  in `expandmd01.mix`. Voxels/HVAs in `local(md).mix`; infantry SHP in `conquer.mix`/
  `conqmd.mix`; cameos in `cameo.mix`/`cameomd.mix`; theater art in theater mixes.
- Ares loads `EXPANDMD##.MIX` **before** `LANGMD/LANGUAGE` so mods can override
  `ra2md.csf`. Phobos adds MIX loading-order control, extra BAG files, loose audio.

**Per-title differences**
- TS uses `TIBSUN.MIX` + `LOCAL.MIX` + `CONQUER.MIX` + `SCORES*.MIX` + `MAPS01/02.MIX` +
  `MOVIES01/02.MIX` + `THEME.MIX`; RA2 uses `RA2.MIX`/`CACHE.MIX`/`CAMEO.MIX`/`THEME.MIX`;
  YR adds the `*md` variants and `expandmd`.
- `EXPAND01.MIX` in Firestorm contains `ecache01.mix` (new FS SHPs); naming collisions with
  `ecache##.mix` are a known pitfall.
- ECACHE ordering: TS loads `99→00`; RA2/YR load alphanumeric **ascending**. Older FAT32
  filesystems may not sort at all.
- Load order of ECACHE/ELOCAL in RA2/YR is filesystem-dependent (WinAPI `FindNextFile`).

**Unified-model implication** — A **VirtualFileSystem** with ordered archive mounts and a
"first match wins" resolver, plus loose-file support. The mount list must be data (per
title profile), not code. Mods mount `expandmd`-style high-priority packs. Preserve the
cache/non-cache distinction only if simulating engine quirks is required; otherwise treat
`ECACHE`/`EXPAND` uniformly in the unified importer. `.mmx`/`.yro` are just MIX containers.

**Sources** — ModEnc `MIX`; ModEnc `INI`; Ares docs → MIX Loading Order / Additional Bag
Files; Phobos docs → Miscellanous.

**Confidence** — high.

---

### X-DATA-025 — Sound, Voice, and EVA Data

**What** — Audio is referenced by name from rules (`Voice*`, `MoveSound`, `DieSound`,
`CreateSound`, `AmbientSound`, `CrushSound`, `TurretRotateSound`, `DeploySound`, `Report`,
`SpecialSound`, `StartSound`, `VoiceHarvest`, `VoiceCapture`, ...). Actual audio lives in
`.bag`/`.idx` (RA2/YR) or MIX audio; EVA packs are per-side.

**Keys/structure**
- Rules-side named sound references (many dozens per TechnoType; see X-DATA-003).
- `[AudioVisual]` global settings, `[Sound]`/`[EVA]`-family sections in `sound(md).ini` /
  `eva(md).ini`.
- Per-side voice via `sidec##.mix` / `speech##.mix` and side EVA assignment (GDI=Allied,
  Nod=Russian, ThirdSide=Yuri in RA2/YR).
- Phobos adds loose audio files, additional BAG files, `SpeakDelays`.

**Per-title differences**
- RA2/YR use `.bag`/`.idx` plus `audio(md).mix`; TS uses MIX-stored audio and per-side
  `speech##.mix`. Side EVA mapping is RA2/YR-specific.

**Unified-model implication** — An **AudioRegistry** keyed by named ID, decoupled from
container format. Side-specific voice/EVA is faction metadata (see X-DATA-019). Keep the
logical names so rules files import unchanged; the importer maps names to clips.

**Sources** — ModEnc `VehicleTypes` (sound keys); ModEnc `Sides`; ModEnc `MIX`; ModEnc
`Sound.ini`; Ares/Phobos audio docs.

**Confidence** — high for shape; med for exact per-title filenames.

---

### X-DATA-026 — Mission Control (Mission Types)

**What** — `[Mission Control]` tunes automatic mission behaviour (Attack, Guard, Harvest,
...). Missions are **hardcoded types**; only a few flags per mission are overridable.

**Keys/structure**
- One section per mission name, with flags `NoThreat`, `Zombie`, `Recruitable`,
  `Paralyzed`, `Retaliate`, `Scatter`, `Rate`, `AARate`.
- Mission set differs per title. Shared: Sleep, Attack, Move, Retreat, Guard, Sticky,
  Enter, Capture, Harvest, Area Guard, Return, Stop, Ambush, Hunt, Unload, Sabotage,
  Construction, Selling, Repair, Rescue, Missile. TS→YR adds QMove, Patrol, Open, Harmless,
  Eaten (YR). TD had Timed Hunt only.
- Script actions reference these missions by number (X-DATA-018); the numbering shift
  between TS and RA2/YR is a direct consequence of the mission list order changing.

**Unified-model implication** — A **MissionRegistry** with fixed, per-title ordered
mission types and per-mission policy flags. The mission ID is shared with AI script
actions; the per-title opcode map from X-DATA-018 must key off this registry.

**Sources** — ModEnc `Mission Control`; ModEnc `ScriptTypes`.

**Confidence** — high for set; med for per-mission flag availability per title.

---

### X-DATA-027 — Extension Engines: Ares (what schema it adds)

**What** — Ares is a DLL injected into YR 1.001 via Syringe; it extends the INI schema
and fixes engine bugs. It is the de-facto reference for "extended YR data model".

**New / extended schema (representative, not exhaustive)**
- **New sections:** `[ArmorTypes]` (extra armor classes + `Verses`), `[WeaponTypes]`
  (declare weapons without a dummy carrier), `[AITargetTypes]`, `[AttachEffectType]`,
  `[SuperWeaponTypes]` extensions.
- **Sides/Countries:** new sides/countries, `ParentCountry`, side-specific sidebars,
  per-side power plants/crew, `RequiredHouses`-style gating extensions.
- **TechnoTypes:** `TypeConversion`, `FakeOf`/`Fakes`, `Survivors`, `FactoryPlant`,
  `Academy`, `PrismForwarding`, `Tunnel`, `Gunner`/IFV modes, `Spawner` extensions,
  `Harvester`/slave miner extensions, `Bounty`, `Drain`, `SelfHeal`, `RadarJammers`.
- **Weapons/Warheads/Projectiles:** `WeaponTypes`, `Ammo`, `Radiation` beams, `ElectricBolts`,
  `Waves`, `LaserThickness`, `Railgun`, `ProjectileRange`, `Splits`/`Airburst`,
  `BallisticScatter`, `Ranged`, warhead `EMP`/`IronCurtain`/`IonCannon`/`Sonar`/`Flash`/
  `NukeFlash`/`DisableWeapons`/`MindControl`/`Temporal`/`Berserk`/`Culling`/`Crit`.
- **Superweapons:** `SW.*` namespace (availability, targeting, range, charge/drain, cost,
  animation/sound, EVA, messages, lighting, cameo overlay).
- **Tiberium:** storage, spill, heal, remains, damage, visceroids, explosive, chain
  reactions.
- **Misc:** `[$Include]`, string-table enhancements, `[#include]` (Ares),
  `ListLengths`, MIX loading order, bag files, loose audio.
- **Restored TS logic:** EMP, Firestorm Wall, Laser Fences, Multi Engineer, Spotlights,
  Vehicle Thief, `Action=SellUnit`.

**Per-title differences** — Ares is **YR-only**. It does not apply to TS/RA2 (though some
concepts are inspired by Vinifera for TS). Vinifera is the TS analogue (new Tiberiums,
`ELOCAL##.MIX`, side-specific sections).

**Unified-model implication** — Treat Ares/Phobos as **schema dialects** layered on the YR
profile. The unified model should already accommodate: a pluggable ArmorTable, a
WeaponRegistry, namespaced effect parameters (`EMP.Cap`), an Superweapon `SW` namespace,
`AttachEffectType` as a reusable effect-definition section, and an include/inheritance
mechanism. Supporting the dialect means the importer accepts dotted keys and extra
sections without a code fork.

**Sources** — Ares docs (index + New & Enhanced In-Game Logic, Restored Tiberian Sun
Logic); ModEnc `Ares` / `WeaponTypes`; ModEnc `Vinifera`.

**Confidence** — high.

---

### X-DATA-028 — Extension Engines: Phobos (what schema it adds)

**What** — Phobos is an independent (Ares-compatible) YR engine extension using YRpp +
SyringeEx. It adds hundreds of tags/sections and fixes vanilla behaviour; it is the
current frontier of YR mod data.

**New / extended schema (representative)**
- **New sections/types:** `[AttachEffectType]`, `[SelectBoxType]`, `[RadiationType]`
  (extended radiation), `[InsigniaType]`, `[BannerType]`, `[AITargetTypes]`,
  `[ShieldType]` (shields), plus map-editor `[ParamTypes]`/`[EventsRA2]`/`[ActionsRA2]`/
  `[ScriptsRA2]` entries for FA2.
- **TechnoTypes:** shields (`Shield.*`), `AttachEffect`, `TypeConversion`,
  `AutoDeath`, `Spawns` extensions, `KeepAlive`, `PassengerDeletion`,
  `Grinding`/`DisplayIncome`, `SelfHeal`, `Insignia`, `Crew` per country.
- **Weapons/Warheads/Projectiles:** new trajectories (`Trajectory=Straight`, `Parabola`,
  `Bombard`), `Splits`/`Airburst`, `ProjectileRange.ApplyModifiers`, crits
  (`Crit.*`), damage multipliers, `ExtraWarheads`, `KillWeapon`, `DetonateOnAllMapObjects`,
  `Convert(N)`, `LimboKill`, `AirstrikeTargets`, `Shield.Penetrate`/`Shield.Break`.
- **Triggers/scripts:** local/global variable arithmetic, banners, mission-timer control,
  `LaunchSW`, `CreateUnit`, `BuildAt`, `DropCrate`, hate-value editing, radar mode.
- **UI/misc:** building production queue, type-select for buildings, exclusive superweapon
  sidebar, placement preview, select box, real-time timers, tooltip descriptions,
  `[Phobos]` user-settings section in `RA2MD.INI`.
- **Compatibility:** many tags renamed across versions (`AffectsTarget`/`AffectsHouse`
  enums, `DisplayIncome`), so dialect version matters.

**Per-title differences** — YR-only; complements Ares rather than replacing it. Phobos
requires SyringeEx. Some features interact with Ares (e.g. tunnel buildings, `[$Include]`).

**Unified-model implication** — Phobos confirms the **dialect/versioning** requirement: the
importer needs a dialect + version selector and a migration/alias table (old→new tag
names). New concepts (shields, AttachEffect, trajectories, variable scripting) should be
first-class components so dialect support is data, not code. Many Phobos features are
already implemented in a modern 3D engine (shields, type-select, placement preview), so
import can map them to native systems.

**Sources** — Phobos docs (What's New, New/Enhanced Logics, Fixed/Improved Logics,
AI Scripting & Mapping, User Interface).

**Confidence** — high.

---

### X-DATA-029 — Firestorm Overlay Semantics (TS base + FS deltas)

**What** — FS is not a separate data model; it is TS's model plus a file overlay and a
handful of objects/logics. The research here is the per-title delta a unified loader must
express.

**Keys/structure**
- Detection: presence of `expand01.mix` and `firestrm.ini`.
- Files: `firestrm.ini` (FS rules) + a fresh TS `rules.ini` in the same mix; `artfs.ini`,
  `aifs.ini`, `battlefs.ini`, `langfs.ini`, `sound01.ini`, `theme01.ini`, `mapsel01.ini`,
  `mission1.ini`, `key/…`.
- FS-only objects/logics: Firestorm Wall generator + wall (`GAFIRE`, `GAFSDF`, `GAFSDF_A`),
  Drop Pods, Hunter-Seeker, EMP (`EMEffect`), the FS campaign `fsnod*`/`fsgdi*` maps and
  their scrambled localization INIs.
- Map flag `RequiredAddOn` marks FS-required maps.

**Per-title differences**
- FS inherits TS behavior wholesale; only additions. YR has no "FS-like" overlay; it is
  the RA2 base renamed to `md`.
- FS mix `ecache01.mix` inside `expand01.mix` is a trap for modders adding `ecache##.mix`.

**Unified-model implication** — Model FS as the **TS title profile + an FS overlay pack**
(files + object set + `RequiredAddOn` gate). No separate loader branch. This validates the
overlay-chain design from X-DATA-001.

**Sources** — ModEnc `INI`; ModEnc `Rules.ini`; ModEnc `Ai.ini`; ModEnc `Art.ini`;
ModEnc `MIX`; ModEnc `Basic` (`RequiredAddOn`).

**Confidence** — high.

---

### X-DATA-030 — Per-Map Overrides and Roster Gates

**What** — Maps are the final data layer: they override rules, add registrations, define
houses, gate units, and enable/disable AI triggers.

**Keys/structure**
- Rules section override: redefining a unit/building section in the map overrides its
  keys; array additions append.
- `[Houses]`/`[Countries]`: singleplayer maps append map-local houses; MP maps cannot.
- `[Basic]` gates: `IgnoreGlobalAITriggers`, `RequiredAddOn` (FS), `Player`, `HomeCell`,
  `AllowableUnits`(Maximums) (TS dropship roster), `MultiplayerOnly`, `Official`.
- `[SpecialFlags]` match-rule gates: `MCVDeploy`, `InitialVeteran`, `FixedAlliance`,
  `HarvesterImmune`, `FogOfWar`, `Inert`, `TiberiumGrows/Spreads/Explosive`,
  `DestroyableBridges`, `IonStorms`, `Meteorites`, `Visceroids`.
- `[MultiplayerDialogSettings]` (RA2/YR) / `[MultiplayerDefaults]` (TS): starting money,
  unit count, tech level, game speed, AI difficulty, superweapons allowed, MCV redeploy,
  crates, short game, etc. These gate the roster globally.
- Object-level roster gates: `RequiredHouses`, `ForbiddenHouses`, `Owner`, `TechLevel`,
  `BuildLimit`.
- `[AITriggerTypesEnable]` enables map-local AI triggers.

**Per-title differences**
- TS uses `[Houses]`; RA2/YR use `[Countries]` + map `[Houses]` with `Country=`.
- TS-only gates (`VeinGrowthEnabled`, `IceGrowthEnabled`, `TiberiumDeathToVisceroid`,
  `AllowableUnits`, `StartingDropships`); RA2/YR-only gates (`MultiplayerDialogSettings`,
  `BridgeDestruction`, `CaptureTheFlag`, `HarvesterTruce`, `MultiEngineer`,
  `AlliesAllowed`, `AllyChangeAllowed`, `BuildOffAlly`).
- `[AITriggerTypesEnable]` works in TS→YR.

**Unified-model implication** — A **MatchConfig** + **MapOverrides** resolved at load:
title defaults → rules → expansion → map → match dialog. Roster gating is a query over
the object registry with house/tech/limit predicates. Keep TS/RA2/YR dialog keys as a
superset; unknown keys are ignored per title.

**Sources** — ModEnc `Basic`; ModEnc `SpecialFlags`; ModEnc `Houses`; ModEnc
`MultiplayerDialogSettings`; ModEnc `AITriggerTypesEnable`; ModEnc `RequiredHouses`.

**Confidence** — high.

---

## Unified Data-Model Mapping (the big table)

Columns: concept → TS/FS tag → RA2 tag → YR tag → proposed unified field. TS and FS share
the TS column unless noted; RA2 and YR share the RA2 column unless noted.

| Concept | TS tag (TS/FS) | RA2 tag | YR tag | Unified field |
|---|---|---|---|---|
| Registry array | `[InfantryTypes]`, `[VehicleTypes]`, `[AircraftTypes]`, `[BuildingTypes]` | same | same | `Registry{kind, entries[], stable_index}` |
| Object ID | `Name` (section) | `Name` | `Name` | `EntityDef.id` |
| Display name | `UIName` | `UIName` | `UIName` | `EntityDef.ui_label` (StringTable key) |
| Art link | `Image` | `Image` | `Image` | `EntityDef.art_id` (defaults to id) |
| Cost | `Cost` | `Cost` | `Cost` | `EntityDef.cost` |
| Hit points | `Strength` | `Strength` | `Strength` | `EntityDef.max_health` |
| Armor class | `Armor` (5 classes) | `Armor` (11 classes) | `Armor` (11 classes) | `EntityDef.armor_class` + `ArmorTable` |
| Power | `Power`/`Powered` | same | same | `BuildingDef.power` (signed) |
| Footprint | `Foundation`, `Height` | same | same | `BuildingDef.foundation_mask`, `height` |
| Build prereq | `Prerequisite` / `PrerequisiteOverride` | same | same | `BuildReq.all_of`, `BuildReq.any_of` |
| Tech level | `TechLevel` | `TechLevel` | `TechLevel` | `BuildReq.min_tech` |
| Owner gate | `Owner` | `Owner` | `Owner` | `BuildReq.owners` |
| Exclusive build | — (emulated via Owner/Side) | `RequiredHouses`/`ForbiddenHouses` | same | `BuildReq.required_houses`, `.forbidden_houses` |
| Weapon slots | `Primary`, `Secondary`, `ElitePrimary`, `EliteSecondary`, `WeaponX` | same | same | `WeaponSlots{ordered}` |
| Weapon registry | (implicit; no array) | (implicit) | (implicit) | `WeaponRegistry` |
| Warhead | `Warhead` on weapon | same | same | `WarheadDef` |
| Warhead damage vs armor | `Verses` (len 5) | `Verses` (len 11) | `Verses` (len 11) | `WarheadDef.verses[]` in unified armor order |
| Projectile domain | `AA`/`AG`/`AN` | same | same | `ProjectileDef.engagement_mask` |
| Targeting policy | `LandTargeting`/`NavalTargeting` | same | same | `WeaponPolicy.land/naval` |
| Movement speed type | `SpeedType` | `SpeedType` | `SpeedType` | `MovementDef.speed_type` |
| Movement zone | `MovementZone` | `MovementZone` | `MovementZone` | `MovementDef.zone` |
| Special movement | hover/subterranean/train | jumpjet/naval | jumpjet/naval | `MovementDef.locomotor_strategy` |
| Turret | `Turret`, `TurretOffset`, `BarrelLength` | same | same | `TurretDef` |
| Turret/barrel art | art `TurretOffset`/`PrimaryFireFLH` | same | same | `ArtSheet.turret` |
| Cameo | art `Cameo` | art `Cameo` (+`CameoPCX` Ares) | same | `ArtSheet.cameo` |
| Build-up anim | art `Buildup` | same | same | `ArtSheet.build_up` |
| Active anims | art `ActiveAnim*` | same | same | `ArtSheet.states{idle,active,damaged,...}` |
| Remap | art `Remapable` | same | same | `ArtSheet.remap_policy` |
| Theater art | art `Theater`/`NewTheater` | same | same | `ArtSheet.theater_rule` |
| Voxel flag | art `Voxel` | same | same | `ArtSheet.asset_kind` |
| Palette | external `.pal`, `AnimPalette`/`FirersPalette`/`TerrainPalette` | + country `mpls*.pal` | same | `PaletteSet` |
| Superweapon | `[SuperWeaponTypes]` | same | + `YuriCountry` SWs | `SuperweaponRegistry` |
| SW charge | `RechargeTime`, `UseChargeDrain` | same | same | `SuperweaponDef.charge` |
| SW action | `Action` | `Action` | `Action` | `SuperweaponDef.effect` |
| Resource type | `[Tiberiums]` (Riparius/Vinifera/Cruentus/Aboreus) | `[Tiberiums]` (Riparius=ore, Cruentus=gems) | same | `ResourceTable` |
| Ore tiles | `[OverlayTypes]` `TIB*`/`GEM*` | same | same | `CellLayer.overlays` + compat map |
| Map cell data | `[IsoMapPack5]` | same | same | `MapDocument.cells` |
| Map overlays | `[OverlayPack]`/`[OverlayDataPack]` | same | same | `MapDocument.overlays` |
| Theater | `[Map] Theater` | same + Urban | + NewUrban/Desert/Lunar | `MapDocument.theater` (enum) |
| Tile set | `.tem`/`.sno` | + `.urb` | + `.ubn`/`.des`/`.lun` | `TheaterProfile.tilesets` |
| Land passability | terrain-control INI `[LandTypes]` | same | same | `TileDef.passability_by_speed_type` |
| Faction list | `[Houses]` | `[Countries]` | `[Countries]` (+ index 9 Yuri) | `CountryRegistry` |
| Side grouping | `[Sides]` | `[Sides]` (GDI/Nod/Civ/Mutant) | `[Sides]` (+ThirdSide) | `SideRegistry` |
| House→art binding | side index | country index (flag/loading/EVA/palette) | same | `CountryRegistry[i].assets` |
| Map houses | map `[Houses]` | map `[Houses]` w/ `Country=` | same | `MapDocument.houses` |
| AI script team | `[TaskForces]` | same | same | `AiTaskForce` |
| AI behavior script | `[ScriptTypes]` (actions 0–49) | +actions 53–64 | +actions | `AiScript` + opcode map |
| AI team | `[TeamTypes]` | +`UseTransportOrigin` | +`MindControlDecision` | `AiTeamType` |
| AI scheduler | `[AITriggerTypes]` (`Side`=ActsLike+1) | conditions 5/6/7, `Side`=side idx | same | `AiTrigger` + side resolver |
| AI global tuning | `rules [AI]` + `[General]` | same | same | `AiConfig` |
| Mission types | `[Mission Control]` (shared set) | +QMove/Patrol/Open/Harmless/Eaten | same as RA2 | `MissionRegistry` |
| Map trigger | `[Triggers]` | same | same | `MapTrigger` |
| Map tag | `[Tags]` | same | same | `MapTag` (persistence) |
| Cell tag | `[CellTags]` | same | same | `MapDocument.cell_tags` |
| Waypoint | `[Waypoints]` (≤100) | `[Waypoints]` (≤100) | `[Waypoints]` (≤701) | `MapDocument.waypoints` |
| Map events/actions | `[Events]`/`[Actions]` | same | +YR events | `MapEvent` / `MapAction` |
| Localization | `langrule.ini`/`langfs.ini`; per-map `.INI` | `ra2.csf` | `ra2md.csf` | `StringTable` (CSF/INI import) |
| INI overlay | `firestrm.ini`, `*fs`/`01` | — | `*md` | `TitleProfile.overlays[]` |

---

## Engine Abstractions Required

1. **Registry / Section-Array Manager** — per-class ordered registries with stable indices,
   append-on-override, implicit-reference resolution, and duplicate handling. (X-DATA-002)
2. **Layered INI Loader + Title Profile** — base → expansion → map/mod overlay chain with
   per-title suffix rules and merge/replace semantics. (X-DATA-001, X-DATA-029)
3. **Key Dictionary / Dialect Layer** — maps classic keys (and dotted Ares/Phobos keys) onto
   unified component properties, per title and dialect/version, with dead/absent flags.
   (X-DATA-003, X-DATA-027, X-DATA-028)
4. **Faction Registry** — Side → Country/House → Player, with index-bound assets, side GUI/
   EVA metadata, and `Owner`/`RequiredHouses`/`ForbiddenHouses`/`ActsLike` resolvers.
   (X-DATA-019)
5. **Armor Table + Verses Matrix** — per-title ordered armor classes with TS→unified
   padding/alignment; combat resolution order (targeting → warhead → projectile → slots).
   (X-DATA-009)
6. **Weapon / Warhead / Projectile Registries** — slot sets, warhead status effects,
   projectile engagement and flight strategies. (X-DATA-007, X-DATA-010, X-DATA-011)
7. **Status / Effect Registry** — named effects (EMP, mind-control, parasite, temporal,
   radiation, poison, disguise, delay-kill, shields, AttachEffect) with caps, durations,
   stacking, and per-effect house filters. (X-DATA-010)
8. **Superweapon Registry** — charge model, UI metadata, effect hook, tech/house/map gates.
   (X-DATA-012)
9. **Resource Table** — resource value/colour/growth + overlay tile-set binding; veins,
   blossom trees, ice as optional strategies. (X-DATA-013)
10. **Theater Profile** — tileset registry, terrain-control INI, palette set, and
    `NewTheater` substitution. (X-DATA-020)
11. **Map Document + Map Scripting VM** — metadata, cells/overlays, preplaced entities,
    waypoints, tags/triggers/events/actions, variables, AI overrides; coordinate-version
    aware. (X-DATA-021, X-DATA-022)
12. **AI VM** — production planner (`[AI]` category vectors/ratios) + team scheduler
    (weighted `[AITriggerTypes]`) + script interpreter (numbered actions), with per-title
    opcode maps and side resolvers. (X-DATA-017, X-DATA-018)
13. **Mission Registry** — fixed per-title ordered mission types shared with AI scripts and
    `[Mission Control]` policy flags. (X-DATA-026)
14. **Art Sheet + Asset Importer** — state table, turret/barrel sub-assets, aliasing,
    SHP→texture, VXL+HVA→mesh+clips, PAL→palette, with title lepton/voxel scale constants.
    (X-DATA-004, X-DATA-015, X-DATA-016)
15. **Virtual File System** — ordered MIX mounts + loose files, per-title mount list,
    `.mmx`/`.yro` containers. (X-DATA-024)
16. **String Table** — CSF + TS string-INI import, inverse-byte UTF-16 decode, CP1252
    quirk, overlay layers. (X-DATA-023)
17. **Match Config + Roster Gate Service** — title → rules → expansion → map → match dialog;
    house/tech/limit gating. (X-DATA-030)
18. **Audio Registry** — named clips, side-specific voice/EVA, container-agnostic.
    (X-DATA-025)

---

## Coverage Checklist (research scope)

- [x] 1. INI file family per title (`fs`/`md` variants), overlay vs replacement — X-DATA-001,
      X-DATA-029
- [x] 2. Section-list registration architecture, order sensitivity, indexed tables —
      X-DATA-002
- [x] 3. Per-object common schema (identity, prereqs, tech, owners, cost, strength, armor,
      power, foundation, art, weapon slots, movement, special flags) — X-DATA-003,
      X-DATA-004, X-DATA-005, X-DATA-006, X-DATA-007, X-DATA-008
- [x] 4. Art schema (`Image`, voxel/SHP, cameos, turret/barrel, build-up, remap, palettes)
      — X-DATA-015, X-DATA-016
- [x] 5. AI schema (TS `ai.ini` vs RA2/YR `aimd.ini`; TaskForces/TeamTypes/ScriptTypes/
      AITriggerTypes) — X-DATA-017, X-DATA-018
- [x] 6. Map formats (`.map`/`.mpr`/`.yrm`/`.mmx`) and embedded sections — X-DATA-021
- [x] 7. Tilesets/theaters (`.tem`/`.sno`/`.urb`/Lunar), palettes, LAT/terrain objects —
      X-DATA-020, X-DATA-014
- [x] 8. Houses/sides/countries, `[Countries]`/`[Sides]`/`RequiredHouses`, index art
      binding — X-DATA-019
- [x] 9. Localization (CSF, `[UIName]`, strings) — X-DATA-023
- [x] 10. Assets (MIX archives, package formats, loose-file override) — X-DATA-024
- [x] 11. Modding extension engines (Ares/Phobos) and new schema — X-DATA-027, X-DATA-028
- [x] 12. Unified data-model mapping + required engine abstractions — big table +
      engine abstractions list
- [x] Bonus: warheads/verses/combat (X-DATA-009/010/011), projectiles (X-DATA-011),
      superweapons (X-DATA-012), resources (X-DATA-013), overlays (X-DATA-014),
      sound/EVA (X-DATA-025), missions (X-DATA-026), roster gates (X-DATA-030)

**Not covered (out of scope / not found authoritatively on the web):**
- Exact TS vs RA2/YR per-key flag diffs for every flag (ModEnc tables are YR-only; only
  documented deltas are captured).
- Full SFX/cameo mapping rollups and `.pkt`/`.pkt`-list internals.
- Binary MapPack/IsoMapPack5/OverlayPack bit-level compression layouts (described only at
  the section/coordinate level).
- Complete Ares/Phobos key inventories (representative subsets given; see their docs).

---

## Open Questions / Top Uncertainties

1. **Exact TS armor/Verses vs unified alignment.** TS uses 5 armor classes, RA2/YR 11; how
   mods (and Ares `[ArmorTypes]`) insert classes changes the meaning of every `Verses`
   vector. Need a canonical mapping and a regression test with independently computed
   damage. (X-DATA-009) — **med**.
2. **Per-title flag membership.** ModEnc explicitly warns its tables are YR-only; a
   machine-readable TS/FS/RA2/YR key matrix is not publicly authoritative. The unified
   key dictionary needs empirical extraction from shipped INIs (disallowed here). —
   **med/low**.
3. **Script action / mission numbering across TS→RA2/YR.** The documented +1 shift and new
   actions are clear, but not all per-action argument arities are documented; the opcode
   map may be incomplete. (X-DATA-018, X-DATA-026) — **med**.
4. **ECACHE/ELOCAL load-order determinism.** RA2/YR ordering is filesystem-dependent
   (WinAPI `FindNextFile`), so "which override wins" can differ by host. A deterministic
   unified VFS must pick a rule and document divergence. (X-DATA-024) — **med**.
5. **Hardcoded overlay/Tiberium indices.** The exact hardcoded behaviours per
   `[OverlayTypes]`/`[Tiberiums]` index are only partly documented ("Hardcoded"/"Do Not
   Add" markers); reverse engineering may be needed for full fidelity. (X-DATA-013/014) —
   **med**.
6. **Country index→asset binding exactness.** Flag/loading/EVA/palette filenames and
   textures are documented for the shipped 10 YR countries; reordering the list or adding
   countries requires executable patching in vanilla, so a unified model must define its own
   binding to avoid the original's crash-on-reorder. (X-DATA-019) — **high** (documented),
   but the migration strategy is unresolved.
7. **Ares vs Phobos dialect interactions.** Several keys are renamed across Phobos versions
   and interact with Ares; a single dialect model may need explicit version pinning per
   mod. (X-DATA-027/028) — **med**.
8. **Firestorm rule-merge exactness.** FS loads both a new `rules.ini` (for plain TS) and
   `firestrm.ini`; the precise merge precedence when both define a key is described but not
   exhaustively tested here. (X-DATA-001/029) — **med**.
9. **Voxel scale/precision.** TS 34 vs RA2/YR 43 voxels-per-cell and 1 voxel ≈ 6.03397
   leptons are documented; exact conversion for a 3D engine needs a model-space convention.
   (X-DATA-016) — **high** for the numbers, **med** for the mapping.
10. **Cameo/PCX and palette edge cases.** `CameoPCX` is Ares-only; whether the unified
    importer should accept it in all titles is a design choice, not documented ground truth.
    (X-DATA-004/015) — **med**.

---

*End of document.*
