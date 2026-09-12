class_name WeaponMountGroupData extends Resource

## Per-unit binding of one weapon to one or more sockets, plus its firing
## discipline. Mount groups live on EntityData (behavior), never on WeaponData,
## because a weapon resource is shared across units.

enum FireMode {
    ## Fire every socket on the same tick (fire_delay = optional wind-up).
    SALVO,
    ## Fire sockets in order, each fire_delay seconds after the previous.
    STAGGER,
}

## Index into EntityData.weapons this group fires.
@export var weapon_index: int = 0
## Socket ids that fire this weapon. More than one id = one weapon fired from
## several turrets (e.g. twin rocket pods).
@export var socket_ids: PackedStringArray = PackedStringArray()
## SALVO = all sockets together; STAGGER = one after another.
@export var fire_mode: FireMode = FireMode.SALVO
## Seconds. SALVO: wind-up before the volley (0 = immediate). STAGGER: gap
## between consecutive sockets.
@export var fire_delay: float = 0.0
