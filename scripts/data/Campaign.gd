class_name Campaign
extends Resource

## Campaign — a linear, ordered set of missions won one by one.
## One campaign per `.tres` under `<game>/campaigns/`, discovered by
## CampaignCatalog. `missions` holds mission ids in win order; the first entry
## is the campaign's starting mission.

@export var id: String = ""
@export var display_name: String = ""
@export var faction_id: String = ""
@export var missions: PackedStringArray = PackedStringArray()


## The first mission id in win order, or "" when the campaign is empty.
func first_mission_id() -> String:
    return missions[0] if not missions.is_empty() else ""
