extends Node

const LOW_RES_WIDTH := 960
const LOW_RES_HEIGHT := 540

var _low_res_viewport: SubViewport
var _viewport_camera: Camera3D
var _texture_rect: TextureRect
var _main_camera: Camera3D
var _entity_mask_material: ShaderMaterial


func _ready() -> void:
    _create_low_res_viewport()
    _create_texture_rect()


func _process(_delta: float) -> void:
    _find_main_camera()
    if not is_instance_valid(_main_camera):
        return
    _sync_camera()
    _setup_shared_world()
    _update_uniforms()


func _create_low_res_viewport() -> void:
    _low_res_viewport = SubViewport.new()
    _low_res_viewport.name = "LowResViewport"
    _low_res_viewport.size = Vector2i(LOW_RES_WIDTH, LOW_RES_HEIGHT)
    _low_res_viewport.transparent_bg = false
    _low_res_viewport.disable_3d = false
    _low_res_viewport.audio_listener_enable_3d = false
    _low_res_viewport.handle_input_locally = false
    add_child(_low_res_viewport)

    _viewport_camera = Camera3D.new()
    _viewport_camera.name = "ViewportCamera3D"
    _viewport_camera.cull_mask = 0b01
    _viewport_camera.current = true
    _viewport_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    _low_res_viewport.add_child(_viewport_camera)


func _create_texture_rect() -> void:
    _texture_rect = TextureRect.new()
    _texture_rect.name = "PixelArtTextureRect"
    _texture_rect.texture = _low_res_viewport.get_texture()
    _texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
    _texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _texture_rect.anchor_left = 0.0
    _texture_rect.anchor_top = 0.0
    _texture_rect.anchor_right = 1.0
    _texture_rect.anchor_bottom = 1.0
    _texture_rect.offset_left = 0.0
    _texture_rect.offset_top = 0.0
    _texture_rect.offset_right = 0.0
    _texture_rect.offset_bottom = 0.0
    _texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var shader_material := ShaderMaterial.new()
    shader_material.shader = preload("res://shaders/postprocessing/PixelArtOutline01.gdshader")
    _texture_rect.material = shader_material
    _entity_mask_material = shader_material
    add_child(_texture_rect)


func _find_main_camera() -> void:
    if is_instance_valid(_main_camera):
        return
    var vp := get_viewport()
    if is_instance_valid(vp):
        _main_camera = vp.get_camera_3d()
    if not is_instance_valid(_main_camera):
        var root := get_node("/root")
        if is_instance_valid(root):
            _main_camera = _search_camera3d(root)


func _search_camera3d(node: Node) -> Camera3D:
    if node is Camera3D:
        return node as Camera3D
    for i in node.get_child_count():
        var child := node.get_child(i)
        var found := _search_camera3d(child)
        if is_instance_valid(found):
            return found
    return null


func _sync_camera() -> void:
    _viewport_camera.global_transform = _main_camera.global_transform
    _viewport_camera.size = _main_camera.size
    _viewport_camera.far = _main_camera.far
    _viewport_camera.near = _main_camera.near


func _setup_shared_world() -> void:
    if is_instance_valid(_low_res_viewport.world_3d):
        return
    var vp := get_viewport()
    if not is_instance_valid(vp):
        return
    var world := vp.world_3d as World3D
    if not is_instance_valid(world):
        return
    _low_res_viewport.world_3d = world


func _update_uniforms() -> void:
    if not is_instance_valid(_entity_mask_material):
        return
    _entity_mask_material.set_shader_parameter("pixel_texture", _low_res_viewport.get_texture())
