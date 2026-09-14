# Command & Conquer: Tiberian Sun — FIRESTORM
## Deep research: every addition and change vs. Tiberian Sun (TS)

**Scope:** exhaustive web-sourced delta for a data-driven Redot-engine RTS remake. Firestorm (FS) is treated as a **delta over Tiberian Sun (TS)** to be expressed as a data package. Research is **web-only** (no local game files read). Primary sources are the archived original INI files (`FIRESTRM.INI`, `AIFS.INI`, `ARTFS.INI`) from the Vinifera-Developers `Tiberian-Sun-INIs` archive, cross-checked against ModEnc, the C&C Wiki (Fandom), CNCNZ, PPM, OpenTS, and CnCNet.

**Release:** Westwood Studios, US 2000-03-07, final patch 2.03 (2000-05-31). 18 new missions (9 GDI + 9 Nod), both canon and simultaneous. New units/buildings, new Tiberium lifeform (Floater), new skirmish maps, World Domination Tour mode, INI data files `firestrm.ini`/`aifs.ini`/`artfs.ini`.

**How to read `Kind`:**
- `firestorm-data` — stat/ID/mission data only; no new engine behavior. Pure data package.
- `generic-engine` — requires engine-level behavior or hardcoded flag not present in baseline TS. The unified engine must implement it.
- `engine+data` — both.

**Confidence:** high = two or more independent sources, incl. raw INI. med = one solid source. low = single weak/narrative source or unresolved conflict.

---

### FS-000 — FS INI architecture, loading and gating (generic-engine)

**What.** Firestorm is a data overlay on TS, detected by file presence, not a separate engine executable. The game first checks whether `expand01.mix` exists; if it does, it looks for `firestrm.ini`. If BOTH exist, the game runs in Firestorm mode, `sound01.ini` replaces `sound.ini`, and `theme01.ini` is merged after `theme.ini`. `firestrm.ini` contains only *deltas*: sections/keys that override or add to `rules.ini`. `artfs.ini` and `aifs.ini` do the same for `art.ini` and `ai.ini`.

**Data keys.** File-level detection (`expand01.mix`, `firestrm.ini`), `[General]` override merge semantics (last value wins), companion files `AIFS.INI`, `ARTFS.INI`, `sound01.ini`, `theme01.ini`.

**Numbers.** FS expansion pack ships `expand01.mix`. Patch 2.03 is applied with or without Firestorm installed. The retail `TS`/`FS` executable lets the player pick the game at launch (the "modified executable"). Freeware/First Decade port moved FS cutscenes from `movies03.mix` into `movies01.mix` (port bug).

**Edge cases.** ModEnc notes the `rules.ini` shipped in FS's `expand01.mix` is identical to the patched `patch.mix` rules.ini. Firestorm does **not** introduce a new rules *format*; it reuses the TS INI schema and adds new sections/keys. OpenTS (open reimplementation) confirms the model: "OpenTS supplies the engine, not the game data"; it targets "Tiberian Sun 2.03 Firestorm" and runs GDI, Nod and the Firestorm campaigns as data on one engine.

**Kind.** generic-engine (expansion detection + overlay merge + mode switch).

**Sources.**
- https://modenc.renegadeprojects.com/Rules.ini (redirect `Firestrm.ini`; footnote on `expand01.mix`/`firestrm.ini` detection, `sound01.ini`, `theme01.ini`)
- https://modenc.renegadeprojects.com/Firestorm
- https://opents-developers.github.io/ (OpenTS manual)
- https://raw.githubusercontent.com/OpenTS-Developers/OpenTS/master/README.md
- https://ppmforums.com/topic-45058/ts-firestorm-203-questions

**Confidence.** high.

---

### FS-001 — GDI: Juggernaut (mobile artillery walker)

**What.** GDI's first long-range fire-support walker; modified Titan chassis + naval artillery tech. Must **deploy** (plant stabilisers) to fire in any direction (360°); cannot fire while mobile.

**Data keys.** `[JUGG]` vehicle; `DeploysInto=DJUGG`, `DeployToFire=yes`, `NoMovingFire=yes`, `Primary=Jugg90mm`, `EliteAbilities=SENSORS`, `AllowedToStartInMultiplayer=yes`, `CrateGoodie=yes`.

**Numbers (FIRESTRM.INI).** Strength 350; Armor light; Cost 950; TechLevel 6; Sight 9; Speed 5; ROT 5; Points 40; Prerequisite `GDIFACTORY,GARADR`. Weapon `Jugg90mm`: Damage 75, Burst 3, ROF 150, Range 18, MinimumRange 5, Warhead `ARTYHE`, Projectile `Ballistic2`, Speed 10, `Lobber=yes`. Wiki infobox cites ground attack 75 (×3), cooldown 150, range 18 (min 5). Deploy process ≈2 s.

**Edge cases.** `DeployToFire` + `NoMovingFire` means a large dead zone under the walker. Widely "splash" and anti-crowd. Weak to air and anti-armour. Elite gains `SENSORS` (stealth detection). `CrateGoodie=yes`. Verifiable behavior: deployed turret traverses 360°, mobile mode cannot fire.

**Kind.** engine+data (`DeployToFire`/`NoMovingFire` behavior; stats data).

**Sources.**
- https://raw.githubusercontent.com/Vinifera-Developers/Tiberian-Sun-INIs/master/FIRESTRM.INI (`[JUGG]`, `[Jugg90mm]`, `[Ballistic2]`)
- https://cnc-central.fandom.com/wiki/Juggernaut_(Firestorm) (infobox)
- https://cnc.fandom.com/wiki/Juggernaut_(Firestorm)
- https://cncnz.com/games/tiberian-sun/firestorm/new-gdi-weapons

**Confidence.** high.

---

### FS-002 — GDI: Deployed Juggernaut

**What.** The deployed building-form of the Juggernaut.

**Data keys.** `[DJUGG]` building; `UndeploysInto=JUGG`, `IsJuggernaut=yes`, `Turret=yes`, `TurretAnim=DJUGG_A`, `VoxelBarrelFile=DJUGGBAR`, `StartFacing`, `StartPitch`, `EliteAbilities=SELF_HEAL`, `HasStupidGuardMode=false`, `Crewed=yes`.

**Numbers.** Strength 400; Armor light; Cost 975; Sight 9; Points 50; ROT 5; ThreatPosed 30. Art: Foundation 1×1, `PBarrelLength=224`, `PrimaryFireFLH=0,0,64`, `TurretNotExportedOnGround=yes`.

**Edge cases.** Deployed form is a *building* (capturable/sell semantics differ). Elite self-heals. `StartFacing=4` (south), `StartPitch=2` (east) noted in INI comments.

**Kind.** engine+data.

**Sources.** FIRESTRM.INI (`[DJUGG]`); ARTFS.INI (`[DJUGG]`). **Confidence.** high.

---

### FS-003 / FS-004 — GDI: Mobile EM-Pulse (Mobile EMP) + charged variant

**What.** GDI support vehicle that emits a radial EMP blast disabling ground vehicles, cyborgs and structures on a charge/discharge cycle. Not affected by its own discharge.

**Data keys.** `[MOBILEMP]`: `IsMobileEMP=true`, `PipScale=Charge`, `MaxCharge=1800`, `StartCharge=0`, `TypeImmune=yes`, `Trainable=no`, `SpecialThreatValue=1`, `MovementZone=Crusher`. `[CMOBILEMP]` = pre-charged (`StartCharge=1800`, TechLevel −1). Engine weapon `[MobileEMPulseWeapon]` (not unit-accessible): Damage 1200 (interpreted as EMP duration), ROF 1, Range 40, Warhead `MobileEMPulse`, Projectile `PulsPr`. Warhead `[MobileEMPulse]`: Spread 6, `EMEffect=yes`, `AnimList=MEMPFX`.

**Numbers (FIRESTRM.INI).** Strength 800 (was 600); Armor heavy; Cost 1000 (was 1400); TechLevel 6; Sight 6; Speed 7 (was 3); ROT 5; Points 60; Prerequisite `GDIFACTORY,NAPULS` (EMP cannon). Wiki infobox: 58 s disable duration, 86 s recharge, radius 6 tiles, HP 800, cost $1000, heavy.

**Edge cases.** Disables friendlies too. Non-cyborg infantry immune. Long charge is the counterplay. `MaxCharge` raised to 1800 from 1200. Charged variant exists as a separate type (used by missions/scenarios).

**Kind.** engine+data (charge/discharge EMP behavior + radius disable; stats data).

**Sources.** FIRESTRM.INI; https://cnc-central.fandom.com/wiki/Mobile_EMP; https://cncnz.com/games/tiberian-sun/firestorm/new-gdi-weapons. **Confidence.** high.

---

### FS-005 — GDI: Mobile War Factory (`MOBWARG` / `DGWEAP`)

**What.** Deployable mobile unit-production structure (GDI). One at a time. Cannot be manually repaired while deployed; needs a Service Depot or Mobile Repair Vehicle. Deployed form is captureable by Engineer; build options respect the tech tree.

**Data keys.** `[MOBWARG]` vehicle `DeploysInto=DGWEAP`, `BuildLimit=1`, `TechLevel=10`, `Prerequisite=GAWEAP,GAPLUG`, `Trainable=no`, `MovementZone=Normal`. `[DGWEAP]` building: `WeaponsFactory=yes`, `Factory=UnitType`, `DeployTime=.044`, `Capturable=true`, `Bib=yes`, `IsMobileWar=yes`, `UndeploysInto=MOBWARG`, `Strength=800`.

**Numbers.** Vehicle: Strength 800, Armor heavy, Cost 1800, Sight 6, Speed 3, ROT 5, Points 60. Building: Cost 2000, Points 80, Sight 4, Strength 800, BuildLimit 1, Power 0. Wiki: $1800, HP 800, heavy, sight 6 mobile / 4 deployed.

**Edge cases.** `BuildLimit=1` globally. Deployed cannot be repaired like a normal building. Art: Foundation 4×3, multiple anims (`MWAR_A/B/C`, `MWAR_1/2/D` door stages, `MWARBB` bib).

**Kind.** engine+data (mobile factory deploy/production behavior + `IsMobileWar`).

**Sources.** FIRESTRM.INI; ARTFS.INI; https://cnc-central.fandom.com/wiki/Mobile_war_factory. **Confidence.** high.

---

### FS-006 — GDI + Nod: Limpet Drone (`LIMPET` / `DLIMPET`)

**What.** Hovering recon drone; deploys into a stealth mine that attaches to a vehicle, slows it, and shares the vehicle's vision/location with the owner. Amphibious (hovers over water).

**Data keys.** `[LIMPET]`: `IsLimpetDrone=yes`, `DeploysInto=DLIMPET`, `SpeedType=Hover`, `MovementZone=AmphibiousDestroyer`, `AlternateSpeed=10`, `Trainable=no`, `Owner=GDI,Nod`, `Prerequisite=FACTORY,RADAR`, `AllowedToStartInMultiplayer=no`. `[DLIMPET]`: `Cloakable=yes`, `CloakingSpeed=10`, `IsLimpetMine=true`, `Unsellable=true`, `Primary=LIMP`, `UndeploysInto=LIMPET`. Engine weapon `[LIMP]`: Damage 1, ROF 80, Range 2, Projectile `LimpetBullet`, Warhead `LIMPY` (`LimpetFactor=35`). Art adds `[DLIMP_A]` active anim, `DLIMPET` foundation 1×1.

**Numbers.** Strength 100; Armor none; Cost 550 (was 700); Speed 8; Sight 5; ROT n/a; TechLevel 3; Points 50; cooldown 80; range 2.

**Edge cases.** Deployed drone is stealthed but **instantly destroyed by EMP**. Removed if host vehicle is repaired (service depot/MRV) or destroyed; drone leaves play. Sensor systems can detect deployed drones. Attached drone cannot be killed directly while inside the host. `LimpetFactor` controls speed penalty (35). Used heavily in Nod mission 3 ("Tratos' Final Act").

**Kind.** engine+data (attach/slow/vision relay/EMP-kill behavior; stats data).

**Sources.** FIRESTRM.INI; https://cnc-central.fandom.com/wiki/Limpet_drone. **Confidence.** high.

---

### FS-007 — GDI: Drop Pod Control Plug (`GAPLUG4`) + Drop Pod superweapon

**What.** A module for the GDI **Upgrade Center** (`GAPLUG` power-up) that grants the player-controlled **Drop Pod** support power: deploys 2 Heroic Light Infantry and 4 Heroic Disc Throwers anywhere on the battlefield. Units receive an initial move order on impact.

**Data keys.** `[GAPLUG4]` building: `PowersUpBuilding=gaplug`, `PowersUpToLevel=-1`, `SuperWeapon=DropPodSpecial`, `Prerequisite=GAPLUG`, `TechLevel=10`, `Power=-20`. `[DropPodSpecial]` superweapon: `Type=DropPod`, `Action=DropPod`, `SidebarImage=PODSICON`, `IsPowered=true`, `RechargeTime=7` (was 6). Engine weapon `[DropGun]`: Damage 1 (was 50), ROF 50, Warhead `SA`, for the pod itself. `[AudioVisual] DropPod=DROPPOD,DROPPOD2,DROPPODY,DROPPODY2`.

**Numbers.** Plug Cost 1000 (was 1200); HP n/a; Armor wood; Sight 1; Points 30; TechLevel 10. Upgrade Center max 2 plugins (so all plugins need a second Upgrade Center).

**Edge cases.** `PowersUpBuilding` means the plug must be attached to a `GAPLUG`; it is an addon, not a standalone building. Drop pods can be configured only via engine (`[General]` `DropPodWeapon`, `DropPodInfantryMinimum/Maximum`). Drop-pod infantry arrive Heroic.

**Kind.** engine+data (`Type=DropPod` superweapon + pod delivery; GAPLUG power-up data).

**Sources.** FIRESTRM.INI (`[GAPLUG4]`, `[DropPodSpecial]`, `[DropGun]`); https://cnc-central.fandom.com/wiki/Drop_pod_control_plug; https://cnc-central.fandom.com/wiki/Drop_pod. **Confidence.** high.

---

### FS-008 — GDI: Riot Soldier (campaign-only)

**What.** Non-lethal anti-riot infantry with tranquiliser rifles, used only in GDI mission 3 ("Quell the Civilian Riots"). Firing at a hostile civilian/mutant **subdues** it, converting it to a neutral unit. Negligible damage; can eventually kill unarmoured infantry in large numbers.

**Data keys.** Map-specific modification of the **Anton Slavik** unit (`SLAV`); art uses the Slavik SHP. Not part of the standard buildable roster (`Cameo = FS_Elite_Cadre_Icons.gif` per wiki; unit art `SLAV` with `Sequence=E1Sequence`). In the archive it only exists as a modifiable map unit.

**Numbers.** Wiki: campaign-only; no stable published statline (subdues rather than kills). See open question FS-Q1.

**Edge cases.** Subdued units become neutral. Mission fails if civilians/mutants die or the Supply Depot falls.

**Kind.** firestorm-data (mission-scripted unit; engine needs the "subdue to neutral" hook tied to the map).

**Sources.** https://cnc.fandom.com/wiki/Riot_soldier; https://cnc-central.fandom.com/wiki/Quell_the_Civilian_Riots; FIRESTRM.INI (`[ELCAD]`/`[SLAV]` art). **Confidence.** med (stats), high (existence/behavior).

---

### FS-009 — Nod: Cyborg Reaper (`REAPER`)

**What.** Four-legged spider-like cyborg walker (Tiberium-mutated human operator). Quad rocket launchers (anti-vehicle/air) + web launcher (anti-infantry immobiliser). CABAL's abductor unit. First-stage rocket splits into two, each splits into two (4 total). 25% chance per rocket to redirect to a random nearby unit (friendly or hostile).

**Data keys.** `[REAPER]`: `Primary=QuadLauncher`, `Secondary=WebLauncher`, `Owner=Nod`, `Prerequisite=NATECH,NODFACTORY`, `SpeedType=Creep`, `NonVehicle=yes`, `CrateGoodie=yes`, `AllowedToStartInMultiplayer=yes`, `ImmuneToVeins=yes`, `TiberiumProof=yes`, `TiberiumHeal=yes`, `EliteAbilities=CRUSHER`, `Accelerates=false`, `Trainable` implicit. Weapons: `[QuadLauncher]` Damage 0, ROF 180, Range 7, ProjectileRange 2, MinimumRange 3, Projectile `DualCluster`, Speed 25, Warhead `SA`, Burst 2. `[DualCluster]` projectile `Cluster=2`, `Splits=yes`, `AirburstWeapon=DualRockets`, `IgnoresFirestorm=yes`, `RetargetAccuracy=75%`, Image DRAGON. `[DualRockets]` Damage 5, ROF 180, Range 6, Projectile `AAHeatSeeker2`, Warhead `AP`, Burst 2. `[WebLauncher]` Damage 0, ROF 200 (was 180), Range 7, Projectile `WebCapsule`, Speed 25 (was 10), Warhead `WebMass`.

**Numbers.** Strength 400 (was 350); Armor light; Cost 1100; TechLevel 6; Sight 7; Speed 5; Points 30; Ground attack 50 (×4); Ground/Air attack per wiki 50 (×4) `AP`; cooldown 180; range 7 (min 3) rockets, 7 web. `[WebMass]`: Verses 600%/0/0/0/0, `Webby=true`, `WebDuration=600` (was 300), `WebDurationVariation=25`, `WebRadius=2`, `Particle=WebSys`, Spread 4, InfDeath 4.

**Edge cases.** Web immobilises infantry (`WebbedInfantry=WEBGUY` anim); allies of CABAL can capture/kill helpless infantry. Reaper does **not** have cyborg "top appendage separation"; it goes inert and self-repairs on Tiberium. EMP-vulnerable (`CYC2 IsWebImmune=true` means the commando cyborg is web-immune). Fires at air and ground. Prone to friendly fire due to 25% redirect. Death animation takes extra hits that count as kills for veterancy (bug).

**Kind.** engine+data (web immobilisation, cluster-splitting projectile, retarget; stats/IDs data).

**Sources.** FIRESTRM.INI (`[REAPER]`, `[QuadLauncher]`, `[DualCluster]`, `[DualRockets]`, `[WebLauncher]`, `[WebMass]`, `[WebSys]`, `[Web]`); https://cnc-central.fandom.com/wiki/Reaper_(Firestorm). **Confidence.** high.

---

### FS-010 — Nod: Mobile Stealth Generator (`SGEN` / `MSTL`)

**What.** Self-powered mobile version of Nod's Stealth Generator. Cannot move while deployed. Smaller cloak radius than the static generator, but consumes almost no base power. Two or more allow "leapfrog" permanent cloaking.

**Data keys.** `[SGEN]`: `DeploysInto=MSTL`, `Prerequisite=NODFACTORY,NASTLH`, `Trainable=no`, `crewed=no`, `Turret=no`, `IsTilter=yes`, `EliteAbilities=EXPLODES`. `[MSTL]` building: `CloakGenerator=yes`, `CloakRadiusInCells=6`, `HasRadialIndicator=true`, `RadialColor=255,0,0`, `Powered=false`, `Powered` off, `Sensors=yes`, `UndeploysInto=SGEN`, `IsMobileStealth=yes`, `BaseNormal=no`, `Capturable=false`.

**Numbers.** Vehicle: Strength 200 (was 250); Armor light; Cost 1600 (was 1800); TechLevel 9; Sight 5; Speed 6; ROT 5; Points 25. Deployed: Strength 200 (was 600); Armor wood; Sight 6; Cost 1600 (was 2000). Wiki: deployed armortype Wood, mobile Light; rail says cloaks adjacent (Adjacent=2).

**Edge cases.** Damage makes the stealth bubble flicker. Repairable by Mobile Repair Vehicle. AI ignores it (largely useless vs AI). Replaced post-war by Disruption Towers (TW3 lore).

**Kind.** engine+data (`IsMobileStealth` + deployed cloak generator; stats data).

**Sources.** FIRESTRM.INI (`[SGEN]`, `[MSTL]`); https://cnc-central.fandom.com/wiki/Mobile_stealth_generator. **Confidence.** high.

---

### FS-011 — Nod: Fist of Nod (`MOBWARN` / `DNWEAP`) — Mobile War Factory

**What.** Nod's Mobile War Factory, known to Kane's faithful as the **Fist of Nod**. Same function as the GDI unit: deploy to produce any Nod unit respecting the tech tree. One at a time. Cannot be manually repaired deployed.

**Data keys.** `[MOBWARN]` `DeploysInto=DNWEAP`, `Prerequisite=NAWEAP,NATMPL` (Temple of Nod), `BuildLimit=1`, `TechLevel=10`, `Trainable=no`. `[DNWEAP]` building `WeaponsFactory=yes`, `Factory=UnitType`, `DeployTime=.044`, `IsMobileWar=yes`, `Combat` voice set, `UndeploysInto=MOBWARN`, `BaseNormal=no`, `Bib=yes`.

**Numbers.** Vehicle: Strength 800, Armor heavy, Cost 1800, Sight 6, Speed 3, ROT 5, Points 60. Building: Cost 2000, Points 80, Sight 4. Wiki: $1800, HP 800, heavy.

**Edge cases.** Oddity: selected deployed Fist of Nod still responds with vehicle-era voice lines (GDI deployed one does not). Captureable by Engineer when deployed.

**Kind.** engine+data.

**Sources.** FIRESTRM.INI (`[MOBWARN]`, `[DNWEAP]`); https://cnc-central.fandom.com/wiki/Mobile_war_factory. **Confidence.** high.

---

### FS-012 — Nod: Elite Cadre (`ELCAD`)

**What.** Heavy assault infantry (Black Hand) introduced to replace Nod's Cyborgs, which CABAL took over. Uses a heavy pulse rifle (same weapon family as Cyborgs). Immune to the immobilising effect of EMP. Campaign only in practice.

**Data keys.** `[ELCAD]`: `Image=SLAV`, `Primary=Vulcan3`, `Prerequisite=NAHAND` (Hand of Nod), `TiberiumProof=yes`, `Fearless=yes`, `TechLevel=-1`, `Owner=Nod`, `AllowedToStartInMultiplayer=no`, `ImmuneToVeins=yes`, `PhysicalSize=1`. Art: `Sequence=E1Sequence`, `FireUp=2`, camo `WEATICON`.

**Numbers (FIRESTRM.INI).** Strength 175; Armor light; Cost 300; Sight 4; Speed 4; Points 5; Ground attack 10 (×3) `SA`, cooldown 30, range 4. Wiki infobox gives cost **$300** but the assessment text says **$350** (conflict). Wiki ground attack 10 (×3).

**Edge cases.** Loses 1v1 to a Cyborg (less armour, no Tiberium heal). Cheaper than Cyber. Can't be built in standard MP. `[ELCAD]` and art-only `[SLAV]` both map to `WEATICON`.

**Kind.** firestorm-data mostly (reuses infantry engine; distinct weapon `Vulcan3`).

**Sources.** FIRESTRM.INI (`[ELCAD]`, `[SLAV]`, `Vulcan3`); https://cnc-central.fandom.com/wiki/Elite_cadre. **Confidence.** high (data), conflict noted on $300/$350.

---

### FS-013 — Nod: "Huey the Infected Cyborg" (`HUEY`)

**What.** A named/unique infected Cyborg used in the GDI mission "Factory Recall" (Huey carries the virus into CABAL's network). Category Soldier, appears only through the campaign. Also listed under FS `[InfantryTypes]`.

**Data keys.** `[HUEY]`: `Image=CYBORG`, `Primary=Vulcan3`, `TiberiumProof=yes`, `TiberiumHeal=yes`, `Fearless=yes`, `Cyborg=yes`, `TechLevel=-1`, `Owner=` (none), `EliteAbilities=STRONGER`, `ImmuneToVeins=yes`, `Locomotor` cyborg.

**Numbers.** Strength 300 (was 350); Armor light; Cost 650; Sight 5; Speed 4; Points 5. (Campaign/story unit, not buildable.)

**Edge cases.** Owner empty → not player-buildable. Virus insertion is mission scripting.

**Kind.** firestorm-data (campaign unit).

**Sources.** FIRESTRM.INI (`[HUEY]`); https://cnc.fandom.com/wiki/Factory_Recall; https://cnc.fandom.com/wiki/Huey. **Confidence.** high (data), med (purpose details).

---

### FS-014 — Nod: Retro Flame Tank (`FLMTNK`, tech/civilian)

**What.** A Flame Tank (First-Tiberium-War-style) re-included in FS as a low-tier/civilian/crate unit (`Owner=Civilian`, `TechLevel=-1`), used by Nod-aligned map forces.

**Data keys.** `[FLMTNK]`: `Image=FTNK`, `Primary=FireballLauncher`, `Owner=Civilian`, `TechLevel=-1`, `CrateGoodie=yes`, `MovementZone=Destroyer`, `EliteAbilities=EXPLODES`, `AccelerationFactor=0.01`. Art `[FTNK]`: `Voxel=yes`, `Remapable=yes`, `PrimaryFireFLH=175,30,0`.

**Numbers.** Strength 300; Armor light; Cost 700; Sight 5; Speed 6; Points 40; ROT 5.

**Edge cases.** Civilian owner → appears via crates / placed on maps, not normal build.

**Kind.** firestorm-data (added type + art).

**Sources.** FIRESTRM.INI (`[FLMTNK]`); ARTFS.INI (`[FTNK]`). **Confidence.** high.

---

### FS-015 — Nod/CABAL: Obelisk of Darkness (`AAOB`) — anti-air Obelisk

**What.** CABAL's advanced anti-air laser Obelisk. Fires a solid AA beam that can one-shot an Orca, and can fire **through a Firestorm barrier**. Cannot target ground. Requires base power but itself draws 0.

**Data keys.** `[AAOB]` building: `Image=OBL2`, `Primary=AALaserFire`, `Turret=no`, `TurretAnim=OBL2_C`, `TurretAnimZAdjust=-3`, `Powered=yes`, `IsBaseDefense=yes`, `BaseNormal=no`, `Capturable=false`, `Owner=Civilian`. Weapon `[AALaserFire]`: Damage 250, ROF 20, Range 12 (was 10.5), Warhead `Super`, Projectile `AALLine` (`AA=yes, AG=no, Inviso=yes`), `IsLaser=true`, `LaserInnerColor=0,0,255`, `LaserDuration=15`.

**Numbers.** Strength 1000; Armor concrete; Cost 1500 (INI); TechLevel −1 (not buildable); Sight 8; cooldown 20; range 12. Wiki: air attack 250, cooldown 20, range 12.

**Edge cases.** Helpless vs ground; paired with the CABAL Obelisk so ground is covered. Art `[OBL2]` Foundation 1×2, height 4, charge anims `OBL2_A/B/C` (+ damaged variants).

**Kind.** engine+data (`Ignore AA vs ground`, laser-through-Firestorm via `IgnoresFirestorm`-family handling; stats/art data).

**Sources.** FIRESTRM.INI (`[AAOB]`, `[AALaserFire]`, `[AALLine]`); ARTFS.INI (`[OBL2*]`); https://cnc-central.fandom.com/wiki/Obelisk_of_Darkness. **Confidence.** high.

---

### FS-016 — CABAL: CABAL Obelisk (`CROB`)

**What.** Advanced ground laser Obelisk defending the CABAL Core; 2× as tough as a normal Obelisk with shorter cooldown; can fire **through Firestorm walls**. Requires base power, draws 0.

**Data keys.** `[CROB]`: `Image=OBL1`, `Primary=CABLaser`, `TurretAnim=OBL1_C`, `TurretAnimZAdjust=-100`, `Powered=yes`, `IsBaseDefense=yes`, `Capturable=false`, `Owner=Civilian`. Weapon `[CABLaser]`: Damage 100, ROF 70, Range 10.5, Warhead `Super`, Projectile `LLine`, `IsBigLaser=true`, `IsLaser=true`, `Charges=yes`.

**Numbers.** Strength 1000; Armor concrete; Cost 1500 (INI); TechLevel −1; Sight 8; cooldown 70 frames; range 10.5. Wiki: ground attack 100, cooldown 70, range 10.5.

**Edge cases.** Comparable raw power/range to a standard Obelisk of Light; edge is through-wall fire + bulk. Art `[OBL1]` Foundation 2×2, charge anims `OBL1_A/B/C` (+ damaged).

**Kind.** engine+data (through-Firestorm targeting; stats/art data).

**Sources.** FIRESTRM.INI (`[CROB]`, `[CABLaser]`); ARTFS.INI (`[OBL1*]`); https://cnc-central.fandom.com/wiki/CABAL_Obelisk. **Confidence.** high.

---

### FS-017 — CABAL: CABAL Core (`CORE`)

**What.** CABAL's central command structure; the final mission objective. Nominal, radar-invisible, place-anywhere.

**Data keys.** `[CORE]`: Strength 3000, Armor concrete, `Nominal=yes`, `RadarInvisible=yes`, `PlaceAnywhere=yes`, `Points=5`, `TechLevel=-1`. Art `[CORE]`: Foundation 3×3, height 3, `ExtraDamageStage=yes`, `ActiveAnim=CORE_A/B/C` with damaged variants `CORE_AD/BD/CD` (looped frames 0..60/0..20/0..30), `Buildup=COREMK`.

**Numbers.** Strength 3000; Armor concrete.

**Edge cases.** `RadarInvisible` + `Nominal` = does not show on radar / counts as a targetable non-unit. Mission requires destruction; destruction ends the campaign.

**Kind.** firestorm-data (structure + art); engine-level destruction gating via mission scripting.

**Sources.** FIRESTRM.INI (`[CORE]`); ARTFS.INI (`[CORE*]`); https://cnc-central.fandom.com/wiki/CABAL_Core. **Confidence.** high.

---

### FS-018 — CABAL: Core Defender (`DEFENDER` / `DDEFD`)

**What.** Giant bipedal walker, CABAL's last line of defence at the true Core. Two-shot blue laser burst (approx Ion-Cannon-scale damage) with very short recharge; fires on the move while taking damage; immune to EMP and Ion Cannon; self-heals; immune to veins; heals in Tiberium; crushes infantry; no anti-air. Deployed form is invulnerable (inactive stance) until activated.

**Data keys.** `[DEFENDER]`: `IsCoreDefender=yes`, `Primary=DEFOB`, `Strength=10000`, `Armor=heavy`, `MovementZone=Destroyer`, `Crusher=yes`, `ImmuneToVeins=yes`, `TiberiumProof=yes`, `TiberiumHeal=yes`, `SelfHealing=yes`, `NoMovingFire=true`, `Trainable=yes`, `EliteAbilities=SENSORS`, `WalkRate=4`, `MaxDebris=30`, `Owner=Civilian`. `[DDEFD]`: `Strength=9999`, `Armor=concrete`, `Immune=yes`, `UndeploysInto=DEFENDER`, `IsCoreDefender=yes`, `UndeploySound=COREUP1`. Weapon `[DEFOB]`: Damage 350, Burst 2, ROF 20, Range 10.5, Warhead `Super2`, Projectile `LLine`, `IsBigLaser=true`, `LaserInnerColor=0,0,255`, `LaserDuration=2` (was 15). Art `[DEFENDER]`: WalkFrames 8, FiringFrames 12, Facings 8, `PrimaryFireFLH=200,-200,450`, `SecondaryFireFLH=200,200,450`.

**Numbers.** HP 9999 inactive / 10000 active; ground attack 350 (×2) `Super2`; cooldown 20; range 10.5; speed 5; sight 9; cost 2000 (INI, not buildable); Points 40. Wiki: "12.5× the HP of a Mammoth Mk. II"; approx Ion-Cannon damage per burst.

**Edge cases.** Inactive state is invulnerable (`Armor=concrete`, `Immune=yes`), so it must be "activated" (mission trigger) before it can be fought. `NoMovingFire=true` in INI conflicts with the wiki claim that it can fire on the move — flag conflict (see FS-Q4). Best counter in vanilla lore: Jump Jet Infantry / air (no AA). Bridge-destruction and Firestorm-wall traps are scripted exploits. `[DEFD_EXP]` explosion + `MaxDebris=30`; deployed `[DEFD]` Foundation 2×2, `Buildup=DEFDMK`.

**Kind.** engine+data (`IsCoreDefender` activation/invuln/immunity behavior; stats/art data).

**Sources.** FIRESTRM.INI (`[DEFENDER]`, `[DDEFD]`, `[DEFOB]`, `[Super2]`, `[DEFD_EXP]`); ARTFS.INI (`[DEFENDER]`, `[DEFD]`, `[DEFD_EXP]`); https://cnc-central.fandom.com/wiki/Core_Defender. **Confidence.** high (data), conflict noted re moving fire.

---

### FS-019 — CABAL faction: content and behavior (generic-engine + data)

**What.** CABAL is not a selectable multiplayer faction; it is a scripted/opponent faction in the Firestorm campaign and uses a hybrid Nod/CABAL roster. CABAL controls all **cyborgs** (including Reapers) after its rebellion, plus Nod hardware and unique defences. Its core base is protected by an indefinitely-active Firestorm barrier, an Obelisk of Darkness, a CABAL Obelisk, and the Core Defender.

**Data keys.** CABAL roster = Nod arsenal + `REAPER`, `MOBWARN`/`DNWEAP`, `SGEN`/`MSTL`, `LIMPET`, `FLMTNK`, `HUEY`, plus CABAL structures `CORE`, `CROB` (CABAL Obelisk), `AAOB` (Obelisk of Darkness), `DEFENDER`/`DDEFD`, and CABAL Firestorm generator. AI: `AIFS.INI` contains **no dedicated CABAL AI team/script types** — only new GDI/Nod teams for `JUGG` and `REAPER` (see FS-031); CABAL missions are scripted.

**Numbers.** Core Firestorm barrier unlimited vs GDI's limited. Three control stations (outside the barrier) deactivate it. Four Advanced Power Plants also power CABAL's defences (an alternative to control stations). Core HP 3000.

**Edge cases.** Destroying the control station in "Determined Retribution" fails the mission (must capture). In "Core of the Problem" there are 3 control stations and/or 4 Advanced Power Plants; destroying power plants also disables the Obelisks and triggers Core Defender ("Miscalculation in enemy capabilities; compensation initiated."). CABAL's Firestorm generator is destroyed or powered down to disable the barrier. CABAL cyborgs are EMP-vulnerable.

**Kind.** engine+data (mission scripting + faction AI behaviour), with the roster as data.

**Sources.** FIRESTRM.INI; AIFS.INI; https://cnc.fandom.com/wiki/Computer_Assisted_Biologically_Augmented_Lifeform; https://cnc-central.fandom.com/wiki/CABAL_Core; https://cnc.fandom.com/wiki/Core_of_the_Problem_(GDI). **Confidence.** high.

---

### FS-020 — New Tiberium lifeform: Tiberium Floater (`JFISH`, "Tiberium Jellyfish")

**What.** New FS Tiberium lifeform — a floating jellyfish-like creature that drifts and attacks with a tentacle. Has bespoke levitation/flight parameters (`[LEVITATION]`).

**Data keys.** `[JFISH]`: `Image=FLOATER`, `Owner=Civilian`, `Category=Civilian`, `Primary=Tentacle`, `Jellyfish=yes`, `SpeedType=Hover`, `MovementZone=AmphibiousDestroyer`, `Locomotor={3DC0B295-...}`, `TiberiumHeal=yes`, `TiberiumProof=yes`, `ImmuneToVeins=yes`, `Insignificant=yes`, `Nominal=yes`, `AllowedToStartInMultiplayer=no`, `MaxDebris=0`. Weapon `[Tentacle]`: Damage 16, ROF 80, Range 15, Projectile `Invisible`, Warhead `Stinger`. `[LEVITATION]` section: Drag 0.1, MaxVelocityWhenHappy 5.0, WhenFollowing 4.5, WhenPissedOff 10.0, AccelerationProbability 0.01, AccelerationDuration 20, Acceleration 0.75, InitialBoost 2.0, MaxBlockCount 3, `PropulsionSoundEffect=FLOATMOV,...`, IntentionalDeacceleration 1.0, IntentionalDriftVelocity 12.0, ProximityDistance 3.0. Warhead `[Stinger]`: Verses 60%/45%/90%/55%/0%, InfDeath 5, `AnimList=PULSEFX1,PULSEFX2`.

**Numbers.** Strength 500; Armor light; Sight 5; Speed 10; ROT 16; Points 50; GuardRange 5; ThreatPosed 20.

**Edge cases.** Civilian-owned, not player-buildable. Because it is `Jellyfish`/levitating, normal ground pathing does not apply; it uses the bespoke `[LEVITATION]` model. Appears in "Party Crashers" and elsewhere.

**Kind.** engine+data (levitation/floater movement system + new lifeform data).

**Sources.** FIRESTRM.INI (`[JFISH]`, `[LEVITATION]`, `[Tentacle]`, `[Stinger]`); https://cnc-central.fandom.com/wiki/Party_Crashers; https://cncnz.com/games/tiberian-sun-firestorm. **Confidence.** high.

---

### FS-021 — Weapons, warheads, projectiles added/changed (engine+data)

**What.** The FS weapon/warhead/projectile delta. New warheads declared in `[Warheads]`: `WebMass`, `LIMPY`, `CoreDefPlasmaWH` (the latter declared but **not defined** in FIRESTRM.INI — see open question).

**Data keys / Numbers.** Full list:

| Type | ID | Key values | Kind |
|---|---|---|---|
| Weapon | `Jugg90mm` | Dmg 75, Burst 3, ROF 150 (was 110), Range 18, MinRange 5, Proj `Ballistic2`, WH `ARTYHE`, Lobber | engine+data |
| Weapon | `LIMP` | Dmg 1, ROF 80, Range 2, Proj `LimpetBullet`, WH `LIMPY` | data |
| Weapon | `WebLauncher` | Dmg 0, ROF 200 (was 180), Range 7, Proj `WebCapsule`, WH `WebMass` | engine+data (web) |
| Weapon | `DualRockets` | Dmg 5 (was 4), ROF 180 (was 80), Range 6, Proj `AAHeatSeeker2`, WH `AP`, Burst 2 | data |
| Weapon | `QuadLauncher` | Dmg 0, ROF 180 (was 80), Range 7, ProjRange 2, MinRange 3 (was 2), Proj `DualCluster`, WH `SA`, Burst 2 | engine+data (split) |
| Weapon | `Tentacle` | Dmg 16, ROF 80, Range 15, WH `Stinger` | data |
| Weapon | `DEFOB` | Dmg 350, Burst 2, ROF 20, Range 10.5, WH `Super2`, Proj `LLine`, Laser, `LaserDuration=2` (was 15) | engine+data (laser) |
| Weapon | `AALaserFire` | Dmg 250, ROF 20, Range 12 (was 10.5), WH `Super`, Proj `AALLine`, AA-only | engine+data |
| Weapon | `CABLaser` | Dmg 100, ROF 70, Range 10.5, WH `Super`, Proj `LLine`, Laser | engine+data |
| Weapon | `MobileEMPulseWeapon` | Dmg 1200 (=duration), ROF 1, Range 40 (was 30), WH `MobileEMPulse`, Proj `PulsPr` | engine+data |
| Weapon | `DropGun` | Dmg 1 (was 50), ROF 50, Range 6, WH `SA` | engine+data |
| Warhead | `WebMass` | Verses 600/0/0/0/0, InfDeath 4, `Webby=true`, `WebDuration=600` (was 300), `WebDurationVariation=25`, `WebRadius=2`, `Particle=WebSys`, Spread 4 | engine+data |
| Warhead | `LIMPY` | `LimpetFactor=35`, Spread 0, Verses 0/100/100/100/100 | engine+data |
| Warhead | `CoreDefPlasmaWH` | declared in `[Warheads]` but **no definition** in FIRESTRM.INI | unknown |
| Warhead | `Super2` | Verses 100/100/100/100/100, InfDeath 5, `Tiberium=yes`, `Wall=yes`, ProneDamage 60% | data |
| Warhead | `MobileEMPulse` | Spread 6 (was 8), `EMEffect=yes`, `AnimList=MEMPFX` | engine+data |
| Warhead | `Stinger` | Verses 60/45/90/55/0, InfDeath 5, Bright | data |
| Projectile | `DualCluster` | `Cluster=2`, `Splits=yes`, `AirburstWeapon=DualRockets`, `IgnoresFirestorm=yes`, `RetargetAccuracy=75%`, Image DRAGON, ROT 4 | engine+data |
| Projectile | `WebCapsule` | `Arm=2`, `Proximity=yes`, `Ranged=yes`, `AA=no`, `AG=yes`, Image WEB, ROT 5 | engine+data |
| Projectile | `Ballistic2` | `High=yes`, Image 120MM, `Arcing=true`, `Inaccurate=true`, `Bouncy=yes`, Elasticity 0.0 | data |
| Projectile | `AALLine` | `Inviso=yes`, `AA=yes`, `AG=no` | engine+data |
| Projectile | `LimpetBullet` | `Inviso=yes`, Image none, `AV=true` | data |
| Weapon | `Ballistic` (fix) | added `Arcing=true, Bouncy=yes` to make Artillery less accurate | data |
| Weapon | `WeakGas` (warhead) | Spread 512, Verses 100/0/0/0/0, InfDeath 1, ProneDamage 300% | data |
| Weapon | `SlimeAttack` | Range 2.0 | data |
| Weapon | `Grenade` | ROF 80 (was 60) | data |
| Weapon | `Bomb` | Range 3 (was 5) | data |

**Edge cases.** `[CMOBILEMP]` charged variant reuses `[MobileEMPulseWeapon]`. `MobileEMPulseWeapon` warning: "Do NOT give this weapon to any units or all hell will break loose." `[DualCluster]` fires via `AirburstWeapon`; the `IgnoresFirestorm=yes` lets Reaper rockets pass Firestorm walls. `[WeakGas]` particle commented out (`;Particle=`), `[GasPuffSys]` lifetime shrank 30→3.

**Kind.** engine+data (web, split/cluster, EMP, beam laser, limpet) with pure data stats.

**Sources.** FIRESTRM.INI (`[Warheads]`, all weapon/projectile sections). **Confidence.** high (attributes), med (functional intent).

---

### FS-022 — Particles, particle systems and animations added (engine+data)

**What.** New particle systems/particles for webs, gas, smoke; new animation entries.

**Data keys / Numbers.**
- `[ParticleSystems]`: `WebSys` (HoldsWhat=Web, BehavesLike=Web, ParticleCap=20, SpawnRadius=10, Lifetime=30, Slowdown 0.05, SpawnCutoff 15.0, SpawnTranslucencyCutoff 13.0); `GasPuffSys` (HoldsWhat=WeakGasCloud, BehavesLike=WeakGas, Lifetime=3 (was 30)); `SmokeStackSys` (HoldsWhat=SmokeStackPuff, Spawns=yes, SpawnFrames=2, SpawnRadius=3, ParticleCap=15, Lifetime=75).
- `[Particles]`: `Web` (Persistent=true, MaxDC=2, MaxEC=80, Damage=0, Translucency=25, Velocity=8.0, Deacc=.05, EndStateAI=10, StateAIAdvance=2, DeleteOnStateLimit=yes); `WeakGasCloud` (MaxDC=60, MaxEC=50 (was 1000), Damage=4, Warhead=Gas, NextParticle=WeakGasCloudD); `WeakGasCloudD` (MaxDC=60, MaxEC=10 (was 50), Damage=1, DeleteOnStateLimit=yes); `SmokeStackPuff` (MaxEC=80, Velocity=9.0); `WeakGasCloudM2` (declared).
- `[Animations]` (FS adds 38 anim ids): `WEBGUY, WEB, K_LIGHT1, K_LIGHT2, MWAR_1, MWAR_2, MWAR_A, MWAR_B, MWAR_C, MWAR_D, MWARMK, DLIMP_A, DJUGG, DJUGG_A, DJUGGMK, MSTLMK, MSTL_A, DEFDMK, CORE_A, CORE_AD, CORE_B, CORE_BD, CORE_C, CORE_CD, OBL1_A, OBL1_AD, OBL1_B, OBL1_BD, OBL1_C, OBL1_CD, OBL2_A, OBL2_AD, OBL2_B, OBL2_BD, OBL2_C, OBL2_CD, DEFD_EXP, MEMPFX`.
- `[AudioVisual]`: `WebbedInfantry=WEBGUY` (new key — infantry struggle-under-web animation when webbed); `DropPod=DROPPOD,DROPPOD2,DROPPODY,DROPPODY2` (ground marks left after pods).

**Edge cases.** `WEBGUY` is the visual for webbed infantry (`Normalized=true, Surface=yes, RandomLoopDelay=10,300`). `MEMPFX` is the EMP discharge effect (`Normalized=yes, Surface=yes, Translucent=yes, UseNormalLight=yes`).

**Kind.** engine+data (web particle rendering, webbed-infantry anim hook, drop-pod mark).

**Sources.** FIRESTRM.INI (`[Animations]`, `[ParticleSystems]`, `[Particles]`, `[AudioVisual]`); ARTFS.INI (`[WEBGUY]`, `[MEMPFX]`). **Confidence.** high.

---

### FS-023 — Art (`artfs.ini`) additions/changes (firestorm-data)

**What.** The FS art delta: cameos, voxels, anims, foundations for new and changed objects.

**Data keys / Numbers.**
- `[GACTWR] Height=2`; `[GAWALL]/[NAWALL] DamageLevels=2` (walls can show damage).
- `[FTNK] Voxel=yes, Remapable=yes, PrimaryFireFLH=175,30,0`.
- `[FONA01..15] Theater=yes, Foundation=1x1` (Fona Tiberium plants re-enabled).
- `[DoggieSequence]/[E1Sequence]/[MedicSequence]/[JumpjetSequence]/[CyborgSequence] Struggle=0,6,0` (all common infantry get web-struggle).
- `[DLIMPET] Foundation=1x1, Height=1, Buildup=DLIMPMK, ActiveAnim=DLIMP_A`; `[DLIMP_A]` loop frames.
- `[C_KODIAK] Foundation=3x3, Height=3, ActiveAnim=K_LIGHT1/2` (Kodiak crash-site lights).
- `[M_EMP] Cameo=MEMPICON, Voxel=yes`; `[SGEN] Cameo=MSTLICON, Voxel=yes`; `[MWAR_NOD] Cameo=MWARICON, Voxel=yes`; `[JUGGER] Voxel=no, WalkFrames=15, Facings=8`; `[LIMPED] Cameo=LIMPICON`.
- `[MWAR]` Foundation 4×3, Height 2, `DeployingAnim=MWAR_2`, `UnderDoorAnim=MWAR_1`, `DoorAnim=MWAR_D`, `DoorStages=12`, `ActiveAnim=MWAR_A`, `ActiveAnimTwo=MWAR_B`, `ActiveAnimThree=MWAR_C`, `BibShape=MWARBB`, `NewTheater=yes`.
- `[DJUGG]` see FS-002. `[MSTL]` Foundation 1×1, `ActiveAnim=MSTL_A`, `ExtraLight=-100`.
- `[DEFENDER]` WalkFrames 8, FiringFrames 12, `StartStandFrame=0`, `StartWalkFrame=8`, `StartFiringFrame=72`, `Facings=8`. `[DEFD]` Foundation 2×2, `Buildup=DEFDMK`. `[DEFD_EXP]` `Report=EXPNEW05, Next=TWLT100`.
- `[CORE]` Foundation 3×3, `ExtraDamageStage=yes`, `ActiveAnim=CORE_A` + damaged variants.
- `[REAPER]` Cameo=REAPICON, Facings 8, WalkFrames 12, DeathFrames 13, `StartDeathFrame=104`, `MaxDeathCounter=64`.
- `[ELCAD]/[SLAV]` Cameo=WEATICON, `Sequence=E1Sequence`, `FireUp=2`.
- `[OBL1]/[OBL2]` charge anims (+ damaged variants), `ChargeAnim=yes`, `PrimaryFirePixelOffset`.
- `[BIGBLUE3] Theater=yes, Foundation=1x1`.
- `[Movies]`: FS movie IDs 67–90 (`FSGDIM02/M03/M07`, `FSNODM01..09`, `FS_TITLE`, `FSGDIM04/05/06/08/09`, `FSGDIFNL`, `FSGDIINT`, `FS_SB01`, `FSNODFNL`, `MEKATAK2`, `TS_TITLE`, `GDI_LOGO` etc.). FS movies begin at index 67 (`FSGDIM02`).

**Edge cases.** `[NAOBEL_B]` loop range changed. The movies list also includes the full TS movie table (IDs 1–66) because the archive merges.

**Kind.** firestorm-data (art config; requires asset files).

**Sources.** ARTFS.INI (entire). **Confidence.** high.

---

### FS-024 — AI (`aifs.ini`) additions (firestorm-data)

**What.** FS adds AI TaskForces, ScriptTypes, TeamTypes and AITriggerTypes. The only *unit*-specific new AI content is for `JUGG` (GDI) and `REAPER` (Nod). Everything else is a parallel GDI/Nod team set (E/M/H difficulty variants) targeting base defences, construction yards, factories, missile silos, power facilities, refineries, upgrade centers, and base defence, plus APC/engineer theft teams.

**Data keys.** `[TaskForces]` 1000–1060; `[ScriptTypes]` 1000–1018; `[TeamTypes]` 1000–1031; `[AITriggerTypes]`. New unit-specific teams:
- `08820130-G` = "1 juggernaut" (1×JUGG); `08822830-G` = "3 juggernauts" (3×JUGG).
- `0A70DB10-G` = "1 cyborg reaper" (1×REAPER); `0A70E6A0-G` = "3 cyborg reapers" (3×REAPER).
- New scripts include "Base defense attack", "Construction yard attack", "Factories attack", "Deployed base defense", "Missile silo attack", "Power facilities attack", "Tiberium refinery attack", "Upgrade center attack", "APC/engineer attack", "APC/eng. steal money", "APC/commando attack", "Harvester attack", "Aerial base attack", "Vehicle attack", "Infantry attack", "APC/infantry attack", "Replace MCV".
- AITriggers: "E/M/H_GDI juggernaut pool" (ID GARADR, priority 4), "E/M/H_Nod cyborg reaper pool" (ID NATECH, priority 4), plus base/factory/etc. attacks for GDI and Nod.

**Edge cases.** No CABAL-specific AI entries in `aifs.ini`; CABAL behavior is mission-scripted. `Digest=VIYs66hN8BSm544VkgK0QVZgCtw=` is a checksum-like line in the archived file.

**Kind.** firestorm-data (AI team/script definitions; engine already supports the AI format).

**Sources.** AIFS.INI (entire). **Confidence.** high.

---

### FS-025 — Rule changes: `[General]` and global tuning (gameplay delta)

**What.** FS overrides TS `[General]` and a few global values. This is the core balance/rules delta a FS data package must reproduce.

**Data keys / Numbers.**

| Key | FS value | TS value | Effect |
|---|---|---|---|
| `DropPodInfantryMinimum` | 5 | 3 | min infantry per drop pod |
| `DropPodInfantryMaximum` | 8 | 5 | max infantry per drop pod |
| `DropPodWeapon` | DropGun | — | weapon mounted on drop pod |
| `BallisticScatter` | 2.0 | 1.5 | artillery scatter (accuracy) |
| `PrerequisiteFactory` | GAWEAP,NAWEAP,DGWEAP,DNWEAP | (TS set) | factory prereq list incl. mobile war factories |
| `PrerequisiteGDIFactory` | GAWEAP,DGWEAP | — | GDI factory list |
| `PrerequisiteNodFactory` | NAWEAP,DNWEAP | — | Nod factory list |
| `EngineerCaptureLevel` | 1.0 | (TS default) | engineer can capture any building (no damage threshold) |
| `EngineerDamage` | 0.0 | (TS default) | engineers deal no damage on capture |
| `SurvivorRate` | .1 | .4 | chance an infantryman survives death |
| `SurvivorDivisor` | 100 | — | survival divisor |
| `VeteranRatio` | 5.0 | — | kills needed (×self-value) per vet level |
| `VeteranCombat` | .50 | — | veteran combat bonus |
| `VeteranSpeed` | .30 | — | veteran speed bonus |
| `VeteranSight` | 0.0 | — | veteran sight bonus |
| `VeteranArmor` | .50 | — | veteran armour bonus |
| `VeteranROF` | .30 | — | veteran rate-of-fire bonus |
| `VeteranCap` | 2 | — | max veteran level |
| `InitialVeteran` | no | — | initial forces not veteran |
| `[AI] BuildWeapons` | GAWEAP,NAWEAP,DGWEAP,DNWEAP | — | AI builds mobile war factories too |

**Other per-unit overrides in FIRESTRM.INI** (selected): `[HVR]`, `[REPAIR]`, `[ART2]`, `[WEED]`, `[APC]`, `[MMCH]`, `[HMEC]`, `[SMECH]`, `[BIKE]`, `[BGGY]`, `[SAPC]`, `[SUBTANK]`, `[SONIC]`, `[TTNK]`, `[STNK]`, `[TRUCKA]`, `[TRUCKB]`, plus aircraft `[SCRIN] Cost 1250 (was 1500)`, `[APACHE] Cost 800 (was 1000)`, infantry `[JUMPJET] Speed=8`, `[CYBORG] VoiceDie`, `[CYC2] IsWebImmune=true`, `[E2] CollateralDamageCoefficient=.33`, `[DOGGIE] ImmuneToVeins=yes`. Terrain `[GAWALL]/[NAWALL] Strength=225`; `[BIGBLUE3]` blue Tiberium tree spawns Tiberium (`SpawnsTiberium=yes, TiberiumToSpawn=2`). `[Clear]/[Rough]/[Road]/[Water]/[Rock]/[Wall]/[Tiberium]/[Weeds]/[Beach]/[Ice]/[Railroad]/[Tunnel]` all get `Creep=%` values (movement speed modifiers). `[JumpjetControls] CloakDetectionRadius=3` (Jump Jet Infantry refit to detect stealth).

**Edge cases.** `EngineerCaptureLevel=1.0` + `EngineerDamage=0.0` means FS engineers always capture (never damage) — a significant change from TS. `BallisticScatter` raised globally *and* Artillery's `Ballistic` projectile given `Arcing` in FS, i.e. double nerf to artillery accuracy. `SurvivorRate` halved to 0.1 (fewer infantry survive). Veteran bonuses are new/tuned (veteran factors "updated"). Mobile War Factories added to factory prerequisite lists. `CloakDetectionRadius` on jump jets.

**Kind.** engine+data (globals consumed by engine; values data).

**Sources.** FIRESTRM.INI (`[General]`, `[AI]`, per-unit overrides). **Confidence.** high.

---

### FS-026 — Firestorm Defence system: flags and mechanics (engine)

**What.** The Firestorm barrier system (`FirestormWall=yes` wall sections + `Type=Firestorm` superweapon) is documented by ModEnc. Present in TS, used prominently by CABAL (unlimited barrier). FS adds CABAL usage and the Firestorm Generator is built by CABAL.

**Data keys.** `[BuildingType] FirestormWall`; `[Projectile] IgnoresFirestorm`; `[General] ChargeToDrainRatio`, `DamageToFirestormDamageCoefficient`, `GDIFirestormGenerator`; `[CombatDamage] FirestormWarhead`, `DefaultFirestormExplosionSystem`; `[AudioVisual] FirestormActiveAnim`, `FirestormIdleAnim`, `FirestormGroundAnim`, `FirestormAirAnim`; `[SuperWeaponType] RechargeTime`, `SW.ChargeToDrainRatio` (Ares), `SW.Unstoppable` (Ares); map trigger actions **#92 Activate Firestorm**, **#93 Deactivate Firestorm**.

**Numbers.** `ChargeToDrainRatio` default **0.3333**; active duration = `RechargeTime × ChargeToDrainRatio`. `DamageToFirestormDamageCoefficient` default **0.1 in TS** (0.0 in Ares): incoming damage × 0.1 = frames removed from the active timer; the wall itself takes no damage while active. Wall section HP 200, Armor concrete, Cost 50, Power −2, TechLevel 9; generator HP 800, Cost 2000, Power −200, build time 0:30, TechLevel 9.

**Edge cases.** Active wall blocks units/projectiles unless `IgnoresFirestorm=yes`; units entering are destroyed with `FirestormWarhead`. Ambient/spread damage reduces the superweapon charge instead of damaging the wall. Only **inactive** wall sections can be sold. Shape frame order: 64 active/idle frames + 64 shadow; 16 inactive, 16 damaged-inactive, 16 active, 16 damaged-active; connection bitmask (1=top-right, 2=bottom-right, 4=bottom-left, 8=top-left). Some FS weapons bypass the wall: `[DualCluster] IgnoresFirestorm=yes`; Disruptors/Ion/Mammoth Mk. II bypass in lore; Devil's Tongue fires through. CABAL's wall is unlimited (custom generator).

**Kind.** generic-engine (already present from TS; FS data uses it).

**Sources.** https://modenc.renegadeprojects.com/Firestorm_System_Flags; https://modenc.renegadeprojects.com/FirestormWall; https://modenc.renegadeprojects.com/ChargeToDrainRatio; https://modenc.renegadeprojects.com/DamageToFirestormDamageCoefficient; FIRESTRM.INI; https://cnc-central.fandom.com/wiki/Firestorm_generator; https://cnc-central.fandom.com/wiki/Firestorm_wall_section. **Confidence.** high.

---

### FS-027 — GDI Firestorm campaign: "Desperate Measures" (9 missions)

**What.** FS GDI campaign. Both campaigns are canonical and take place simultaneously; there are **no side missions** in FS (unlike TS). Each mission has an FMV briefing.

**Missions (objectives):**

| # | Mission | Place / date | Objectives (from briefing) | Special map logic / events |
|---|---|---|---|---|
| 1 | Recover the Tacitus | Egypt, Jan 2031 | Find the Kodiak; recover the Tacitus to the pickup zone | Nod enemy; ion storm blocks advanced units; ruined Nod airbase (capturing Radar reveals map); Nod MCV deploys on whichever route player took; mutants assist |
| 2 | Party Crashers | Colony 3 | Protect/escort civilians to airlift; defend base until reinforcements | Enemies only Tiberium lifeforms incl. new Floaters; 4 waves (SE, NW, NE, S); then all-out attack; reinforcements incl. drop-pod infantry, Titans, Wolverines, Hover MLRS, 2 Disruptors, MCV |
| 3 | Quell the Civilian Riots | Colony 3 | Neutralise 4 riot leaders without killing civilians/mutants; protect Supply Depot | Riot Soldiers subdue (become neutral); Mobile EMP neutralises vehicles; 4 sub-factions (2 NE, 2 S) |
| 4 | In the Box | Poland | Destroy 2 bridges; infiltrate & capture CABAL's core | Nod laser fencing; capture command stations via civilian technicians; capture Nod Radar reveals map |
| 5 | Dogma Day Afternoon | Temple of the Tacitus, Bolivia | Reconnoiter & identify the Temple; recover Tacitus to airlift | Commando mission: Ghost Stalker + Medic + archaeologist + Juggernaut (first Juggernaut use); cultists (Believers, cult guards, priests, Mortimer); blue Tiberium fiends; 3 temples; lightning ignites blue Tiberium |
| 6 | Escape from CABAL | — | Escort Dr. Boudreau to outpost for evacuation; fortify outpost & destroy CABAL's base | CABAL betrayal; Nod base (ally-of-convenience, sells out); can capture Nod base using Carryall+APC+jump jets; stealth generators; Juggernauts recommended |
| 7 | The Cyborgs are Coming | Trondheim (Colony 6), Norway | Warn local civilians; establish base & destroy CABAL | Hospital spawns infinite cyborgs for CABAL; cyborgs detect stealth; bridge destruction tactic |
| 8 | Factory Recall | Cyborg Production Plant, Africa | Insert infected cyborg (Huey) into network centre; destroy cyborg manufacturing facility; destroy remaining CABAL forces | Dam powers CABAL base even if Advanced Power Plants destroyed; civilians held in facility; GDI+Nod ceasefire |
| 9 | Core of the Problem | Central Africa, 2032 | Build base & survive initial onslaught; capture 3 control stations; destroy CABAL's core | Final battle; joint GDI/Nod; Core Defender; Obelisk of Darkness; CABAL Obelisk; Firestorm barrier; alternative: destroy 4 Advanced Power Plants; CABAL deploys Core Defender; Mammoth Mk. II; EMP cannon + Mobile EMP ambush |

**Edge cases.** The ending reveals Cortez and Boudreau were married; the Tacitus contains a warning of the future Scrin invasion. Mission 1 is the only FS GDI mission where Nod is the enemy (rest is CABAL/Tiberium life/Cultists). "Core of the Problem" and "Determined Retribution" are the only FS GDI/Nod missions in the same location series.

**Kind.** firestorm-data (mission maps + scripts), with engine support for scripting triggers.

**Sources.** https://cnc.fandom.com/wiki/Recover_the_Tacitus, Party_Crashers, Quell_the_Civilian_Riots, In_the_Box, Dogma_Day_Afternoon, Escape_from_CABAL_(GDI), The_Cyborgs_are_Coming, Factory_Recall, Core_of_the_Problem_(GDI); https://cnc.fandom.com/wiki/Command_%26_Conquer:_Tiberian_Sun_-_Firestorm. **Confidence.** high.

---

### FS-028 — Nod Firestorm campaign: "From the Ashes" (9 missions)

**Missions (objectives):**

| # | Mission | Place / date | Objectives | Special map logic / events |
|---|---|---|---|---|
| 1 | Operation Reboot | Cairo, Egypt, Jan 2031 | Infiltrate GDI base; locate 3 CABAL core pieces; return to drop zone | Stealth emphasis; subterranean APCs; infiltrate/capture; no alarm |
| 2 | Seeds of Destruction | Colony 3 | Remain hidden from GDI; use drugged civilians to lure life forms from the Genesis Pit to cleanse the region | Toxin soldiers drug civilians; civilians run to Genesis Pit and lure Tiberium creatures; if attacked, mission fails |
| 3 | Tratos' Final Act | (Tratos compound) | Attach limpet mines to GDI units to locate Tratos; deactivate Firestorm defence & neutralise sensor arrays; assassinate Tratos | Limpet drones; cap 6 of 8 GDI power plants to drop Firestorm; sensor towers; mutant commando; may capture GDI Barracks/War Factory/Titans |
| 4 | Mutant Extermination | Central Africa | Locate mutant encampment; recover Tacitus to drop zone; destroy remaining mutants | Forgotten use repurposed GDI/Nod equipment incl. Mammoth tanks |
| 5 | Escape from CABAL | — | Evade CABAL's forces to the abandoned airfield; repair the array; retreat to the Montauk | CABAL turns on Nod; only mission with the Montauk on the battlefield; no announcer |
| 6 | The Needs of the Many | Europe | Reconnoiter; create distractions; get an engineer into GDI radar facility to steal the EVA unit | First mission with Mobile Stealth Generator; veteran stealth tanks; cloaking leapfrog |
| 7 | Determined Retribution | France | Repair bridges for reinforcements; capture command station to shut down laser fencing; destroy CABAL's base & defences | CABAL's core is a decoy; multi-missile strike kills the assault force; missile silos, stealth generators, cyborg commando |
| 8 | Harvester Hunting | Eastern Africa | Save civilians/town from CABAL siege; disrupt CABAL's Tiberium harvesting | First mission with Fist of Nod; veinholes; capture CABAL War Factories; developer oversights (can build Cyborg Commando / GDI MCV with captured tech) |
| 9 | Core of the Problem | Central Africa, 2032 | Build base & survive; capture 3 control stations; destroy CABAL's core | Final joint battle; speedrun via Devil's Tongues destroying 4 Advanced Power Plants; CABAL line "Miscalculation in enemy capabilities; compensation initiated."; Core Defender |

**Edge cases.** Nod's Core Defender speedrun is officially supported (CABAL voice reaction). Nod mission 8 has exploitable dev oversights (Cyborg Commando build, GDI MCV via captured tech centre). Nod mission 5 is the only mission where CABAL is already hostile from an ally faction.

**Kind.** firestorm-data (mission maps + scripts).

**Sources.** https://cnc.fandom.com/wiki/Operation_Reboot, Seeds_of_Destruction, Tratos%27_Final_Act, Mutant_Extermination, Escape_from_CABAL_(Nod), The_Needs_of_the_Many, Determined_Retribution, Harvester_Hunting, Core_of_the_Problem_(Nod). **Confidence.** high.

---

### FS-029 — New skirmish / multiplayer maps (firestorm-data)

**What.** FS shipped its own skirmish/multiplayer map set (distinct from the TS set). Wiki lists **14 FS maps**.

**Maps.** Cityscape (Temperate, 4–6, Large), Drawbridges (Temperate, 8), Dueling Islands (Temperate, 2), Hidden Valley (Temperate, 4), Hot Springs (Snow, 2), Narrow River (Temperate, 6), Nowhere to Run (Snow, 6), Permafrost (Snow, 4), River Raid (Temperate, 8), Theme Park (Temperate, 4), They All Float (Temperate, 2 — likely showcases the Floater), Tiberium Forest (Temperate, 4), Tiers of Sorrow (Temperate, 2), Xcapades (Snow, 4).

**Numbers.** TS base skirmish set ≈22 maps (A River Runs Near It, Casey's Canyon, Cliffs of Insanity, Desolation Redux, Forest Fires, Grand Canyon, Grassy Knoll, Hextreme!, Ice Cliffs, Limited Access, Night of the Mutants, Pentagram, Pit or Plateau, Pockets, Seismic, Sinkholes, Storms, Stormy Valley, Tactical Opportunities, Terrace, The Ice Must Floe, Tiberium Garden Redux, Tread Lightly). FS adds 14 new ones.

**Edge cases.** "They All Float" and "Hot Springs"/"Permafrost"/"Nowhere to Run"/"Xcapades" are snow-theater FS maps. FS MP can host TS objects (the engine runs both data sets).

**Kind.** firestorm-data (map files + preview art).

**Sources.** https://cnc.fandom.com/wiki/Skirmish_maps_(Tiberian_Sun); https://cnc.fandom.com/wiki/Category:Firestorm_skirmish_map_images. **Confidence.** high (existence), med (exact player/size fields partly blank).

---

### FS-030 — UI / presentation deltas (engine+data)

**What.** FS-specific UI/sidebar/presentation changes.

**Data keys / evidence.**
- New sidebar cameos/icons: `MEMPICON` (Mobile EMP), `MSTLICON` (Mobile Stealth Generator), `MWARICON` (Mobile War Factory), `JUGGICON` (Juggernaut), `LIMPICON` (Limpet), `PODSICON` (Drop Pod), `REAPICON` (Reaper), `WEATICON` (Elite Cadre), plus new structure cameos (`TS CABAL Obelisk Cameo.gif`, etc.).
- New EVA/voice sets: Drop Pod `RechargeVoice=00-I506`; `[AudioVisual]` drop-pod marks. CABAL voice lines ("Listen to the sounds of your own extinction", "Activating defense protocol, Defender, now", "Miscalibration..."). New unit voice lines (`60-N1xx` Reaper, `15-I0xx` Elite Cadre, GDI Titan voice set reused for Juggernaut/Mobile EMP/MWF).
- Main menu/launcher lets the player choose Tiberian Sun or Firestorm; FS has its own title movie `FS_TITLE` (and `TS_TITLE` retained). FS intro `FSGDIINT`.
- Firestorm wall renders an animated barrier; cloak generators show a radial indicator (`HasRadialIndicator`, `RadialColor=255,0,0`).
- World Domination Tour: a turn-based meta-mode with a regional map UI (see FS-033).

**Edge cases.** The `PipScale=Charge` on Mobile EMP shows a charge pip. Mobile War Factory selection voice anomaly (Nod deployed form uses vehicle lines). Freeware port corrupted `movies03.mix` handling and moved FS cutscenes into `movies01.mix`.

**Kind.** engine+data (new sidebar entries, cameos, charge pip, radial cloak indicator).

**Sources.** FIRESTRM.INI; ARTFS.INI; https://cnc.fandom.com/wiki/Command_%26_Conquer:_Tiberian_Sun_-_Firestorm. **Confidence.** med (UI is partially inferable; no exhaustive UI doc found).

---

### FS-031 — Data/format and other changes (engine+data)

**What.** Structural/data changes tying it together.

**Data keys.**
- New INI files: `FIRESTRM.INI` (rules delta), `AIFS.INI` (AI delta), `ARTFS.INI` (art delta). Sound: `sound01.ini` replaces `sound.ini`. Themes: `theme01.ini` merged after `theme.ini`.
- New section entries added by FS (visible in FIRESTRM.INI): `[VehicleTypes]` adds REAPER, JFISH, JUGG, LIMPET, MOBILEMP, SGEN, MOBWARG, MOBWARN, FLMTNK, DEFENDER, CMOBILEMP. `[InfantryTypes]` adds HUEY, CIV4, CIV5, CIV6, ELCAD. `[BuildingTypes]` adds GAPLUG4, DJUGG, DLIMPET, C_KODIAK, DGWEAP, DNWEAP, MSTL, DDEFD, AAOB, CORE, CROB, INORNGLAMP. `[Warheads]` adds WebMass, LIMPY, CoreDefPlasmaWH. `[SuperWeaponTypes]` adds DropPodSpecial. `[ParticleSystems]`/`[Particles]`/`[Animations]`/`[TerrainTypes]` additions. `[LEVITATION]` and `[JumpjetControls] CloakDetectionRadius` sections/keys. New engine flags used: `IsLimpetDrone`, `IsLimpetMine`, `IsMobileEMP`, `IsCoreDefender`, `IsMobileWar`, `IsMobileStealth`, `IsJuggernaut`, `Webby`, `WebDuration`, `WebDurationVariation`, `WebRadius`, `WebbedInfantry`, `IsWebImmune`, `IgnoresFirestorm`, `CloakGenerator` (deployed), `CloakRadiusInCells`, `HasRadialIndicator`, `PipScale=Charge`, `MaxCharge`.
- Terrain overlays: `FONA01..FONA15` (Fona Tiberium plant) re-added as theater terrain; `BIGBLUE3` blue Tiberium tree (`SpawnsTiberium=yes, TiberiumToSpawn=2`); `GAWALL`/`NAWALL` Strength 225 with DamageLevels 2.

**Numbers.** See tables above.

**Edge cases.** `[INORNGLAMP]` ("Invisible Orange Light Post", image GALITE, `InvisibleInGame=yes`) is a lighting-only object used by maps. `[C_KODIAK]` ("Kodiak Crash") is a placeable doodad. `[WEEDGUY] Secondary=DualRockets, Elite=MobileEMPulseWeapon` is a data "hack" to make MultiMissile & MobileEMPulseWeapon work (per INI comment "Don't change data!"). `CoreDefPlasmaWH` is declared but undefined (likely leftover/unused).

**Kind.** engine+data (merge/loader and new engine flags), with the bulk as data.

**Sources.** FIRESTRM.INI; ARTFS.INI; AIFS.INI; ModEnc Rules.ini footnote. **Confidence.** high.

---

### FS-032 — World Domination Tour (mode) (engine)

**What.** A turn-based persistent-campaign multiplayer mode added in FS, later reused in Red Alert 2 / Yuri's Revenge. Players of each faction fight for regions on a world map; after some time ownership resets. Only playable on the original Westwood Online server; XWIS/CnCNet lack the code.

**Data keys.** Region lists stored in string files (30 regions per map). FS regions: North America (30) and Europe (30). RA2 adds East Asia (30).

**Numbers / lists.** FS North America: North Pacific, Northern Rockies, Dakotas, Black Hills, Lake Superior, Lawrence, Northern Gulf, New England, Sierra Nevada, Salt Lake, Great Divide, Great Plains, Western Gateway, Great Lakes, Appalachians, Southern Cal, Southern Desert, White Sands, Dodge, Ozarks, Ohio River, Roanoke, Gila Desert, Panhandle, Texas Gulf, Gulf Coast, Savannah, Baja, Sierra Madre, Southern Gulf. FS Europe: Eire, Britannia, Norway, Sweden, Finland, Bay of Biscay, La Seine, Germany, Poland, Baltic, Belarus, Ukraine, North Atlantic, Ebro, Gulf of Lions, Alps, Liguria, Adriatic Coast, Danube Delta, Black Sea, Sierra Morena, Sardinia, Tyrrhenia, Aegean Coast, Dardanelles, Mesopotamia, Gibraltar, South Med, Sahara, Tunisia.

**Edge cases.** Server-dependent (Westwood Online only). In the OpenTS roadmap, CnCNet support is a milestone but WDT itself is not part of parity targets; likely out of scope for a remake.

**Kind.** generic-engine (meta-game/session system) — but optional for a data-driven remake.

**Sources.** https://cnc.fandom.com/wiki/World_Domination_Tour; https://cnc.fandom.com/wiki/Command_%26_Conquer:_Tiberian_Sun_-_Firestorm. **Confidence.** high (mode/regions), med (exact mechanics).

---

### FS-033 — Firestorm Generator (shared TS/FS structure, CABAL-critical)

**What.** Central power source for a Firestorm barrier. Gathers energy then releases it into wall sections. If deactivated early, can be restarted but duration shortens; if fully drained, it is disabled until fully recharged. GDI built it in TS (Hammerfest); CABAL constructed its own with an effectively **unlimited** barrier around the Core.

**Data keys.** Building; `FirestormWall` sections produced by it; `[General] GDIFirestormGenerator`; powered structure.

**Numbers.** HP 800; Armor heavy; Cost 2000; build time 0:30; Power −200; Sight 5; TechLevel 9; required by Firestorm Wall Section (cost 50, Power −2, HP 200).

**Edge cases.** CABAL's unlimited generator is destroyed/powered down to open the Core. Destroying the generator is the "worst option" in Core of the Problem (must then fight Obelisks + Core Defender); destroying the 4 Advanced Power Plants is better.

**Kind.** engine+data (Firestorm system already TS; FS adds CABAL usage).

**Sources.** https://cnc-central.fandom.com/wiki/Firestorm_generator; https://cnc-central.fandom.com/wiki/Firestorm_wall_section; FIRESTRM.INI. **Confidence.** high.

---

## Consolidated "FS vs TS" delta list

**New roster — GDI**
- Juggernaut (`JUGG`) + Deployed Juggernaut (`DJUGG`) — 3-round artillery walker, deploy-to-fire.
- Mobile EM-Pulse (`MOBILEMP`) + Charged (`CMOBILEMP`) — charge/discharge EMP support vehicle.
- Mobile War Factory (`MOBWARG`/`DGWEAP`) — deployable war factory, BuildLimit 1.
- Limpet Drone (`LIMPET`/`DLIMPET`) — shared GDI/Nod recon mine; slows + shares vision.
- Drop Pod Control Plug (`GAPLUG4`) — Upgrade Center addon granting the Drop Pod support power.
- Riot Soldier — campaign-only non-lethal unit (map mod of Slavik).

**New roster — Nod**
- Cyborg Reaper (`REAPER`) — quad rocket + web cyborg walker.
- Mobile Stealth Generator (`SGEN`/`MSTL`) — deployable cloaking field.
- Fist of Nod (`MOBWARN`/`DNWEAP`) — Nod mobile war factory.
- Elite Cadre (`ELCAD`) — Black Hand heavy infantry (cyborg replacement).
- Huey the Infected Cyborg (`HUEY`) — campaign unit.
- Retro Flame Tank (`FLMTNK`) — redone TW1-style flame tank (civilian/crate).
- Limpet Drone (shared).

**New roster — CABAL**
- Cabal Core (`CORE`, HP 3000).
- CABAL Obelisk (`CROB`) — ground laser, 2× Obelisk bulk, fires through Firestorm.
- Obelisk of Darkness (`AAOB`) — AA-only laser, fires through Firestorm.
- Core Defender (`DEFENDER`/`DDEFD`) — 10 000 HP super-walker.
- CABAL uses all Nod hardware + all cyborgs + its own Firestorm generator.

**New lifeform**
- Tiberium Floater / Jellyfish (`JFISH`) — levitating attacker with `[LEVITATION]` movement.

**New weapons/warheads/projectiles/particles/anims**
- Weapons: `Jugg90mm`, `LIMP`, `WebLauncher`, `DualRockets`, `QuadLauncher`, `Tentacle`, `DEFOB`, `AALaserFire`, `CABLaser`, `MobileEMPulseWeapon`, `DropGun`; changed `Ballistic`, `Grenade`, `Bomb`, `SlimeAttack`.
- Warheads: `WebMass`, `LIMPY`, `CoreDefPlasmaWH` (declared/undefined), `Super2`, `MobileEMPulse`, `Stinger`, `WeakGas`.
- Projectiles: `DualCluster`, `WebCapsule`, `Ballistic2`, `AALLine`, `LimpetBullet`.
- Particle systems/particles: `WebSys`/`Web`, `GasPuffSys`/`WeakGasCloud(+D,M2)`, `SmokeStackSys`/`SmokeStackPuff`.
- 38 new animation IDs (web, MWAR, MSTL, DJUGG, CORE, OBL1/2, DEFD, MEMPFX, DLIMP, K_LIGHT).
- New `[AudioVisual]` keys `WebbedInfantry`, `DropPod`; `[LEVITATION]`; `[JumpjetControls] CloakDetectionRadius`.

**Rules / global changes**
- Veteran system retuned (`VeteranRatio=5.0`, `VeteranCombat=.50`, `VeteranSpeed=.30`, `VeteranSight=0`, `VeteranArmor=.50`, `VeteranROF=.30`, `VeteranCap=2`, `InitialVeteran=no`).
- `BallisticScatter` 1.5→2.0; Artillery `Ballistic` gets `Arcing`.
- `EngineerCaptureLevel=1.0`, `EngineerDamage=0.0` (always capture, never damage).
- `SurvivorRate` .4→.1; `SurvivorDivisor=100`.
- Drop pod: min 3→5, max 5→8, `DropPodWeapon=DropGun`.
- Factory prereqs now include mobile war factories (`GAWEAP,NAWEAP,DGWEAP,DNWEAP`) for `PrerequisiteFactory` and `[AI] BuildWeapons`.
- Per-unit rebalances: Mobile EMP (HP 600→800, speed 3→7, cost 1400→1000, MaxCharge 1200→1800), Juggernaut/Reaper/Limpet/Mobile WF/Fist of Nod/Mobile Stealth re-costed, Scrin cost 1500→1250, Apache 1000→800, Jumpjet speed 8, Tank strength 200, wall HP 225, etc.

**Tiberium / terrain / ecology**
- Fona Tiberium plants (`FONA01..15`) re-added as theater terrain.
- Blue Tiberium Tree (`BIGBLUE3`) spawns Tiberium.
- Tiberium mosss/growth re-added (ModEnc: "Tiberium plants (Fona), and Tiberium growth (Moss)").
- New Floater lifeform; Genesis Pit (Nod M2) is a map feature used to lure/spawn lifeforms.

**Campaign**
- 18 new missions (9 GDI "Desperate Measures" + 9 Nod "From the Ashes"), all canon, simultaneous; FMV briefing for every mission; no side missions.

**Maps**
- 14 new skirmish/multiplayer maps (FS set).

**Mode**
- World Domination Tour (turn-based persistent meta-mode), Westwood Online only.

**Format / launcher**
- `expand01.mix` + `firestrm.ini` detection; `AIFS.INI`, `ARTFS.INI`, `sound01.ini`, `theme01.ini`.
- Launcher lets the player choose TS or FS.

---

## Coverage checklist (scope → findings)

| # | Scope item | Covered by | Status |
|---|---|---|---|
| 1 | GDI units/structures + stats (Juggernaut, Mobile EMP, Mobile War Factory, Firestorm Generator, Limpet, others) | FS-001…FS-008, FS-033 | ✔ |
| 2 | Nod units/structures (Cyborg Reaper, Mobile Stealth Gen, Mobile War Factory, AA Obelisk, others) | FS-009…FS-016 | ✔ |
| 3 | CABAL faction (Core Defender, CABAL Obelisk, Cabal Core, all CABAL content) | FS-015…FS-019 | ✔ |
| 4 | New weapons/warheads/projectiles/particles/anims + parameters | FS-021, FS-022 | ✔ |
| 5 | ALL rule changes vs TS (drop pods, BallisticScatter, EngineerCaptureLevel/Damage, ChargeToDrainRatio, DamageToFirestormDamageCoefficient, CraterLevel, veinhole, tech/costs) | FS-025, FS-026 (+ FS-031) | partial — `CraterLevel`/veinhole tuning not found in FS INI (see FS-Q5) |
| 6 | New superweapons/support powers (Firestorm barrier, mobile EMP, mobile stealth, mutate) | FS-003/010/026/033; mutate = Floater (FS-020) | ✔ with note |
| 7 | Campaign: full GDI/Nod mission lists, objectives, briefings, scripted events | FS-027, FS-028 | ✔ |
| 8 | Maps, theaters/ecology tiles, scenario flag `Firestorm=yes` gating | FS-029, FS-000, FS-031 | ✔ maps/ecology; scenario flag = expansion detection (FS-Q2) |
| 9 | UI changes/deltas | FS-030, FS-032 | partial — no exhaustive UI diff doc exists |
| 10 | Data/format changes (rules/art/ai merges, new sections) | FS-000, FS-023, FS-024, FS-031 | ✔ |

---

## Open questions / uncertainties

- **FS-Q1 (med):** Riot Soldier exact statline. It is a map-specific modification of the Anton Slavik unit (`SLAV`); no standalone rules entry. Its "subdue → neutral" behaviour is engine/mission-side, so a remake must decide whether to model it as a weapon effect or a script.
- **FS-Q2 (med):** There is **no confirmed per-map `Firestorm=yes` flag**. Firestorm mode is detected at the installation level (`expand01.mix` + `firestrm.ini`), and maps simply reference FS objects. If a map-level flag exists in the retail map format, I could not verify it from web sources; treat as an engine/data-loader concern.
- **FS-Q3 (low):** `[CoreDefPlasmaWH]` is declared in `[Warheads]` but has no definition in `FIRESTRM.INI`; the Core Defender actually uses `Super2`. Likely unused/leftover.
- **FS-Q4 (med):** Core Defender moving fire. The wiki says it fires while moving, but `FIRESTRM.INI` sets `NoMovingFire=true`. `IsCoreDefender` engine behaviour may override, or the wiki is describing the "shoot on the move" design intent; needs engine-level verification.
- **FS-Q5 (med):** Scope item 5 explicitly names `CraterLevel` and veinhole tuning. I found no FS `CraterLevel` override and no veinhole numeric change in `FIRESTRM.INI`; suspected the ask conflates these with TS-era globals or a different rules file not archived. Verify against a full retail `rules.ini`/`firestrm.ini` dump.
- **FS-Q6 (low):** "Mutate" as a Firestorm superweapon appears to be a misattribution — the only superweapons in the archive are Chemical/Multi Missile, Firestorm, Hunter-Seeker/Seeker, and the new DropPod. The likely intended item is the **Tiberium Floater** (mutation-cloud/floating lifeform) and the Genesis Pit. Confirm before modelling a "mutate" power.
- **FS-Q7 (low):** Elite Cadre cost conflict ($300 in infobox vs $350 in wiki prose; INI says 300). Resolve in favour of the INI (300).
- **FS-Q8 (med):** The `aifs.ini` archive shows no CABAL-specific AI; CABAL's behaviour is entirely scripted. A unified engine needs a scripting layer, not just data.
- **FS-Q9 (med):** Firestorm patch 2.03 is the shipping baseline; OpenTS targets "Tiberian Sun 2.03 Firestorm". Some FS balance values in this document come from the archived post-2.03 INIs and may differ slightly from the original 2000 retail disc (pre-patch). Cross-check against the disc if bit-exact parity matters.
