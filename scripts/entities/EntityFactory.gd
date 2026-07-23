extends Node

## EntityFactory autoload — creates entities from EntityData resources
## and dynamically adds components based on data properties.

const ENTITY_SCENE: PackedScene = preload("res://scenes/entities/Entity.tscn")
const STATS_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/StatsComponent.gd")
const HEALTH_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/HealthComponent.tscn")
const HITBOX_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/HitboxComponent.tscn")
const SELECT_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/SelectComponent.tscn")
const COMBAT_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/CombatComponent.tscn")
const MOVEMENT_CONTROLLER_SCENE: PackedScene = preload(
    "res://scenes/components/MovementController.tscn"
)
const ART_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/ArtComponent.tscn")
const FOUNDATION_COMPONENT_SCRIPT: GDScript = preload(
    "res://scripts/components/FoundationComponent.gd"
)
const POWER_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/PowerComponent.gd")
const RADAR_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/RadarComponent.gd")
const FACTORY_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/FactoryComponent.gd")
const EXIT_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/ExitComponent.gd")
const RALLY_POINT_COMPONENT_SCRIPT: GDScript = preload(
    "res://scripts/components/RallyPointComponent.gd"
)
const TRANSPORT_COMPONENT_SCRIPT: GDScript = preload(
    "res://scripts/components/TransportComponent.gd"
)
const SPECIAL_ABILITY_COMPONENT_SCRIPT: GDScript = preload(
    "res://scripts/components/SpecialAbilityComponent.gd"
)
const RESOURCE_TREE_COMPONENT_SCRIPT: GDScript = preload(
    "res://scripts/components/ResourceTreeComponent.gd"
)
const RESOURCE_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/ResourceComponent.gd")
const HARVEST_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/HarvestComponent.gd")
const DOCK_HOST_COMPONENT_SCRIPT: GDScript = preload(
    "res://scripts/components/DockHostComponent.gd"
)
const DOCK_CLIENT_COMPONENT_SCRIPT: GDScript = preload(
    "res://scripts/components/DockClientComponent.gd"
)

const FREE_UNIT_COMPONENT_SCRIPT: GDScript = preload(
    "res://scripts/components/FreeUnitComponent.gd"
)
const DOCK_UNLOAD_COMPONENT_SCRIPT: GDScript = preload(
    "res://scripts/components/DockUnloadComponent.gd"
)
const DEPLOY_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/DeployComponent.gd")

var _entity_cache: Dictionary = {}
var _global_rules: GlobalRules = null
var _data_sets: Array[String] = []


func _ready() -> void:
    _load_default_data()


func _load_default_data() -> void:
    register_data_set("res://resources/entities/")
    if ResourceLoader.exists("res://resources/global_rules.tres"):
        _global_rules = load("res://resources/global_rules.tres") as GlobalRules


func register_data_set(path: String) -> void:
    if _data_sets.has(path):
        return
    _data_sets.append(path)
    _scan_directory(path)


func _scan_directory(path: String) -> void:
    var dir := DirAccess.open(path)
    if not dir:
        push_warning("EntityFactory: Cannot open directory: %s" % path)
        return
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tres"):
            var full_path := path + file_name
            var resource := load(full_path)
            if resource is EntityData:
                var entity_data := resource as EntityData
                _entity_cache[entity_data.id] = entity_data
        elif dir.current_is_dir() and not file_name.begins_with("."):
            _scan_directory(path + file_name + "/")
        file_name = dir.get_next()
    dir.list_dir_end()


func create_entity(entity_id: String, overrides: Dictionary = {}) -> Node3D:
    if not _entity_cache.has(entity_id):
        push_warning("EntityFactory: Unknown entity id: %s" % entity_id)
        return null
    var data := _entity_cache[entity_id] as EntityData
    var errors := data.validate()
    for error in errors:
        push_warning("EntityFactory: %s" % error)
    if not overrides.is_empty():
        data = data.duplicate() as EntityData
        for key in overrides:
            data.set(key, overrides[key])
    var entity := ENTITY_SCENE.instantiate() as Node3D
    _add_components(entity, data)
    _configure_components(entity, data)

    # Cell occupancy — all except OVERLAY, and TERRAIN without foundation.
    var etype := data.entity_type
    if etype != EntityData.EntityType.OVERLAY:
        if etype != EntityData.EntityType.TERRAIN or data.foundation != Vector2i(1, 1):
            entity.add_to_group("entities")

    # Selection — selectable (single-click) and drag_selectable (box-select).
    var is_unit := (
        etype == EntityData.EntityType.INFANTRY
        or etype == EntityData.EntityType.VEHICLE
        or etype == EntityData.EntityType.AIRCRAFT
    )
    if is_unit:
        entity.add_to_group("selectable")
        entity.add_to_group("drag_selectable")
    elif etype == EntityData.EntityType.BUILDING:
        entity.add_to_group("selectable")

    # Resource groups.
    if data.resource_category != "":
        entity.add_to_group("resources")
        _add_interact_hitbox(entity)
    if data.resource_category == "tiberium_tree":
        entity.add_to_group("resource_trees")
    return entity


func _add_components(entity: Node3D, data: EntityData) -> void:
    _add_stats_component(entity, data)
    _add_health_component(entity, data)
    if data.resource_category == "":
        _add_hitbox_component(entity, data)
        _add_select_component(entity, data)
    _add_combat_component(entity, data)
    _add_movement_controller(entity, data)
    _add_foundation_component(entity, data)
    _add_power_component(entity, data)
    _add_radar_component(entity, data)
    _add_factory_component(entity, data)
    _add_transport_component(entity, data)
    _add_special_ability_component(entity, data)
    _add_resource_tree_component(entity, data)
    _add_resource_component(entity, data)
    _add_harvest_component(entity, data)
    _add_dock_host_component(entity, data)
    _add_dock_client_component(entity, data)
    _add_dock_unload_component(entity, data)
    _add_free_unit_component(entity, data)
    _add_deploy_component(entity, data)
    _add_exit_component(entity, data)
    _add_rally_point_component(entity, data)
    if data.resource_category != "tiberium":
        _add_art_component(entity, data)


func _add_stats_component(entity: Node3D, _data: EntityData) -> void:
    var component := Node.new()
    component.name = "StatsComponent"
    component.set_script(STATS_COMPONENT_SCRIPT)
    entity.add_child(component)
    component.owner = entity


func _add_health_component(entity: Node3D, data: EntityData) -> void:
    if data.strength > 0:
        var component := HEALTH_COMPONENT_SCENE.instantiate()
        component.name = "HealthComponent"
        entity.add_child(component)
        component.owner = entity


func _add_hitbox_component(entity: Node3D, data: EntityData) -> void:
    var component := HITBOX_COMPONENT_SCENE.instantiate()
    component.name = "HitboxComponent"
    var health := entity.get_node_or_null("HealthComponent")
    if health:
        component.health_component = health
    if data.hitbox_size != Vector3.ZERO:
        component.size = data.hitbox_size
    match data.entity_type:
        EntityData.EntityType.INFANTRY, EntityData.EntityType.VEHICLE:
            component.collision_layer = HitboxComponent.LAYER_HITBOX_GROUND
        EntityData.EntityType.AIRCRAFT:
            component.collision_layer = HitboxComponent.LAYER_HITBOX_AIR
        EntityData.EntityType.BUILDING:
            component.collision_layer = HitboxComponent.LAYER_HITBOX_BUILDING
        _:
            component.collision_layer = HitboxComponent.LAYER_HITBOX_GROUND
    component.collision_mask = HitboxComponent.LAYER_PROJECTILE
    entity.add_child(component)
    component.owner = entity


func _add_select_component(entity: Node3D, data: EntityData) -> void:
    var etype := data.entity_type
    if etype != EntityData.EntityType.TERRAIN and etype != EntityData.EntityType.OVERLAY:
        var component := SELECT_COMPONENT_SCENE.instantiate()
        component.name = "SelectComponent"
        match data.entity_type:
            EntityData.EntityType.INFANTRY:
                component.select_box_type = 0
                component.outline_2d_size = Vector2(1.0, 1.5)
            EntityData.EntityType.VEHICLE, EntityData.EntityType.AIRCRAFT:
                component.select_box_type = 1
            EntityData.EntityType.BUILDING:
                component.select_box_type = 2
                var cell_size := 2.0
                var w := data.foundation.x * cell_size
                var d := data.foundation.y * cell_size
                component.selection_size = Vector3(w, 0.01, d)
                component.outline_size = Vector3(w, data.height, d)
        component.is_drag_selectable = data.is_drag_selectable
        var health := entity.get_node_or_null("HealthComponent")
        if health:
            component.health_component = health
        entity.add_child(component)
        component.owner = entity


func _add_combat_component(entity: Node3D, data: EntityData) -> void:
    if not data.weapons.is_empty():
        var component := COMBAT_COMPONENT_SCENE.instantiate()
        component.name = "CombatComponent"
        entity.add_child(component)
        component.owner = entity


func _add_movement_controller(entity: Node3D, data: EntityData) -> void:
    if data.speed > 0.0:
        var component := MOVEMENT_CONTROLLER_SCENE.instantiate()
        component.name = "MovementController"
        entity.add_child(component)
        component.owner = entity


func _add_foundation_component(entity: Node3D, data: EntityData) -> void:
    if data.foundation != Vector2i(1, 1):
        var component := Node.new()
        component.name = "FoundationComponent"
        component.set_script(FOUNDATION_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_power_component(entity: Node3D, data: EntityData) -> void:
    if data.power != 0 or data.powered:
        var component := Node.new()
        component.name = "PowerComponent"
        component.set_script(POWER_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_radar_component(entity: Node3D, data: EntityData) -> void:
    if data.radar:
        var component := Node.new()
        component.name = "RadarComponent"
        component.set_script(RADAR_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_factory_component(entity: Node3D, data: EntityData) -> void:
    if not data.buildable_queue.is_empty():
        var component := Node.new()
        component.name = "FactoryComponent"
        component.set_script(FACTORY_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_exit_component(entity: Node3D, data: EntityData) -> void:
    if data.exit_offset != Vector3.ZERO or data.spawn_offset != Vector3.ZERO:
        var component := Node.new()
        component.name = "ExitComponent"
        component.set_script(EXIT_COMPONENT_SCRIPT)
        component.spawn_offset = data.spawn_offset
        component.exit_offset = data.exit_offset
        component.exit_facing = data.exit_facing
        component.exit_delay = data.exit_delay
        entity.add_child(component)
        component.owner = entity


func _add_rally_point_component(entity: Node3D, data: EntityData) -> void:
    if data.has_rally_point:
        var component := Node.new()
        component.name = "RallyPointComponent"
        component.set_script(RALLY_POINT_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_transport_component(entity: Node3D, data: EntityData) -> void:
    if data.passengers > 0 or data.harvester:
        var component := Node.new()
        component.name = "TransportComponent"
        component.set_script(TRANSPORT_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_special_ability_component(entity: Node3D, data: EntityData) -> void:
    if data.has_special_abilities():
        var component := Node.new()
        component.name = "SpecialAbilityComponent"
        component.set_script(SPECIAL_ABILITY_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_art_component(entity: Node3D, _data: EntityData) -> void:
    var component := ART_COMPONENT_SCENE.instantiate()
    component.name = "ArtComponent"
    entity.add_child(component)
    component.owner = entity


func _wire_components(entity: Node3D) -> void:
    var health_component := entity.get_node_or_null("HealthComponent")
    if health_component:
        var hitbox_component := entity.get_node_or_null("HitboxComponent")
        if hitbox_component and hitbox_component.has_method("set"):
            if "health_component" in hitbox_component:
                hitbox_component.health_component = health_component
        var select_component := entity.get_node_or_null("SelectComponent")
        if select_component and select_component.has_method("set"):
            if "health_component" in select_component:
                select_component.health_component = health_component


func _configure_components(entity: Node3D, data: EntityData) -> void:
    for child in entity.get_children():
        if child.has_method("configure"):
            child.configure(data)


func get_entity_data(entity_id: String) -> EntityData:
    return _entity_cache.get(entity_id)


func get_all_by_type(entity_type: EntityData.EntityType) -> Array[EntityData]:
    var result: Array[EntityData] = []
    for data in _entity_cache.values():
        if data.entity_type == entity_type:
            result.append(data)
    return result


func get_global_rules() -> GlobalRules:
    return _global_rules


func _add_resource_tree_component(entity: Node3D, data: EntityData) -> void:
    if data.resource_category == "tiberium_tree":
        var component := Node.new()
        component.name = "ResourceTreeComponent"
        component.set_script(RESOURCE_TREE_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_resource_component(entity: Node3D, data: EntityData) -> void:
    if data.resource_category != "":
        var component := Node.new()
        component.name = "ResourceComponent"
        component.set_script(RESOURCE_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_harvest_component(entity: Node3D, data: EntityData) -> void:
    if data.harvester:
        var component := Node.new()
        component.name = "HarvestComponent"
        component.set_script(HARVEST_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_dock_host_component(entity: Node3D, data: EntityData) -> void:
    if data.dock_position != Vector3.ZERO:
        var component := Node.new()
        component.name = "DockHostComponent"
        component.set_script(DOCK_HOST_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_dock_client_component(entity: Node3D, data: EntityData) -> void:
    if not data.dock.is_empty():
        var component := Node.new()
        component.name = "DockClientComponent"
        component.set_script(DOCK_CLIENT_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_dock_unload_component(entity: Node3D, data: EntityData) -> void:
    if data.dock_unload:
        var component := Node.new()
        component.name = "DockUnloadComponent"
        component.set_script(DOCK_UNLOAD_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_free_unit_component(entity: Node3D, data: EntityData) -> void:
    if not data.free_unit.is_empty():
        var component := Node.new()
        component.name = "FreeUnitComponent"
        component.set_script(FREE_UNIT_COMPONENT_SCRIPT)
        component.free_unit_id = data.free_unit
        entity.add_child(component)
        component.owner = entity


func _add_deploy_component(entity: Node3D, data: EntityData) -> void:
    if not data.deploys_into.is_empty() or not data.undeploys_into.is_empty():
        var component := Node.new()
        component.name = "DeployComponent"
        component.set_script(DEPLOY_COMPONENT_SCRIPT)
        entity.add_child(component)
        component.owner = entity


func _add_interact_hitbox(entity: Node3D) -> void:
    var component := HITBOX_COMPONENT_SCENE.instantiate()
    component.name = "HitboxComponent"
    component.collision_layer = 1 << 16  # layer 17 — interaction (resource, dock)
    component.collision_mask = 0
    component.size = Vector3(1.5, 1.5, 1.5)
    entity.add_child(component)
    component.owner = entity
