# RA2/YR Core Engine & Simulation Mechanics — Deep Research Reference

Exhaustive, web-sourced reference for the core engine and simulation mechanics of
**Command & Conquer: Red Alert 2 (RA2) and Yuri's Revenge (YR)**, written to inform a
unified data-driven reimplementation (Tiberian Sun / Firestorm / RA2 / YR).

## Scope, method, and authority

- **Web only.** Ground truth is ModEnc, cnc.fandom.com, Project Perfect Mod (PPM), the
  CnCNet / Ares / Phobos ecosystems, and released/reverse-engineered INI data.
- **Cross-checked** against at least two sources per mechanic where possible.
- **Version basis:** YR `rulesmd.ini` (Yuri's Revenge final) and RA2 `rules.ini`. Where the
  two differ, both are named. Values quoted from a community `rulesmd.ini`
  (`hamdirizal/red-alert-2-rules`) are marked *(modded INI)* and cross-checked against
  vanilla `rules.ini` (`FreemanZY/Command_And_Conquer_INI`) and ModEnc defaults.
- **No code snippets.** Prose / short pseudocode only.
- **Terminology** follows `GLOSSARY.md` where it exists; engine terms are quoted as-is
  (e.g. `Verses`, `SpeedType`).

Confidence scale: **high** = multiple independent authoritative sources agree; **med** =
single authoritative source or a known-ambiguous mechanic; **low** = inferred / unresolved.

---

### RA2-CORE-001 — Isometric Grid Geometry, Leptons, and Tile Size

**What** — The world is a pseudo-isometric cell grid. Cell and sub-cell distances are
measured in *leptons*.

**Data keys** — Internal units (no INI key): lepton, cell, voxel. Related keys: `Range`
(cells), `CellSpread` (cells), `Sight` (cells), `Speed` (leptons/frame), firing offsets
`FLH` (leptons).

**Numbers**
- **1 lepton = 1/256 of a map cell edge.** A cell is **256 × 256 leptons**.
- Leptons obey the isometric projection: the **leptons-per-pixel ratio is larger
  vertically than horizontally** (the map is drawn squashed; distances must be converted).
- **Voxel:** 1 voxel ≈ **6.03397 leptons**. A cell edge is therefore **≈ 42.4264 voxels in
  RA2** (and ≈ 33.94112 voxels in TS, because TS assets use a different voxel scale).
- Render tile: RA2/TS isometric cells are conventionally drawn at a **2:1 pixel ratio**
  (horizontal:vertical), with a nominal cell footprint on screen of roughly 48 × 24 px.
  *(pixel footprint is art/render-side, not a simulation value — low confidence on exact px.)*
- `Cell` is the smallest map unit a structure/vehicle/aircraft can occupy. Up to **3
  infantry** share a cell in TS–YR (5 in TD/RA); this is the **Cell Spots** sub-position
  system. Buildings span multiple cells (foundations up to 4×4).

**Edge cases**
- Infantry occupy one of 3 sub-cell spots, so their exact point inside a cell shifts
  CellSpread/`Range` calculations (see `CellSpread`).
- `Range` and `Sight` are integer *cell* radii but resolved in leptons internally; the
  engine uses lookup tables (see `CellSpread`, `Sight`).
- Pseudo-isometry means a "circle" of range appears **octagonal**, not circular.

**Kind** — geometry / coordinate system / units of measure.

**Sources**
- https://modenc.renegadeprojects.com/Lepton (high)
- https://modenc.renegadeprojects.com/Voxel (high)
- https://modenc.renegadeprojects.com/Cell (high)
- https://modenc.renegadeprojects.com/CellSpread (high)

**Confidence** — high (lepton/cell/voxel), low (exact on-screen pixel footprint).

---

### RA2-CORE-002 — Height Levels, Altitude, and Elevation Bonuses

**What** — Terrain has discrete height levels; units have altitude in leptons. Height
affects LOS, weapon range, projectile blocking, and air/ground targeting.

**Data keys** — `[General]` `LeptonsPerSightIncrease`, `LeptonsPerFireIncrease`,
`FlightLevel`, `CliffBackImpassability`, `AttackingAircraftSightRange`;
`[ElevationModel]` `ElevationIncrement`, `ElevationIncrementBonus`, `ElevationBonusCap`;
per-object `FlightLevel`; projectile `SubjectToCliffs`, `SubjectToElevation`,
`DetonationAltitude`.

**Numbers**
- `[General] LeptonsPerSightIncrease=2000` and `LeptonsPerFireIncrease=2000` — height
  (leptons above absolute ground level 0) a unit must climb before gaining a **sight** /
  **weapon-range** bonus. 2000 exceeds *all height levels combined*, so the logic is
  **effectively disabled in vanilla**.
- `[General] FlightLevel=1500` — default aircraft cruise altitude in leptons (was 600 in TS).
- `[ElevationModel] ElevationIncrement=4`, `ElevationIncrementBonus=2`,
  `ElevationBonusCap=2` — for every **4 height levels** of elevation advantage, **+2 cells**
  of range, capped at **+2**.
- `[General] CliffBackImpassability=2` (0=minimal, 2=maximal).
- `[General] AttackingAircraftSightRange=2` *(YR)*.
- Aircraft considered "in the air" for CellSpread distance halving when **> 208 leptons**
  above ground (or a moving V3/Dread missile).
- `FlightLevel<=207` → aircraft only checks airports on ammo depletion; `FlightLevel<=-2`
  turns only on altitude change or map boundary.

**Edge cases**
- Sight/fire altitude bonus is measured from **ground level 0, not from surrounding
  terrain**, so a unit on high ground always sees/fires farther than on low ground. This is
  documented as a quirk/bug.
- `VeteranSight=0.0` in vanilla is a **deliberate 0 multiplier** (see 014) that would be a
  hard crash if set > 10.
- Height levels are an integer tile property; exact leptons-per-height-level is not
  documented in the sources reviewed → **open question**.
- `LeptonsPerFireIncrease` interacts with the `[ElevationModel]` bonus; both are separate
  systems (absolute altitude vs. differential elevation).

**Kind** — geometry / LOS / combat modifiers.

**Sources**
- https://modenc.renegadeprojects.com/LeptonsPerSightIncrease (high)
- https://modenc.renegadeprojects.com/LeptonsPerFireIncrease (high)
- https://modenc.renegadeprojects.com/FlightLevel (high)
- https://modenc.renegadeprojects.com/CellSpread (high)
- Rules INI `[General]` / `[ElevationModel]` (high)

**Confidence** — high (key semantics and values); low (exact lepton height per level).

---

### RA2-CORE-003 — Land Types (full list + per-type speed tables)

**What** — Every terrain tile links to a **LandType**. Each LandType has a section in
`rules(md).ini` giving the **percentage of normal speed** that each `SpeedType` may move
over it, plus `Buildable`.

**Data keys** — LandType sections: `[Clear]`, `[Rough]`, `[Road]`, `[Water]`, `[Rock]`,
`[Wall]`, `[Tiberium]`, `[Weeds]`, `[Beach]`, `[Ice]`, `[Railroad]`, `[Tunnel]`;
per-type keys `Foot`, `Track`, `Wheel`, `Float`, `Hover`, `Amphibious`, `Creep` (FS only),
`FloatBeach` (RA2/YR only), `Buildable`. Related: `[Overlay] Land=`, `[TileSet]` types,
`WaterBound`.

**Full LandType list (ModEnc; game availability RA = Red Alert, TS = Tiberian Sun,
RA2 = Red Alert 2/YR):**

| LandType | RA | TS | RA2 | Meaning | Allows veins |
|---|---|---|---|---|---|
| Clear | Y | Y | Y | Clear ground | Y |
| Rough | Y | Y | Y | Rough ground; **RA2 default = Clear values** | Y |
| Road | Y | Y | Y | Dirt/paved roads | Y |
| Water | Y | Y | Y | Lakes/ocean | N |
| Rock | Y | Y | Y | Rocks/trees/cliffs, impassable | N |
| Wall | Y | Y | Y | Non-Firestorm/non-laser walls | N |
| Ore | Y | N | N | RA ore/gem overlays (TD/RA only) | N |
| Tiberium | N | Y | Y | Ore/gem/Tiberium overlays | N |
| Beach | Y | Y | Y | Water/ground join | N |
| River | Y | N | N | RA rivers | N/A |
| Ice | N | Y | Y | Frozen water (RA2: unassigned; free for new rules) | N |
| Tunnel | N | Y | Y | Tunnel entrance/exit (RA2 needs TX) | Y |
| Railroad | N | Y | Y | Train tracks (RA2 needs TX) | Y |
| Weeds | N | Y | Y | Tiberium veins (RA2: unassigned) | Y |
| Cliff | N | N | Y | Cliffs (pre-RA2 used Rock); DestroyableCliff tile type | ? |

*(`[Ore]` and `[River]` are RA-only and absent from RA2. `[Cliff]` is a LandType in RA2 but
is handled via TileTypes `DestroyableCliff`/`Cliff`, not a normal section.)*

**Numbers — vanilla YR `rulesmd.ini` land sections (modded-INI values cross-checked):**

| Section | Foot | Track | Wheel | Float | Hover | Amphibious | FloatBeach | Buildable |
|---|---|---|---|---|---|---|---|---|
| Clear | 100% | 100% | 100% | 0% | 50% | 80% | 0% | yes |
| Rough | 100% | 100% | 100% | 0% | 50% | 80% | 0% | yes |
| Road | 100% | 100% | 100% | 0% | 75% | 100% | 0% | yes |
| Water | 0% | 0% | 0% | 100% | 100% | 100% | 100% | no |
| Rock | 0% | 0% | 0% | 0% | 0% | 0% | 0% | no |
| Wall | 0% | 0% | 0% | 0% | 0% | 0% | 0% | no |
| Tiberium | 90% | 70% | 50% | 0% | 50% | 50% | 0% | no |
| Weeds | 50% | 70% | 50% | 0% | 100% | 50% | 0% | no |
| Beach | 0% | 0% | 0% | 0% | 75% | 60% | 100% | no |
| Ice | 50% | 80% | 50% | 0% | 100% | 50% | 0% | no |
| Railroad | 90% | 100% | 50% | 0% | 100% | 50% | 0% | no |
| Tunnel | 100% | 100% | 100% | 0% | 100% | 100% | 0% | no |

**Edge cases**
- Percentages **> 100% are ignored** (200% == 100%).
- If a LandType's **Track = 0%**, it is also impassable to `Foot` units.
- If `Float > 0%`, the tile is considered **water-bound** and also honors `WaterBound`.
- `Winged` **cannot** be restricted per LandType (always 100%). Writing `Winged=x%` has no effect.
- `Rough` in RA2 defaults to Clear (the terrain distinction was dropped; the section remains
  for modders). In this modded INI, the commented-out original Rough (Foot 80 / Track 60 /
  Wheel 40 / Hover 50 / Amph 40) is present, confirming the Westwood intent.
- **Vein spread** is hardcoded per LandType (not INI).
- `Buildable` on the tile + `Buildable` on the LandType both gate construction.

**Kind** — terrain / movement / build placement.

**Sources**
- https://modenc.renegadeprojects.com/LandTypes (high)
- https://modenc.renegadeprojects.com/SpeedType (high)
- https://modenc.renegadeprojects.com/TileTypes (high)
- Vanilla YR `rulesmd.ini` land sections (high)

**Confidence** — high.

---

### RA2-CORE-004 — SpeedTypes (movement/speed classes)

**What** — `SpeedType` is the class used to look up a unit's per-LandType speed multiplier.
It is *not* the same as Locomotor (which controls animation/steering behavior).

**Data keys** — `[TechnoType] SpeedType=`. Defaults: `Track` or `Wheel` for vehicles,
`Foot` for infantry, `Winged` for aircraft, none for buildings.

**Full value list**
- `Foot` — infantry.
- `Track` — tracked vehicles (also the default for vehicles with `Crusher=yes`).
- `Wheel` — wheeled vehicles (default for vehicles with no `Crusher` / `Crusher=no`).
- `Float` — ships; forces `WaterBound` behavior on buildings.
- `Winged` — aircraft; always 100% over any tile.
- `Hover` — hover vehicles (TS+).
- `Amphibious` — land+water units (TS+).
- `Creep` — **Firestorm only** (not in RA2/YR).
- `FloatBeach` — **RA2/YR only** (beach-capable Float).

**Numbers** — see the LandType table in 003 for the complete per-SpeedType matrix.

**Edge cases**
- Aircraft are hardcoded to pathfind using **`SpeedType=Track` + `MovementZone=Normal`**, so
  in vanilla they cannot path to water cells. Removed in Phobos Build#46.
- Ares' `Deliver.Types` and similar spawn logic follow the same aircraft rule for
  non-`Float`/non-`WaterBound` buildings.
- For buildings, the SpeedType value is largely inert except `Float`, which grants
  `WaterBound=yes` and **ignores the tile's `Buildable`** during construction.
- `Underground` is **not** a valid SpeedType (a common misinformation traced to DeeZire's
  guide); the submarine concept is `Locomotor`/`Level`/cloak, not a SpeedType.

**Kind** — movement class.

**Sources**
- https://modenc.renegadeprojects.com/SpeedType (high)
- https://modenc.renegadeprojects.com/LandTypes (high)

**Confidence** — high.

---

### RA2-CORE-005 — MovementZones (full list)

**What** — `MovementZone` tells the pathfinder where a unit may go and what it assumes it can
crush/destroy. Distinct from SpeedType (which enforces terrain passability).

**Data keys** — `[TechnoType] MovementZone=` (techno types). Default `Normal`.

**Full value list (TS + RA2/YR)**
1. `None`
2. `Normal` — clear ground passable; assumes it can destroy terrain obstacles and crush infantry.
3. `Crusher` — only clear ground passable; assumes infantry crush, unarmed.
4. `Destroyer` — ground passable; can destroy terrain obstacles and crush infantry.
5. `AmphibiousDestroyer` — AmphibiousCrusher + can destroy terrain obstacles.
6. `AmphibiousCrusher` — ground **and** water passable; assumes infantry crush, unarmed.
7. `Amphibious` — ground and water passable. **Only zone** that lets amphibious units dock
   with all `UnitRepair=yes` buildings (land or naval).
8. `Subterrannean` *(sic)* — clear ground; digs when destination/obstacle requires; otherwise
   behaves like Crusher/Destroyer.
9. `Infantry` — only clear ground passable.
10. `InfantryDestroyer` — Infantry + can destroy terrain obstacles (trees).
11. `Fly` — everything passable.
12. `Water` — only water passable.
13. `WaterBeach` — Water + Beach cells.
14. `CrusherAll` *(YR only)* — Crusher + assumes it can crush any mobile object and walls.

**Numbers** — no numeric values; behavioral classes. Usage counts in a stock YR INI:
Infantry (58), Normal (35), Fly (19), Water (14), Destroyer (13), Crusher (6), Amphibious
Destroyer (4), Amphibious (3), CrusherAll (1), InfantryDestroyer (1).

**Edge cases**
- `SpeedType` is what *actually* allows/disallows terrain; MovementZone is the pathfinder's
  assumption set.
- Crushing requires the crusher to also be `Crusher=yes` (and `OmniCrusher=yes` to crush
  vehicles). `Crushable=no` / `DeployedCrushable=no` (YR) block infantry crushing.
- Amphibious\* infantry other than `AmphibiousDestroyer` fail to switch to the aquatic
  sequence on Beach/Water.
- `MovementZone=Fly` harvesters cannot manually enter refineries (fixed in Phobos #48);
  `Fly` vehicles cannot enter buildings (`NoEnter` cursor) incl. `Grinding`/`Bunker`.
- `Subterrannean` harvesters/weeders fail to pathfind home near water/cliffs (Phobos #49).
- `Subterrannean` + `Locomotor=Tunnel` + `Crusher` MovementZone digs only if ≥ 11 tiles
  between unit and destination over clear tiles.
- `CrusherAll` + `OmniCrusher=yes` ignores `Crushable` but respects `OmniCrushResistant`.

**Kind** — movement / pathfinding / AI.

**Sources**
- https://modenc.renegadeprojects.com/MovementZone (high)
- https://modenc.renegadeprojects.com/SpeedType (high)
- https://modenc.renegadeprojects.com/OmniCrusher (high)

**Confidence** — high.

---

### RA2-CORE-006 — Locomotors (full CLSID list + behavior)

**What** — Locomotors drive movement/steering and the correct animation states. Default when
missing/invalid = **Teleport**.

**Data keys** — `[TechnoType] Locomotor=<CLSID or (Phobos) alias>`. TS+ / YR warheads with
`IsLocomotor=yes` assign a Locomotor.

**Full list (alias → CLSID → default SpeedType):**

| Alias | CLSID | Default SpeedType | Used by |
|---|---|---|---|
| Levitate | `{3DC0B295-6546-11D3-80B0-00902792494C}` | Hover(?) | Firestorm only, vehicles |
| Drive | `{4A582741-9839-11d1-B709-00A024DDAFD1}` | `Track` if `Crusher=yes` else `Wheel` | ground vehicles |
| Hover | `{4A582742-9839-11d1-B709-00A024DDAFD1}` | Hover | hover vehicles (Hover MLRS, Robot Tank) |
| Tunnel | `{4A582743-9839-11d1-B709-00A024DDAFD1}` | same as Drive | burrowing vehicles |
| Walk | `{4A582744-9839-11d1-B709-00A024DDAFD1}` | same as Drive | ground infantry |
| DropPod | `{4A582745-9839-11d1-B709-00A024DDAFD1}` | Hover(?) (temporary) | falling objects / drop pods |
| Fly | `{4A582746-9839-11d1-B709-00A024DDAFD1}` | Winged | aircraft |
| Teleport | `{4A582747-9839-11d1-B709-00A024DDAFD1}` | same as Drive | chrono units; **default** |
| Mech | `{55D141B8-DB94-11d1-AC98-006008055BB5}` | same as Drive | walkers (Mammoth Mk.II) |
| Ship | `{2BEA74E1-7CCA-11d3-BE14-00104B62A16C}` | Float | ships (AI recognition) |
| Jumpjet | `{92612C46-F71F-11d1-AC9F-006008055BB5}` | Hover | jumpjet vehicles/infantry |
| Rocket | `{B7B49766-E576-11d3-9BD9-00104B972FE8}` | Winged | spawned missiles (V3, Dreadnought, Boomer) |

**Numbers / notable behavior**
- **Walk:** arrival threshold `< 17 leptons`; not for infantry with `Speed >= 14` (those
  behave erratically). Infantry default to `SpeedType=Foot` regardless of Locomotor.
- **Mech:** arrival threshold `< 16 leptons`; ignores acceleration (instant accel/decel);
  hardcoded not to tilt/sink; ~**40% slower** than Drive at equal `Speed`. Not for
  `Speed >= 14` vehicles.
- **Hover:** ~**35% slower** than Drive at equal `Speed`; do not use with `Speed >= 31`
  (erratic) or with `IsTrain=yes`.
- **Fly:** hardcoded to pathfind as Track+Normal; vehicles get grounded shadow bugs; used by
  `AircraftType`; `FlyBy=yes` ignores landing orientation; `Landable` defaults no.
- **Jumpjet:** infantry pathfind as `SpeedType=Hover` (can't stand on buildings/cliffs);
  `Crashable=no` recommended for aircraft (Ares extends); bobbing hardcoded unless
  `IsDropship=yes` (Phobos #49).
- **Teleport:** `Teleporter=yes` vehicles use Drive normally and Teleport only to `Dock=`
  buildings; vehicle-factory output drives to rally then chronos; naval factory output
  chronos directly.
- **Tunnel:** burrow switches when > 11 cells of `AllowBurrowing=no` lie before target;
  `TunnelSpeed=1` global; horizontal underground altitude hardcoded `-256`, speed hardcoded
  `19`.
- **Rocket:** kamikaze; ignores destination altitude during climb (Phobos #49).

**Edge cases**
- Invalid/missing Locomotor → Teleport (chrono) locomotor.
- Locomotor on buildings is parsed but inert.
- `[COW]` and `[DESO]` are hardcoded special units (random movement; radiation-based deploy).
- `DropPod` is temporary; direct assignment causes Internal Error.

**Kind** — movement / animation.

**Sources**
- https://modenc.renegadeprojects.com/Locomotor (high)
- https://modenc.renegadeprojects.com/SpeedType (high)
- https://modenc.renegadeprojects.com/MovementZone (high)

**Confidence** — high.

---

### RA2-CORE-007 — Armor Classes (the 11)

**What** — RA2/YR have **11 armor classes**. `Armor=` on a TechnoType is a **class label**,
not a numeric damage absorber. The warhead `Verses` list indexes these classes.

**Data keys** — `[TechnoType] Armor=`; `[Warhead] Verses=` (11 comma-separated percentages).

**Full ordered list (index → code → role)**
1. `none` — standard infantry (cloth); vulnerable to everything.
2. `flak` — special infantry; more resistant than none.
3. `plate` — exclusive infantry; near-immune to tank shells, tougher vs bullets.
4. `light` — light vehicles; fragile.
5. `medium` — miners and Kirovs only; very resistant to everything.
6. `heavy` — heavy tanks; similar to light but more resistant to explosives/bullets/fire.
7. `wood` — light building armor; fragile.
8. `steel` — base defenses and superweapons; very resistant.
9. `concrete` — Construction Yard and Shipyard only; very resistant to superweapons.
10. `special_1` — Terror Drone; weak vs bullets (esp. 20mmRapid).
11. `special_2` — V3/Dreadnought/Boomer missiles; prevents chain-detonation of stacked missiles.

**Numbers** — no numeric value. RA2 armor is a lookup column selector; the engine performs
**no armor-strength subtraction** (unlike TD/RA/TS numeric armor and later Generals). Country
armor modifiers use `ArmorAircraftMult`, `ArmorUnitsMult`, `ArmorInfantryMult`,
`ArmorBuildingsMult`, `ArmorDefensesMult`.

**Edge cases**
- TS had only 5 classes: `none`, `light`, `wood`, `heavy`, `concrete`. RA2 added `flak`,
  `plate`, `medium`, `steel`, `special_1`, `special_2`.
- `Verses` shorter than 11 entries defaults the remainder to 100%.
- Missile armor (`special_2`) with radiation/other warheads can destroy in-flight missiles
  before launch if not made immune (`ImmuneToRadiation`).
- Armor powerup (`[Powerups] Armor`) in RA2 **divides** incoming damage by `S`
  (vs. TS where it multiplied).

**Kind** — combat / damage typing.

**Sources**
- https://modenc.renegadeprojects.com/Armor_types (high)
- https://modenc.renegadeprojects.com/Armor (high)
- https://modenc.renegadeprojects.com/Verses (high)
- https://modenc.renegadeprojects.com/The_YR_Combat_System (high)

**Confidence** — high.

---

### RA2-CORE-008 — Warheads and Verses Semantics

**What** — A Warhead is the damage-delivery profile: `Verses` multiplier per armor class,
area spread, impact animation, and special effects. It is the single most important combat
tag. Warheads are the "rock–paper–scissors" of RA2.

**Data keys** — `[Warhead]` keys: `Verses`, `CellSpread`, `PercentAtMax`, `Wall`, `Wood`,
`WallAbsoluteDestroyer`, `Conventional`, `Fire`, `Radiation`, `Tiberium`, `Sparky`,
`Rocker`, `DirectRocker`, `Bright`, `CombatLightSize`, `Bullets`, `AnimList`, `Particle`,
`InfDeath`, `ProneDamage`, `Sonic`, `EMEffect`, `EMP.Cap`, `EMP.Duration`,
`PenetratesBunker`, `Parasite`, `Culling`, `MindControl`, `MindControl.Permanent`,
`PsychicDamage`, `AffectsAllies`, `IvanBomb`, `BombDisarm`, `Airstrike`, `Temporal`,
`Temporal.WarpAway`, `IsLocomotor`, `Locomotor`, `MinDebris`, `MaxDebris`, `NukeMaker`,
`Poison`, `Psychedelic`, `Veinhole`, `EVerses`, `IronCurtain.Cap`, `IronCurtain.Duration`,
`CausesDelayKill`, `DelayKillFrames`, `DelayKillAtMax`, `CLDisableRed/Green/Blue`, `ShakeXlo/hi`, `ShakeYlo/hi`.

**Verses order (RA2/YR):** `none, flak, plate, light, medium, heavy, wood, steel, concrete,
special_1, special_2`. Default = 100% repeated as needed.

**Full stock YR warhead registry (`[Warheads]`, 105 entries):**
`EMPuls, SonicWarhead, TankOGas, SA, HE, AP, Gas, Fire, HollowPoint, Super, Organic, Slimer,
FirestormWH, IonCannonWH, RailShot, Mechanical, VeinholeWH, IonWH, ARTYHE, PlasmaWH, SAMWH,
ORCAAP, RailShot2, ORCAHE, Controller, PsiPulse, IvanBomb, IvanWH, Electric,
ElectricAssault, V3HE, Parasite, NUKE, BlimpHE, ParasitePlus, DeathWH, ParasiteDog,
BombDisarm, Snapshot, RadBeamWarhead, RadEruptionWarhead, RadSite, GrandCannonWH, UltraAP,
HowitzerWH, CometWH, MaverickHE, FlakWH, OilExplosionWH, TankSnapshot, CRNUKEWH, ChronoBeam,
HollowPoint2, NukeMaker, FakeC4WH, HollowPointNoBuilding, V3WH, FlakTWH, APSplash, DMISLWH,
DemobombWH, MirageWH, SSA, SSAB, ApocAP, HARVWH, V3EWH, DMISLEWH, TerrorBombWH, FlakGuyWH,
CRTerrorBombWH, HollowPoint3, ControllerBuilding, SuperPsiPulse, DominatorWH, AirstrikeFlare,
VirusGas, Virus, PsychGasCreate, PsychGas, Battering, GattWH, Mutate, CMISLWH, CMISLEWH,
Smashing, LocomotorBeam, MIGWH, LUNARWH, GUARDWH, AntiB, AntiPerson, PJABWH, APSplash2,
SAFlame, SSABFlame, DiskWH, NukeB, BORISWH, SCHOPWH, TRexWH, MutateExplosion, TRexInfWH,
Crush, BlimpHEEffect`.
Additional actual sections not in the registry (engine-default / mod-added):
`Fire2`, `DummyWarhead`, `GRIZAPE`, `RHINAPE`, `RPG`, `Shard`, `Shock`, `MagnetronWH`,
`PrismWarhead`, `OldPsychGasCreate`, plus mod's `Hamdi*`.

**Verbatim special semantics**
- **`Verses > 3%`** → normal combat allowed.
- **`Verses = 2%`** → intended "no passive acquire", but the effect is **broken**; behaves
  like normal combat (documented as a bug).
- **`Verses = 1%`** → **cannot passive-acquire**, but *will* accept an explicit attack order,
  force-fire, and retaliate. Used for spy/disguise weapons.
- **`Verses = 0%`** → **forbidden armor type**: no attack order, no force fire, no retaliate,
  no passive acquire; targeting is passed to the Secondary/another weapon if possible.
- **Negative Verses** → damage is reversed, **restoring** Strength (e.g. −30% heals 30).
- `0 < Damage × Verses < 1` rounds down to **0 damage**.

**Numbers / effects**
- `[Special]` (`Warhead=Special`) is a **dummy** used by spawner weapons (Aircraft Carrier,
  V3); it attacks every armor type, only bounded by Land/NavalTargeting and AG/AA=no.
- `ProneDamage` (warhead) reduces damage to **prone infantry**; default 100%.
  **Conflict:** ModEnc's `ProneDamage` page says it applies **before** `Verses`; the PPM/ModEnc
  YR Combat System page says **after**. Treat order as *uncertain*.
- `AffectsAllies` defaults **yes** (splash hits friendlies).
- `CellSpread` buildings take damage **per covered cell** (a 3×3 building under CellSpread=1
  takes the hit 9×).
- `Sonic` removes Parasite units; `Culling` instant-kills red-health targets; `Parasite`
  drives Terror Drone / Attack Dog logic; `PenetratesBunker` passes damage into Yuri's bunker.
- `EMEffect` is **non-functional in RA2/YR** (works in TS); `Spread` is obsolete in RA2/YR.
- `Tiberium`/`Wall`/`Wood`/`Fire` gate what the warhead may damage (ice is melted by `Fire`).

**Edge cases**
- Warhead targeting hierarchy: **Land/NavalTargeting → Warhead → Projectile →
  Primary/Secondary**.
- A warhead with a cursor-sabotage weapon (C4, MigAttackCursor) is not swapped to merely by a
  1% verse; `CanC4=no` blocks the override entirely.
- ModEnc notes `Verses` is **reset to default (all 100%)** after being modified via map INI.
- Ares changed behavior across versions (0.1 kept original damage; 0.2 no longer affects
  target selection).

**Kind** — combat / damage typing / targeting.

**Sources**
- https://modenc.renegadeprojects.com/Verses (high)
- https://modenc.renegadeprojects.com/Warhead (high)
- https://modenc.renegadeprojects.com/The_YR_Combat_System (high)
- https://modenc.renegadeprojects.com/ProneDamage (med — order conflict)
- Vanilla YR `[Warheads]` registry (high)

**Confidence** — high (semantics/registry); med (ProneDamage order).

---

### RA2-CORE-009 — Damage Formula and Area Falloff

**What** — Final damage is `Weapon.Damage` multiplied by the target's `Verses` entry for its
armor class, then adjusted by area falloff, prone state, veterancy, and special multipliers.
RA2 has **no numeric armor absorption**.

**Data keys** — `[Weapon] Damage`, `Burst`, `[Warhead] Verses`, `CellSpread`, `PercentAtMax`,
`ProneDamage`; `[General] VeteranCombat/VeteranArmor`; `[CombatDamage] MaxDamage`, `MinDamage`,
`Crush`, `ExpSpread`, `HomingScatter`, `BallisticScatter`.

**Formula (pseudocode, converging on engine behavior):**
```
base     = Weapon.Damage × Verses[target.Armor] / 100
# area falloff (CellSpread > 0):
M        = 1 - (1 - PercentAtMax) × (distance_cells / CellSpread)
base    *= M
# prone infantry: base *= Warhead.ProneDamage   (order vs Verses uncertain)
# clamp:
damage   = floor(base)            # 0 < base < 1 -> 0
if damage > MaxDamage: damage = MaxDamage   # MaxDamage default 10000
# then apply veterancy, prism support, open-topped, bunker, occupy, country modifiers
# immunities / special warheads applied last
```
**Numbers**
- `[CombatDamage] MaxDamage=10000` (hard cap per shot after adjustments).
- `[CombatDamage] MinDamage=1` (obsolete).
- `PercentAtMax` default `100%`; falloff is **linear** across `CellSpread` cells.
- `[CombatDamage] Crush=1.8` cells — AI crush-vs-fire decision radius.
- `ExpSpread=.7` — cell damage spread per 100 damage for `Explodes=yes` objects.
- `HomingScatter=2.0`, `BallisticScatter=1.0` (max scatter cells).
- `[AudioVisual] Gravity=6` for ballistic projectiles.

**Edge cases**
- **Negative `Verses`** heals; **negative `Damage`** is a repair weapon (hardcoded to be
  inactive against hostiles, to remove parasites, and — vanilla — to only affect same-type
  units until Ares 0.D/Phobos #37).
- `0 ≤ base < 1` → 0 damage (rounding down).
- **Buildings with multi-cell foundations take the warhead once per covered cell** — a
  `Damage=100`, `CellSpread=1.5`, `PercentAtMax=1` weapon does 100 to a 1×1 defense but 900
  to a 3×3 building (up to 16× at 4×4 foundations).
- CellSpread uses a 20×20 air-unit sector grid for airborne targets and halves an airborne
  target's measured distance (aircraft > 208 leptons up).
- CellSpread values **> 11** cause an Internal Error on detonation.
- `Verses` only decides *targeting* at 0%/1%; actual damage is a straight multiplier.

**Kind** — combat / damage resolution.

**Sources**
- https://modenc.renegadeprojects.com/PercentAtMax (high)
- https://modenc.renegadeprojects.com/CellSpread (high)
- https://modenc.renegadeprojects.com/Damage (high)
- https://modenc.renegadeprojects.com/Damage_calculation_over_area (high)
- https://modenc.renegadeprojects.com/Verses (high)
- https://modenc.renegadeprojects.com/Armor (high — "no numeric armor")
- Vanilla YR `[CombatDamage]` (high)

**Confidence** — high (chain and caps); med (exact intermediate rounding/order).

---

### RA2-CORE-010 — Projectiles (full type list + every parameter)

**What** — The projectile is the delivery method that carries the warhead to the target. It
decides AA/AG/AN eligibility and flight behavior; most other projectile tags are aesthetic.

**Data keys (complete stock parameter set with defaults):**
`AA` (0), `AG` (1), `AN` (1), `AS` (0), `ASW` (0), `Acceleration` (3), `Airburst` (0),
`AirburstWeapon`, `Arcing` (0), `Arm` (0), `Bouncy` (0), `Cluster` (1),
`CourseLockDuration` (0), `Color`, `Degenerates` (0), `DetonationAltitude` (0), `Dropping` (0),
`Elasticity` (1.8125; docs say 0.75), `FirersPalette` (0), `FlakScatter` (0), `Floater` (0),
`High`, `Image`, `Inaccurate` (0), `Inviso` (0), `Level` (0), `LineTrailColor`/`Decrement`,
`Parachuted`, `Proximity` (0), `Ranged` (0), `ROT` (0), `Scalable` (0), `Shadow` (1),
`ShrapnelWeapon`, `ShrapnelCount` (0), `SubjectToCliffs` (0), `SubjectToElevation` (0),
`SubjectToWalls` (0), `Vertical` (0), `VeryHigh` (0).

**Full stock projectile set (YR rules):**
`Invisible, Invisible2, Invisible3, Invisible4, Invisible5, InvisibleVertical, InvisibleLow,
InvisibleMedium, InvisibleHigh, InvisibleAll, PsychicControl, Psychic, QuadShell, Null,
Cannon, Cannon2, ChemMissile, V3AirburstP, JUMP, DOGJUMP, ADOGJUMP, SQDJUMP, GiantNukeUp,
GiantNukeDown, HeatSeeker, Torpedo, Sonic, ASWVirt, ClusterBits, ProtonTorpedo, NormalBomb,
BlimpBombP, BlimpBombPE, DepthCharge, ProtonBlast, AAHeatSeeker, AAHeatSeeker2,
AirToGroundMissile, AAHeatSeeker3, NavalToGroundSeeker, DredMissile, MedusaProjectile,
Lobbed, Lobbed2, Ballistic, PulsPr, LLine, LLine2, DogShard, GrandCannonBall`.

**Representative parameter values**
- `[Invisible...]`: `Inviso=yes`, `Image=none`; variants add
  `SubjectToCliffs/Elevation/Walls` (Low = all yes, Medium = cliffs+elev only,
  High = elevation only, All = AA/AG yes, no subjects).
- `[Cannon]`: `Image=120MM`, `Arcing=true`, all three SubjectTo = yes.
- `[HeatSeeker]`: homing `ROT=8`, `Proximity=yes`, `Ranged=yes`, no SubjectTo.
- `[Torpedo]`: `ROT=12`, `AA=no`, `AG=yes`, `Level=yes`.
- `[ChemMissile]`: `Arm=2`, `VeryHigh=yes`, `Cluster=8`, `ROT=4`.
- `[AAHeatSeeker]`: `ROT=80`, `AA=yes`, `AG=no`; `[AAHeatSeeker2]` `ROT=60` AA+AG;
  `[AirToGroundMissile]` `ROT=100` AG only.
- `[GiantNukeUp]`/`[GiantNukeDown]`: `Vertical=yes`, `DetonationAltitude=20000/30000`,
  `Acceleration=1`.
- `[BlimpBombP]`: `Arm=10`, `Vertical=yes`, `DetonationAltitude=20000`;
  `[BlimpBombPE]` adds `ShrapnelWeapon=SuperCometFragment`, `ShrapnelCount=8`.
- `[ClusterBits]`: `ROT=60`; `[MedusaProjectile]`: `Arm=1`, `CourseLockDuration=15`, `ROT=20`,
  `Scalable=yes`.

**Edge cases**
- `AA/AG/AN` determine *what can be shot*; `AN`/`AS` are redundant in RA2/YR (`AG` covers
  naval).
- `Arcing=true` + `AA=yes` is broken: projectile flies ~300 leptons up and returns, never
  reaching the air target.
- `ROT=0` on a non-Arcing/Inviso/Vertical projectile uses a faulty default arc (always hits
  at 2/3 of path beyond 8 cells; GearZero made it straight, Phobos offers "Straight
  trajectory").
- `ROT=1` is effectively straight but can overshoot/misbehave at low ROT/Speed ratios,
  especially with `AA=yes` or fired from aircraft ("Circling Missile bug").
- Homing projectiles whose target dies mid-flight fly to `MissileSafetyAltitude=750` and
  detonate.
- Aircraft firing a projectile with `ROT < 2` and `Inviso=no` enter strafing mode and cannot
  hit air (fixed Phobos #43).

**Kind** — combat / ballistics.

**Sources**
- https://modenc.renegadeprojects.com/Projectile (high)
- https://modenc.renegadeprojects.com/ROT (high)
- https://modenc.renegadeprojects.com/Warhead (projectile flags list) (high)
- Vanilla YR projectile section block (high)

**Confidence** — high.

---

### RA2-CORE-011 — Targeting Hierarchy, LandTargeting, NavalTargeting

**What** — What a unit fires at is resolved in priority order, then special multi-weapon logic.

**Data keys** — `LandTargeting`, `NavalTargeting`, `Primary`, `Secondary`, `Weapon1..N`,
`Gunner`, `IsGattling`, `IsChargeTurret`, `Spawner`, `ElitePrimary`, `AirRangeBonus`.

**Targeting hierarchy** — `Land/NavalTargeting → Warhead → Projectile → Primary/Secondary`.

**Numbers**
- `LandTargeting`: `0 = LAND_OKAY`, `1 = LAND_NOT_OKAY` (forbidden to fire on ground),
  `2 = LAND_SECONDARY` (ground only via Secondary). Default 0.
- `NavalTargeting`: `0 = UNDERWATER_NEVER`, `1 = UNDERWATER_SECONDARY`, `2 = UNDERWATER_ONLY`,
  `3 = ORGANIC_SECONDARY`, `4 = SEAL_SPECIAL`, `5 = NAVAL_ALL`, `6 = NAVAL_NONE`,
  `7 = NAVAL_PRIMARY`. Default 0 (only forbids direct underwater attack).
- `Verses`: `0%` passes targeting to Secondary.

**Edge cases**
- Primary is checked first and always tries land tiles; Secondary is a fallback.
- Land/NavalTargeting supersede everything **except air targeting** (Warhead/projectile).
- `AirRangeBonus` applies only to Primary weapons, not Secondary.
- Secondary will not fire until Primary's `ROF` has elapsed (and vice versa) to prevent ROF abuse.
- `Gunner` (IFV) suspends Primary/Secondary in favor of `WeaponX` slots; `IsGattling`
  increments weapons over time and ignores most restrictions; `IsChargeTurret` only animates.
- `Spawner` + `Warhead=Special` turns a unit into a spawn-maker (Aircraft Carrier, V3).

**Kind** — combat / target selection.

**Sources**
- https://modenc.renegadeprojects.com/The_YR_Combat_System (high)
- https://modenc.renegadeprojects.com/Verses (high)
- https://modenc.renegadeprojects.com/Naval (high)

**Confidence** — high.

---

### RA2-CORE-012 — ROT / Turret Traverse, JumpjetControls, Helicopter Behavior

**What** — `ROT` (Rate Of Turn) controls how fast a techno or projectile can turn. Separate
global blocks configure jumpjets; helicopters are aircraft that use Fly + special semantics.

**Data keys** — Techno/Projectile `ROT`; `[JumpjetControls]` (`TurnRate`, `Speed`, `Climb`,
`CruiseHeight`, `Acceleration`, `WobblesPerSecond`, `WobbleDeviation`) and per-unit overrides
`JumpjetTurnRate`, `JumpjetSpeed`, `JumpjetClimb`, `JumpjetHeight`, `JumpjetAccel`,
`JumpjetWobbles`, `JumpjetDeviation`; `TurretSpins`; `[General] CurleyShuffle`,
`MissileSpeedVar`, `MissileROTVar`, `HoverHeight`; `[AudioVisual] Gravity`.

**Numbers**
- `ROT=0` for technos: infantry always turn instantly; vehicles/buildings with ROT=0 turn
  instantly (RA1: immobile); aircraft fly straight.
- Projectile `ROT`: non-zero = homing; 0 = arcing/default; 1 = near-straight.
- `[JumpjetControls]`: `TurnRate=4`, `Speed=14`, `Climb=5`, `CruiseHeight=500`,
  `Acceleration=2`, `WobblesPerSecond=.15`, `WobbleDeviation=40`. *(Section believed obsolete
  in YR; Phobos #22 re-enables it.)*
- `[General] MissileSpeedVar=.25`, `MissileROTVar=.25` (±25% random speed/turn variation).
- `[General] CurleyShuffle=yes` — helicopters shuffle position between shots.
- `[General] HoverHeight=120`; hover dampen/bob/boost/accel/brake see 017.

**Helicopter specifics**
- Helicopters are `AircraftType`s (e.g. ORCA, BEAG, HIND) using `Locomotor=Fly`; they must
  return to a helipad/airport to rearm (`ReloadRate=.3` min per ammo point) unless
  `SeparateAircraft=yes` (first heli free from helipad).
- `PadAircraft=ORCA,BEAG` lists airport-bound aircraft.
- `TurretSpins=yes` makes a flying vehicle's body rotate like a turret.
- Damaged aircraft emit SGRYSMK1 smoke (10%/frame yellow, 80%/frame red).
- `Fighter=yes` defines the bombing pattern; `FlyBy` ignores landing orientation.

**Edge cases**
- `ROT=0` projectiles not of Arcing/Inviso/Vertical type use the faulty default arc.
- Low `Speed` on missile ROT types causes vertical ascent then detonation / strange paths.
- `ROT` on infantry is ignored (instant turn).

**Kind** — movement / combat / flight.

**Sources**
- https://modenc.renegadeprojects.com/ROT (high)
- https://modenc.renegadeprojects.com/JumpjetControls (high)
- https://modenc.renegadeprojects.com/Locomotor (high)
- Vanilla YR `[General]`/`[AudioVisual]` (high)

**Confidence** — high.

---

### RA2-CORE-013 — Power: Supply/Demand, Low-Power Penalties, DamageDelay

**What** — Buildings produce or consume power; a house-wide balance determines the
low-power state, which cripples production and defenses.

**Data keys** — `[BuildingType] Power=` (supply if > 0, demand if < 0), `Powered=yes/no`,
`PipScale=Power`, `Drainable` (YR), `TogglePower`, `[General] MinLowPowerProductionSpeed`,
`MaxLowPowerProductionSpeed`, `LowPowerPenaltyModifier`, `DamageDelay`,
`[AI] PowerEmergency`, `PowerSurplus`.

**Numbers**
- `Power`: positive = supply, negative = demand (e.g. power plants vs. consumers).
- `[General] MinLowPowerProductionSpeed=.5` — floor production multiplier under low power.
- `[General] MaxLowPowerProductionSpeed=.8` — ceiling production multiplier under low power
  (so 99% power is treated as this).
- `[General] LowPowerPenaltyModifier=1` — penalty = modifier × power shortfall fraction
  (2 = double penalty, .5 = half).
- `[General] DamageDelay=1` minute — interval of **trivial structure damage while low on
  power**.
- `[AI] PowerEmergency=75%` — AI sells to restore power below this level.
- `[AI] PowerSurplus=50` — AI builds plants until surplus reaches this.

**Edge cases**
- `Powered=yes` buildings **freeze active animations** when underpowered
  (`ActiveAnimPowered=no` exempts an animation).
- Underpowered `Powered` buildings with negative `Power` also stop firing and stop emitting
  light (lightposts).
- Power plants underpowered (or EMP'd) stop providing power; `Powered` does **not** grant EMP
  immunity.
- `Drainable=yes` (YR) lets `DrainWeapon=yes` drain `PipScale=Power` (or `Storage`).
- `Cloning` (Yuri) keeps working under low power in vanilla (fixed Ares 2.0).

**Kind** — economy / base systems.

**Sources**
- https://modenc.renegadeprojects.com/Powered (high)
- https://modenc.renegadeprojects.com/Power (high)
- https://modenc.renegadeprojects.com/Drainable (high)
- Vanilla YR `[General]`/`[AI]` (high)

**Confidence** — high.

---

### RA2-CORE-014 — Veterancy / Rank System

**What** — Objects gain ranks (Rookie → Veteran → Elite) by destroying value, gaining stat
multipliers and ability upgrades.

**Data keys** — `[General] VeteranRatio`, `VeteranCombat`, `VeteranSpeed`, `VeteranSight`,
`VeteranArmor`, `VeteranROF`, `VeteranCap`, `InitialVeteran`; `[TechnoType] VeteranAbilities`,
`EliteAbilities`, `ElitePrimary`/`EliteSecondary` (or `Elite`), `DontScore`, `Insignificant`;
`[Houses]` `VeteranInfantry`/`VeteranUnits`/`VeteranAircraft`.

**Numbers (vanilla YR defaults)**
- `VeteranRatio=3.0` — must destroy **more than `VeteranRatio × Cost`** credits to gain one level.
- `VeteranCombat=1.1` (× damage), `VeteranSpeed=1.2` (× speed),
  `VeteranSight=0.0` (× sight; values >10 are the hardcoded "Vegas" crash),
  `VeteranArmor=1.5` (damage divided by this), `VeteranROF=0.6` (× ROF delay),
  `VeteranCap=2` (max level: 0=Rookie, 1=Veteran, 2=Elite), `InitialVeteran=no`.
- Promotion example: a GI costs 200 → needs > 601 credits of kills; a Prism Tank needs ≥ 3601.
- `VeteranRatio` defaults: 10 (TS), 5 (FS), **3 (RA2/YR)**.

**Full ability value list (hardcoded)** — `FASTER, STRONGER, FIREPOWER, SCATTER, ROF, SIGHT,
CLOAK, GUARD_AREA, CRUSHER, SELF_HEAL, EXPLODES, RADAR_INVISIBLE, SENSORS, FEARLESS`
(all also used by `EliteAbilities`).
Ineffective in RA2: `C4, TIBERIUM_PROOF, VEIN_PROOF, TIBERIUM_HEAL`.
Ares-added: `EMPIMMUNE, RADIMMUNE, PROTECTED_DRIVER, UNWARPABLE, POISONIMMUNE,
PSIONICWEAPONIMMUNE, PSIONICSIMMUNE`.

**Edge cases**
- Elite bonuses **do not stack** with Veteran bonuses, but a Veteran-only ability is retained
  at Elite (e.g. `SENSORS`).
- `FIREPOWER`/`ROF` at Elite apply to the object's **Elite weapon** if one exists.
- `DontScore=yes` / `Insignificant=yes` kills do not count toward promotion.
- Civilian/neutral and even your own (with `Temporal=yes`) objects count as kills.
- `SCATTER` is auto-granted to human players if `PlayerScatter=yes`, and to houses with IQ >
  `[IQ] Scatter`; before Phobos #48, any Elite unit always had it.
- `C4` veteran ability only functioned in TS/FS; broken in RA2/YR (fixed Ares 0.5).

**Kind** — progression / combat modifiers.

**Sources**
- https://modenc.renegadeprojects.com/VeteranAbilities (high)
- https://modenc.renegadeprojects.com/EliteAbilities (high)
- https://modenc.renegadeprojects.com/VeteranRatio (high)
- https://modenc.renegadeprojects.com/Elite (high)
- Vanilla YR `[General]` (high)

**Confidence** — high.

---

### RA2-CORE-015 — Crushing, Ice, and Destroyable Bridges

**What** — Vehicles can crush objects; weight cracks/shatters ice; bridges are destructible map
structures.

**Data keys** — `Crusher`, `OmniCrusher`, `OmniCrushResistant`, `Crushable`,
`DeployedCrushable` (YR), `CrushSound`, `Crusher` MovementZone, `MovementZone=CrusherAll`;
`[General] IceCrackingWeight`, `IceBreakingWeight`, `[AudioVisual] IceGrowthRate`,
`IceSolidifyFrameTime`, `IceCrackSounds`; `[CombatDamage] DestroyableBridges`, `BridgeStrength`,
`[General] BridgeVoxelMax`, `BridgeExplosions`, `RepairBridgeSound`, warhead `Wood`,
`WallAbsoluteDestroyer`; `[Map SpecialFlags] DestroyableBridges`.

**Numbers**
- `[General] IceCrackingWeight=50.0` — weight above which objects **crack** ice.
- `[General] IceBreakingWeight=50.0` — weight above which objects **break through** ice.
- `[AudioVisual] IceGrowthRate=1.5`, `IceSolidifyFrameTime=1000` frames between crack and
  re-solidify; `IceCrackSounds=` (empty).
- `[CombatDamage] BridgeStrength=1500`; `[General] BridgeVoxelMax=3` debris per section.
- `[CombatDamage] DestroyableBridges=yes` — read from the **map `[SpecialFlags]`**, only
  effective in **campaign**; skirmish/multiplayer bridges are always destroyable.
- `Crush=1.8` cells AI crush radius (see 009).

**Edge cases**
- Crushing infantry needs `Crusher=yes` on the crusher; `Crushable=no` /
  `DeployedCrushable=no` (YR) protect the victim.
- Crushing **vehicles** requires `OmniCrusher=yes` (and `Crusher=yes`; it cannot be used
  alone). `OmniCrushResistant=yes` blocks it.
- `MovementZone=CrusherAll` (YR) lets a crusher also crush walls and all mobile objects.
- The target must be on a tile the crusher's MovementZone allows it to enter.
- Buildings with `Crushable=yes` only process correctly at `Foundation=1x1`; larger ones become
  passable instead of destroyed.
- Trees (`TerrainType`) with `Crushable=yes` crush but leave lingering sprites and don't tilt.
- Warheads with `Wood=yes` damage **wood bridges**; `WallAbsoluteDestroyer` destroys walls;
  destroyed bridge cells become water (impassable to land units) and are rebuilt via
  `RepairBridgeSound` behavior.
- **Ice:** the `[Ice]` LandType is **unassigned to any tile in stock RA2** (works in TS);
  mods/maps must assign it. `Fire=yes` warheads melt ice.

**Kind** — terrain / combat / special.

**Sources**
- https://modenc.renegadeprojects.com/Crusher (high)
- https://modenc.renegadeprojects.com/OmniCrusher (high)
- https://modenc.renegadeprojects.com/OmniCrushResistant (high)
- https://modenc.renegadeprojects.com/Crushable (high)
- https://modenc.renegadeprojects.com/DestroyableBridges (high)
- https://modenc.renegadeprojects.com/LandTypes (high)
- Vanilla YR `[General]`/`[AudioVisual]`/`[CombatDamage]` (high)

**Confidence** — high.

---

### RA2-CORE-016 — Water/Naval, Amphibious, Cloaking/Submerging, Chrono/Teleport

**What** — Water is a LandType plus a movement zone; naval logistics, amphibious units,
submarine cloaking, and chrono teleportation are separate layered systems.

**Data keys** — `Naval`, `WaterBound`, `SpeedType=Float`, `MovementZone=Water/WaterBeach/
Amphibious`, `NavalTargeting`, `Cloakable`, `CloakStop`, `CloakingSpeed`, `CloakingStages`,
`CloakSound`, `CloakDelay`, `Sensors`, `SensorArray`, `Teleporter`, `[General]` chrono keys,
anims `WarpIn/WarpOut/WarpAway/ChronoSparkle1/ChronoPlacement/ChronoBlast/ChronoBlastDest`.

**Numbers**
- `[General] ChronoDelay=60` frames after teleport (chrono sphere); `ChronoReinfDelay=180`.
- `ChronoDistanceFactor=48` (default 32) — divisor for warp-out delay:
  `frames_per_cell = 256 / ChronoDistanceFactor` (≈5.33 at 48; 8 at 32).
- `ChronoTrigger=yes` (delay varies with distance), `ChronoMinimumDelay=16`,
  `ChronoRangeMinimum=0` leptons.
- `[General] CloakDelay=.02` min — subs stay surfaced before submerging; `CloakingStages=9`.
- `[General] ShipSinkingWeight=3.0` — ships ≥ this weight sink rather than explode.
- `[General] TunnelSpeed=1` (subterranean).
- `[AI] AINavalYardAdjacency=20` cells from ConYard.

**Edge cases**
- `Naval=yes` on a factory restricts it to `Naval=yes` vehicles; on a vehicle marks it a naval
  target for `NavalTargeting`.
- `Naval=yes` buildings can only be placed/deployed on **Water**, overriding `WaterBound`.
- `WaterBound=yes` forces `SpeedType=Float` behavior; checks the tile's `Float` ratio, so
  beaches/roads can be made water-bound selectively.
- **NCO bug:** land and naval factories share the `Factory=VehicleType` class, so every unit
  must list an explicit factory `Prerequisite` or the "new construction options" EVA bug
  appears.
- Only `MovementZone=Amphibious` lets amphibious units dock with **both** land and naval
  `UnitRepair` buildings.
- Hover/Flying units do **not** support `Cloakable` in vanilla (can be granted via
  veteran/elite abilities); `CloakStop=yes` keeps a sub cloaked while firing/ambushing.
- Cloak is revealed by `Sensors=yes` units / `SensorArray=yes` buildings; explosions/retaliation
  may reveal a cloaked sub.
- Chrono: `Teleporter=yes` vehicles use Drive except to `Dock=` buildings; naval factory output
  chronos directly to rally; `WarpIn` was historically unused (Phobos #12 restored it).
- Parasites are ejected from a teleporting unit.
- `IsLocomotor=yes` warheads (Chrono Legionnaire, Magnetron) assign `Locomotor=` from the
  warhead and use `Damage=` as the max target `Size` they may affect.

**Kind** — terrain / movement / special abilities.

**Sources**
- https://modenc.renegadeprojects.com/Naval (high)
- https://modenc.renegadeprojects.com/WaterBound (high)
- https://modenc.renegadeprojects.com/Cloakable (high)
- https://modenc.renegadeprojects.com/Locomotor (high)
- Vanilla YR `[General]` (high)

**Confidence** — high.

---

### RA2-CORE-017 — `[General]` Full Key Set (with notable values)

**What** — The main global rules block. Values below are vanilla-YR defaults (modded-INI
cross-checked); distances in cells/leptons unless noted, times in minutes unless noted.

**Full key list (vanilla YR order):**
`UIName, Name, VeteranRatio, VeteranCombat, VeteranSpeed, VeteranSight, VeteranArmor,
VeteranROF, VeteranCap, InitialVeteran, RefundPercent, ReloadRate, RepairPercent, RepairRate,
RepairStep, URepairRate, IRepairRate, IRepairStep, TiberiumHeal, SelfHealInfantryFrames,
SelfHealInfantryAmount, SelfHealUnitFrames, SelfHealUnitAmount, BuildSpeed, BuildupTime,
GrowthRate, TiberiumGrows, TiberiumSpreads, SeparateAircraft, SurvivorRate,
AlliedSurvivorDivisor, SovietSurvivorDivisor, ThirdSurvivorDivisor, PlacementDelay,
WeedCapacity, CurleyShuffle, BaseBias, BaseDefenseDelay, CloseEnough, DamageDelay,
GameSpeedBias, Stray, RelaxedStray, CloakDelay, SuspendDelay, SuspendPriority, FlightLevel,
ParachuteMaxFallRate, NoParachuteMaxFallRate, GuardModeStray, MissileSpeedVar, MissileROTVar,
MissileSafetyAltitude, TeamDelays, AIHateDelays, AIAlternateProductionCreditCutoff,
NodAIBuildsWalls, AIBuildsWalls, MultiplayerAICM, AIVirtualPurifiers, AISlaveMinerNumber,
HarvestersPerRefinery, AIExtraRefineries, HealScanRadius, FillEarliestTeamProbability,
MinimumAIDefensiveTeams, MaximumAIDefensiveTeams, TotalAITeamCap, UseMinDefenseRule,
DissolveUnfilledTeamDelay, LargeVisceroid, SmallVisceroid, AIIonCannon*Value (ConYard,
WarFactory, Power, TechCenter, Engineer, Thief, Harvester, MCV, APC, BaseDefense),
LightningDeferment, LightningDamage, LightningStormDuration, LightningWarhead,
LightningHitDelay, LightningScatterDelay, LightningCellSpread, LightningSeparation, IonStorms,
ForceShieldRadius, ForceShieldDuration, ForceShieldBlackoutDuration,
ForceShieldPlayFadeSoundTime, MutateExplosion, PrismType, PrismSupportModifier,
PrismSupportMax, PrismSupportDelay, PrismSupportDuration, PrismSupportHeight,
V3Rocket* (PauseFrames, TiltFrames, PitchInitial, PitchFinal, TurnRate, RaiseRate,
Acceleration, Altitude, Damage, EliteDamage, BodyLength, LazyCurve, Type),
DMisl* (same shape), CMisl* (same shape), ParadropRadius, FogOfWar, Visceroids, Meteorites,
CrewEscape, CameraRange, FineDiffControl, Pilot, AlliedCrew, SovietCrew, ThirdCrew,
Technician, Engineer, PParatrooper, ChronoDelay, ChronoReinfDelay, ChronoDistanceFactor,
ChronoTrigger, ChronoMinimumDelay, ChronoRangeMinimum, AmerParaDropInf/Num,
AllyParaDropInf/Num, SovParaDropInf/Num, YuriParaDropInf/Num, AnimToInfantry, SecretInfantry,
SecretUnits, SecretBuildings, AlliedDisguise, SovietDisguise, ThirdDisguise, SpyPowerBlackout,
SpyMoneyStealPercent, AttackCursorOnDisguise, DefaultMirageDisguises, InfantryBlinkDisguiseTime,
MaximumCheerRate, AISafeDistance, AIMinorSuperReadyPercent, HarvesterTooFarDistance,
ChronoHarvTooFarDistance, AlliedBaseDefenseCounts, SovietBaseDefenseCounts,
ThirdBaseDefenseCounts, AIPickWallDefensePercent, AIRestrictReplaceTime, ThreatPerOccupant,
ApproachTargetResetMultiplier, CampaignMoneyDeltaEasy, CampaignMoneyDeltaHard,
GuardAreaTargetingDelay, NormalTargetingDelay, AINavalYardAdjacency,
DisabledDisguiseDetectionPercent, AIAutoDeployFrameDelay, MaximumBuildingPlacementFailures,
TiberiumShortScan, TiberiumLongScan, SlaveMinerShortScan, SlaveMinerSlaveScan,
SlaveMinerLongScan, SlaveMinerScanCorrection, SlaveMinerKickFrameDelay,
AISuperDefenseProbability, AISuperDefenseFrames, AISuperDefenseDistance, AICaptureNormal,
AICaptureWounded, AICaptureLowPower, AICaptureLowMoney, AICaptureLowMoneyMark,
AICaptureWoundedMark, PurifierBonus, DropPodWeapon, DropPodHeight, DropPodSpeed, DropPodAngle,
HoverHeight, HoverDampen, HoverBob, HoverBoost, HoverAcceleration, HoverBrake,
BalloonHoverHeight, BalloonHoverDampen, BalloonHoverBob, BalloonHoverBoost,
BalloonHoverAcceleration, BalloonHoverBrake, TunnelSpeed, MultipleFactory,
MinLowPowerProductionSpeed, MaxLowPowerProductionSpeed, LowPowerPenaltyModifier, GDIGateOne,
GDIGateTwo, WallTower, Shipyard, NodGateOne, NodGateTwo, NodRegularPower, NodAdvancedPower,
GDIPowerPlant, ThirdPowerPlant, RepairBay, BaseUnit, HarvesterUnit, PadAircraft, TreeStrength,
WindDirection, TrackedUphill, TrackedDownhill, WheeledUphill, WheeledDownhill,
LeptonsPerSightIncrease, LeptonsPerFireIncrease, AttackingAircraftSightRange, BlendedFog,
CliffBackImpassability, IceCrackingWeight, IceBreakingWeight, ShipSinkingWeight,
CloakingStages, TiberiumTransmogrify, TreeFlammability, CraterLevel, BridgeVoxelMax,
WallBuildSpeedCoefficient, AllowShroudedSubteranneanMoves, AircraftFogReveal,
MaximumQueuedObjects, MaxWaypointPathLength, ChargeToDrainRatio,
DamageToFirestormDamageCoefficient, VeinholeGrowthRate, VeinholeShrinkRate, MaxVeinholeGrowth,
VeinDamage, VeinholeTypeClass, AITriggerSuccessWeightDelta, AITriggerFailureWeightDelta,
AITriggerTrackRecordCoefficient, SpotlightSpeed, SpotlightMovementRadius,
SpotlightLocationRadius, SpotlightAcceleration, SpotlightAngle, RadarEventSuppressionDistances,
RadarEventVisibilityDurations, RadarEventDurations, FlashFrameTime, RadarCombatFlashTime,
RadarEventMinRadius, RadarEventSpeed, RadarEventRotationSpeed, RadarEventColorSpeed,
RevealTriggerRadius, ExplosiveVoxelDebris, TireVoxelDebris, ScrapVoxelDebris,
OKBuildingSmokeSystem, DamagedBuildingSmokeSystem, DamagedUnitSmokeSystem, DebrisSmokeSystem,
PrerequisitePower, PrerequisiteFactory, PrerequisiteBarracks, PrerequisiteRadar,
PrerequisiteTech, PrerequisiteProc, PrerequisiteProcAlternate, HunterSeekerDetonateProximity,
HunterSeekerDescendProximity, HunterSeekerAscentSpeed, HunterSeekerDescentSpeed,
HunterSeekerEmergeSpeed, MyEffectivenessCoefficientDefault, TargetEffectivenessCoefficientDefault,
TargetSpecialThreatCoefficientDefault, TargetStrengthCoefficientDefault,
TargetDistanceCoefficientDefault, DumbMyEffectivenessCoefficient,
DumbTargetEffectivenessCoefficient, DumbTargetSpecialThreatCoefficient,
DumbTargetStrengthCoefficient, DumbTargetDistanceCoefficient, EnemyHouseThreatBonus,
DamageFireTypes, OreTwinkle, BarrelExplode, BarrelDebris, BarrelParticle, NukeTakeOff, Wake,
DropPod, DeadBodies, MetallicDebris, BridgeExplosions, IonBlast, IonBeam, WeatherConClouds,
WeatherConBolts, WeatherConBoltExplosion, DominatorWarhead, DominatorDamage,
DominatorCaptureRange, DominatorFirstAnim, DominatorSecondAnim, DominatorFireAtPercentage,
ChronoPlacement, ChronoBeam, ChronoBlast, ChronoBlastDest, WarpIn, WarpOut, WarpAway,
IronCurtainInvokeAnim, ForceShieldInvokeAnim, WeaponNullifyAnim, ChronoSparkle1,
InfantryExplode, FlamingInfantry, InfantryHeadPop, InfantryNuked, InfantryVirus, InfantryBrute,
InfantryMutate, Behind, MoveFlash, Parachute, BombParachute, DropZoneAnim, EMPulseSparkles`.

**Notable values:** `BuildSpeed=.7` (minutes to build 1000cr), `GrowthRate=5` min,
`MultipleFactory=0.8` (cumulative discount), `GameSpeedBias=1.6`, `RepairPercent=15%`,
`RefundPercent=50%`, `CrewEscape=50%`, `SpyMoneyStealPercent=.5`, `PurifierBonus=.25`,
`TiberiumLongScan=48`, `MaximumQueuedObjects=29`, `MaxWaypointPathLength=15`.

**Kind** — global rules.

**Sources**
- Vanilla YR `rulesmd.ini` `[General]` (high)
- Vanilla RA2 `rules.ini` `[General]` (high)
- ModEnc category: `Category:General_Flags` (high)

**Confidence** — high (keys/defaults from the shipped reference INI).

---

### RA2-CORE-018 — `[CombatDamage]` Full Key Set

**Full key list:** `AmmoCrateDamage, IonCannonDamage, HarvesterImmune, DestroyableBridges,
TiberiumExplosive, Scorches, Scorches1..4, TiberiumExplosionDamage, TiberiumStrength, Craters,
AtomDamage, BallisticScatter, BridgeStrength, C4Delay, C4Warhead, V3Warhead, DMislWarhead,
V3EliteWarhead, DMislEliteWarhead, CMislWarhead, CMislEliteWarhead, CrushWarhead, IvanWarhead,
IvanDamage, IvanTimedDelay, CanDetonateTimeBomb, CanDetonateDeathBomb, IvanIconFlickerRate,
OccupyDamageMultiplier, OccupyROFMultiplier, OccupyWeaponRange, BunkerDamageMultiplier,
BunkerROFMultiplier, BunkerWeaponRangeBonus, OverloadCount, OverloadDamage, OverloadFrames,
ControlledAnimationType, PermaControlledAnimationType, MindControlAttackLineFrames,
DrainMoneyFrameDelay, DrainMoneyAmount, DrainAnimationType, FallingDamageMultiplier,
CurrentStrengthDamage, OpenToppedRangeBonus, OpenToppedDamageMultiplier, OpenToppedWarpDistance,
DeathWeapon, IronCurtainDuration, FirestormWarhead, IonCannonWarhead, VeinholeWarhead,
PsychicRevealRadius, DefaultFirestormExplosionSystem, DefaultLargeGreySmokeSystem,
DefaultSmallGreySmokeSystem, DefaultSparkSystem, DefaultLargeRedSmokeSystem,
DefaultSmallRedSmokeSystem, DefaultDebrisSmokeSystem, DefaultFireStreamSystem,
DefaultTestParticleSystem, DefaultRepairParticleSystem, Crush, ExpSpread, FireSupress,
FlameDamage, FlameDamage2, HomingScatter, MaxDamage, MinDamage, PlayerAutoCrush, PlayerReturnFire,
PlayerScatter, SplashList, TreeTargeting, TurboBoost, Incoming, CollapseChance, BerzerkAllowed`.

**Notable values**
- `AmmoCrateDamage=200`, `IonCannonDamage=751`, `AtomDamage=1000`.
- `HarvesterImmune=no`, `TiberiumExplosive=no`, `DestroyableBridges=yes`.
- `BridgeStrength=1500`, `C4Delay=.03`, `C4Warhead=Super`, `CrushWarhead=Crush`.
- `IvanDamage=450`, `IvanTimedDelay=450`, `IronCurtainDuration=750` frames.
- `OccupyDamageMultiplier=1.2`, `OccupyROFMultiplier=1.2`, `OccupyWeaponRange=5`.
- `BunkerDamageMultiplier=1.3`, `BunkerROFMultiplier=1.3`, `BunkerWeaponRangeBonus=2`.
- `OverloadCount=3,6,10,50`, `OverloadDamage=0,50,100,500`, `OverloadFrames=30,60,60,60`.
- `OpenToppedRangeBonus=2`, `OpenToppedDamageMultiplier=1.2`, `OpenToppedWarpDistance=7`.
- `MaxDamage=10000`, `HomingScatter=2.0`, `BallisticScatter=1.0`.
- `PlayerAutoCrush=no`, `PlayerReturnFire=no`, `PlayerScatter=no` (player units don't
  auto-scatter/return-fire/crush; AI does via IQ).

See also `[Radiation]` (`RadDurationMultiple=1`, `RadApplicationDelay=16`, `RadLevelMax=500`,
`RadLevelDelay=90`, `RadLevelFactor=0.2`, `RadSiteWarhead=RadSite`), `[ElevationModel]`, and
`[WallModel]` (`WallPenetratorThreshold=50%`).

**Kind** — global combat rules.

**Sources** — Vanilla YR `rulesmd.ini`/RA2 `rules.ini` `[CombatDamage]`; ModEnc
`Category:CombatDamage_Flags`. **Confidence** — high.

---

### RA2-CORE-019 — `[AudioVisual]` Full Key Set

**Full key list:** `DetailMinFrameRateNormal, DetailMinFrameRateMovie, DetailBufferZoneWidth,
LineTrailColorOverride, ChronoBeamColor, MagnaBeamColor, OreTwinkleChance, CreateInfantrySound,
CreateUnitSound, CreateAircraftSound, SpySatActivationSound, SpySatDeactivationSound,
UpgradeVeteranSound, UpgradeEliteSound, BaseUnderAttackSound, BuildingGarrisonedSound,
BuildingRepairedSound, CheerSound, PlaceBeaconSound, DirectRockingCoefficient,
FallBackCoefficient, LaserTargetColor, IronCurtainColor, BerserkColor, ForceShieldColor,
StartPlanningModeSound, EndPlanningModeSound, AddPlanningModeCommandSound, ExecutePlanSound,
CratePromoteSound, CrateMoneySound, CrateRevealSound, CrateFireSound, CrateArmourSound,
CrateSpeedSound, CrateUnitSound, GUIMainButtonSound, GUIBuildSound, GUITabSound, GUIOpenSound,
GUICloseSound, GUIMoveOutSound, GUIMoveInSound, GUIComboOpenSound, GUIComboCloseSound,
GUICheckboxSound, ScoreAnimSound, SinkingSound, ImpactWaterSound, ImpactLandSound,
BombTickingSound, ChronoInSound, ChronoOutSound, BombAttachSound, YuriMindControlSound,
PoseDir, DeployDir, WaypointAnimationSpeed, DigSound, GateUp, GateDown, ShroudGrow,
ScrollMultiplier, ShakeScreen, CloakSound, SellSound, GameClosed, IncomingMessage,
MessageCharTyped, SystemError, OptionsChanged, GameForming, PlayerJoined, Construction,
CreditTicks, BuildingDieSound, BuildingSlam, RadarOn, RadarOff, MovieOn, MovieOff, ScoldSound,
TeslaCharge, TeslaZap, BuildingDamageSound, ChuteSound, GenericClick, GenericBeep, BuildingDrop,
StopSound, GuardSound, ScatterSound, DeploySound, StormSound, LightningSounds,
ShellButtonSlideSound, VoiceIFVRepair, SlavesFreeSound, SlaveMinerDeploySound,
SlaveMinerUndeploySound, BunkerWallsUpSound, BunkerWallsDownSound, RepairBridgeSound,
PsychicDominatorActivateSound, GeneticMutatorActivateSound, PsychicRevealActivateSound,
MasterMindOverloadDeathSound, MindClearedSound, EnterGrinderSound, LeaveGrinderSound,
EnterBioReactorSound, LeaveBioReactorSound, ActivateSound, DeactivateSound, AirstrikeAbortSound,
AirstrikeAttackVoice, SpyPlaneCamera, SpyPlaneCameraFrames, DiskLaserChargeUp,
LetsDoTheTimeWarpOutAgain, LetsDoTheTimeWarpInAgain, Smoke, EliteFlashTimer, AllyReveal,
ConditionRed, ConditionYellow, DropZoneRadius, EnemyHealth, Gravity, IdleActionFrequency,
MessageDelay, MovieTime, NamedCivilians, SavourDelay, ShroudRate, FogRate, IceGrowthRate,
IceSolidifyFrameTime, IceCrackSounds, AmbientChangeRate, AmbientChangeStep, SpeakDelay,
TimerWarning, ExtraUnitLight, ExtraInfantryLight, ExtraAircraftLight, LocalRadarColor`.

**Notable values:** `Gravity=6`, `ConditionRed=25%`, `ConditionYellow=50%`, `ShroudGrow=no`,
`ScrollMultiplier=.07`, `ShakeScreen=400`, `EliteFlashTimer=150`, `EnemyHealth=yes`,
`AllyReveal=yes`, `IceGrowthRate=1.5`, `IceSolidifyFrameTime=1000`, `Extra*Light=.2`,
`CloakSound=NavalUnitEmerge`, `SinkingSound=GenLargeWaterDie`.

**Kind** — global audio/visual.

**Sources** — Vanilla YR `rulesmd.ini`/RA2 `rules.ini` `[AudioVisual]`; ModEnc
`Category:AudioVisual_Flags`. **Confidence** — high.

---

### RA2-CORE-020 — `[Maximums]`, `[CrateRules]`, `[SpecialWeapons]`

**`[Maximums]`** — In RA2/YR this section contains essentially only **`Players=8`** (IPX layer
limit). Object limits are dynamic (`[InfantryTypes]`, etc. registries) rather than fixed
maximums. In **Red Alert (RA1)** the section also held `Warhead=`, `Projectile=`, etc. maximum
counts (RA1 only) — those do **not** apply to RA2/YR. *(Both vanilla RA2 `rules.ini` and the
modded YR `rulesmd.ini` show only `Players=8`, confirming this.)*

**`[CrateRules]` full keys / values:**
`CrateMaximum=255`, `CrateMinimum=1`, `CrateRadius=3.0`, `CrateRegen=3`, `SilverCrate=HealBase`,
`SoloCrateMoney=5000`, `UnitCrateType=none`, `WoodCrate=Money`, `WaterCrate=Money`,
`HealCrateSound=HealCrate`, `WoodCrateImg=CRATE`, `CrateImg=CRATE`, `WaterCrateImg=WCRATE`,
`FreeMCV=yes`.

**`[Powerups]` (random crate) shares / anim / water-ok / data:**
`Armor=10,ARMOR,yes,1.5`, `Firepower=10,FIREPOWR,yes,2.0`, `HealBase=10,HEALALL,yes`,
`Money=20,MONEY,yes,2000`, `Reveal=10,REVEAL,yes`, `Speed=10,SPEED,yes,1.2`,
`Veteran=20,VETERAN,yes,1`, `Unit=20,<none>,no`, `Invulnerability=0,ARMOR,yes,1.0`,
`IonStorm=0,<none>,yes`, `Gas=0,<none>,yes,100`, `Tiberium=0,<none>,no`, `Pod=0,<none>,no`,
`Cloak=0,CLOAK,yes`, `Darkness=0,SHROUDX,yes`, `Explosion=0,<none>,yes,500`,
`ICBM=0,CHEMISLE,yes`. Crates can never exceed 255; radius 3 cells; average 3 min regen.

**`[SpecialWeapons]` full keys / values:**
`NukeWarhead=Nuke`, `NukeDown=NukeDown`, `NukeProjectile=NukeUp`, `EMPulseWarhead=EMPuls`,
`EMPulseProjectile=PulsPr`, `MutateWarhead=Mutate`, `MutateExplosionWarhead=MutateExplosion`.
(Vanilla RA2 additionally has `HSBuilding=GAPLUG,NATMPL` — Hunter Seeker spawn buildings.)

**Kind** — object caps / economy-via-crates / superweapon wiring.

**Sources**
- https://modenc.renegadeprojects.com/Warhead (Maximums is RA1-only for Warhead) (high)
- https://modenc.renegadeprojects.com/Projectile (same) (high)
- Vanilla RA2 `rules.ini` / YR `rulesmd.ini` `[Maximums]`, `[CrateRules]`, `[SpecialWeapons]`
  (high)
- https://forums.revora.net/topic/31001-powerups-ra2yr (med)

**Confidence** — high.

---

### RA2-CORE-021 — Simulation Timing, Tick Rate, Game Speed

**What** — The engine is frame/tick-driven; timers are expressed in frames or minutes. Game
speed caps the logic frame rate.

**Data keys** — `[MultiplayerDialogSettings] GameSpeed`; `[General] GameSpeedBias`; all
`*Frames`, `*Delay`, `ROF` values.

**Numbers**
- Game speed settings are **0–6**; **0 = fastest, 6 = slowest** in the SP menu convention
  (`GameSpeed` is stored in `SUN.ini`).
- **Singleplayer caps (fps):** 6 = unlimited, 5 = 60, 4 = 30, 3 = 20, 2 = 15, 1 = 12, 0 = 10.
- **Multiplayer caps (fps):** 6 = 60, 5 = 45, 4 = 30, 3 = 20, 2 = 15, 1 = 12, 0 = 10.
- At a constant **15 fps**, **1 game second = 1 real second**. Vanilla `[MultiplayerDialogSettings]
  GameSpeed=1` (12 fps).
- Times given in "minutes" in rules are converted to frames (e.g. `[General] DamageDelay=1`
  minute; comments reference "900 = 1 minute at 15 fps").
- `[General] GameSpeedBias=1.6` — global multiplier on object movement speed (was 1.2 in RA2).
- `ROF` is weapon reload in frames; `Burst`/`BurstDelayX` control shot groups.
- `GameSpeed` does not speed up a slow system; it only lowers/raises the cap.

**Edge cases**
- Comments in the shipped `rulesmd.ini` contain both 15 fps and 30 Hz references, so some
  frame→time constants are internally inconsistent; treat per-mechanic comments as approximate.
- AI difficulty and game speed are independent; `[MultiplayerDialogSettings] AIDifficulty`
  default 0 (easy).
- `VeteranSight`/`Radar`/superweapon charge timers all count logic frames, not real time.

**Kind** — timing / simulation loop.

**Sources**
- https://modenc.renegadeprojects.com/Game_Speed (high)
- Vanilla YR `[MultiplayerDialogSettings]`, `[General]` (high)
- PPM/ModEnc frame comments (med)

**Confidence** — high (caps, 15 fps baseline); med (per-key frame constants that conflict).

---

### RA2-CORE-022 — Other Core Systems (supporting mechanics)

**What** — Remaining first-class systems that a reimplementation must also cover.

**Numbers / behavior**
- **Prerequisites / tech tree:** `Prerequisite=`, `PrerequisiteOverride=`, `PrerequisiteProc=`,
  and the `Prerequisite*` category lists in `[General]` (Power, Factory, Barracks, Radar, Tech,
  Proc). `TechLevel=` gates availability; `BuildLimit=`, `RequiredHouses=`,
  `ForbiddenHouses=`, `RequiresStolen*Tech=`.
- **Superweapons:** charge in `[General]`/`[Recharge]` style time; wired via `[SpecialWeapons]`
  and `[SuperWeaponTypes]`; e.g. Iron Curtain `IronCurtainDuration=750` frames, Force Shield
  `ForceShieldDuration=500`/`ForceShieldBlackoutDuration=1000`; Nuke/Weather Control/
  Chronosphere/Genetic Mutator/Psychic Dominator each have `[General]` control blocks
  (see 017). `AIMinorSuperReadyPercent=.7`.
- **Mind control:** `MindControl=yes` warhead, `MindControl.Permanent`, `ControllerBuilding`;
  Mastermind overload uses `OverloadCount/Damage/Frames`; `MindControlAttackLineFrames=20`.
- **Garrisoning / urban combat:** `OccupyDamageMultiplier=1.2`, `OccupyROFMultiplier=1.2`,
  `OccupyWeaponRange=5`; `Bunker=yes` with `PenetratesBunker`; Yuri tank bunker.
- **Harvesting / economy:** refinery dock, `HarvesterUnit=HARV,CMIN`, `WeedCapacity=56`,
  `PurifierBonus=.25`, `TiberiumShortScan=6`, `TiberiumLongScan=48`, `GrowthRate=5`,
  `TiberiumGrows=yes`, `TiberiumSpreads=yes`.
- **Repair / sell:** `RepairPercent=15%`, `RepairRate=.016` (units), `IRepairRate=.001`
  (infantry), `RepairStep=8`, `IRepairStep=20`, `RefundPercent=50%`, `[AI] CreditReserve=100`.
- **Radar / shroud / fog:** per-player shroud, `[General] FogOfWar=no`, `ShroudGrow=no`,
  `ShroudRate=4`, `[AudioVisual] BlendedFog=yes`, `AircraftFogReveal=6`, `CameraRange=9`,
  `RevealTriggerRadius=9`; SpySat/`SpyPowerBlackout=1000` frames.
- **Cloaking / disguises:** `Cloakable`, `CloakingStages=9`, spies
  (`SpyMoneyStealPercent=.5`, `AttackCursorOnDisguise=yes`, `DefaultMirageDisguises`,
  `InfantryBlinkDisguiseTime=20`, `DisabledDisguiseDetectionPercent=15,5,2`).
- **Airstrikes / Boris / Hunter Seeker:** `Airstrike=yes` warhead, `AirstrikeAbortSound`,
  Hunter Seeker (`HunterSeeker*` values).
- **Crates:** see 020.
- **Paradrops:** `AmerParaDropInf/Num` etc.; `ParadropRadius=1024` leptons; `[AudioVisual]
  Parachute`, `ChuteSound`.
- **Meteorites / Visceroids / Ion storms:** `Meteorites=no`, `Visceroids=no`, `IonStorms=no`,
  `CraterLevel=1`, `LargeVisceroid=VISC_LRG`, `SmallVisceroid=VISC_SML`, `Lightning*` values.
- **Weather Control:** `WeatherConClouds/Bolts/BoltExplosion`, `StormSound`,
  `LightningSounds`.
- **Anim-to-infantry / secret lab:** `AnimToInfantry=BRUTE`, `SecretInfantry/Units/Buildings`.

**Kind** — misc core systems.

**Sources** — Vanilla YR `rulesmd.ini`; ModEnc flag pages for each key. **Confidence** — high
(existence/keys); med (some exact interactions).

---

## Coverage Checklist

| # | Scope item | Block(s) | Status |
|---|---|---|---|
| 1 | Isometric grid, lepton ratio, tile size | 001 | covered |
| 1 | Height levels, LOS/range from altitude, `LeptonsPerSightIncrease/FireIncrease` | 002 | covered |
| 2 | Full land types + per-locomotor/speed passability & speed tables | 003 | covered (full table) |
| 2 | `SpeedType` list | 004 | covered |
| 2 | `MovementZone` list | 005 | covered |
| 3 | Full armor class list (11) | 007 | covered |
| 3 | Full warhead list + Verses semantics + exact damage formula + 0%/1% gating | 008, 009 | covered |
| 4 | Full projectile type list + every parameter (gravity, scatter, ROT, homing, arming, AA/AG, invisibility, cliffs) | 010 | covered |
| 5 | ROT/turret traverse, `[JumpjetControls]`, helicopter behavior | 012 | covered |
| 6 | Power supply/demand, `Powered`/`Drainable`, low-power penalties, `DamageDelay` | 013 | covered |
| 7 | Veterancy tiers, ratio, all `VeteranXxx`, `VeteranAbilities`/`EliteAbilities` | 014 | covered |
| 8 | Crushing (`Crusher`/`CrusherAll`/`OmniCrusher`), ice, destroyable bridges | 015 | covered |
| 9 | Water/naval zones, amphibious, teleport/chrono parameters | 016 | covered |
| 10 | `[General]`, `[CombatDamage]`, `[AudioVisual]`, `[Maximums]`, `[CrateRules]`, `[SpecialWeapons]` full key sets | 017–020 | covered |
| 11 | Simulation timing/tick units, game speed bias | 021 | covered |
| 12 | Every other core mechanic | 022 | covered |

Locomotor full list: 006. Targeting hierarchy & Land/NavalTargeting: 011.

---

## Open Questions / Top Uncertainties

1. **Height-level quantization** — exact leptons per terrain height level and the number of
   levels (0..N) is not documented in the reviewed sources. `LeptonsPerSightIncrease=2000`
   only bounds the *total* range. Needs source/reverse-engineering.
2. **`ProneDamage` order vs `Verses`** — ModEnc's flag page says *before*; the YR Combat
   System page says *after*. No authoritative resolution found.
3. **Exact intermediate damage rounding/order** — the chain (Verses → CellSpread falloff →
   ProneDamage → veterancy → country/Prism/OpenTopped modifiers → immunity) is agreed, but the
   precise order and integer-rounding points are only partially documented.
4. **Frame↔time constants** — shipped comments mix 15 fps and 30 Hz; e.g. `RadDurationMultiple`
   notes contradict each other. Per-key frame values should be treated as approximate/legacy.
5. **Isometric on-screen pixel footprint** (e.g. 48×24 px) — commonly cited but not
   authoritatively confirmed in the sources fetched; simulation uses leptons regardless.
6. **Modded-INI contamination** — the downloadable `rulesmd.ini` used for cross-checking is a
   community modification (extra `Hamdi*` warheads, pruned `[Maximums]`, tuned `[Rough]`). Its
   `[General]`/`[CombatDamage]` values match vanilla comments closely, but per-unit numbers
   need a clean vanilla `rulesmd.ini` to lock down.
7. **RA2 vs YR deltas** — some values (`GameSpeedBias` 1.2→1.6, `ChronoDistanceFactor`
   32→48, `VeteranRatio` TS/FS/RA2 differ) are noted, but a full RA2-vs-YR diff was not
   exhaustively enumerated.
8. **`DestroyableBridges` source** — documented as read from map `[SpecialFlags]` despite
   living in `[CombatDamage]`; campaign-only, skirmish always destroyable. Edge behavior at
   map-vs-rules precedence is only partly documented.
