@tool
class_name ArtComponent extends Node3D

@export var art_data: ArtData = null

var _animation_player: AnimationPlayer


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    if art_data:
        _load_model()
        if not art_data.active_anims.is_empty():
            _setup_animation_player()


func configure(data: EntityData) -> void:
    art_data = data.art_data
    if art_data:
        _load_model()
        if not art_data.active_anims.is_empty():
            _setup_animation_player()


func _load_model() -> void:
    if art_data == null or art_data.model_path.is_empty():
        return
    if not ResourceLoader.exists(art_data.model_path):
        push_warning("ArtComponent: model not found: %s" % art_data.model_path)
        return
    var scene := load(art_data.model_path) as PackedScene
    if scene == null:
        push_warning("ArtComponent: failed to load model: %s" % art_data.model_path)
        return
    var instance := scene.instantiate()
    add_child(instance)
    instance.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner


func _setup_animation_player() -> void:
    if not has_node("AnimationPlayer"):
        var ap := AnimationPlayer.new()
        ap.name = "AnimationPlayer"
        add_child(ap)
    _animation_player = get_node("AnimationPlayer") as AnimationPlayer


func play_animation(anim_name: String) -> void:
    if _animation_player and _animation_player.has_animation(anim_name):
        _animation_player.play(anim_name)
