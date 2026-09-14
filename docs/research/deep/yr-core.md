# Yuri's Revenge — Core Engine Mechanics (delta over Red Alert 2)

Research scope: engine-level mechanics new or changed in *Command & Conquer: Red Alert 2 —
Yuri's Revenge* (Westwood, 2001), intended as the reference for a YR data package layered on the
unified Redot engine. Roster content (units, buildings, art) is out of scope; only the mechanics,
tags, parameters and edge cases are enumerated.

Method: web sources only. Ground truth is the community modding reference ModEnc, the stock
`rulesmd.ini` posted as a public gist (all concrete default values below), the Ares 3.0
documentation (used for how the *vanilla* engine handles each superweapon type, since Ares
documents vanilla defaults explicitly), the CnC Wiki patch 1.001 changelog, and EA's official
patch notes. Every block carries sources and a confidence rating.

Convention: `Tag` names are written as they appear in the INI. Values in **Numbers** are the
stock YR defaults unless labelled otherwise. A **Conflict** line flags sources that disagree.

---

## 1. Files, executables and packaging

### YR-CORE-001 — The `md` (Mission Disk) file split

**What:** YR ships as a separate `ra2md.exe` with its own data tree. Every data file that existed
in RA2 gains an `md` suffix for YR, and the YR files are complete replacements, not overrides of
the RA2 files: `rulesmd.ini`, `artmd.ini`, `aimd.ini`, `soundmd.ini`, `evamd.ini`, `uimd.ini`,
and the theater files (`temperatmd.ini`, `snowmd.ini`, `urbmd.ini`, `lunarmd.ini`). A YR data
package therefore cannot layer on RA2 INIs by inheritance at the file level — it must supply its
own full files or run a merge/override step in the engine.

**Data keys:** file names / mix archives. `expandmd##.mix` are the expansion mix archives for YR
(the 1.001 patch changed the loader from `expand##.mix` to `expandmd##.mix`, which is what makes
version-specific assets possible).

**Numbers:** n/a.

**Edge cases:** the 1.001 patch's main engine change is exactly this mix-name switch; a mod built
for 1.000 that put assets in `expand##.mix` stops loading them under 1.001 unless renamed.

**Kind:** yr-data + generic-engine (archive-name dispatch is engine-side).

**Sources:** https://modenc.renegadeprojects.com/Yuri%27s_Revenge ;
https://modenc.renegadeprojects.com/YR_Patch ;
https://cnc.fandom.com/wiki/Yuri%27s_Revenge_patch_1.001

**Confidence:** high.

### YR-CORE-002 — New command-line switches

**What:** YR's `ra2md.exe` accepts the RA2 switches plus:
- `-DLINK1` — unknown, network-related.
- `-SPEEDCONTROL` — unlocks the Game Speed slider in campaign mode (normally only available in
  non-campaign modes) when the pause menu's Game Controls window is open.

RockPatch adds `-LOG`, `-OUTMISSINGSTRS`. Ares adds `-CD`, `-NOLOGO`, `-LOG`, `-LOG-CSF`,
`-STRICT`, `-AI-CONTROL`, `-AFFINITY:N`. The Ares/RockPatch flags are **not** vanilla YR and
should be treated as mod-loader extensions.

**Data keys:** CLI only.

**Numbers:** `-AFFINITY:N` bitmask, one bit per CPU starting at 1; default 1 (first CPU); 0
disables.

**Edge cases:** `-AFFINITY` off-by-default single-CPU affinity exists because the engine is not
multi-core-safe.

**Kind:** generic-engine (vanilla: `-DLINK1`, `-SPEEDCONTROL`); extensions are mod-engine.

**Sources:** https://modenc.renegadeprojects.com/Yuri%27s_Revenge

**Confidence:** high for the vanilla two; medium for Ares/RockPatch specifics.

---

## 2. Version 1.001 patch mechanics

### YR-CORE-003 — Patch 1.001 engine + INI deltas

**What:** The only official YR patch. Engine-side: `expandmd##.mix` loader change (see YR-CORE-001).
INI/balance-side changes relevant to engine semantics:
- `[YURIPR]` gains `ImmuneToPsionicWeapons=yes` (Yuri Prime becomes immune to psychic damage).
- `[PsiPulse]` gains `AffectsAllies=no` (psi-pulse deploy stops hurting allies; default is
  `yes`).
- `[GUARDWH]` gains `CellSpread=.5` and `PercentAtMax=.5`.
- Gattling anti-ground weapons `AGGattling`, `AGGattling2`, `AGGattling3` and their Elite variants
  go from `Range=5` to `Range=6`.
- `[MagneticBeamE]` range 10 → 12.
- `BuildTimeMultiplier` added to several units; Apocalypse `BuildTimeMultiplier=1.0`; Tesla
  Tank/Crazy Ivan/MCV/Apocalypse/Slave Miner/Refinery rebalanced.
- Hero units (Flint Westwood / Sammy Stallion / Arnnie Frankenfurter) are re-voiced to standard
  GI voices and renamed; `[GHOST]` gains `CreateSound=SealCreated`.

**Data keys:** per-section; see sources for the full diff.

**Numbers:** as above.

**Edge cases:** the deploy/undeploy mind-control exploit fix was also added in 1.001 (an engine
check, see YR-CORE-011). `SellUnit` action was retired after 1.001 (see YR-CORE-014).

**Kind:** yr-data (INI values) + generic-engine (mix loader, `ConstructionYard` check,
`AffectsAllies` gating).

**Sources:** https://modenc.renegadeprojects.com/YR_Patch ;
https://cnc.fandom.com/wiki/Yuri%27s_Revenge_patch_1.001 ;
https://cnc-comm.com/red-alert-2/downloads/patches/yuris-revenge-1.001

**Confidence:** high.

---

## 3. Houses, countries and sides

### YR-CORE-004 — Country/side registry and the hard house-array order

**What:** `[Countries]` is a zero-based list; `[Sides]` groups countries into sides. RA2 has two
playable sides (GDI/Allied and Nod/Soviet); YR adds a third, `ThirdSide`, containing exactly one
country, `YuriCountry`, inserted at index 9. The first **nine** indices are a hard array whose
order must not change:

`0=Americans 1=Alliance 2=French 3=Germans 4=British 5=Africans 6=Arabs 7=Confederation 8=Russians 9=YuriCountry 10=GDI 11=Nod 12=Neutral 13=Special`

`[Sides]`: `GDI=British,French,Germans,Americans,Alliance`, `Nod=Russians,Africans,Confederation,Arabs`, `ThirdSide=YuriCountry`, `Civilian=Neutral`, `Mutant=Special`.

The stock file carries an explicit warning: do not remove, override or reorder the major nine
houses — they must be first in the house array, uninterrupted — or skirmish/LAN maps crash. Art
assets (`flag` PCX, loading-screen SHP, palette) and CSF tooltip/loading strings are bound to the
country **index**, not the name; index 9 is hardcoded to Yuri (`yrii.pcx`, `ls800yuri.shp`,
`mpyls.pal`), and YR is the first game where load-screen palettes are per-country (RA2 shares
`mpls.pal`).

**Data keys:** `[Countries]` list entries; `[Sides]`; per-country `UIName`, `Name`, `Suffix`,
`Prefix`, `Color`, `Multiplay`, `MultiplayPassive`, `Side`, `SmartAI`, `ParentCountry`,
`VeteranAircraft`, `VeteranUnits`, `VeteranInfantry`, the `*Mult` family (YR-CORE-005),
`IncomeMult`, `Firepower`, `WallOwner`, `PowerPlant`/`PowerPlants`.

**Numbers:** 9 fixed indices; index 9 = Yuri; 14 countries total in stock (0–13).

**Edge cases:** `Name=` creates an alternate internal alias usable anywhere `Owner=` accepts the
section name. `Side=` only selects EVA/GUI/actions; starting units and tech tree follow the
country's `[Sides]` membership. `MultiplayPassive=yes` marks non-selectable countries (GDI, Nod,
Neutral, Special). Adding a third side therefore requires a free contiguous country slot and new
CSF/art bound to that index.

**Kind:** generic-engine (side/array semantics) + yr-data (YuriCountry, ThirdSide).

**Sources:** https://modenc.renegadeprojects.com/Countries ;
https://modenc.renegadeprojects.com/ParentCountry

**Confidence:** high.

### YR-CORE-005 — Per-country bonus model

**What:** Countries can grant unit-veterancy gifts and multiplier bonuses.
- `VeteranInfantry=`, `VeteranUnits=`, `VeteranAircraft=` — comma lists; units built start at
  veteran and, per ModEnc, are auto-added to the relevant `[InfantryTypes]`/`[VehicleTypes]`/
  `[AircraftTypes]` arrays.
- `YYYZZZMult=` where `YYY` ∈ {`Armor`, `Cost`, `Speed`, `BuildTime`} and `ZZZ` ∈ {`Aircraft`,
  `Units`, `Infantry`, `Buildings`, `Defenses`}. Nonsensical cross-products (e.g.
  `SpeedBuildingsMult`) logically do nothing.
- `IncomeMult=` — special case: multiplies ore value when **this house's** harvesters unload.
- `Firepower=`, `WallOwner=`, plus legacy `BuildTime=`, `Cost=`, `ROF=`, `Airspeed=`,
  `Groundspeed=`, `PowerPlant`/`PowerPlants`.

**Data keys:** all of the above, placed in the country section (`[Americans]` etc.) or a map
`[Houses]` section.

**Numbers:** all `*Mult` values are straight multipliers on baseline engine values. Stock YR ships
the per-country bonuses **commented out** (e.g. America `;CostUnitsMult=.85`, Iraq
`;IncomeMult=1.2`, Britain `;VeteranInfantry=GHOST,SNIPE`); the hooks are engine-supported but not
used in the default rules.

**Edge cases:** `IncomeMult` does not follow the `YYYZZZMult` naming logic. `VeteranXXX` values
that are not owned by the country can error. Veteran-to-Elite promotion itself still uses the
global `[General]` veteran factors (`VeteranRatio=3.0`, `VeteranCombat=1.1`, `VeteranSpeed=1.2`,
`VeteranArmor=1.5`, `VeteranROF=0.6`, `VeteranCap=2`), inherited from RA2.

**Kind:** generic-engine (bonus application) + yr-data (which bonuses YR ships).

**Sources:** https://modenc.renegadeprojects.com/VeteranInfantry ;
https://modenc.renegadeprojects.com/IncomeMult ;
https://modenc.renegadeprojects.com/Countries

**Confidence:** high for tags; medium for whether every multiplier is actually consumed in YR
(ModEnc flags some as possibly leftover).

---

## 4. Mind control — complete model

### YR-CORE-006 — Temporary warhead control (`MindControl`)

**What:** `MindControl=yes` on a **warhead** turns a hit into an instant possession instead of
damage; the weapon's projectile can miss and the effect still applies. The firer must have a valid
targeting path. The link is drawn with `YURICNTL` (warhead `AnimList`).

**Data keys:** warhead `MindControl`; `Verses` (must rate the target’s armor class non-zero);
weapon `Primary`/`ElitePrimary`, `Damage` (capacity, see below), `ROF`, `Range`, `Projectile`,
`FireOnce`, `OmniFire`; global `[AudioVisual] YuriMindControlSound`; `[CombatDamage]
MindControlAttackLineFrames` (line redraw cadence).

**Numbers:** stock `[MindControl]` weapon: `Damage=1`, `ROF=200`, `Range=7`, `Projectile=
PsychicControl`, `Speed=100`, `Warhead=Controller`, `FireOnce=yes`. Warhead `[Controller]
Verses=100,100,100,100,100,100,0,0,0,100,100` (cannot affect the three vehicle armor classes) and
`MindControl=yes`. `[General] MindControlAttackLineFrames=20`.

**Edge cases:**
- Control is one-to-one: a second shot releases the first target, unless the weapon's `Damage`
  capacity is >1 (YR-CORE-007).
- The capacity is read from the **Primary** weapon `Damage` only; `ElitePrimary` damage is
  ignored even when elite.
- No `CellSpread` support and no sub-weapon support (`ShrapnelWeapon`, `AirburstWeapon`, etc.) —
  the mind-control warhead is strictly one target.
- Putting `MindControl=yes` on a secondary warhead while the primary is not, triggers
  `EIP#00471CA4`; same for an `OccupyWeapon` warhead on a structure whose primary is not MC
  (fixed in Ares 0.1).
- MC “parasites” draw the link to the point on the map where the parasite entered (Ares 0.1 fix).
- Aircraft can only be MC’d if a valid anti-air MC weapon exists.

**Kind:** generic-engine (RA2 flag, extended in YR), YR adds multi-target capacity.

**Sources:** https://modenc.renegadeprojects.com/MindControl ;
https://modenc.renegadeprojects.com/MindControlAttackLineFrames ;
stock rules gist (weapons)

**Confidence:** high.

### YR-CORE-007 — Multi-target and infinite mind control

**What:** In YR, the Primary weapon `Damage` is the **number of simultaneous MC links**. Values
>1 keep already-established links when a new target is acquired; once the cap is reached, no new
target can be captured until an old victim dies (and the unit cannot even fire on a further
target with primary or secondary). `InfiniteMindControl=yes` on the **weapon** ignores `Damage`
as the cap and switches to the overload table.

**Data keys:** weapon `Damage`, `InfiniteMindControl`; global `[CombatDamage] OverloadCount`,
`OverloadDamage`, `OverloadFrames`.

**Numbers:** Mastermind weapon `[MultipleMindControlTank] Damage=3`, `InfiniteMindControl=yes`,
`ROF=10`, `Range=6`, `OmniFire=yes`, `FireOnce=yes`. Psychic Tower weapon
`[MultipleMindControlTower] Damage=3`, `ROF=100`, `Range=7`, `FireOnce=yes`. Standard Yuri
`[MindControl] Damage=1`.

**Edge cases (documented bugs):**
- With `InfiniteMindControl=yes`, the unit can control **unlimited** targets even if the weapon’s
  `Damage=0`.
- With `InfiniteMindControl=yes` and `Damage=1`, only **one** target can be controlled (the
  `Damage=1` special case still caps).
- Both fixed in Phobos.

**Kind:** generic-engine (YR-only).

**Sources:** https://modenc.renegadeprojects.com/InfiniteMindControl ;
https://modenc.renegadeprojects.com/MindControl

**Confidence:** high.

### YR-CORE-008 — Mastermind overload table

**What:** When a controller exceeds the first `OverloadCount` threshold, it takes damage at each
category. The engine picks the **largest category whose `OverloadCount` ≥ current link count**
(last entry is effectively “and above”) and applies that category’s `OverloadDamage` once every
that category’s `OverloadFrames` frames. `OverloadDamage=0` is a no-damage tier used by the stock
Mastermind.

**Data keys:** `OverloadCount`, `OverloadDamage`, `OverloadFrames` (all in `[CombatDamage]`);
`ControlledAnimationType`, `PermaControlledAnimationType`, `MindControlAttackLineFrames`;
`[AudioVisual] MasterMindOverloadDeathSound`.

**Numbers:** `OverloadCount=3,6,10,50`; `OverloadDamage=0,50,100,500`;
`OverloadFrames=30,60,60,60`. `ControlledAnimationType=MINDANIM`;
`PermaControlledAnimationType=MINDANIMR`.

**Edge cases:** `OverloadCount=1` makes the unit re-target instead of ever overloading (per
ModEnc). The table is global, not per-unit, so all `InfiniteMindControl` units share it.

**Kind:** generic-engine (YR-only).

**Sources:** https://modenc.renegadeprojects.com/OverloadCount ;
https://modenc.renegadeprojects.com/OverloadDamage ;
https://modenc.renegadeprojects.com/OverloadFrames ; stock rules gist

**Confidence:** high.

### YR-CORE-009 — Psionic immunity and psychic damage

**What:** Two distinct immunity axes:
- `ImmuneToPsionics=yes` — blocks `MindControl=yes` warheads, `Psychedelic=yes` (berserk)
  warheads, and the permanent capture of `Type=PsychicDominator`. Buildings **default to yes**
  (all other techno types default no); Yuri Prime’s building-capture relies on both a non-zero
  `Verses` on the warhead **and** `ImmuneToPsionics=no` set broadly across buildings.
- `ImmuneToPsionicWeapons=yes` — blocks `PsychicDamage=yes` warheads only. Default is “yes if
  `ImmuneToPsionics=yes` or the unit has the PSIONICSIMMUNE veteran ability, otherwise no”.
  `ImmuneToPsionics` and `ImmuneToPsionicWeapons` are independent: a unit can resist MC but still
  take psychic damage or vice versa. Buildings default to `ImmuneToPsionicWeapons=yes`.

**Data keys:** `ImmuneToPsionics`, `ImmuneToPsionicWeapons` (TechnoTypes); warhead `PsychicDamage`;
`[AudioVisual] InfantryHeadPop=YURIDIE` (InfDeath 6 anim).

**Numbers:** `Type=PsychicDominator` will not capture buildings — hardcoded, not overridable.

**Edge cases:** `ImmuneToPsionicWeapons` only gates whether the warhead affects the target; it does
not gate target selection, so the AI will still shoot. Stock `[PsiPulse]`/`[SuperPsiPulse]` use
`PsychicDamage=yes` (InfDeath 6 = “head pop”, `YURIDIE`). Patch 1.001 gives Yuri Prime
`ImmuneToPsionicWeapons=yes`.

**Kind:** generic-engine (YR-only flags; `ImmuneToPsionics` exists in RA2).

**Sources:** https://modenc.renegadeprojects.com/ImmuneToPsionics ;
https://modenc.renegadeprojects.com/ImmuneToPsionicWeapons ;
https://modenc.renegadeprojects.com/PsychicDamage

**Confidence:** high.

### YR-CORE-010 — Permanent Psychic Dominator capture

**What:** `Type=PsychicDominator` superweapon. After a delay/animation it deals `DominatorDamage`
using `DominatorWarhead`, then permanently MCs eligible units within `DominatorCaptureRange`.
Building capture is hardcoded off. Damage and capture are separate concerns: `SW.Range` (Ares) and
the stock `DominatorCaptureRange` govern capture; the warhead governs damage.

**Data keys (`[General]`):** `DominatorWarhead=DominatorWH`, `DominatorDamage=1000`,
`DominatorCaptureRange=1`, `DominatorFirstAnim=PDFXCLD`, `DominatorSecondAnim=PDFXLOC`,
`DominatorFireAtPercentage=20`. Per-SW `[PsychicDominatorSpecial]`: `Type=PsychicDominator`,
`Action=PsychicDominator`, `RechargeTime=10`, `Range=1.4`, `LineMultiplier=3`, `IsPowered=true`,
`ShowTimer=yes`, `DisableableFromShell=yes`, `SidebarImage=PDOMICON`.

**Numbers:** `DominatorCaptureRange` accepts larger values but effective cap is 11 cells.
`DominatorFireAtPercentage=20` means the strike fires after 20% of the first animation’s frames.
Building `[YAPPET]` (cost 5000, `Power=-200`, TechLevel 10, `BuildLimit=1`, `RevealToAll=yes`).

**Edge cases:**
- Capture range is a circular plane; air units are not captured.
- Ares documents that the vanilla defaults capture both normal and already-MC’d/perma-MC’d units
  (`Dominator.CaptureMindControlled=yes`, `Dominator.CapturePermaMindControlled=yes`), do **not**
  ignore `ImmuneToPsionics` (`Dominator.CaptureImmuneToPsionics=no`), and are permanent
  (`Dominator.PermanentCapture=yes`). In vanilla, permanent victims cannot be re-captured by
  ordinary MC.
- `SW.Range` and `DominatorDamage` are Ares names; stock YR only exposes the `Dominator*` globals.

**Kind:** generic-engine (the `PsychicDominator` type is YR-hardcoded).

**Sources:** https://modenc.renegadeprojects.com/DominatorCaptureRange ;
https://modenc.renegadeprojects.com/DominatorDamage ;
https://modenc.renegadeprojects.com/Type ;
https://ares-developers.github.io/Ares-docs/new/superweapons/types/psychicdominator.html ;
stock rules gist

**Confidence:** high.

### YR-CORE-011 — Link lifecycle, release conditions and interaction bugs

**What:** Mind-control links end or misbehave under several conditions:
- **Controller dies / link released** — the victim reverts to its original owner; `MindClearedSound`
  plays.
- **Original owner defeated while MC’d** — on release the victim goes to the **neutral** house. If
  the victim is an MCV this commonly triggers `EIP#00505E41` (Internal Error).
- **Deploy/undeploy exploit** — `MindControl` plus `DeploysInto`/`UndeploysInto` severs the link
  and permanently changes ownership; the free unit does not count against the MC limit. Westwood
  added a 1.001 check for `ConstructionYard=yes` on the conversion target to stop a mind-controlled
  MCV from deploying (and a Construction Yard from undeploying) — but this only blocks the specific
  case, not type conversion generally. Phobos transfers the link correctly instead.
- **Garrison interaction** — infantry under mind control cannot garrison; `Occupier=yes` is made
  inert for them (RA2 behaviour, carried into YR). Spies/Engineers are exempt because they are
  consumed on entry.
- **AI target acquisition** — in YR, `Insignificant=yes` units that are mind-controlled are still
  treated as valid targets by the AI (a new YR check).
- **Pip display** — `PipScale=MindControl` shows one pip per `Damage` (capacity), with an extra
  “overload” pip when an `InfiniteMindControl` unit exceeds its pips. A `PipScale=MindControl`
  techno with no primary weapon throws `IE=007162B6`.
- **Serialization** — MC links are part of the live object graph and therefore saved with the
  scenario; there is no documented per-tag switch to disable it.

**Data keys:** `PipScale=MindControl`, `PipsDrawForAll`; `[AudioVisual] MindClearedSound`;
`Insignificant`; `DeploysInto`/`UndeploysInto`; `ConstructionYard`.

**Numbers:** stock `[MultipleMindControlTank] Damage=3` → 3 pips.

**Edge cases:** releasing to neutral can break win conditions because a neutral MCV is not a
player asset. `PipScale=MindControl` with very large `Damage`, `GuardRange`, `Range` or
`SpawnsNumber` causes severe slowdowns.

**Kind:** generic-engine.

**Sources:** https://modenc.renegadeprojects.com/MindControl ;
https://modenc.renegadeprojects.com/PipScale ;
https://modenc.renegadeprojects.com/Insignificant

**Confidence:** high for the listed bugs; medium for savegame specifics (no authoritative page
found).

### YR-CORE-012 — Building control and Yuri Prime

**What:** Building mind control is achieved with a dedicated weapon/warhead pair, not by the
`PsychicDominator` superweapon:
- `[SuperMindControl]` weapon: `Damage=1`, `ROF=200`, `Range=7`, `Projectile=PsychicControl`,
  `Warhead=ControllerBuilding`, `FireOnce=yes`.
- `[ControllerBuilding]` warhead: `Verses` = 100 for all armor classes, `MindControl=yes`,
  `AnimList=YURICNTL`.

Yuri Prime (`[YURIPR]`) uses `Primary=SuperMindControl`, `Secondary=SuperPsiWave`,
`OpenTransportWeapon=1`, `Deployer=yes`, `DeployFire=yes`, `UndeployDelay=75`, `Strength=150`,
`Armor=flak`, `BuildLimit=1`, `ImmuneToPsionics=yes`. Because buildings default to
`ImmuneToPsionics=yes`, YR’s designers set `ImmuneToPsionics=no` broadly on the buildings Yuri
Prime is meant to capture; the `Verses` must also be non-zero.

**Data keys:** `Primary`/`Secondary` weapons; warhead `ControllerBuilding`; `ImmuneToPsionics`;
`Deployer`, `DeployFire`, `UndeployDelay`, `OpenTransportWeapon`; `Deployer` is infantry-only.

**Numbers:** Yuri Prime in 1.001 also gains `ImmuneToPsionicWeapons=yes`.

**Edge cases:** `OccupyWeapon` with an MC warhead while the structure’s primary is not MC throws
`EIP#00471CA4` (Ares 0.1 fix). Deployable infantry + cyborg logic conflict (see YR-CORE-039).

**Kind:** generic-engine (YR adds building-capable MC and the warhead pair).

**Sources:** stock rules gist ([YURIPR], [SuperMindControl], [ControllerBuilding]) ;
https://modenc.renegadeprojects.com/MindControl

**Confidence:** high.

---

## 5. Gattling weapon system

### YR-CORE-013 — `IsGattling` spooling

**What:** The Gattling system splits the `WeaponX` list into stages of two weapons, alternating
anti-ground (odd) and anti-air (even). A per-unit firing timer advances the stage; it increases
`RateUp` per frame while firing and decreases `RateDown` per frame while not firing. `StageX`
values are **endpoints** that divide the timer, not durations.

**Data keys:** `IsGattling`, `TurretCount`, `WeaponCount`, `Weapon1..WeaponN`,
`EliteWeapon1..EliteWeaponN`, `WeaponStages`, `StageX`, `EliteStageX`, `RateUp`, `RateDown`.
Read order matters: `TurretCount≥1` must be set or the engine throws `EIP#0070DF8A` when
processing `Report`. `WeaponCount` must equal `WeaponStages*2` (fewer → `EIP#0070DF8A`; more is
allowed but the extras are only reachable via `NoAmmoWeapon`).

**Numbers (Gattling Tank `[YTNK]`):** `TurretCount=1`, `WeaponCount=6`, `WeaponStages=3`,
`Stage1=200`, `Stage2=400`, `Stage3=600`, `EliteStage1=100`, `EliteStage2=200`,
`EliteStage3=300`, `RateUp=1`, `RateDown=50`. Gattling Cannon `[YAGGUN]` uses the same stage
numbers with building turret animation. `TurretCount` also makes the engine load
`<name>turN.vxl/hva` instead of `<name>tur.vxl/hva`.

**Edge cases:**
- `StageX` need not be increasing. If `Stage1=400, Stage2=200, Stage3=600`, forward timing jumps
  1→3 and reverse timing falls 3→1; a single frame is spent in the unreachable stage 2.
- At an exact transition boundary the higher stage still gets one frame.
- `RateDown=0` resets the timer instantly on losing the target rather than holding it; you cannot
  make a non-downgrading gattling with it.
- `RateUp`/`RateDown` are signed; negative `RateDown` makes the unit “self-wind” from creation,
  but the first attack always uses stage-1 weapons, so a dummy first-stage weapon is needed.
- Higher-stage weapons that cannot fire at the target cause a fallback to lower stages; combined
  with `Verses` this gives the “multi-weapon per stage” trick.
- `FireOnce=yes` + `RateDown=0` can be used as an energy-accumulator charge pattern, but
  `FireOnce` defeats `Burst`; Ares adds `Gattling.Cycle` for auto-cycling.
- Under the vanilla engine, a unit always opens with the first-stage weapon.

**Kind:** generic-engine (YR-introduced system).

**Sources:** https://modenc.renegadeprojects.com/Gattling_Weapon_System ;
https://modenc.renegadeprojects.com/IsGattling ;
https://modenc.renegadeprojects.com/WeaponStages ;
https://modenc.renegadeprojects.com/TurretCount ;
https://modenc.renegadeprojects.com/RateUp ; stock rules gist

**Confidence:** high.

---

## 6. Superweapons

### YR-CORE-014 — `Type=` and `Action=` registries

**What:** A `SuperWeaponType` selects an engine routine with `Type=` and a targeting/cursor
delivery method with `Action=`. `Type` and `Action` are hardcoded enums; a value that does not
exist cannot be invented in INI. An Action can be used only **once** in the whole ruleset. If the
Action is missing/invalid, the SW fires immediately at a random map point.

**Data keys:** `[SuperWeaponTypes]` list; per-SW `Type`, `Action`, `SidebarImage`, `RechargeTime`,
`Range`, `LineMultiplier`, `IsPowered`, `ShowTimer`, `DisableableFromShell`, `AIDefendAgainst`,
`SpecialSound`, `StartSound`, `FlashSidebarTabFrames`, `PreClick`, `PostClick`,
`PreDependent`, `WeaponType`, `UseChargeDrain`.

**Numbers — YR `Type` values:** RA2 gave `MultiMissile=0x00`, `IronCurtain=0x01`,
`LightningStorm=0x02`, `ChronoSphere=0x03`, `ChronoWarp=0x04`, `ParaDrop=0x05`, `AmerParaDrop=0x06`.
YR adds `PsychicDominator=0x07`, `SpyPlane=0x08`, `GeneticConverter=0x09`, `ForceShield=0x0A`,
`PsychicReveal=0x0B`. TS-only values (`Firestorm`, `HunterSeeker`, `ChemMissile`, `DropPod`, etc.)
are not valid in YR.

**Numbers — YR `Action` values:** YR adds `PsychicDominator=0x42`, `SpyPlane=0x43`,
`GeneticConverter=0x44`, `ForceShield=0x45`, `NoForceShield=0x46`, `PsychicReveal=0x48`
(`Airstrike=0x47` also exists). `SellUnit` (0x0D) was retired after 1.001.

**Stock `[SuperWeaponTypes]` order:** `1=NukeSpecial 2=IronCurtainSpecial 3=LightningStormSpecial
4=ChronoSphereSpecial 5=ChronoWarpSpecial 6=ParaDropSpecial 7=AmericanParaDropSpecial
8=PsychicDominatorSpecial 9=SpyPlaneSpecial 10=GeneticConverterSpecial 11=ForceShieldSpecial
12=PsychicRevealSpecial`.

**Edge cases:** `Type=ForceShield` is hardcoded to work only with building targets. `SellUnit`
action on a unit inside a Tank Bunker triggers an IE when the bunker is sold/destroyed.

**Kind:** generic-engine (YR-hardcoded types/actions) + yr-data (which SWs use them).

**Sources:** https://modenc.renegadeprojects.com/Type ;
https://modenc.renegadeprojects.com/Actions ; stock rules gist

**Confidence:** high.

### YR-CORE-015 — Psychic Dominator superweapon object

**What:** See YR-CORE-010 for behaviour. SW section is `[PsychicDominatorSpecial]`.

**Data keys/numbers:** `Type=PsychicDominator`, `Action=PsychicDominator`, `RechargeTime=10`
(minutes), `Range=1.4`, `LineMultiplier=3`, `IsPowered=true`, `ShowTimer=yes`,
`DisableableFromShell=yes`, `SidebarImage=PDOMICON`. Provided by building `[YAPPET]`
(“Yuri Puppet Master”), cost 5000, `Power=-200`, `RevealToAll=yes`, `ChargedAnimTime=1`,
`BuildLimit=1`, `ProtectWithWall=yes`, TechLevel 10, `Prerequisite=YATECH,YACNST`.

**Edge cases:** `ShowTimer=yes` and `DisableableFromShell=yes`; the SW `Range` is only the
targeting indicator; actual capture uses `DominatorCaptureRange`.

**Kind:** generic-engine.

**Sources:** stock rules gist ; https://modenc.renegadeprojects.com/Type

**Confidence:** high.

### YR-CORE-016 — Genetic Mutator / mutation

**What:** `Type=GeneticConverter` superweapon. Two modes selected by `[General] MutateExplosion`:
- `MutateExplosion=yes` (stock): detonate `MutateExplosionWarhead` for **10,000** damage over the
  effect area (warhead `CellSpread=5`), no per-infantry verses filtering beyond the warhead.
- `MutateExplosion=no`: subject each infantry in a 3×3 area to a one-shot kill with
  `MutateWarhead`.
Either way the kill uses `InfDeath=9` (`InfantryMutate=GENDEATH`), whose animation carries
`MakeInfantry` and spawns a **player-owned** `BRUTE` (index 0 of `[General] AnimToInfantry=BRUTE`).

**Data keys:** `[SpecialWeapons] MutateWarhead=Mutate`, `MutateExplosionWarhead=MutateExplosion`;
`[General] MutateExplosion`, `AnimToInfantry`; warhead `InfDeath=9`, `PercentAtMax`, `CellSpread`;
art `MakeInfantry`; per-SW `Type=GeneticConverter`, `Action=GeneticConverter`, `RechargeTime=5`,
`Range=5`, `SidebarImage=MUTEICON`, `IsPowered=true`; building `[YAGNTC]` cost 2500,
`Power=-200`, `RevealToAll=yes`, `BuildLimit=1`, `ChargedAnimTime=1`.

**Numbers:** warhead `[Mutate] Verses=100,100,100,0,0,0,0,0,0,0,0` (infantry armor classes only),
`InfDeath=9`. `[MutateExplosion] CellSpread=5`, `PercentAtMax=1`, `Verses` same, `InfDeath=9`.
`[General] InfantryMutate=GENDEATH`.

**Edge cases:**
- `InfDeath=9` deals **no damage** to airborne infantry (paratroopers) and forces `Die2` in that
  case; area-effect mutation that can kill falling paratroopers throws an IE unless they are
  immune.
- `MakeInfantry` when the spawn cell is blocked leaks memory/CPU forever with no fix; Ares
  deletes the animation instead.
- Mutation only mutates infantry; `Mutate.KillNatural` (Ares) kills `Natural=yes` targets instead
  of mutating. Brute is `Unnatural=yes`, so `Natural` units cannot attack it.
- `AnimToInfantry` is the global index list; the spawned infantry’s owner is the firing house for
  `InfDeath=9` (hardcoded remappable unit palette).

**Kind:** generic-engine (new SW type + `InfDeath=9` + `MakeInfantry`) + yr-data (BRUTE).

**Sources:** https://modenc.renegadeprojects.com/MutateExplosion ;
https://modenc.renegadeprojects.com/MutateExplosionWarhead ;
https://modenc.renegadeprojects.com/MutateWarhead ;
https://modenc.renegadeprojects.com/InfDeath ;
https://modenc.renegadeprojects.com/MakeInfantry ;
https://modenc.renegadeprojects.com/Mutation ; stock rules gist

**Confidence:** high.

### YR-CORE-017 — Force Shield

**What:** `Type=ForceShield` invincibility superweapon. Like the Iron Curtain but with its own
defaults: it only affects **buildings** (this is hardcoded, not just an Ares default), uses the
Force Shield color, and inflicts a power blackout on the firing house for longer than the shield
lasts. The blackout can trip `PoweredSpecial` on the owner’s buildings.

**Data keys (`[General]`):** `ForceShieldRadius`, `ForceShieldDuration`,
`ForceShieldBlackoutDuration`, `ForceShieldPlayFadeSoundTime`, `ForceShieldInvokeAnim`;
`[AudioVisual] ForceShieldColor`; per-SW `[ForceShieldSpecial]` `Type=ForceShield`,
`Action=ForceShield`, `RechargeTime=5`, `Range=3.4`, `LineMultiplier=3`, `IsPowered=true`,
`ShowTimer=no`, `SidebarImage=FORCICON`, `SpecialSound=ForceShieldFading`, `StartSound=
ForceShieldStarting`, `FlashSidebarTabFrames=120`.

**Numbers:** `ForceShieldRadius=4` cells, `ForceShieldDuration=500` frames,
`ForceShieldBlackoutDuration=1000` frames, `ForceShieldPlayFadeSoundTime=75` frames,
`ForceShieldInvokeAnim=FORCSHLD`, `ForceShieldColor=6`, `RechargeTime=5` min.

**Edge cases:**
- The Iron Curtain’s own protection is hardcoded to a 3×3 area in vanilla; Force Shield uses the
  radius tag.
- Ares documents the vanilla defaults that make Force Shield different: affects only buildings,
  only own/team houses, and uses the Force Shield cursor; duration defaults to
  `ForceShieldDuration`; blackout defaults to `ForceShieldBlackoutDuration`.
- AI can fire Force Shield defensively against incoming supers via `[General]
  AISuperDefenseProbability=90,50,10`, `AISuperDefenseFrames=50`, `AISuperDefenseDistance=12`;
  superweapons with `AIDefendAgainst=yes` (Nuke, Lightning Storm) trigger that logic.
- Buildings can be permanently excluded from being shield targets with Ares’
  `ForceShield.Modifier=0` (Ares only, not vanilla).

**Kind:** generic-engine (new SW type) + yr-data.

**Sources:** https://modenc.renegadeprojects.com/ForceShieldDuration ;
https://modenc.renegadeprojects.com/ForceShieldRadius ;
https://modenc.renegadeprojects.com/ForceShieldBlackoutDuration ;
https://modenc.renegadeprojects.com/ForceShieldInvokeAnim ;
https://modenc.renegadeprojects.com/PoweredSpecial ;
https://ares-developers.github.io/Ares-docs/new/superweapons/types/protect.html ; stock rules gist

**Confidence:** high.

### YR-CORE-018 — Spy Plane and Psychic Reveal support supers

**What:** Two new non-damaging `Type` values used by YR.
- `Type=SpyPlane` (`[SpyPlaneSpecial]`, `Action=SpyPlane`, `RechargeTime=4`, `ShowTimer=no`,
  `DisableableFromShell=no`, `SidebarImage=SPYPICON`): flies over and photographs a target area.
  Audio hooks `[AudioVisual] SpyPlaneCamera` and `SpyPlaneCameraFrames=16`.
- `Type=PsychicReveal` (`[PsychicRevealSpecial]`, `Action=PsychicReveal`, `RechargeTime=4`,
  `ShowTimer=no`, `DisableableFromShell=no`, `IsPowered=false`, `SidebarImage=PSYRICON`):
  clears shroud in a radius. Radius is `[CombatDamage] PsychicRevealRadius=15` cells. Provided by
  `[NAPSIS]` (Yuri Psychic Sensor, `PsychicDetectionRadius=15`, `DetectDisguiseRange=15`,
  `SuperWeapon=PsychicRevealSpecial`).

`PsychicDetectionRadius` additionally draws a house-colored dashed line to attackers and spawns a
`[PSIWARN]` animation at the impact point when an **enemy** `Type=MultiMissile` is about to land
inside the radius (not trigger-fired nukes).

**Data keys:** `PsychicRevealRadius`; `PsychicDetectionRadius`, `DetectDisguise`,
`DetectDisguiseRange`; `SpyPlaneCamera`, `SpyPlaneCameraFrames`.

**Edge cases:** `DisableableFromShell=no` on both means the skirmish checkbox cannot turn them
off. Reveal clears shroud for the activating house only.

**Kind:** generic-engine (new SW types) + yr-data.

**Sources:** https://modenc.renegadeprojects.com/PsychicDetectionRadius ;
https://modenc.renegadeprojects.com/Type ; stock rules gist

**Confidence:** high for tags; medium for the exact SpyPlane flight/photograph behaviour (ModEnc
has no dedicated page).

### YR-CORE-019 — Shared superweapon contract and global reveal

**What:** Independent of `Type`, every SW shares a charge contract: `RechargeTime` in **minutes**,
`IsPowered` (charge suspends when the owner is low on power), `ShowTimer` (sidebar countdown),
`DisableableFromShell` (whether the “Superweapons” skirmish checkbox can switch it off since
`DisableableFromShell=yes`), `AIDefendAgainst` (counts as a threat for the AI Force Shield logic).
SW-providing buildings can reveal themselves globally with `RevealToAll=yes` (the Psychic
Dominator and Genetic Mutator do) and use `ChargedAnimTime` (minutes before ready at which the
building switches to its charged animation). `[AudioVisual]` holds per-SW activate sounds
(`PsychicDominatorActivateSound`, `GeneticMutatorActivateSound`, `PsychicRevealActivateSound`).
`SpecialSound`/`StartSound`/`FlashSidebarTabFrames` are per-SW sound/tab hooks; Force Shield uses
them because it has no animation to hook onto.

**Data keys:** `RechargeTime`, `IsPowered`, `ShowTimer`, `DisableableFromShell`, `AIDefendAgainst`,
`RevealToAll`, `ChargedAnimTime`, `SpecialSound`, `StartSound`, `FlashSidebarTabFrames`,
`WeaponType`, `PreDependent`, `PreClick`, `PostClick`.

**Numbers:** stock recharge times (minutes): Nuke 10, Iron Curtain 5, Lightning Storm 10,
Chrono Sphere 7, Chrono Warp 1, ParaDrop 4, American ParaDrop 4, Psychic Dominator 10, Spy Plane 4,
Genetic Converter 5, Force Shield 5, Psychic Reveal 4.

**Edge cases:** There is no per-SW “shared timer” between players — charge is per house per SW.
`PreClick`/`PostClick` and `PreDependent` implement the two-click Chrono Sphere → Chrono Warp
flow (one Action for source, one for destination). `WeaponType` is used by nuke-type SWs.

**Kind:** generic-engine + yr-data.

**Sources:** stock rules gist ; https://modenc.renegadeprojects.com/Type

**Confidence:** high for tags/values; medium for the precise meaning of every UI hook.

---

## 7. Mutation, conversion and ownership transfer

### YR-CORE-020 — Mutation as entity conversion

**What:** Mutation is not a stat change on an existing unit; it kills the infantry and spawns a
new infantry type via the death animation’s `MakeInfantry` index into `[General] AnimToInfantry`.
The spawned unit is owned by the mutating house (the `InfDeath=9`/`GENDEATH` path is hardcoded to
remap to that house). Since Brute is a distinct `InfantryType`, there is no in-place conversion
and no preservation of the victim’s identity.

**Data keys:** `[General] AnimToInfantry=BRUTE`, `InfantryMutate=GENDEATH`; art `MakeInfantry`;
`[BRUTE]` `Owner=YuriCountry`, `Unnatural=yes`, `SelfHealing=yes`, `ImmuneToPsionics=yes`,
`Size=2`.

**Numbers:** Brute: `Strength=200`, `Armor=plate`, `Cost=500`, `Soylent=250`, `Speed=6`, `Pip=white`.

**Edge cases:** see YR-CORE-016 (airborne immunity, blocked-cell memory leak, Natural/Unnatural
targeting). `NotHuman=yes` infantry normally use `Die1` regardless of `InfDeath`, but an
area-effect mutation can still throw the paratrooper IE.

**Kind:** generic-engine (MakeInfantry + InfDeath 9) + yr-data (Brute).

**Sources:** https://modenc.renegadeprojects.com/MakeInfantry ;
https://modenc.renegadeprojects.com/NotHuman ; stock rules gist

**Confidence:** high.

### YR-CORE-021 — Ownership transfer summary

**What:** Three distinct ownership-transfer paths exist in YR:
1. **Temporary MC** — ownership is functionally transferred while the link holds; the original
   owner is restored on release.
2. **Permanent Psychic Dominator capture** — ownership is transferred permanently; the victim
   cannot be re-captured by ordinary MC.
3. **Mutation** — the victim is destroyed and a new, differently-typed unit is created for the
   mutating house.
Plus the `DeploysInto`/`UndeploysInto` link-severing bug that can leak a permanently-owned unit
to the controller (YR-CORE-011).

**Data keys:** see the three sub-mechanics.

**Edge cases:** on release after the original owner is defeated, the unit defects to neutral.
Player defeat/elimination logic therefore must be aware of ghost-owned units.

**Kind:** generic-engine.

**Sources:** https://modenc.renegadeprojects.com/MindControl ;
https://modenc.renegadeprojects.com/Mutation

**Confidence:** medium (synthesis of cited mechanics).

---

## 8. Power model extensions

### YR-CORE-022 — Negative power, `PoweredSpecial`, blackout

**What:** Buildings declare supply/demand with `Power` (positive = output, negative = drain).
`Powered=yes`/`TogglePower` control whether the building is affected by the grid and whether the
player can toggle it. Three new YR blackout and low-power triggers interact with buildings:
- **Spy infiltration** of a power plant (`[General] SpyPowerBlackout=1000` frames, i.e. ~1 minute
  at the game’s frame rate) shuts the owner down.
- **Force Shield activation** blackout (`ForceShieldBlackoutDuration`).
- **DrainWeapon** (Floating Disc) puts the target building/owner into LowPower.

A building with `PoweredSpecial=yes` plays its `LowPower` art while drained, while blacked out by a
spy, or while its owner fired a Force Shield. `PoweredSpecial` requires `Power ≤ 0` (non-zero) or
`Power > 0` to behave correctly. There is a separate documented bug class where
`MinimumAIDefensiveTeams` etc. don’t matter — the relevant production penalty tags are
`MinLowPowerProductionSpeed`, `MaxLowPowerProductionSpeed`, `LowPowerPenaltyModifier`.

**Data keys:** `Power`, `ExtraPower`, `Powered`, `TogglePower`, `PoweredSpecial`, `LowPower`,
`SuperLowPower*`; `[General] SpyPowerBlackout`, `ForceShieldBlackoutDuration`;
`[CombatDamage] DrainMoneyFrameDelay`, `DrainMoneyAmount`, `DrainAnimationType`.

**Numbers:** stock power-plant outputs: `YAPOWR` (Bio Reactor) `Power=150`, `ExtraPower=100`;
Allied/Soviet basic plants `Power=200`/`150`; advanced plants `Power=-…` consumers; Tech Power
Plant `Power=2000` (`[CAPOWR]`). Force Shield blackout 1000 frames; spy blackout 1000 frames.

**Edge cases:** `FactoryPlant` discounts do **not** check whether the building is powered or
toggled — the discount applies even while offline (ModEnc bug note). The Force Shield blackout is
deliberately longer than the shield (`1000 > 500`), which is the intended trade-off.

**Kind:** generic-engine (YR blackout triggers added; `Power`, `Powered` are RA2).

**Sources:** https://modenc.renegadeprojects.com/PoweredSpecial ;
https://modenc.renegadeprojects.com/ForceShieldBlackoutDuration ; stock rules gist

**Confidence:** high.

### YR-CORE-023 — Per-unit power dependency (`PoweredUnit`/`PowersUnit`)

**What:** A vehicle with `PoweredUnit=yes` is only active while its owner has at least one powered
instance of a building whose `PowersUnit=` names that vehicle. If the building is unpowered,
destroyed, or sold, all of the owner’s matching units shut down (offline voices, no movement).
`PowersUnit` is only honoured on `BuildingType`s even though all techno sections parse it.

**Data keys:** `PoweredUnit` (VehicleType); `PowersUnit` (BuildingType).

**Numbers:** `[ROBO]` (Robot Tank) `PoweredUnit=yes`, `ImmuneToPsionics=yes`, `ImmuneToRadiation=yes`.
`[GAROBO]` (Allied Robot Control Center) `PowersUnit=ROBO`, `Power=-100`, `Powered=true`,
`TogglePower=yes`, `Capturable=true`.

**Edge cases (major engine limit):** the logic works correctly only when a house owns **one**
building type with this function. With several, only one deactivates/reactivates its units
correctly; Units with `PoweredUnit=yes` are deactivated when they try to move without the center
present but are **not reactivated**; units without the flag ignore a missing center entirely.
ModEnc concludes “you must sacrifice the robot-tank logic to use this on another unit”. Vehicles
using the jumpjet/hover locomotors when floating are not affected.

**Kind:** generic-engine (YR-introduced).

**Sources:** https://modenc.renegadeprojects.com/PoweredUnit ;
https://modenc.renegadeprojects.com/PowersUnit ; stock rules gist

**Confidence:** high.

### YR-CORE-024 — Floating Disc money drain

**What:** `DrainWeapon=yes` on a weapon makes it “attack” a building without dealing damage,
putting it into LowPower. If the building also has `ResourceDestination=yes` (refineries/silos),
the drain transfers credits from the building owner to the firer owner at a fixed cadence.
`Drainable=yes` on the target is required for targeting; non-buildings can still be targeted but
the drain has no effect. The weapon only works when the firer is directly above the target and
the projectile is `Vertical=yes` (Jumpjet locomotor + `BalloonHover=yes` vehicle, or Ares
`IsPassable=yes`).

**Data keys:** `DrainWeapon` (weapon), `Drainable`, `ResourceDestination` (building),
`[CombatDamage] DrainMoneyFrameDelay`, `DrainMoneyAmount`, `DrainAnimationType`.
Floating Disc also carries `DiskLaser=yes` for its ring-draw primary and `[AudioVisual]
DiskLaserChargeUp`.

**Numbers:** weapon `[DiskDrain] Damage=1`, `Burst=1`, `ROF=50`, `Range=1.5`,
`Projectile=InvisibleVertical`, `Speed=20`, `Warhead=AntiB`, `OmniFire=yes`, `FireOnce=yes`,
`FireWhileMoving=no`. Globals: `DrainMoneyFrameDelay=30` frames, `DrainMoneyAmount=30` credits,
`DrainAnimationType=DISKRAY`. Disc primary `[DiskLaser] Damage=90`, `ROF=80`, `Range=7`,
laser colors `LaserInnerColor=216,0,184`, `LaserOuterColor=80,0,88`, `LaserDuration=15`.

**Edge cases:** a “drained” non-building keeps draining forever but does nothing. If the firer is
not a vehicle (e.g. infantry) it can drain while overlapping cell #0 and never stops naturally.
Drain only affects a positive-`Power` building’s supply; Ares later added `Drain.Local`/
`Drain.Amount` for per-building control (not vanilla).

**Kind:** generic-engine (YR-introduced).

**Sources:** https://modenc.renegadeprojects.com/DrainWeapon ; stock rules gist

**Confidence:** high.

---

## 9. Status effects

### YR-CORE-025 — Berserk (`Psychedelic`)

**What:** A warhead with `Psychedelic=yes` is a “chaos” warhead: affected units go berserk for a
duration equal to the firing weapon’s `Damage` (after `Verses`/armor multipliers). Negative
damage (e.g. −600) cancels/removes the effect. Berserk units ignore orders, treat friendlies as
enemies in their threat scan, and are tinted from `[ColorAdd]` via `[AudioVisual] BerserkColor`.
`ImmuneToPsionics=yes` grants immunity; units owned by the firing player are immune by default
unless `AffectsAllies=yes`.

**Data keys:** warhead `Psychedelic`, `AffectsAllies`; TechnoType `BerserkFriendly`;
`[AudioVisual] BerserkColor`; `[CombatDamage] BerzerkAllowed` (cyborg berzerk, non-functional in
RA2/YR without scripting); `Cyborg=yes` (cyborg infantry, TS-inherited).

**Numbers:** `[AudioVisual] BerserkColor=4`. Damage is the duration; there is no separate duration
tag.

**Edge cases:**
- ModEnc reports that, unlike human players, the AI can still issue orders to berserk units, so
  they may not look berserk despite the tint.
- `AffectsAllies=yes` is the default and can hit allies; `AffectsAllies=no` is the fix. Patch
  1.001 sets `AffectsAllies=no` on `PsiPulse`.
- Aircraft can be affected but are not tinted.
- Vehicles’ SHP art may not display the tint.
- Effects from particles have no owner and hit every faction.
- `BerserkFriendly=yes` makes berserkers skip that object type when re-targeting.
- Stock YR ships `BerserkFriendly=yes` on at least one section; no stock warhead uses
  `Psychedelic=yes` (the hook exists engine-side; the `ChaosAttack` weapon survives from RA2).

**Kind:** generic-engine (RA2 flag improved in YR) + yr-data.

**Sources:** https://modenc.renegadeprojects.com/Psychedelic ;
https://modenc.renegadeprojects.com/BerserkFriendly ;
https://modenc.renegadeprojects.com/Cyborg ; stock rules gist

**Confidence:** high for mechanics; medium for the claim that no stock YR warhead is
`Psychedelic` (based on grep of the stock gist).

### YR-CORE-026 — Poison and virus death

**What:** `Poison=yes` on a warhead makes it unable to target or damage objects with
`ImmuneToPoison=yes`. Poison damage is delivered by `InfDeath=8` (`InfantryVirus=VIRUSD`), which
can spawn a player-owned infantry via `MakeInfantry` and always spawns a particle from its
animation’s `SpawnsParticle`. YR’s Virus sniper uses it.

**Data keys:** warhead `Poison`, `InfDeath=8`, `Particle`, `ProneDamage`, `CellSpread`,
`PercentAtMax`; TechnoType `ImmuneToPoison`; `[General] InfantryVirus=VIRUSD`.

**Numbers:** `[VirusGas] CellSpread=1`, `Verses=100,100,100,50,50,50,0,0,0,100,0`, `InfDeath=8`,
`Poison=yes`, `Particle=GasCloudSys`, `ProneDamage=300%` (gas is more lethal to prone infantry).
`[Virus] Verses=100,100,100,1,1,1,1,1,1,1,100`, `AnimList=PIFF`, `ProneDamage=100%`, `Bullets=yes`,
`InfDeath=8`.

**Edge cases:** `InfDeath=8` assumes the death animation has a valid `SpawnsParticle`; a missing
or volatile value causes an IE or erratic behaviour. Against `NotHuman=yes` or airborne targets
only **one** particle (not `NumParticles`) is spawned. InfDeath=8 anims do not remap to house
colors (Ares fixes via `DeathAnims`). Poison is a target-filter, not a damage type.

**Kind:** generic-engine (YR `InfDeath=8`, `Poison`; `ImmuneToPoison` may be inherited) + yr-data.

**Sources:** https://modenc.renegadeprojects.com/Poison ;
https://modenc.renegadeprojects.com/InfDeath ; stock rules gist

**Confidence:** high.

### YR-CORE-027 — InfDeath registry (YR values)

**What:** `InfDeath` selects the infantry death animation. YR’s additions are 8 (Virus),
9 (Mutate), 10 (Brute). 11+ has no generic animation and requires an explicit `DeathAnims` list.
`NotHuman=yes` forces `Die1` regardless of `InfDeath` unless `DeathAnims` is set. A `LaserFence`
kill forces InfDeath=5; a paradropping victim forces InfDeath=3.

**Data keys:** warhead `InfDeath` (0–10); infantry `DeathAnims`, `NotHuman`; `[General]`
`InfantryExplode`, `FlamingInfantry`, `InfantryHeadPop`, `InfantryNuked`, `InfantryVirus`,
`InfantryMutate`, `InfantryBrute`.

**Numbers:** 0 none; 1 Die1; 2 Die2; 3 `InfantryExplode`; 4 `FlamingInfantry`; 5 electro; 6
`InfantryHeadPop=YURIDIE`; 7 `InfantryNuked=NUKEDIE`; 8 `InfantryVirus=VIRUSD`; 9
`InfantryMutate=GENDEATH`; 10 `InfantryBrute=BRUTDIE`.

**Edge cases:** InfDeath 3/4/5/6/7/10 are “spawn-capable” (can create a neutral-owned infantry
via `MakeInfantry`); 8 and 9 spawn player-owned. Only #9 remaps correctly to the player color by
default. All spawn-capable animations except #9 do not remap to house colors.

**Kind:** generic-engine (8/9/10 are YR-new).

**Sources:** https://modenc.renegadeprojects.com/InfDeath ;
https://modenc.renegadeprojects.com/NotHuman ; stock rules gist

**Confidence:** high.

---

## 10. Garrison, bunkers and fire-from-transport

### YR-CORE-028 — Urban combat / garrison

**What:** Buildings opt into garrison with `CanBeOccupied=yes` and `MaxNumberOccupants`. Infantry
opt in with `Occupier=yes`. Occupants fire a dedicated `OccupyWeapon`/`EliteOccupyWeapon` while
inside; the building’s own `Primary` is not used by occupants. `CanOccupyFire=yes` is the flag
that lets occupants actually shoot. Occupied buildings gain threat value
(`[General] ThreatPerOccupant=10`) and the damage/ROF/range modifiers in `[CombatDamage]`.

**Data keys:** `CanBeOccupied`, `MaxNumberOccupants`, `CanOccupyFire`, `Occupier`,
`OccupyWeapon`, `EliteOccupyWeapon`; `[CombatDamage] OccupyDamageMultiplier`,
`OccupyROFMultiplier`, `OccupyWeaponRange`; `[General] ThreatPerOccupant`.

**Numbers:** `OccupyDamageMultiplier=1.2`, `OccupyROFMultiplier=1.2`, `OccupyWeaponRange=5`.
Soviet Battle Bunker `[NABNKR] CanBeOccupied=yes`, `MaxNumberOccupants=5`, `CanOccupyFire=yes`,
`Sight=6`, `Strength=600`, `Cost=500`. Partial Yuri Psychic Dominator `[YAPPPT]` also has
`CanBeOccupied=yes`, `MaxNumberOccupants=10`, `CanOccupyFire=yes`.

**Edge cases:** infantry under mind control cannot garrison (`Occupier` inert). The range bonus is
not a flat add — for large-footprint buildings a bonus is added automatically, so
`OccupyWeaponRange` is the fallback for short-range occupants; the engine cannot read range from
the weapon because switching occupants would make a long-range occupant then stop shorter-range
ones from firing. `CanOccupyFire=no` + `CanBeOccupied=yes` gives passive shelter.

**Kind:** generic-engine (RA2-inherited, still used heavily in YR).

**Sources:** stock rules gist ; https://modenc.renegadeprojects.com/MindControl

**Confidence:** high.

### YR-CORE-029 — Tank Bunker (`Bunker=yes` / `Bunkerable`)

**What:** `Bunker=yes` on a building turns it into a Tank Bunker: exactly one vehicle can drive in
and gains weapon bonuses while inside. `Bunkerable=no` is set on most stock vehicles to prevent
them from entering bunkers (units default to yes, buildings/other objects default to no). Only
one vehicle fits regardless of `NumberOfDocks`.

**Data keys:** `Bunker` (building), `Bunkerable` (techno); `[CombatDamage] BunkerDamageMultiplier`,
`BunkerROFMultiplier`, `BunkerWeaponRangeBonus`; `[AudioVisual] BunkerWallsUpSound`,
`BunkerWallsDownSound`; foundation (`Foundation`, `NumberImpassableRows`); warhead
`PenetratesBunker`.

**Numbers:** `BunkerDamageMultiplier=1.3`, `BunkerROFMultiplier=1.3` (multiplies fire rate;
implemented as a division of rearm time), `BunkerWeaponRangeBonus=2` cells (an addition, unlike
the garrison range rule). `[NATBNK]`: `Strength=1000`, `Cost=400`, `Power=0`, `NumberOfDocks=1`,
`NumberImpassableRows=0`, `Adjacent=3`, `TechLevel=3`.

**Edge cases:**
- The building footprint must have a side longer than 1 cell; a 1×1 `Foundation` refuses entry.
- Even-length foundations mis-align the vehicle’s exit position, which breaks cell-based logic
  (e.g. arcing projectiles miss). `ConstructionYard=yes` had been the community workaround for
  the entry stutter; Phobos later added `BunkerStateUpdateDelay`.
- A bunkered unit’s weapon must have range ≥ 384 leptons (1.5 cells) to be targetable.
- Entering stops the building’s own weapon fire but retains target; the target resumes on exit.
- Cannot be combined with `InfantryAbsorb`/`UnitAbsorb` (the vehicle will attempt to enter but
  never do so).
- `PenetratesBunker=yes` on a warhead makes the warhead damage the unit rather than the bunker.
- Selling a unit inside a bunker via the `SellUnit` action throws an IE in vanilla.

**Kind:** generic-engine (YR-introduced bunker logic).

**Sources:** https://modenc.renegadeprojects.com/Bunker ;
https://modenc.renegadeprojects.com/Actions ; stock rules gist

**Confidence:** high.

### YR-CORE-030 — Fire from transport (`OpenTopped`)

**What:** A transport with `OpenTopped=yes` and `Passengers` lets passengers fire out. The carrier
and passengers use `OpenTransportWeapon` when the passenger has one (else the passenger’s primary).
Global modifiers apply to passenger fire.

**Data keys:** `OpenTopped`, `Passengers`, `SizeLimit`, `OpenTransportWeapon`;
`[CombatDamage] OpenToppedRangeBonus`, `OpenToppedDamageMultiplier`,
`OpenToppedWarpDistance`.

**Numbers:** `OpenToppedRangeBonus=2`, `OpenToppedDamageMultiplier=1.2`,
`OpenToppedWarpDistance=7`. Battle Fortress uses `OpenTopped=yes`; Yuri Prime sets
`OpenTransportWeapon=1`.

**Edge cases:** if a passenger’s weapon range is lower than the carrier’s, the carrier stops
respecting its own `OpenTransportWeapon` range and uses the passenger’s; giving passengers a
`GuardRange` ≤ the carrier weapon avoids this. `OpenTopped` on a **building** makes exiting
infantry attack the building (unverified; `ExitCoord` may fix it). Chrono Legionnaire’s warp link
breaks if the carrier moves more than `OpenToppedWarpDistance` cells.

**Kind:** generic-engine (RA2 partly; YR uses it for Battle Fortress and the transport-fire
model).

**Sources:** https://modenc.renegadeprojects.com/OpenTopped ; stock rules gist

**Confidence:** high.

---

## 11. Bio Reactor and absorb mechanics

### YR-CORE-031 — Bio Reactor power hook

**What:** The Yuri Bio Reactor eats infantry (and optionally vehicles) to boost output. Two flags
enable absorption: `InfantryAbsorb=yes` and `UnitAbsorb=yes`. Each absorbed unit adds the
building’s `ExtraPower` to output (when positive). `PipScale=Passengers` (plus `Passengers` and
`SizeLimit`) draws occupancy pips; the engine draws one pip per absorbed unit and uses specific
`pips.shp` frames.

**Data keys:** `InfantryAbsorb`, `UnitAbsorb`, `ExtraPower`, `Passengers`, `SizeLimit`,
`PipScale`; `[AudioVisual] EnterBioReactorSound`, `LeaveBioReactorSound`.

**Numbers:** `[YAPOWR]` (Bio Reactor): `Power=150`, `ExtraPower=100`, `Passengers=5`,
`SizeLimit=15`, `InfantryAbsorb=yes`, `UnitAbsorb=no`, `PipScale=Passengers`, `Drainable=yes`,
`PoweredSpecial=yes`, `Capturable=true`, `Spyable=yes`, `Cost=600`, `Strength=700`.

**Edge cases:**
- `InfantryAbsorb` overrides normal passenger logic and enables the Bio Reactor art hack: active
  anim 1 plays unoccupied, active anim 2 plays occupied; idle anim loops as an active anim;
  active animes 3/4 still function. The “full” anim plays for one frame after buildup.
- Each infantry occupies one pip using frame 3 (0-based) of `pips.shp`.
- `Armory=yes` combined with `InfantryAbsorb` breaks capacity checks: it can hold unlimited
  passengers until manually deployed, refuses elite infantry, and refuses vehicles.
- `UnitAbsorb` with `DockUnload=yes` breaks docking behaviours (ore trucks fail to unload).
- `InfantryAbsorb` and `Bunker` are mutually exclusive in practice.

**Kind:** generic-engine (YR-introduced).

**Sources:** https://modenc.renegadeprojects.com/InfantryAbsorb ;
https://modenc.renegadeprojects.com/UnitAbsorb ;
https://modenc.renegadeprojects.com/PipScale ; stock rules gist

**Confidence:** high.

---

## 12. Economy hooks

### YR-CORE-032 — Grinder recycling

**What:** `Grinding=yes` on a building makes it a Grinder. Own infantry/vehicles sent into it are
destroyed and refunded at their `Soylent` value. A Grinder plays its `SpecialAnim` on grind,
replacing `ActiveAnim`. This is the successor to RA2’s Cloning Vat infantry-recycling (which is
removed in YR).

**Data keys:** `Grinding` (building), `Soylent` (unit), `UnitAbsorb`/`InfantryAbsorb` interaction,
`SpecialAnim`/`ActiveAnim`; `[AudioVisual] EnterGrinderSound`, `LeaveGrinderSound`.

**Numbers:** `[YAGRND]` Grinder: `Cost=600`, `Power=-50`, `Strength=900`, `Armor=wood`,
TechLevel 9, `Prerequisite=YAWEAP,YACNST`. Stock vehicles have `Soylent=Cost` (100% refund);
buildings/infantry default to 50% via `[General] RefundPercent=50%`.

**Edge cases:**
- If `Soylent` is non-zero, the refund ignores country/Industrial Plant multipliers, so Grinder +
  Industrial Plant can produce free money. The community workaround is to set `Soylent` to the
  discounted cost.
- If `Soylent` is zero, the refund is `Cost × country mult × FactoryPlant mult × RefundPercent`
  computed at **refund time**, so losing the Industrial Plant after building inflates the refund.
- An Engineer infantry can enter a Grinder at full strength, and if the Grinder is damaged it
  prioritises repairing itself.
- Units with `AttackFriendlies=yes`/`AttackCursorOnFriendlies=yes` attack instead of entering;
  units with a negative-damage weapon never enter.
- `Grinding=yes` + `Cloning=yes` + `InfantryAbsorb=yes` makes `UnitAbsorb` the deciding flag
  (default no blocks vehicles).

**Kind:** generic-engine (YR-introduced).

**Sources:** https://modenc.renegadeprojects.com/Grinding ;
https://modenc.renegadeprojects.com/Soylent ; stock rules gist

**Confidence:** high.

### YR-CORE-033 — Industrial Plant discount

**What:** `FactoryPlant=yes` on a building lets it apply the five cost-bonus multipliers to the
owning player’s production. The discount does not check whether the building is powered or
toggled.

**Data keys:** `FactoryPlant`, `InfantryCostBonus`, `UnitsCostBonus`, `AircraftCostBonus`,
`BuildingsCostBonus`, `DefensesCostBonus`.

**Numbers:** `[NAINDP]` Soviet Industrial Plant: `FactoryPlant=yes`, `InfantryCostBonus=1`,
`UnitsCostBonus=0.75`, `AircraftCostBonus=1`, `BuildingsCostBonus=1`, `DefensesCostBonus=1`,
`Power=-200`, `Cost=2500`, `BuildLimit=1`, `TogglePower=no`, `Powered=true`. A multiplier of 1 is
no change; 0.75 = 25% cheaper.

**Edge cases:** because the refund multiplier (see YR-CORE-032) is applied at refund time, the
Plant’s discount and Grinder refund interact into the free-money exploit. `FactoryPlant` is also
the mechanism used by the Alliance’s `;CostInfantryMult` country bonus, which means country and
building discounts stack.

**Kind:** generic-engine (RA2 flag, heavily used in YR) + yr-data.

**Sources:** https://modenc.renegadeprojects.com/FactoryPlant ;
https://modenc.renegadeprojects.com/Soylent ; stock rules gist

**Confidence:** high.

### YR-CORE-034 — Credit siphon (Floating Disc)

**What:** See YR-CORE-024. The Floating Disc’s `DrainWeapon` secondary steals
`DrainMoneyAmount` credits every `DrainMoneyFrameDelay` frames from a `ResourceDestination`
building’s owner to the Disc owner. This is the YR “credit siphon” mechanic.

**Data keys:** `DrainWeapon`, `Drainable`, `ResourceDestination`, `DrainMoneyFrameDelay`,
`DrainMoneyAmount`.

**Numbers:** 30 credits / 30 frames.

**Edge cases:** only works against buildings flagged `ResourceDestination=yes`; also blacks out
positive-power targets.

**Kind:** generic-engine (YR-introduced).

**Sources:** https://modenc.renegadeprojects.com/DrainWeapon

**Confidence:** high.

### YR-CORE-035 — Slave Miner economy

**What:** YR’s Yuri economy uses the deployable Slave Miner. The vehicle `[SMIN]` undeploys into
the refinery building `[YAREFN]`, which enslaves worker infantry with `Enslaves=SLAV`,
`SlavesNumber=5`, `SlaveRegenRate=500`, `SlaveReloadRate=25`. The deployed building has weapons,
`Storage=200`, `ResourceGatherer=yes`, `ResourceDestination=yes`, and `Unsellable=yes`.

**Data keys:** `Enslaves`, `SlavesNumber`, `SlaveRegenRate`, `SlaveReloadRate`,
`ResourceGatherer`, `ResourceDestination`, `UndeploysInto`, `DeploysInto`, `Unsellable`,
`Trainable`; `[General] SlaveMinerShortScan=8`, `SlaveMinerSlaveScan=14`, `SlaveMinerLongScan=48`,
`SlaveMinerScanCorrection=3`, `SlaveMinerKickFrameDelay=150`.

**Numbers:** `[YAREFN]` cost 1750 (1.001; 1500 in 1.000), `Soylent=1750`, `Strength=2000`,
`Power=0`, `Sight=6`, `Primary=20mmRapid`. `[SLAV]` cost 10, `Strength=125`, `ImmuneToPsionics=yes`.

**Edge cases:** when deployed, the slaves are passed from the unit to the building; the building
does not need its own `Enslaves` listing. Slave miners are unsellable and `Trainable=yes`.

**Kind:** generic-engine (Enslaves/ResourceGatherer are RA2) + yr-data.

**Sources:** stock rules gist

**Confidence:** high for values; high for mechanics that are RA2-inherited.

---

## 13. Miscellaneous YR engine mechanics

### YR-CORE-036 — Magnetron (unit throwing)

**What:** The Yuri Magnetron lifts a vehicle and drops it. `[CombatDamage]
FallingDamageMultiplier` scales the fall damage; `CurrentStrengthDamage=yes` bases that damage on
the dropped unit’s current health instead of max.

**Data keys:** `FallingDamageMultiplier`, `CurrentStrengthDamage`. Weapon is a magnetic beam
(`[MagneticBeam]`, elite `[MagneticBeamE]`).

**Numbers:** `FallingDamageMultiplier=1.0`, `CurrentStrengthDamage=yes`. 1.001 raises
`MagneticBeamE` range 10 → 12.

**Edge cases:** the lift/drop is a special mechanic not expressible with ordinary weapons; the
damage is computed on impact, not on firing.

**Kind:** generic-engine (YR-introduced).

**Sources:** stock rules gist ; https://modenc.renegadeprojects.com/YR_Patch

**Confidence:** medium (ModEnc has no dedicated Magnetron page; based on stock comments).

### YR-CORE-037 — Psychic Sensor / detection

**What:** `PsychicDetectionRadius` on a building detects enemies attempting to attack and draws a
dashed house-colored line; it also spawns `[PSIWARN]` at the impact point of an enemy
`Type=MultiMissile` about to land in range. `DetectDisguise=yes` and `DetectDisguiseRange`
provide disguise detection (spy/mirage) at range.

**Data keys:** `PsychicDetectionRadius`, `DetectDisguise`, `DetectDisguiseRange`,
`Nuke.PsiWarning`; `[General] DisabledDisguiseDetectionPercent`.

**Numbers:** `[NAPSIS] PsychicDetectionRadius=15`, `DetectDisguise=yes`,
`DetectDisguiseRange=15`, `Power=-50`, `Cost=1000`, `SuperWeapon=PsychicRevealSpecial`.

**Edge cases:** trigger-created nukes do not spawn `[PSIWARN]`. Detection is per sensor range and
only warns the owner.

**Kind:** generic-engine (RA2-introduced; YR ties it to the psychic identity) + yr-data.

**Sources:** https://modenc.renegadeprojects.com/PsychicDetectionRadius ; stock rules gist

**Confidence:** high.

### YR-CORE-038 — Disguise and spy changes

**What:** Spy mechanics carried/extended in YR: `SpyPowerBlackout=1000` frames (~1 minute) on
infiltrating a power plant, `SpyMoneyStealPercent=.5` on infiltrating a refinery,
`AttackCursorOnDisguise=yes` (the cursor treats a disguised unit as attackable),
`InfantryBlinkDisguiseTime=20` (mirage test blink timing), and
`DisabledDisguiseDetectionPercent=15,5,2` (hard/normal/easy chance per unit to detect a fake-
blinking mirage). `DefaultMirageDisguises=TREE01..TREE04` requires a TerrainType, not a rock.

**Data keys:** as above; `Spyable=yes` on buildings.

**Edge cases:** `AttackCursorOnDisguise=yes` still yields an attack cursor on a fake-blinking
mirage and a spy always. The `DisabledDisguiseDetectionPercent` is per-unit, so many nearby units
make detection near-automatic.

**Kind:** generic-engine (RA2 mechanics refined for YR).

**Sources:** stock rules gist

**Confidence:** medium (values exact; mechanics from stock comments).

### YR-CORE-039 — Deploy / undeploy

**What:** Infantry can deploy with `Deployer=yes` + `DeployFire=yes` (used by Yuri Prime and
Guardian GI), with `UndeployDelay` (frames) timing the automatic undeploy to the secondary weapon.
Vehicles convert with `DeploysInto`/`UndeploysInto` (MCV ↔ Construction Yard, Slave Miner ↔
Refinery). Deployable infantry and cyborg logic conflict: deploy/undeploy clears the prone status
that cyborgs use to represent lost legs.

**Data keys:** `Deployer`, `DeployFire`, `UndeployDelay`, `DeploysInto`, `UndeploysInto`,
`DeploySound`, `UndeploySound`, `DeployedCrushable`, `DeployFacing`.

**Numbers:** Yuri Prime `UndeployDelay=75`, `BuildLimit=1`. `[YAREFN] DeployFacing=0`,
`UndeploysInto=SMIN`; `[YACNST] UndeploysInto=PCV`; `[GACNST] UndeploysInto=AMCV`;
`[NACNST] UndeploysInto=SMCV`.

**Edge cases:** `Deployer` applies only to infantry, not vehicles, and has no water logic (GI
switches to secondary weapon in water). Deploy/undeploy severs mind-control links and changes
ownership (YR-CORE-011); the 1.001 Construction Yard check blocks the MCV case. Cyborgs ignore
the `Down` prone sequence and always die as `InfDeath=3`.

**Kind:** generic-engine (RA2-inherited) + yr-data (Yuri Prime, PCV).

**Sources:** https://modenc.renegadeprojects.com/Deployer ;
https://modenc.renegadeprojects.com/UndeployDelay ;
https://modenc.renegadeprojects.com/Cyborg ; stock rules gist

**Confidence:** high.

### YR-CORE-040 — Cloning (still present in YR)

**What:** `Cloning=yes` still exists in YR on `[NACLON]` (“Yuri Cloning Vats”) and clones infantry
produced by other barracks of the same house. What changed is that the RA2 Cloning Vat’s
infantry-recycling function is gone, replaced by the Grinder. In vanilla, cloning works even at
low power; Ares later required power, and Phobos made it configurable.

**Data keys:** `Cloning`; `Factory=InfantryType`, `WeaponsFactory`, `Refinery`, `BuildLimit`.

**Numbers:** `[NACLON] Cost=2500`, `Power=-200`, `TechLevel=9`, `BuildLimit=1`.
`[General] AlliedSurvivorDivisor=500`, `SovietSurvivorDivisor=250`, `ThirdSurvivorDivisor=750`.

**Edge cases:** Cloning on a `Refinery=yes` building breaks `BuildLimit` infantry production for
the rest of the game. Buildings with `Cloning=yes` do not clone their own output if they are the
producing building; only other production buildings trigger cloning.

**Kind:** generic-engine (RA2) + yr-data.

**Sources:** https://modenc.renegadeprojects.com/Cloning ; stock rules gist

**Confidence:** high.

### YR-CORE-041 — Multiplayer game-mode registry

**What:** Multiplayer modes are declared per-map with `GameModes` (plural; `GameMode` singular is
the newer/aliased form) and the shell presents a fixed list. YR adds **Team Alliance**
(`teamgame`) and retains the RA2 modes; the obsolete RA2 **Siege** mode is replaced by Team
Alliance.

**Data keys:** map `[Basic] GameModes=...`; `[MultiplayerDialogSettings]`.

**Numbers/values:** `standard` (Battle), `teamgame` (Team Alliance, YR), `megawealth`,
`duel` (Land Rush), `meatgrind`, `navalwar`, `cooperative` (Co-Op Campaign; may not work on
standard multiplayer maps), `siege` (obsolete, replaced by Team Alliance). The CnC Wiki and map
databases additionally list **Free For All** and **Unholy Alliance** as shell modes; Unholy
Alliance is a map/scenario convention (all players get all MCVs) rather than a distinct engine
mode.

**Edge cases:** `GameModes` was added in RA2 v1.005 for Final Alert 2. Cooperative mode is
`unholy`-adjacent but engine-recognised only on campaign maps.

**Kind:** generic-engine (mode IDs) + yr-data (which modes exist/ship).

**Sources:** https://modenc.renegadeprojects.com/GameModes ;
https://modenc.renegadeprojects.com/GameMode ; https://cnc.fandom.com/wiki/Yuri%27s_Revenge

**Confidence:** high for the ID list; medium for whether Unholy Alliance is a true engine mode.

### YR-CORE-042 — Multiplayer dialog defaults and new YR options

**What:** `[MultiplayerDialogSettings]` holds the skirmish/lobby defaults. YR adds/holds
`MCVRedeploys=yes` (re-deploy a Construction Yard back into an MCV) and `AllyChangeAllowed=yes`
(players may change alliances mid-game) alongside the RA2 set.

**Data keys:** `MinMoney`, `Money`, `MaxMoney`, `MoneyIncrement`, `MinUnitCount`, `UnitCount`,
`MaxUnitCount`, `TechLevel`, `GameSpeed`, `AIDifficulty`, `AIPlayers`, `BridgeDestruction`,
`ShadowGrow`, `Shroud`, `Bases`, `TiberiumGrows`, `Crates`, `CaptureTheFlag`, `HarvesterTruce`,
`MultiEngineer`, `AlliesAllowed`, `ShortGame`, `FogOfWar`, `MCVRedeploys`, `AllyChangeAllowed`.

**Numbers:** `MinMoney=5000`, `Money=40000`, `MaxMoney=40000`, `MoneyIncrement=100`,
`UnitCount=10`, `TechLevel=10`, `GameSpeed=1`, `MCVRedeploys=yes`, `AllyChangeAllowed=yes`.

**Edge cases:** the shell checkbox for superweapons is driven by each SW’s
`DisableableFromShell`. `AlliesAllowed=no` governs whether in-game alliance requests are allowed
and is separate from `AllyChangeAllowed`.

**Kind:** generic-engine + yr-data.

**Sources:** stock rules gist ; https://modenc.renegadeprojects.com/GameModes

**Confidence:** high.

### YR-CORE-043 — Yuri-side support data and AI hooks

**What:** YR adds Yuri-specific globals that a unified engine’s YR package must honour:
`[General] ThirdCrew=INIT`, `ThirdDisguise=INIT`, `ThirdSurvivorDivisor=750`,
`ThirdBaseDefenseCounts=25,22,6`, `ThirdPowerPlant=YAPOWR`, `YuriParaDropInf=INIT`,
`YuriParaDropNum=6`. AI mind-control handling: `AICaptureNormal=75,5,5,15`,
`AICaptureWounded=5,80,10,5`, `AICaptureLowPower=5,5,85,5`, `AICaptureLowMoney=5,85,5,5` — the
percent chances an AI uses a captured unit to join the capturer’s team, send it to a Grinder,
send it to a Bio Reactor, or put it in Hunt; thresholds `AICaptureLowMoneyMark=2000`,
`AICaptureWoundedMark=.25`. `[General] PrerequisiteProcAlternate=SMIN`.

**Data keys:** as above; `[Sides] ThirdSide`, `[Countries] 9=YuriCountry`.

**Numbers:** as above. Yuri paradrop drops 6 `INIT`; Allied 6 `E1`; Soviet 9 `E2`; American
8 `E1`.

**Edge cases:** the “third” crew/disguise/survivor/paradrop slots are separate from the Allied
and Soviet ones; the engine selects by side. `ThirdPowerPlant=YAPOWR` is the hook that lets
Yuri power-plant-specific logic find the Yuri plant.

**Kind:** generic-engine (third-side slots) + yr-data (INIT, YAPOWR).

**Sources:** stock rules gist

**Confidence:** high.

### YR-CORE-044 — Misc new tags and mechanics

**What:** Other YR-relevant engine touches:
- `Insignificant=yes` — object ignored for scoring/win conditions and by enemy target scan
  (except buildings with weapons and appropriate `ThreatPosed`). YR changes AI handling so
  mind-controlled `Insignificant` units remain valid targets.
- `PenetratesBunker=yes` — warhead hits the bunkered vehicle rather than the bunker.
- `PercentAtMax` — the stock YR warhead damage falloff control (present widely in YR warheads,
  used alongside `CellSpread`).
- `ProneDamage` — damage multiplier against prone infantry (gas has 300%, bullets 50–100%).
- `Bullets=yes` on a warhead — enables bullet behaviour (used by `[Virus]`).
- `Culling=yes` / `Paralyzes=N` — parasite warhead behaviour (`[ParasitePlus]`), inherited from TS
  but used by YR squid.
- `DiskLaser=yes` — special ring-draw laser used by Floating Disc.
- `AreaFire=yes`, `OmniFire=yes`, `FireOnce=yes`, `FireWhileMoving=no` are supported weapon
  behaviours used by YR’s mind-control and psi weapons.
- `PipScale=MindControl` — new YR pipe for MC link count (YR-CORE-011).
- `ImmuneToRadiation`, `ImmuneToVeins`, `NotHuman`, `Cyborg`, `Natural`/`Unnatural`,
  `SelfHealing` are all parsed by YR; the mutation and Brute systems depend on `Unnatural`.
- `WallOwner`, `Wall=yes`/`Wood=yes`/`Conventional=yes` warhead flags are inherited.
- `BuildTimeMultiplier` is used by 1.001 to rebalance units without touching `Cost`.

**Data keys:** as listed.

**Numbers:** see individual lines above and the stock gist.

**Edge cases:** `Insignificant` objects ignore `BuildLimit`; trigger events attached to them are
ignored; buildings with docks cannot auto-dock if the building is `Insignificant`.

**Kind:** mix of generic-engine (YR additions: `PipScale=MindControl`, mutation flags,
`Insignificant` AI change) and inherited RA2/TS tags.

**Sources:** https://modenc.renegadeprojects.com/Insignificant ;
https://modenc.renegadeprojects.com/PipScale ;
https://modenc.renegadeprojects.com/NotHuman ; stock rules gist

**Confidence:** high.

### YR-CORE-045 — Serialization notes

**What:** No ModEnc page documents a savegame format. What can be stated: mind-control links,
permanent Dominator capture, powered-unit on/off state, grinder/absorption passengers, and
superweapon charge are all part of the live simulation and therefore must be persisted; the
original engine stores house ownership per object and reconstructs links on load. There is no
documented tag to opt a unit out of MC persistence, and the deploy-exploit demonstrates that the
engine’s owner field, not the link object, is authoritative after a type conversion.

**Data keys:** none.

**Edge cases:** releasing an MC’d unit whose original house was defeated assigns it to neutral on
load/release; a save taken mid-overload resumes overload timing.

**Kind:** generic-engine.

**Sources:** synthesis of https://modenc.renegadeprojects.com/MindControl and stock gist.

**Confidence:** low (inference; no authoritative save-format source found).

---

## Coverage checklist (vs. the requested scope)

1. **Mind control, complete** — YR-CORE-006 (warhead, Damage as capacity), 007 (multi-target,
   InfiniteMindControl), 008 (overload), 009 (immunity), 010 (permanent PsychicDominator),
   011 (lifecycle, death/power/overflow/deploy/garrison/serialization), 012 (building control),
   019/021 (ownership transfer). Serialization explicitly low-confidence (045).
2. **Gattling system** — YR-CORE-013: `IsGattling`, `TurretCount`, `WeaponCount`, `WeaponStages`,
   `StageX`/`EliteStageX`, `RateUp`/`RateDown`, AG/AA pairing, all parameter semantics and edge
   cases.
3. **New superweapon types** — YR-CORE-014 (Type/Action registry incl. all YR `Type` + `Action`
   values), 015 (`PsychicDominator`), 016 (`GeneticConverter`), 017 (`ForceShield`), 018
   (`SpyPlane`, `PsychicReveal`), 019 (shared timer/reveal contract).
4. **Entity conversion/mutation** — YR-CORE-016, 020, 021 (ownership transfer, deploy/undeploy
   interaction, MakeInfantry/Mutation).
5. **Power extensions** — YR-CORE-022 (negative/drain, blackout, `PoweredSpecial`), 023
   (`PoweredUnit`/`PowersUnit`), 024 (Floating Disc blackout/drain).
6. **Status effects** — YR-CORE-025 (berserk), 026 (poison/virus), 027 (InfDeath), 009 (psychic),
   016 (mutation), 008 (overload).
7. **Per-country bonus model** — YR-CORE-004 (`ParentCountry`, side→house registry,
   `ThirdSide`/`YuriCountry`), 005 (`VeteranXxx`, `YYYZZZMult`, `IncomeMult`).
8. **Garrison/bunker** — YR-CORE-028 (garrison, `OccupyWeapon`, occupancy fire), 029 (`Bunker`,
   `Bunkerable`, the three `Bunker*` multipliers), 030 (fire-from-transport/`OpenTopped`), 031
   (Bio Reactor power hook).
9. **Economy hooks** — YR-CORE-032 (Grinder recycle, `Soylent`), 033 (Industrial Plant discount),
   034 (credit siphon), 035 (Slave Miner), 005 (`IncomeMult`).
10. **`ra2md.exe`/`md` INI split, 1.001, `-SPEEDCONTROL`, house array order** — YR-CORE-001, 002,
    003, 004, 042.
11. **Game mode registry** — YR-CORE-041, 042.
12. **Other new engine mechanics** — YR-CORE-036 (Magnetron), 037 (psychic detection), 038
    (disguise/spy), 039 (deploy/undeploy), 040 (Cloning), 043 (Yuri-side globals/AI), 044 (misc
    tags), 045 (serialization).

## Top uncertainties / open questions

1. **Savegame serialization of mind-control links** (YR-CORE-011/045) — no authoritative source
   found; behaviour inferred. Needs a save/load test in the original engine or a reading of an
   open reimplementation.
2. **Force Shield colour per unit** — ModEnc/Ares say the force-shield protection colour is fixed
   for buildings and not customisable in vanilla; Ares `ForceShield.Modifier` is a later
   extension. Confirm whether YR allows per-building shield duration.
3. **Exact `SpyPlane` and `PsychicReveal` runtime behaviour** — tags are known, but there is no
   ModEnc page describing the flight path, photograph cadence beyond `SpyPlaneCameraFrames`, or
   reveal persistence.
4. **Whether any stock YR warhead is actually `Psychedelic=yes`** — grep of the stock gist found
   none; the `ChaosAttack` weapon survives, so the hook may be dead content in YR. Confirm against
   `rulesmd.ini` 1.001.
5. **Game-mode inventory** — is Unholy Alliance a true engine mode or only a scenario convention?
   `GameModes` lists `teamgame` (Team Alliance) but not `unholy`; CnC Wiki/map DBs list it as a
   shell mode. Confirm.
6. **`Muscle`/`PoweredUnit` multi-building behaviour** — ModEnc says only one `PowersUnit`
   building type per house works; whether 1.001 changed this is unknown.
7. **SellUnit retirement** — ModEnc says the `SellUnit` action was used before 1.001 and unused
   after; the exact 1.000 vs 1.001 boundary and whether the `SellUnit` superweapon form still
   functions is unclear.
8. **Ares/Phobos extensions mixed into tags** — several tags referenced here (`Dominator.Capture`,
   `Gattling.Cycle`, `BunkerStateUpdateDelay`, `Drain.Local`) are mod-engine only and must not be
   assumed present in YR.
