# Command & Conquer: Red Alert 2 (2000) — Core Feature & Architecture Inventory

Raw research inventory for re-implementing RA2 data-driven in a unified RTS engine
shared with the Tiberian Sun remake.

**Scope:** RA2 base game (2000), with Yuri's Revenge (2001) deltas marked `[YR]`.
**Sources:** actual `rulesmd.ini` (YR, via hamdirizal/red-alert-2-rules), ModEnc
(`Armor_types`, `Projectile`, `Verses`, `Rules.ini`), C&C Fandom wiki. Items not
verified against the INI/docs are marked **[uncertain]**. No unit-stat dumping —
categories + notable examples only.

Conventions in this doc: RA2 internal section names appear as `[E1]`, tags as
`Tag=Value`. Ore and gems replace Tiberium; "Tiberium" tags survive internally
for legacy reasons.

---

## 1. Core Engine & Simulation

- **Isometric tile geometry** — RA2 uses the same Westwood isometric lineage as TS: 2:1 diamond cells on a **lepton** grid (256 leptons per cell edge). Not a separate geometry engine from TS; the difference is content (tilesets, art) not cell math. `[uncertain]` on exact RA2 tile pixel size (TS 48×24 vs RA2 ~60×30).
- **Cell height** — discrete height levels stored per cell; cliffs are impassable except via ramps; higher ground improves LOS/range (`LeptonsPerSightIncrease=2000`, `LeptonsPerFireIncrease=2000`). Height is a simulation value, not just visuals.
- **Terrain / tilesets (theaters)** — Temperate, Snow, Urban/New Urban, plus campaign-only theaters. Tiles carry terrain overlays (ore, gems, walls, bridges, ice, water). Maps are `.map` / `.mpr` (multiplayer) / `.yrm` `[YR]`.
- **Terrain objects** — trees/rocks as `TerrainTypes` (TREE01–04, BOXES, TIBTRE etc.); destructible, give cover, forest slows infantry; some flammable (`TreeFlammability=0.0`).
- **Water & shore** — water is a tile property (`Water=yes`), units need `SpeedType=Float/Ship` or `MovementZone=Water`; beaches/shore art masks passability. Naval-only zones enforced by the locomotor/movement zone, not the tile alone.
- **Bridges** — low (rail/train) and high (road) bridge overlays; `DestroyableBridges=yes`, `BridgeStrength=1500`, `BridgeVoxelMax=3` debris per section; repair via bridge repair hut (`[CABHUTE?]`/`RepairBridgeSound`). Bridge sections are targetable sim objects.
- **Ice** — cracking/solidifying overlays: `IceCrackingWeight=50`, `IceBreakingWeight=50`, `IceGrowthRate`, `IceSolidifyFrameTime`. Heavy units crack ice and can sink/drown.
- **Crushing** — tracked/omni units crush infantry on contact; `CrushWarhead=Crush`, `Crusher`/`CrusherAll` movement zones, `OmniCrusher` (Battle Fortress) also crushes vehicles. Warhead multipliers still apply.
- **Damage model** — `damage = Weapon.Damage × Warhead.Verses[target.Armor]`, clamped; `0%` verses = invalid target (no force-fire/retaliate/acquire), `1%` = no passive acquire (documented differently in INI comments but engine behaves this way per ModEnc).
- **Armor classes (RA2 = 11, TS = 5)** — `none, flak, plate, light, medium, heavy, wood, steel, concrete, special_1, special_2`. Infantry: none/flak/plate; vehicles: light/medium/heavy; buildings: wood/steel/concrete; `special_1` = Terror Drone; `special_2` = V3/Dreadnought/Boomer missiles (so chain explosions don't cascade them).
- **Projectile types** — from `[Projectiles]`: `Bullet` (instant, hitscan), `Cannon`/ballistic (uses `Gravity=6`, `BallisticScatter`), `Missile` (homing w/ `ROT`, `MissileSpeedVar`, `MissileROTVar`, `MissileSafetyAltitude`), `Torpedo` (naval, ASW), `Laser`/prism/rail (instant beam), `Fire`, `Tesla` (wire arc), `Radiation`, `Disk` (YR), `DropPod`. Projectiles have `Arming`, `Range`, `Speed`, `Image`, `Shadow`, `AA`, `AG`, `AN`.
- **ROT (rate of turn)** — degrees/frame for turrets and guided projectiles (`ROT=`, `TurretROT`, `[JumpjetControls] TurnRate=4`). Low ROT creates the classic slow-tracking turret feel.
- **Power** — per-house supply/demand; `Power=`, `Powered=`, `Drainable`, `PoweredSpecial`. Low power scales production down (`MaxLowPowerProductionSpeed=.8`, `MinLowPowerProductionSpeed=.5`, `LowPowerPenaltyModifier`) and disables defenses/radar; `DamageDelay` applies trivial structure damage over time.
- **Veterancy / rank** — 3 tiers (Rookie → Veteran → Elite; `VeteranCap=2`). `VeteranRatio=3.0` (kill value ratio to rank), `VeteranCombat`, `VeteranArmor`, `VeteranSpeed`, `VeteranROF`; per-unit `VeteranAbilities`/`EliteAbilities` (`STRONGER, FIREPOWER, ROF, SELF_HEAL, FASTER, SCATTER, SIGHT, ...`).
- **Resources** — **Ore** and **Gems** (no Tiberium). Ore yields baseline credits; gems yield more per bail and are rarer. Gem/ore density grows and spreads; `TiberiumGrows=yes`, `TiberiumSpreads=yes`, `GrowthRate=5` (minutes).
- **Simulation timing** — frame-based counters throughout (frames dominant: `ChronoDelay=60`, `IvanTimedDelay=450`), some minutes (`BuildSpeed=.7`, `RepairRate`). A unified engine must abstract tick units.
- **Crew/survivors** — `CrewEscape=50%`; destroyed vehicles/buildings can spawn crew (`AlliedCrew=E1`, `SovietCrew=E2`, `ThirdCrew=INIT`), engineers from conyards.
- **Game speed** — `GameSpeedBias=1.6` multiplier on object movement; `CurleyShuffle` for helicopters.

---

## 2. Economy

- **Ore & gem mining** — harvesters drive to ore/gem cells, fill up (`Storage`/bails), return to a refinery, unload for credits.
- **Ore Miner (HARV)** — Allied/Soviet basic harvester; `HarvesterUnit=HARV,CMIN`, auto-targets nearest patch using `TiberiumShortScan=6` / `TiberiumLongScan=48` cell radii. Weaponless, self-heals in ore (`TiberiumHeal`).
- **War/Chrono Miner** — Soviet `[CMON]` war miner (armed) and `[CMIN]` chrono miner (teleports to patches); `ChronoHarvTooFarDistance=50` governs when they teleport.
- **Slave Miner `[SMIN]` (YR)** — deploys into a refinery-on-wheels that spawns slave miners (`SMON`); slaves freed when destroyed (`SlavesFreeSound`). `SlaveMinerShortScan/LongScan/ScanCorrection`, `AISlaveMinerNumber`.
- **Refinery `[GAREFN/NAYAREFN/YAREFN]`** — dock structure with a single tractor/dock; unload anim; `NumberOfDocks`; provides `PROC` prerequisite; `HarvestersPerRefinery`.
- **Ore Purifier `[GAOREP]` (YR)** — `OrePurifier=yes`; `PurifierBonus=.25` (+25% ore value). BuildLimit=1.
- **Silos** — **RA2 has no ore silos** (Tiberium silos from TS were removed; credit storage is effectively unlimited). **`[absent]`** — key TS→RA2 divergence.
- **Ore growth / spread** — patches densify and creep to adjacent cells over time; gem patches grow too. Map editor controls initial fields; `TiberiumGrowth` legacy naming.
- **Gem overload** — gems pay more per bail and are strategically contested; "overload" in practice = the max-density patch cap [uncertain on exact internal cap].
- **Oil derricks / civilian income** — `[CAOILD]` Tech Oil Derrick is neutral/capturable: `ProduceCashStartup=1000`, `ProduceCashAmount=20`, `ProduceCashDelay=100`; capture via engineer; `CaptureEvaEvent=EVA_OilRefineryCaptured`; `DeathWeapon=OilExplosion`.
- **Other cash producers** — `[NANRCT]` gives power, not cash; civilian "Tech Power Plant"; map scripted cash via triggers. `ProduceCashAmount/Delay` is the generic recurring-income tag.
- **Crates** — `[CrateRules]`: money, free unit (`UnitCrateType`), heal, reveal, firepower, armor, speed, promote; wood/silver/water variants (`WoodCrate=Money`, `SilverCrate=HealBase`). `CrateMaximum=255`, `CrateRadius=3`, `CrateRegen=3`; `FreeMCV=yes` gives a free MCV when a player is building-less but funded. Separate sounds per crate type.
- **Selling** — `RefundPercent=50%` credits back when selling buildings; sell can spawn survivors (`AlliedSurvivorDivisor=500`, `SovietSurvivorDivisor=250`).

---

## 3. Construction & Base

- **Construction Yard `[GACNST/NACNST/YACNST]`** — builds structures, defines the initial build radius, gives engineer survivor; `Armor=concrete`, very resistant to superweapons.
- **Build radius / adjacency** — you place a structure if any existing owned structure is within its `Adjacent` radius (2–3 cells typical); no power/wall adjacency wiring like TS. `PlacementDelay=.05`, `MaximumBuildingPlacementFailures=3` (AI retry guard).
- **Placement rules** — footprint must be clear of terrain objects, ore, units, and other structures; must be on valid land/water; `BaseNormal=no` marks addons that don't count as base nodes; walls/gates special.
- **Walls & gates** — `[GAWALL/NAWALL]` line walls (`WallBuildSpeedCoefficient=3.0`, slower than normal); gates via the `GDIGateOne/GDIGateTwo/NodGateOne/NodGateTwo` "hack section" (`GADUMY` placeholders) that open for friendly units; `WallTower`. Walls are crushable by `CrusherAll`.
- **Defenses** — `IsBaseDefense=yes` + `BuildCat=Combat`: Pillbox `[GAPILL]`, AA Gun, Prism Cannon `[ATESLA]`, Soviet Flak Cannon `[NAFLAK]`, Tesla Coil `[TESLA]`, French Grand Cannon `[GTGCAN]`, Yuri Gatling Cannon `[YAGGUN]`. Defenses have `AntiInfantryValue/AntiArmorValue/AntiAirValue` for AI.
- **Sell / repair** — sell refunds 50%; repair costs `RepairPercent=15%` of full cost over time (`RepairRate/RepairStep`), with separate unit/infantry rates (`URepairRate`, `IRepairRate/IRepairStep`). Service Depot `[GADEPT/NADEPT]` repairs vehicles and reloads ammo.
- **Building garrisoning** — infantry can occupy civilian/urban buildings ("Urban Combat"): `OccupyDamageMultiplier=1.2`, `OccupyROFMultiplier=1.2`, `OccupyWeaponRange=5`; occupied buildings gain `ThreatPerOccupant=10`. YR adds the **Tank Bunker** (`BunkerDamageMultiplier`, `BunkerWeaponRangeBonus=2`).
- **Civil building capture** — engineers capture hospitals, airports, oil derricks, tech buildings; each has an on-capture effect (heal infantry, spy plane, income, etc.). `NeedsEngineer=yes`, `Capturable=yes`.
- **Unsellable / insignificant** — `Unsellable=yes`, `Insignificant=yes` mark civilian/tech buildings that don't show on the build list and don't count for scoring.
- **Build-up animation** — `BuildupTime=.06` average; buildings animate from a buildup sequence before becoming active (`Construction=Dummy` sound).
- **Cloning Vats `[NACLON]` (YR)** — `Cloning=yes`, `YuriBarracks=yes`; duplicates trained infantry for free.

---

## 4. Production & Tech

- **Sidebar categories (`BuildCat`)** — RA2 has 4 internal build categories: `Power`, `Resource`, `Combat`, `Tech`; the UI splits by *type* into 6 tabs: **Structures, Defenses, Infantry, Vehicles, Aircraft, Ships** (defenses = `BuildCat=Combat` + `IsBaseDefense=yes`; superweapons/combat structures under Structures).
- **Production queues** — one queue per producing building category; each factory/war factory/barracks/shipyard/airfield runs its own queue; parallel production from multiple factories is supported.
- **Multiple-factory bonus** — `MultipleFactory=0.8` cumulative multiplier (1, .8, .64, .512 → faster with each additional factory of that type).
- **Prerequisites** — `Prerequisite=` references **category buckets** resolved through `[General]`: `PrerequisitePower`, `PrerequisiteFactory`, `PrerequisiteBarracks`, `PrerequisiteRadar`, `PrerequisiteTech`, `PrerequisiteProc`, `PrerequisiteProcAlternate`. Buildings also listed directly (e.g. `Prerequisite=GATECH,GACNST`).
- **Tech gating** — `TechLevel=` (negative = special/campaign), `BuildLimit=`, `RequiredHouses=`, `ForbiddenHouses=`, `PrerequisiteOverride=`, `StolenTech`, `Owner=`. `RequiredHouses` is the mechanism for country uniques (see below).
- **Country / faction-specific buildings** — `[GAAIRC]` American Airforce Command HQ (`RequiredHouses=Americans`, paradrop), `[GTGCAN]` French Grand Cannon, Korea `[BEAG]` via Alliance, etc.
- **Naval Yard `[GAYARD/NAYARD/YAYARD]`** — `Shipyard=GAYARD,NAYARD,YAYARD`; produces ships; `AINavalYardAdjacency=20` governs AI placement distance from conyard.
- **Airforce Command HQ / Helipad** — aircraft come from the Airforce Command HQ (`BuildCat=Tech`, radar + aircraft) or Helipad; `PadAircraft=ORCA,BEAG`; `SeparateAircraft=yes` (first aircraft purchased separately from the pad).
- **Unit exits / rally** — `ExitCoord`, `NumberOfDocks`, `DockingOffset`, dock offset/direction; produced units spawn facing the exit and auto-move to rally point.
- **Yuri production (YR)** — Yuri Barracks `[YABRCK]`, War Factory `[YAWEAP]`, Battle Lab `[YATECH]`, Grinder `[YAGRND]` (recycles units for cash), Bio Reactor `[YABRCK?]` (power from infantry).
- **Maximum queued objects** — `MaximumQueuedObjects=29`; `MaxWaypointPathLength=15`.

---

## 5. Units & Combat

- **Infantry** — basic rifle (GI `[E1]`, Conscript `[E2]`), anti-armor (Rocket/Flak Trooper), Tesla Trooper `[SHK]`, Engineer, Attack Dog `[ADOG]`, SEAL `[GHOST]`, Sniper `[SNIPE]`, Tanya `[TANY]`, Spy `[SPY]`, Crazy Ivan `[IVAN]`, Desolator `[DESO]`, Chrono Legionnaire `[CLEG]`, Boris `[BORIS]` `[YR]`, Yuri `[YURI]` `[YR]`, Brute `[BRUTE]`, Virus `[VIRUS]`, Guardian GI `[GGI]` `[YR]`, Rocketeer/Jumpjet `[JUMPJET]`.
- **Infantry deploy / fortify** — GI deploys into sandbag emplacement (Guardian GI in YR), Desolator deploys to create a radiation field, Tesla Trooper can supercharge Tesla Coils, Yuri Prime `[YURIPR]`. `DeployFire`, `IsSimpleDeployer`, `SimpleDeploy` (Siege Chopper faces `DeployDir` first).
- **Vehicles** — MCV (`AMCV`/`SMCV`/`PCV`), harvesters, Grizzly `[MTNK]`, Rhino `[HTNK]`, IFV `[FV]`, Prism Tank (refraction), Mirage Tank, Apocalypse `[APOC]`, Terror Drone `[DRON]`, V3 Launcher `[V3]`, Tesla Tank `[TSLA]` (Russia), Tank Destroyer `[TNKD]` (Germany), Flak Track, War Miner. YR: Gattling Tank, Magnetron, Chaos Drone, Battle Fortress `[BFRT]`, Robot Tank, Demo Truck `[DTRUCK]` (Libya).
- **Aircraft** — Harrier `[ORCA]` (Allied), Black Eagle `[BEAG]` (Korea), Hornet carrier plane, Nighthawk transport `[SHAD]`, Kirov Airship `[ZEP]` (Soviet bomber), Siege Chopper `[SCHP]` `[YR]`, Spy Plane `[SPYP]`, Cargo Plane, Boris MiG airstrike. `FlightLevel=1500`; helicopters use `CurleyShuffle`.
- **Naval** — Destroyer `[DEST]`, Aegis Cruiser `[AEGIS]`, Amphibious Transport `[LCRF]` (hovercraft carrying vehicles), Dolphin `[DLPH]`, Typhoon Sub `[SUB]`, Dreadnought `[DRED]`, Aircraft Carrier `[CARRIER]`, Sea Scorpion `[HYD]`; YR Boomer `[BSUB]` (sub-launched missiles), Giant Squid `[SQD]`.
- **Turrets / ROT** — `Turret=yes`, `TurretAnim` (SHP or `TurretAnimIsVoxel`), `TurretROT`, `TurretRecoil`, `BarrelTravel/CompressFrames` for ballistic recoil. Prism Cannon uses `ROT=1` (slow traverse) and `TurretAnimZAdjust`.
- **IFV / GI weapon modes** — IFV changes its weapon/role based on the embarked infantry (e.g. GI → AA, Engineer → repair, Tesla Trooper → anti-armor); GI deploys for a stronger stationary weapon. `WeaponMode`-style behavior is data-driven via passenger type.
- **Special abilities** — Spy disguise + infiltration, Engineer capture, Attack Dog detect, Tanya C4, Crazy Ivan time bombs (`IvanWarhead`, `IvanDamage`, `IvanTimedDelay=450`), Boris laser-designated MiG strike, Desolator radiation.
- **Mind control (YR)** — Yuri Clone/Prime, Mastermind (`OverloadCount`, `OverloadDamage`, `OverloadFrames`; overloading kills it), Psychic Tower; `YuriMindControlSound`, `MindClearedSound`. **Base RA2 has no player mind-control units** — only campaign Psychic Beacons. `[uncertain]` on whether any neutral psychics are usable in base RA2.
- **Tesla** — Tesla Coil/Tesla Trooper/Tesla Tank; `TeslaCharge`, `TeslaZap`; chain zap behavior via warhead.
- **Prism / refraction** — Prism Tank and Prism Cannon; `PrismType=ATESLA`, `PrismSupportModifier=150%` per supporting prism building, `PrismSupportMax=8`, `PrismSupportDelay/Duration/Height`. Support beams combine damage.
- **Chrono** — Chronosphere superweapon, Chrono Legionnaire (erases targets from time), Chrono Miner (teleports). `ChronoDelay=60`, `ChronoDistanceFactor=48`, `ChronoTrigger`.
- **Iron Curtain** — renders a group of units invulnerable for a period; `IronCurtainColor`, `IronCurtainInvokeAnim`.
- **Nuclear / lightning** — Soviet Nuclear Missile (`NukeSpecial`, `NukeWarhead`, `NukeUp` projectile), Allied Weather Control lightning storm (`LightningStormSpecial`, `LightningDamage=250`, `LightningStormDuration=180`, `LightningWarhead=IonWH`).
- **Force Shield (YR)** — `ForceShieldSpecial`, `ForceShieldRadius=4`, `ForceShieldDuration=500`, `ForceShieldBlackoutDuration=1000`.
- **Paradrop** — American `AmericanParaDropSpecial`, generic `ParaDropSpecial`; per-side infantry/number lists (`AmerParaDropInf/Num`, `SovParaDropInf/Num`, `YuriParaDropInf/Num`).
- **Spy infiltration** — Spy enters enemy building for effects: power blackout (`SpyPowerBlackout=1000`), money steal (`SpyMoneyStealPercent=.5`), reveal/radar, unit vet promotion, superweapon reset, production sabotage; `Agent=yes`, `Infiltrate=yes`.
- **Gap Generator / blackout** — `[GAGAP]` shroud generator: `GapGenerator=yes`, `GapRadiusInCells=10`, `SuperGapRadiusInCells=10`, huge idle drain (`ExtraPower=-9000`); radar blackout in radius.
- **Terror Drone** — `special_1` armor, parasitizes enemy vehicles, drills them apart; fast, fragile to bullets.
- **Targeting rules** — `CanPassiveAquire`/`CanRetaliate`, `GuardRange`, `GuardAreaTargetingDelay=36`, `NormalTargetingDelay=27`, `ThreatPosed`, `SpecialThreatValue`, `AntiInfantryValue/AntiArmorValue/AntiAirValue` for AI scoring.

---

## 6. Movement

- **Locomotors** — behavior GUIDs in object sections: drive `{4A582741-...}`, ship/walk, `jumpjet {92612C46-...}`, `teleport {4A582747-...}`, hover, tunnel. A unit's *movement class* is a pluggable locomotor, not a hardcoded class.
- **SpeedType** — `Foot, Track, Wheel, Hover, Float, Amphibious, Ship, Air`; controls terrain speed/particle (tracks vs wheels vs hover). `TrackedUphill/Downhill`, `WheeledUphill/Downhill` coefficients; `HoverHeight/HoverBoost/HoverAcceleration`.
- **MovementZone** — pathfinding passability class: `Normal, Infantry, Water, Crusher, CrusherAll, Destroyer, AmphibiousDestroyer, Fly`. This is the core "what can traverse what" switch.
- **Terrain passability** — per-tile; cliffs impassable; water only `Water/Ship/Float/Amphibious`; bridges connect land tiles; ice passable until cracked.
- **Naval movement** — ships restricted to water cells; `MovementZone=Water/Destroyer`; subs can submerge (`CloakDelay`, `CloakSound`).
- **Amphibious** — amphibious units (`SpeedType=Amphibious`) cross water; the Amphibious Transport hovercraft `[LCRF]` ferries land vehicles across water.
- **Crushing** — see §1; `Crusher`/`CrusherAll`/`OmniCrusher`.
- **Bridge destruction / repair** — bridges are overlays with `BridgeStrength`; destroyed sections become rubble/water and block pathing; repair restores them (`RepairBridgeSound`, bridge repair hut `[CABHUTE?]`).
- **Hover / jumpjet** — hover units bob (`HoverBob`, `HoverDampen`); jumpjets use `[JumpjetControls]` (`CruiseHeight=500`, `WobblesPerSecond`, `WobbleDeviation`). Rocketeer/shadow.
- **Teleport** — chrono units/sphere move instantly with a delay based on distance; `ChronoMinimumDelay`, `ChronoRangeMinimum`.
- **Subterranean** — `TunnelSpeed=1` exists in the schema but RA2 has no tunnel-network faction (TS asset); `[absent in practice]`.

---

## 7. Vision & Fog

- **Shroud** — black unexplored shroud; `ShroudGrow=no` (doesn't regrow by default), `ShroudRate=4` creep process. `RevealToAll` for superweapons/missiles.
- **Fog of war** — grey "seen once, not currently visible" layer; `FogOfWar=no` in default rules (skirmish may enable), `FogRate=.01`, `BlendedFog=yes`. RA2 skirmish uses shroud + a "last seen" ghost layer rather than hard fog [uncertain on exact skirmish config].
- **Sight** — `Sight=` per unit/building; `AircraftFogReveal=6`, `LeptonsPerSightIncrease` from altitude.
- **Radar** — provided by `Radar=yes` structures: Soviet Radar Tower `[NARADR]` and Allied Airforce Command HQ `[GAAIRC]` (also `AMRADR`); minimap/radar requires power. Radar is losable: destroying radar building disables minimap (radar-tower destructibility is a RA2 signature).
- **Gap generator blackout** — `[GAGAP]` creates a radar/shroud blackout bubble; spy infiltration can also black out power/radar.
- **Spy satellite** — `[GASPYSAT]` `SpySat=yes` reveals the whole map; `SpySatActivationSound/DeactivationSound`.
- **Psychic reveal (YR)** — `PsychicRevealSpecial` reveals a map region; `PsychicRevealActivateSound`.
- **Cloaking / stealth** — `Cloakable`, `CloakingSpeed`, `CloakingStages`; Mirage Tank disguises as terrain, submarines submerge; sensors/dogs detect. `DisabledDisguiseDetectionPercent`.
- **Radar events** — `RadarEventSuppressionDistances/Durations`, attack flashes (`RadarCombatFlashTime`, `FlashFrameTime`); base/harvester-under-attack alerts.
- **Spy camera** — `CameraRange=9`, reveal around waypoint (`RevealTriggerRadius=9`), `DropZoneRadius=4`.

---

## 8. Special Systems

- **Superweapons (building-mounted, `SuperWeapon=` on structure)** — Allied: Chronosphere `[GACSPH]` (`ChronoSphereSpecial`), Weather Control Device (`LightningStormSpecial`), Spy Satellite. Soviet: Iron Curtain `[NAIRON]` (`IronCurtainSpecial`), Nuclear Missile Silo `[NAMISL]` (`NukeSpecial`). Each is `BuildLimit=1`, `RevealToAll=yes`, `Nominal=yes`, `RequiresGATECH/NATECH`.
- **Support powers (`SuperWeapon=` / no physical structure)** — American Paradrop, Spy Plane (`SpyPlaneSpecial`), Force Shield `[YR]`, Psychic Reveal `[YR]`, Boris airstrike.
- **YR superweapons** — Psychic Dominator `[YAPSYD]` (`PsychicDominatorSpecial`; `DominatorWarhead/Damage/CaptureRange`), Genetic Mutator (`GeneticConverterSpecial`, `MutateWarhead`), Force Shield (`ForceShieldSpecial`), Cloning Vats. `[YR]`
- **Superweapon charging UI** — sidebar icon with radial/linear charge; `ChargedAnimTime=1` switches the building to its "charged" animation when ≤1 minute remains; `RevealToAll` shows enemies your SW is ready.
- **Chronosphere / teleport** — mass-teleport friendly units with arrival delay; `ChronoPlacement/Beam/Blast/WarpIn/WarpOut` anim hooks.
- **Iron Curtain** — temporary invulnerability bubble on units (not buildings in RA2 base? `[uncertain]`; RA2 IC affects units, YR extends); `IronCurtainColor`, `WeaponNullifyAnim`.
- **Mind control (YR)** — Mastermind, Yuri Prime, Psychic Tower; capture enemy units (permanent control), overload death, `PermaControlledAnimationType`. Base RA2 lacks it.
- **Garrisoning** — infantry occupy buildings (Urban Combat) and the Tank Bunker.
- **Capture** — engineer capture of enemy/civilian structures; `Capturable`, `NeedsEngineer`, spy infiltration (distinct from capture).
- **Teleportation** — Chrono Legionnaire erases units; Chrono Miner relocates.
- **Nuke / lightning** — Global superweapon effects: nuke warhead with `AtomDamage=1000`, `NukeTakeOff` anim, EMP variant (`EMPulseWarhead/PulsPr`); lightning storm spawns scattered bolts (`LightningCellSpread`, `LightningSeparation`).
- **Blackout** — spy-infiltrated power plant shuts enemy power for `SpyPowerBlackout` frames.
- **Ivan bombs / C4** — `C4Delay`, `C4Warhead=Super`, `IvanTimedDelay`; death bombs optional.
- **Mutate (YR)** — Genetic Mutator turns infantry into Brutes/visceroids (`MutateExplosion`).
- **Berserk / chaos (YR)** — Chaos Drone causes friendly-fire berserk.
- **Detonate / disarm** — bomb ticking (`BombTickingSound`), bomb disarm.
- **Weather control** — storm clouds/bolts (`WeatherConClouds/Bolts`), `StormSound`.

---

## 9. UI / UX & Controls

- **Sidebar with tabs** — 6 tabs: **Structures, Defenses, Infantry, Vehicles, Aircraft, Ships**; each tab is a grid of cameos; production queue strip along the bottom.
- **Cameos** — 60×48 `[uncertain]`-ish button art per buildable object; greyed out when unbuildable (missing prereq, build limit, no funds, low power); flicker for ready superweapons.
- **Credits & power bars** — credit counter with tick sounds (`CreditTicks`), power bar showing supply/demand (green/yellow/red).
- **Radar / minimap** — bottom-left minimap; click to move camera; radar events flash; disabled without radar building/power.
- **Selection panel** — unit portrait/cameo + name + health bar + veteran chevrons; group selection shows multiple; `EnemyHealth=yes` shows enemy health.
- **Control groups** — 10 groups (Ctrl+0-9 / number keys), double-tap centers camera.
- **Rally points** — set per production building by right-clicking the ground with the building selected.
- **Guard / formation / stances** — Guard mode, area-guard, attack-move (via waypoint planning), `GuardModeStray`, `Stray/RelaxedStray` regroup; formation movement via flocking.
- **Waypoints / planning mode (YR)** — shift-click waypoint chains (`MaxWaypointPathLength=15`), YR planning mode (`StartPlanningModeSound`, `AddPlanningModeCommandSound`).
- **Cursors** — context-sensitive: move, attack, enter, deploy, no-entry, repair, sell, capture, mind-control; `AttackCursorOnDisguise`.
- **Health bars / pips** — health bar color thresholds (`ConditionRed=25%`, `ConditionYellow=50%`); pips for passengers, ammo, storage; `PipScale`, `PipWrap`, `PipSid`.
- **Input roles** — left-click selects/acts; right-click deselects/cancels, never issues unit commands (project convention matches RA2's model [uncertain]).
- **EVA / UI sounds** — full GUI sound set (`GUIBuildSound`, `GUITabSound`, `GUIOpenSound`, etc.).
- **Messages** — incoming message ticker (`MessageDelay=.6`), mission timer warning in red (`TimerWarning`).
- **Sell/repair buttons** — sell and repair cursor modes in the sidebar.
- **Icons/overlays** — move-line/flash (`MoveFlash=RING`), target designator color (`LaserTargetColor`).

---

## 10. Presentation & Audio

- **Voxel + sprite hybrid** — vehicles and aircraft are **voxel** models (`.vxl`) rendered on the 2D isometric grid; infantry and most buildings are **SHP** sprites. Same approach as TS. Art defined in `art(md).ini`.
- **Building animations** — buildup sequences, working/damaged/destroyed anims, `DamageFireTypes=FIRE01-03`, smoke systems (`OKBuildingSmokeSystem`, `DamagedBuildingSmokeSystem`), damage smoke offsets.
- **Turret animations** — `TurretAnim` (SHP) or `TurretAnimIsVoxel=true`; turret offset (`TurretAnimX/Y/ZAdjust`), recoil/travel.
- **EVA per faction** — distinct Allied, Soviet, and (YR) Yuri EVA voice sets; event-driven advisor lines.
- **Unit voices** — every unit has its own move/attack/select voice set; `CreateInfantrySound/CreateUnitSound`.
- **Music** — iconic tracks: "Hell March 2", "Grinder", "HM2", "Destroy", etc.; per-faction/situation scoring [uncertain on exact track list].
- **Death / explosions** — infantry death anims (`InfantryExplode=S_BANG34`, `InfantryHeadPop`), vehicle wrecks/debris (`MetallicDebris`, `ExplosiveVoxelDebris`), building crumble (`BuildingDieSound`), scorch marks (`Scorches`), craters (`Craters`, `CraterLevel`).
- **Particles / weather** — snow/rain in some theaters, ambient lighting (`AmbientChangeRate/Step`), `ShakeScreen`, meteor/nuke lighting changes.
- **Bodies / gore** — `DeadBodies`, `FlamingInfantry`, `InfantryNuked`, `InfantryVirus`.
- **Ambient audio** — battle chatter, chems, `EnterGrinderSound`, `EnterBioReactorSound`.
- **Score / post-game** — score screen with graphs (`StatisticTimeInterval`), victory/defeat stingers.

---

## 11. Campaign & Mission Scripting

- **Mission structure** — per-mission `.map` in a theater; campaign files for Allied and Soviet paths (`RA2`), each with numbered missions; YR adds Yuri missions + coop `[YR]`.
- **Triggers / events / actions** — map trigger system: Events (time, destroyed, entered, global set) → Actions (reinforce, spawn, reveal, win, lose, message, camera). Stored in the map file.
- **Objectives** — primary/secondary objectives shown in the mission panel; completion drives win/lose.
- **Briefings** — pre-mission briefing text/voice and in-mission transmission videos.
- **Taskforces / Teamtypes (AI scripting)** — `[AITriggerTypes]` / `[TeamTypes]` / `[TaskForces]` in `aimd.ini` define AI attack groups, composition, waypoints, and trigger conditions; used heavily in campaign and skirmish AI.
- **Waypoints** — numbered waypoints (0–99) on the map used by triggers, reinforcements, and AI teams; `RevealTriggerRadius`.
- **Reinforcements** — spawn via trigger actions; chrono reinforcements use `ChronoReinfDelay`.
- **Cinematic camera** — camera track/focus actions for cutscenes; `[CameraScripts]`.
- **Win/lose** — trigger actions set mission outcome; `SavourDelay=.1` before ending movie.
- **Country selection campaign** — campaign locks you to Allied or Soviet side; some missions grant temporary country units.
- **Difficulty** — `CampaignMoneyDeltaEasy/Hard` adjust starting credits; `FineDiffControl` enables 5 difficulty levels instead of 3.

---

## 12. Skirmish / Multiplayer & Meta

- **Skirmish AI** — `SmartAI=yes` houses; AI runs bases, build orders, attack teams, base defense via `AITriggerTypes`; difficulty from `TeamDelays=2000,2500,3500` (easy→hard), `AIHateDelays`, `MultiplayerAICM`.
- **Difficulty** — Easy/Medium/Hard (optionally 5 levels via `FineDiffControl`); affects AI income (`AIVirtualPurifiers`), team caps (`TotalAITeamCap`), defense counts (`*BaseDefenseCounts`).
- **AI economy cheats** — `AIVirtualPurifiers`, `AISlaveMinerNumber`, `AIAlternateProductionCreditCutoff`; AI can be given production/income multipliers.
- **Game modes** — Skirmish (vs AI) and multiplayer (LAN/Internet). Standard "Battle"; **no coop in base RA2** — YR adds a coop campaign mode `[YR]`.
- **Map selection** — `.mpr` multiplayer maps with preview thumbnails; random start positions.
- **Random map** — **RA2 has no random map generator** `[uncertain]` (TS/RA2 shipped fixed maps only).
- **Multiplayer options** — starting credits, crates on/off, superweapons on/off, MCV redeploy, short game, unit/build speed, fog, starting units, "no rushing" timers; 2–8 players with teams.
- **Houses / colors** — 8 house colors (see `[Colors]`), teams, alliances; `Multiplay=yes` per country; `AllyReveal=yes` shares radar with allies.
- **Reconnection / observers** — CnCNet-era features; base RA2 has limited reconnect `[uncertain]`.
- **Quickmatch / ladder** — historical Westwood Online ladder; not part of engine core.
- **Cheat codes** — debug cheats in skirmish (e.g. `give me the money`, `we are having a good time`); debug-only.

---

## 13. Modding / Data Architecture

- **`rules(md).ini`** — core object/weapon/warhead/projectile definitions. `rules.ini` (RA2), `rulesmd.ini` (YR). Sections: `[General]`, `[AudioVisual]`, `[CombatDamage]`, `[CrateRules]`, `[SpecialWeapons]`, `[JumpjetControls]`, `[ArmorTypes]`, `[InfantryTypes]`, `[VehicleTypes]`, `[AircraftTypes]`, `[BuildingTypes]`, `[Countries]`, `[Sides]`, plus one section per object.
- **`art(md).ini`** — visuals per object: `Image=`, `Voxel=yes`, `Sequence=`, `TurretAnim`, `Cameo`, shadows, `Remapable`, `TerrainPalette`. Sections mirror the rules sections.
- **`aimd.ini`** — AI: `[TaskForces]`, `[TeamTypes]`, `[AITriggerTypes]`, `[ScriptTypes]`, `[AITriggerTypesEnable]`.
- **Maps** — `.map` (single-player/campaign), `.mpr` (multiplayer), `.yrm` (YR). Contain tiles, overlays, houses, waypoints, triggers, terrain objects, cell tags.
- **Tilesets / theaters** — `.tem/.sno/.urb` tile sets, `[Theater]`/`[Temperate]` etc. in `ini`; each has its own palette and tile bitmaps. RA2 adds Urban/New Urban vs TS.
- **Country / house system** — `[Countries]` list + one section per country; `[Sides]` groups countries into GDI/Nod/ThirdSide; `RequiredHouses`/`ForbiddenHouses` gate country uniques; `Prefix`/`Suffix`/`Color`/`Multiplay`.
- **`[General]` options** — global knobs: build/repair/refund rates, growth rates, superweapon anims, AI tuning, damage gravity, waypoint limits, fog/radar behavior.
- **Section inheritance** — **no native INI inheritance in stock RA2**; art sharing via `Image=` and duplicate sections. (Ares/Phobos later add `[#include]` and inheritance; not base RA2.) `[uncertain]` on any hidden Westwood inheritance.
- **`Image=` reuse** — the primary reuse mechanism: multiple object sections point at one art `Image` (e.g. `[ATESLA] Image=GAPRIS`).
- **Weapons/warheads** — `[WeaponType]` sections: `Damage`, `ROF`, `Range`, `Projectile`, `Warhead`, `Burst`, `Ammo`, `Reload`, `Charges`, `AreaFire`, `Report`. Warheads: `Verses` (11 percentages), `CellSpread`, `PercentAtMax`, `InfDeath`, `AnimList`, `ProneDamage`, `Wood`.
- **Projectiles** — `[ProjectileType]`: `Arm=`, `ROT=`, `Range=`, `Speed=`, `Image=`, `Shadow=`, `AA/AG/AN`, `Inviso`, `SubjectToCliffs`.
- **Houses / triggers in maps** — `[Houses]`, `[Triggers]`, `[Events]`, `[Actions]`, `[Tags]`, `[CellTags]`, `[Waypoints]`.
- **Localization** — `[UIName]`/`Name=` strings, `Suffix=Allied/Soviet`, `Prefix=G/B`; EVA strings.
- **Legacy/Tiberium naming** — many tags keep TS names (`TiberiumGrows`, `TiberiumHeal`, `TiberiumShortScan`) while gameplay is ore/gems; a unified engine should rename or alias.

---

## RA2 vs Tiberian Sun — engine differences a unified engine must abstract

Same Westwood isometric lineage, so much shared code — differences are mostly data
plus a few mechanics. Abstract these behind data/config:

1. **Armor class count/list** — TS: 5 (`none, light, wood, heavy, concrete`); RA2: 11 (`none, flak, plate, light, medium, heavy, wood, steel, concrete, special_1, special_2`). `Verses` arrays must be variable-length and armor names data-driven.
2. **Resource model** — TS: Tiberium (veins, blossoms, lifeforms, healing, visceroids). RA2: Ore + Gems only, no lifeforms/veins. Resource *type table* must be data, not compiled in.
3. **Silos / storage cap** — TS has Tiberium silos limiting storage; RA2 removed them (unlimited). Storage-cap policy must be configurable.
4. **Locomotor set** — RA2 adds hover, teleport, jumpjet, amphibious, destroyer zones; TS has mech/walker and subterranean/tunnel. Locomotors as pluggable components.
5. **MovementZone list** — RA2 zones (`Normal, Infantry, Water, Crusher, CrusherAll, Destroyer, AmphibiousDestroyer, Fly`) vs TS mech/tunnel zones. Pathfinding accepts a zone enum from data.
6. **Build categories / sidebar tabs** — different `BuildCat` sets and tab mapping per game. UI tab layout must be data-driven.
7. **Superweapon set** — TS: Ion Cannon, Firestorm/EMP, Hunter-Seeker, Drop Pod, Chemical Missile. RA2: Chronosphere, Iron Curtain, Nuke, Weather Control; YR adds Psychic Dominator/Genetics/Force Shield. Superweapon logic must be a registry of pluggable effect handlers.
8. **Power / low-power behavior** — both have power, but tag names and penalty curves differ (`MaxLowPowerProductionSpeed` etc.). Parameterize.
9. **Tech trees** — TS uses GDI/Nod structures; RA2 uses category buckets (`POWER/PROC/FACTORY/BARRACKS/RADAR/TECH`) resolved in `[General]` plus Chinese-country-style `RequiredHouses`. Prereq resolution must be data-driven.
10. **Country/house system** — RA2's `RequiredHouses`/`ForbiddenHouses` country-unique units, `[Sides]` grouping, `Prefix/Suffix`; TS has sides but a simpler house model. House model + side grouping must be data.
11. **Infantry deploy semantics** — TS disc thrower / jumpjet differ; RA2 GI/Desolator/TeslaTrooper deploy modes, IFV role-switching. Deploy/transform as a component.
12. **Cloaking & vehicles** — RA2 has Mirage disguise, subs, gap generator, spy satellite, radar-tower dependency; TS has stealth tanks but different detection/reveal. Vision-system must be pluggable.
13. **Bridges & ice** — destroyable bridges and cracking ice are RA2 features with their own entities; TS has bridges too but fewer mechanics. Terrain overlays with health/state.
14. **Damage/weapon schema** — nearly identical, but RA2 adds prism support beams, V3/Dreadnought missiles, jumpjet weapons, mirage disguises. Weapon system needs effect hooks beyond raw damage.
15. **Veterancy** — both have rank; RA2 caps at 2 (`VeteranCap=2`) with ability tags (`VeteranAbilities/EliteAbilities`). Data-driven ability list.
16. **Art pipeline** — both voxel+SHP, but different theaters/tilesets and anim names. Art manifest must be per-game.
17. **Crew / survivor types** — per-side crew lists differ (`AlliedCrew`, `SovietCrew`, `ThirdCrew`). Data-driven.
18. **EVA / voices / music** — entirely per-game content; engine exposes event hooks, content packaged per game.
19. **Map format** — `.map/.mpr/.yrm` vs TS `.map/.mpr`; triggers share format but YR adds tags. Loader must tolerate per-game schema.
20. **AI definitions** — `aimd.ini` structure is shared but team/taskforce content differs; feed the same AI subsystem from per-game files.

---

## Generic RTS vs RA2-specific data — classification

**Generic RTS engine (abstract, reusable across remakes):**
- Cell/lepton grid, height levels, pathfinding (A*, zones/speed classes), occupancy & reservation.
- Selection, control groups, orders, move/attack/guard/stance, rally, waypoints, formations.
- Production queues per facility, build costs/times, prerequisites/tech gating, build radius/adjacency.
- Damage formula (`damage × verses[armor]`), projectiles, warheads, splash, `CellSpread`, ROF, burst, ammo/reload.
- Health, armor, veterancy framework, repair, sell/refund.
- Vision: shroud, fog, sight, radar/minimap, cloak/detect.
- Economy: harvester state machine, refinery docking, resource fields, income.
- Garrison/capture/transport/dock primitives.
- Superweapon charging + effect-dispatch framework.
- Trigger/event/action mission system, taskforces/teamtypes, reinforcements, cinematic camera.
- UI framework: sidebar tabs, cameos, selection panel, power bar, cursors, health/pip overlays.
- INI-style data loading, art manifest, localization, AI definitions.
- Audio/EVA event hooks, music, unit voice sets.

**RA2-specific data (must live in the RA2 game package, NOT the engine):**
- Armor list (11 names + order) and `Verses` arrays.
- Ore + Gem resource types, ore growth/spread rates, purifier bonus, gem values.
- Country roster (`Americans, Alliance/Korea, French, Germans, British, Russians, Africans/Libya, Arabs/Iraq, Confederation/Cuba, YuriCountry`) + `[Sides]` grouping + per-country units/buildings.
- `BuildCat` values and sidebar tab mapping (Structures/Defenses/Infantry/Vehicles/Aircraft/Ships).
- Superweapon set: Chronosphere, Iron Curtain, Nuclear Missile, Weather Control, Psychic Dominator/Genetic Mutator/Force Shield/Psychic Reveal `[YR]`.
- Unit roster & stats (GI, Conscript, Grizzly, Rhino, Prism, Apocalypse, Kirov, Terror Drone, IFV, V3, Dreadnought, Tanya, Boris, Yuri, etc.).
- Special mechanics: prism support beams, Tesla chain, chrono teleport, Iron Curtain invulnerability, mind control/overload, spy infiltration effects, IFV role switching, Desolator radiation, Ivan bombs, Mirage disguise, gap generator, spy satellite.
- Building set: Construction Yard, Refinery, Ore Purifier, War Factory, Barracks, Battle Lab, Radar/Airforce HQ, Shipyard, Service Depot, Helipad, walls/gates, defenses, Grinder/Bio Reactor/Cloning Vats `[YR]`.
- Theater/tileset content (Temperate/Snow/Urban), tile art, ore/gem overlays, civ building set.
- EVA lines, unit voices, music tracks, cameo art, voxel/SHP models, anim sequences.
- Map content & campaign missions, `aimd.ini` teams/taskforces, country-specific `RequiredHouses` gating.
- Rules/art/ai INI files and all tuned numeric constants (`BuildSpeed=.7`, `RefundPercent=50%`, `VeteranRatio=3.0`, etc.).
- "Tiberium"-named legacy tags that in RA2 actually mean ore (`TiberiumGrows`, `TiberiumHeal`, `TiberiumShortScan`) — RA2-specific alias data.

---

*End of inventory. Uncertainties marked inline with `[uncertain]`. Verify any
numeric constant against the target game's own `rules(md).ini` before shipping;
RA2 base vs YR differ in several places noted `[YR]`.*
