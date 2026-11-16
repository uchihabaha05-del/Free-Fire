extends Node3D

# MASS BATTLE — native Godot port of Claude's wasteland map.
# The source map is 2.4 km wide; this mobile-friendly version is scaled to 240 m.
const MAX_UNITS := 10000
const FIELD_WIDTH := 110.0
const FIELD_DEPTH := 72.0
const MAP_SIZE := 240.0
const MAP_RADIUS := 100.0
const TERRAIN_SEGMENTS := 180
const GRASS_COUNT := 12000
const ROCK_COUNT := 520

var team_a_count := 500
var team_b_count := 500
var team_a_alive := 500
var team_b_alive := 500
var battle_running := false
var battle_time := 0.0
var battle_speed := 1.0
var ui_refresh_timer := 0.0
var rng := RandomNumberGenerator.new()

var team_a_mesh: MultiMeshInstance3D
var team_b_mesh: MultiMeshInstance3D
var status_label: Label
var a_spin: SpinBox
var b_spin: SpinBox
var speed_slider: HSlider
var start_button: Button
var battle_camera: Camera3D
var camera_move := {"forward": false, "back": false, "left": false, "right": false, "up": false, "down": false}
var camera_look_sensitivity := 0.0025
var camera_flight_speed := 28.0
var camera_drag_active := false
var touch_look_id := -1
var iron_man: Node3D
var iron_man_core: MeshInstance3D
var iron_man_left_palm: OmniLight3D
var iron_man_right_palm: OmniLight3D
var iron_man_attack_timer := 0.0
var iron_man_hover_time := 0.0
var iron_man_side := -1 # -1 = blue army, 1 = red army
var hulk: Node3D
var hulk_attack_timer := 0.0
var hulk_motion_time := 0.0
var soldier_preview_nodes: Array[Node3D] = []
const CHARACTER_NAMES := ["Spider-Man", "Hulk", "Thor", "Captain America", "Iron Man", "Thanos", "Doctor Strange", "Black Panther", "Deadpool", "Wolverine"]
const CHARACTER_MODELS := {
    "Spider-Man": "res://assets/characters/spider_man.glb",
    "Hulk": "res://assets/characters/hulk.glb",
    "Thor": "res://assets/characters/thor.glb",
    "Captain America": "res://assets/characters/captain_america.glb",
    "Iron Man": "res://assets/characters/iron_man.glb",
    "Thanos": "res://assets/characters/thanos.glb",
    "Doctor Strange": "res://assets/characters/doctor_strange.glb",
    "Black Panther": "res://assets/characters/black_panther.glb",
    "Deadpool": "res://assets/characters/deadpool.glb",
    "Wolverine": "res://assets/characters/wolverine.glb"
}
var team_a_units: Array[Node3D] = []
var team_b_units: Array[Node3D] = []
var unit_data: Dictionary = {}
var a_character_option: OptionButton
var b_character_option: OptionButton
var touch_joy_id := -1
var touch_joy_origin := Vector2.ZERO
var touch_joy_vector := Vector2.ZERO

func _ready() -> void:
    rng.randomize()
    _build_world()
    _build_ui()
    _refresh_ui()

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.20, 0.36, 0.53)
    sky_material.sky_horizon_color = Color(0.72, 0.75, 0.73)
    sky_material.ground_bottom_color = Color(0.12, 0.13, 0.11)
    sky_material.ground_horizon_color = Color(0.48, 0.48, 0.42)
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 1.25
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.18
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.65, 0.68, 0.65)
    environment.fog_density = 0.0022
    environment.fog_sky_affect = 0.5
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_energy = 1.85
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 180.0
    add_child(sun)

    _create_terrain()
    _create_wasteland_props()
    _create_camera()

func _terrain_height(noise: FastNoiseLite, x: float, z: float) -> float:
    var broad := noise.get_noise_2d(x, z) * 3.8
    var detail := noise.get_noise_2d(x * 3.2 + 31.0, z * 3.2 - 17.0) * 0.55
    return broad + detail

func _create_terrain() -> void:
    var noise := FastNoiseLite.new()
    noise.seed = 4812
    noise.frequency = 0.012
    noise.fractal_octaves = 4
    noise.fractal_gain = 0.48

    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var step := MAP_SIZE / float(TERRAIN_SEGMENTS)
    for z in range(TERRAIN_SEGMENTS):
        for x in range(TERRAIN_SEGMENTS):
            var x0 := -MAP_SIZE * 0.5 + float(x) * step
            var x1 := x0 + step
            var z0 := -MAP_SIZE * 0.5 + float(z) * step
            var z1 := z0 + step
            var p00 := Vector3(x0, _terrain_height(noise, x0, z0), z0)
            var p10 := Vector3(x1, _terrain_height(noise, x1, z0), z0)
            var p01 := Vector3(x0, _terrain_height(noise, x0, z1), z1)
            var p11 := Vector3(x1, _terrain_height(noise, x1, z1), z1)
            _terrain_vertex(surface, p00, Vector2(float(x) / TERRAIN_SEGMENTS, float(z) / TERRAIN_SEGMENTS), noise)
            _terrain_vertex(surface, p01, Vector2(float(x) / TERRAIN_SEGMENTS, float(z + 1) / TERRAIN_SEGMENTS), noise)
            _terrain_vertex(surface, p10, Vector2(float(x + 1) / TERRAIN_SEGMENTS, float(z) / TERRAIN_SEGMENTS), noise)
            _terrain_vertex(surface, p10, Vector2(float(x + 1) / TERRAIN_SEGMENTS, float(z) / TERRAIN_SEGMENTS), noise)
            _terrain_vertex(surface, p01, Vector2(float(x) / TERRAIN_SEGMENTS, float(z + 1) / TERRAIN_SEGMENTS), noise)
            _terrain_vertex(surface, p11, Vector2(float(x + 1) / TERRAIN_SEGMENTS, float(z + 1) / TERRAIN_SEGMENTS), noise)
    surface.generate_normals()
    var terrain := MeshInstance3D.new()
    terrain.name = "WastelandTerrain"
    terrain.mesh = surface.commit()
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.albedo_color = Color.WHITE
    material.roughness = 1.0
    material.uv1_scale = Vector3(18.0, 18.0, 1.0)
    terrain.material_override = material
    terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(terrain)

func _terrain_vertex(surface: SurfaceTool, point: Vector3, uv: Vector2, noise: FastNoiseLite) -> void:
    var patch := noise.get_noise_2d(point.x * 0.055 + 170.0, point.z * 0.055 - 90.0)
    var moisture := noise.get_noise_2d(point.x * 0.025 - 300.0, point.z * 0.025 + 200.0)
    var dirt := Color(0.52, 0.43, 0.30)
    var dry_grass := Color(0.42, 0.50, 0.29)
    var dusty := Color(0.66, 0.59, 0.45)
    var color := dirt.lerp(dry_grass, clampf((moisture + 0.35) * 0.85, 0.0, 0.72))
    color = color.lerp(dusty, clampf((patch - 0.25) * 0.32, 0.0, 0.22))
    surface.set_color(color)
    surface.set_uv(uv)
    surface.add_vertex(point)

func _create_wasteland_props() -> void:
    _add_dirt_track()
    _add_rock_scatter()
    _add_grass_scatter()
    _add_ruins()
    _add_outer_wall()

func _add_dirt_track() -> void:
    var road := _add_box(Vector3(13.0, 0.10, FIELD_DEPTH + 28.0), Vector3(0, 0.02, 0), Color(0.30, 0.25, 0.18))
    road.rotation_degrees.y = 1.5
    for side in [-1, 1]:
        for row in range(3):
            var z := float(side) * (13.0 + float(row) * 8.0)
            _add_box(Vector3(25.0 - float(row) * 3.0, 1.0, 1.5), Vector3(float(side) * (7.0 - float(row) * 1.5), 0.42, z), Color(0.34, 0.31, 0.24))
        for i in range(7):
            var x := -42.0 + float(i) * 14.0
            _add_box(Vector3(4.0, 0.72, 1.0), Vector3(x, 0.34, float(side) * 25.0), Color(0.49, 0.43, 0.31))

func _add_rock_scatter() -> void:
    var rock := SphereMesh.new()
    rock.radius = 1.0
    rock.height = 1.7
    rock.radial_segments = 7
    rock.rings = 4
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    mm.mesh = rock
    mm.instance_count = ROCK_COUNT
    for i in range(ROCK_COUNT):
        var angle := rng.randf_range(0.0, TAU)
        var radius := sqrt(rng.randf()) * 96.0
        var x := cos(angle) * radius
        var z := sin(angle) * radius
        if absf(x) < 9.0 and absf(z) < 17.0:
            x += signf(x if x != 0.0 else 1.0) * 13.0
        var scale := rng.randf_range(0.45, 2.2)
        var pos := Vector3(x, _height_approx(x, z) + scale * 0.35, z)
        var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale * rng.randf_range(0.8, 1.4), scale * rng.randf_range(0.5, 0.9), scale))
        mm.set_instance_transform(i, Transform3D(basis, pos))
        var shade := rng.randf_range(0.72, 1.12)
        mm.set_instance_color(i, Color(shade, shade * 0.97, shade * 0.90))
    var node := MultiMeshInstance3D.new()
    node.name = "ScatteredRocks"
    node.multimesh = mm
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.albedo_color = Color(0.55, 0.53, 0.48)
    mat.roughness = 1.0
    node.material_override = mat
    add_child(node)

func _add_grass_scatter() -> void:
    var blade := QuadMesh.new()
    blade.size = Vector2(0.52, 0.95)
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    mm.mesh = blade
    mm.instance_count = GRASS_COUNT
    for i in range(GRASS_COUNT):
        var x := rng.randf_range(-98.0, 98.0)
        var z := rng.randf_range(-98.0, 98.0)
        if Vector2(x, z).length() > 99.0:
            x *= 0.82
            z *= 0.82
        if absf(x) < 8.0 and absf(z) < 16.0:
            x += signf(x if x != 0.0 else 1.0) * 12.0
        var h := rng.randf_range(0.55, 1.35)
        var pos := Vector3(x, _height_approx(x, z) + h * 0.5 - 0.04, z)
        var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(rng.randf_range(0.8, 1.5), h, 1.0))
        mm.set_instance_transform(i, Transform3D(basis, pos))
        var g := rng.randf_range(0.72, 1.12)
        mm.set_instance_color(i, Color(g * 0.82, g, g * 0.62))
    var node := MultiMeshInstance3D.new()
    node.name = "DryGrass"
    node.multimesh = mm
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.albedo_color = Color.WHITE
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color.a = 0.94
    node.material_override = mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _add_ruins() -> void:
    var stone := Color(0.43, 0.41, 0.36)
    for cluster in range(16):
        var angle := rng.randf_range(0.0, TAU)
        var radius := rng.randf_range(35.0, 88.0)
        var center := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        var pieces := rng.randi_range(8, 16)
        for i in range(pieces):
            var offset := Vector3(rng.randf_range(-7.0, 7.0), 0.0, rng.randf_range(-7.0, 7.0))
            var h := rng.randf_range(0.8, 3.2)
            var size := Vector3(rng.randf_range(1.2, 3.8), h, rng.randf_range(1.2, 3.0))
            var block := _add_box(size, center + offset + Vector3(0, h * 0.5, 0), stone.lightened(rng.randf_range(-0.08, 0.08)))
            block.rotation_degrees = Vector3(rng.randf_range(-5, 5), rng.randf_range(0, 180), rng.randf_range(-5, 5))

func _add_outer_wall() -> void:
    var wall_material := Color(0.43, 0.41, 0.37)
    var segments := 112
    for i in range(segments):
        var angle := float(i) / float(segments) * TAU
        var next_angle := float(i + 1) / float(segments) * TAU
        var middle := (angle + next_angle) * 0.5
        var arc_length := TAU * MAP_RADIUS / float(segments)
        var pos := Vector3(cos(middle) * MAP_RADIUS, 11.0, sin(middle) * MAP_RADIUS)
        var wall := _add_box(Vector3(arc_length + 0.8, 22.0, 4.5), pos, wall_material)
        wall.rotation.y = -middle
        if i % 4 == 0:
            var buttress := _add_box(Vector3(5.0, 25.0, 7.0), Vector3(cos(angle) * (MAP_RADIUS - 2.5), 12.5, sin(angle) * (MAP_RADIUS - 2.5)), wall_material.darkened(0.08))
            buttress.rotation.y = -angle

func _height_approx(x: float, z: float) -> float:
    var broad := sin(x * 0.11) * cos(z * 0.09) * 1.4
    var detail := sin(x * 0.43 + 31.0) * cos(z * 0.37 - 17.0) * 0.22
    return broad + detail

func _create_camera() -> void:
    battle_camera = Camera3D.new()
    battle_camera.name = "FreeFlightCamera"
    battle_camera.position = Vector3(0, 27, 68)
    battle_camera.rotation_degrees = Vector3(-23, 0, 0)
    battle_camera.current = true
    battle_camera.fov = 66
    battle_camera.near = 0.08
    battle_camera.far = 520.0
    add_child(battle_camera)

func _add_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.96
    node.material_override = material
    node.position = pos
    add_child(node)
    return node


func _create_iron_man() -> void:
    iron_man = Node3D.new()
    iron_man.name = "IRON_MAN_HERO"
    iron_man.position = Vector3(0.0, 5.2, float(iron_man_side) * 13.0)
    add_child(iron_man)

    var red := _hero_material(Color(0.48, 0.025, 0.018), 0.32)
    var red_dark := _hero_material(Color(0.20, 0.012, 0.009), 0.42)
    var gold := _hero_material(Color(0.92, 0.58, 0.12), 0.30)
    var gold_light := _hero_material(Color(1.0, 0.76, 0.30), 0.24)
    var reactor := _hero_material(Color(0.30, 0.88, 1.0), 0.16, true)
    var dark := _hero_material(Color(0.035, 0.045, 0.055), 0.5)

    _hero_part(BoxMesh.new(), Vector3(0, 1.25, 0), Vector3(0.92, 1.12, 0.48), red)
    _hero_part(SphereMesh.new(), Vector3(0, 1.95, 0.02), Vector3(0.34, 0.42, 0.34), gold)
    _hero_part(BoxMesh.new(), Vector3(0, 1.93, 0.12), Vector3(0.34, 0.07, 0.12), reactor)
    _hero_part(SphereMesh.new(), Vector3(0, 1.23, 0.27), Vector3(0.24, 0.24, 0.08), reactor)

    # Red-and-gold shoulder armor, arms, gauntlets and legs.
    for side in [-1.0, 1.0]:
        _hero_part(SphereMesh.new(), Vector3(side * 0.53, 1.62, 0), Vector3(0.34, 0.34, 0.34), gold)
        _hero_part(CapsuleMesh.new(), Vector3(side * 0.62, 1.13, 0.02), Vector3(0.24, 0.72, 0.24), red)
        _hero_part(BoxMesh.new(), Vector3(side * 0.62, 0.78, 0.19), Vector3(0.25, 0.22, 0.30), gold)
        _hero_part(SphereMesh.new(), Vector3(side * 0.62, 0.72, 0.34), Vector3(0.16, 0.16, 0.10), reactor)
        _hero_part(CapsuleMesh.new(), Vector3(side * 0.25, 0.38, 0), Vector3(0.29, 0.78, 0.30), red_dark)
        _hero_part(BoxMesh.new(), Vector3(side * 0.25, 0.04, 0.12), Vector3(0.34, 0.20, 0.52), gold)
        _hero_part(SphereMesh.new(), Vector3(side * 0.25, -0.12, -0.12), Vector3(0.13, 0.18, 0.13), reactor)

    # Helmet faceplate and narrow glowing eye slits.
    _hero_part(SphereMesh.new(), Vector3(0, 2.08, 0.08), Vector3(0.27, 0.18, 0.28), gold_light)
    _hero_part(BoxMesh.new(), Vector3(-0.12, 2.10, 0.30), Vector3(0.12, 0.035, 0.025), reactor)
    _hero_part(BoxMesh.new(), Vector3(0.12, 2.10, 0.30), Vector3(0.12, 0.035, 0.025), reactor)
    _hero_part(BoxMesh.new(), Vector3(0, 1.42, -0.30), Vector3(0.72, 0.78, 0.16), red_dark)

    # Back thruster pack and blue exhaust glow.
    _hero_part(BoxMesh.new(), Vector3(0, 1.23, -0.34), Vector3(0.62, 0.68, 0.22), gold)
    for side in [-1.0, 1.0]:
        _hero_part(CylinderMesh.new(), Vector3(side * 0.19, 0.82, -0.40), Vector3(0.18, 0.36, 0.18), reactor)
    iron_man_core = iron_man.get_node_or_null("Part_3") as MeshInstance3D
    iron_man_left_palm = _hero_light(Vector3(-0.62, 0.72, 0.40))
    iron_man_right_palm = _hero_light(Vector3(0.62, 0.72, 0.40))
    var core_light := OmniLight3D.new()
    core_light.position = Vector3(0, 1.23, 0.42)
    core_light.light_color = Color(0.24, 0.78, 1.0)
    core_light.light_energy = 1.4
    core_light.omni_range = 5.0
    iron_man.add_child(core_light)

    var label := Label3D.new()
    label.text = "IRON MAN"
    label.position = Vector3(0, 2.55, 0)
    label.font_size = 48
    label.modulate = Color(1.0, 0.78, 0.32)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    iron_man.add_child(label)


func _organic_material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.0
    material.roughness = roughness
    material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
    return material

func _hero_material(color: Color, roughness: float, glow: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.72
    material.roughness = roughness
    if glow:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 2.8
    return material

func _hero_part(mesh: PrimitiveMesh, pos: Vector3, scale: Vector3, material: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.mesh = mesh
    part.position = pos
    part.scale = scale
    part.material_override = material
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    iron_man.add_child(part)
    return part

func _hero_light(pos: Vector3) -> OmniLight3D:
    var light := OmniLight3D.new()
    light.position = pos
    light.light_color = Color(0.22, 0.78, 1.0)
    light.light_energy = 2.2
    light.omni_range = 3.8
    iron_man.add_child(light)
    return light

func _update_iron_man(delta: float) -> void:
    if iron_man == null:
        return
    iron_man_hover_time += delta
    var target_z := float(iron_man_side) * (10.5 + sin(iron_man_hover_time * 0.8) * 1.4)
    iron_man.position = Vector3(sin(iron_man_hover_time * 0.55) * 4.0, 5.2 + sin(iron_man_hover_time * 2.4) * 0.22, target_z)
    iron_man.rotation.y = sin(iron_man_hover_time * 0.7) * 0.10
    var pulse := 1.7 + absf(sin(iron_man_hover_time * 5.0)) * 1.1
    iron_man_left_palm.light_energy = pulse
    iron_man_right_palm.light_energy = pulse
    if not battle_running:
        return
    iron_man_attack_timer -= delta * battle_speed
    if iron_man_attack_timer <= 0.0:
        iron_man_attack_timer = 0.72
        _iron_man_repulsor_attack()

func _iron_man_repulsor_attack() -> void:
    if iron_man_side < 0:
        if team_b_alive <= 0:
            return
        team_b_alive = maxi(0, team_b_alive - 7)
        _spawn_repulsor_beam(Vector3(0.62, 0.72, 0.40), Vector3(0, 1.2, 15.0))
    else:
        if team_a_alive <= 0:
            return
        team_a_alive = maxi(0, team_a_alive - 7)
        _spawn_repulsor_beam(Vector3(0.62, 0.72, 0.40), Vector3(0, 1.2, -15.0))
    _apply_visible_counts()

func _spawn_repulsor_beam(hand_offset: Vector3, target: Vector3) -> void:
    var beam := MeshInstance3D.new()
    var immediate := ImmediateMesh.new()
    immediate.surface_begin(Mesh.PRIMITIVE_LINES)
    immediate.surface_add_vertex(hand_offset)
    immediate.surface_add_vertex(target)
    immediate.surface_end()
    beam.mesh = immediate
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.35, 0.88, 1.0)
    material.emission_enabled = true
    material.emission = Color(0.20, 0.78, 1.0)
    material.emission_energy_multiplier = 5.0
    material.no_depth_test = true
    beam.material_override = material
    iron_man.add_child(beam)
    get_tree().create_timer(0.11).timeout.connect(beam.queue_free)



func _create_hulk() -> void:
    hulk = Node3D.new()
    hulk.name = "HULK_HERO"
    hulk.position = Vector3(0.0, _height_approx(0.0, 13.0), 13.0)
    hulk.rotation.y = PI
    add_child(hulk)

    var skin := _organic_material(Color(0.12, 0.39, 0.12), 0.82)
    var skin_light := _organic_material(Color(0.20, 0.52, 0.18), 0.76)
    var skin_dark := _organic_material(Color(0.055, 0.22, 0.07), 0.88)
    var pants := _hero_material(Color(0.20, 0.055, 0.29), 0.92)
    var pants_light := _hero_material(Color(0.31, 0.10, 0.39), 0.88)
    var hair := _hero_material(Color(0.055, 0.045, 0.035), 0.94)
    var eye := _hero_material(Color(1.0, 0.22, 0.08), 0.28, true)

    # Broad chest, trapezius and abdomen give Hulk a massive silhouette.
    _hulk_part(SphereMesh.new(), Vector3(0, 2.05, 0), Vector3(1.08, 0.86, 0.55), skin)
    _hulk_part(SphereMesh.new(), Vector3(0, 1.62, 0.02), Vector3(0.66, 0.58, 0.43), skin_light)
    # Layered pectorals, obliques and abdominal definition.
    _hulk_part(SphereMesh.new(), Vector3(-0.31, 2.13, 0.40), Vector3(0.34, 0.25, 0.15), skin_light)
    _hulk_part(SphereMesh.new(), Vector3(0.31, 2.13, 0.40), Vector3(0.34, 0.25, 0.15), skin_light)
    for row in range(3):
        for side in [-1.0, 1.0]:
            _hulk_part(SphereMesh.new(), Vector3(side * 0.16, 1.78 - float(row) * 0.17, 0.405), Vector3(0.145, 0.105, 0.075), skin)
    _hulk_part(SphereMesh.new(), Vector3(-0.30, 2.18, 0.42), Vector3(0.34, 0.30, 0.12), skin_light)
    _hulk_part(SphereMesh.new(), Vector3(0.30, 2.18, 0.42), Vector3(0.34, 0.30, 0.12), skin_light)
    for side in [-1.0, 1.0]:
        _hulk_part(SphereMesh.new(), Vector3(side * 0.53, 2.34, 0), Vector3(0.48, 0.48, 0.48), skin)
        _hulk_part(CapsuleMesh.new(), Vector3(side * 0.78, 1.72, 0.02), Vector3(0.39, 0.83, 0.40), skin)
        _hulk_part(SphereMesh.new(), Vector3(side * 0.88, 1.18, 0.06), Vector3(0.39, 0.40, 0.39), skin_light)
        _hulk_part(CapsuleMesh.new(), Vector3(side * 0.92, 0.79, 0.10), Vector3(0.34, 0.66, 0.34), skin)
        _hulk_part(CapsuleMesh.new(), Vector3(side * 0.97, 1.38, 0.34), Vector3(0.07, 0.30, 0.08), skin_light)
        _hulk_part(SphereMesh.new(), Vector3(side * 0.92, 0.48, 0.18), Vector3(0.38, 0.29, 0.34), skin_dark)
        _hulk_part(CapsuleMesh.new(), Vector3(side * 0.30, 0.83, 0), Vector3(0.34, 0.78, 0.35), skin)
        _hulk_part(SphereMesh.new(), Vector3(side * 0.30, 0.42, 0.03), Vector3(0.35, 0.35, 0.38), pants_light)
        _hulk_part(SphereMesh.new(), Vector3(side * 0.30, 0.12, 0.16), Vector3(0.30, 0.17, 0.48), skin_dark)

    # Torn purple shorts with uneven hems and a heavy belt line.
    _hulk_part(BoxMesh.new(), Vector3(0, 1.02, 0), Vector3(0.86, 0.42, 0.48), pants)
    _hulk_part(BoxMesh.new(), Vector3(-0.27, 0.77, 0), Vector3(0.39, 0.20, 0.46), pants_light)
    _hulk_part(BoxMesh.new(), Vector3(0.27, 0.77, 0), Vector3(0.39, 0.20, 0.46), pants)
    _hulk_part(BoxMesh.new(), Vector3(0, 1.20, 0.02), Vector3(0.90, 0.10, 0.50), pants_light)

    # Neck, heavy jaw, brow ridge, nose, ears and swept dark hair.
    _hulk_part(CylinderMesh.new(), Vector3(0, 2.62, 0), Vector3(0.34, 0.36, 0.34), skin_dark)
    _hulk_part(SphereMesh.new(), Vector3(0, 2.98, 0.02), Vector3(0.43, 0.48, 0.39), skin_light)
    _hulk_part(SphereMesh.new(), Vector3(0, 2.77, 0.30), Vector3(0.34, 0.20, 0.18), skin)
    _hulk_part(SphereMesh.new(), Vector3(0, 3.02, 0.37), Vector3(0.10, 0.16, 0.10), skin_dark)
    _hulk_part(SphereMesh.new(), Vector3(-0.19, 3.13, 0.34), Vector3(0.17, 0.09, 0.10), skin_dark)
    _hulk_part(SphereMesh.new(), Vector3(0.19, 3.13, 0.34), Vector3(0.17, 0.09, 0.10), skin_dark)
    _hulk_part(SphereMesh.new(), Vector3(-0.15, 3.04, 0.43), Vector3(0.055, 0.035, 0.025), eye)
    _hulk_part(SphereMesh.new(), Vector3(0.15, 3.04, 0.43), Vector3(0.055, 0.035, 0.025), eye)
    _hulk_part(SphereMesh.new(), Vector3(0, 2.86, 0.43), Vector3(0.18, 0.045, 0.035), hair)
    _hulk_part(SphereMesh.new(), Vector3(0, 3.34, -0.01), Vector3(0.42, 0.19, 0.38), hair)
    _hulk_part(SphereMesh.new(), Vector3(-0.30, 3.27, 0.02), Vector3(0.18, 0.22, 0.25), hair)
    _hulk_part(SphereMesh.new(), Vector3(0.30, 3.27, 0.02), Vector3(0.18, 0.22, 0.25), hair)

    var label := Label3D.new()
    label.text = "HULK"
    label.position = Vector3(0, 3.72, 0)
    label.font_size = 48
    label.modulate = Color(0.55, 1.0, 0.38)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    hulk.add_child(label)

func _hulk_part(mesh: PrimitiveMesh, pos: Vector3, scale: Vector3, material: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.mesh = mesh
    part.position = pos
    part.scale = scale
    part.material_override = material
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    hulk.add_child(part)
    return part

func _update_hulk(delta: float) -> void:
    if hulk == null:
        return
    hulk_motion_time += delta
    hulk.position.y = _height_approx(0.0, 13.0) + absf(sin(hulk_motion_time * 2.1)) * 0.055
    hulk.rotation.y = PI + sin(hulk_motion_time * 0.65) * 0.07
    if not battle_running:
        return
    hulk_attack_timer -= delta * battle_speed
    if hulk_attack_timer <= 0.0:
        hulk_attack_timer = 1.35
        _hulk_ground_slam()

func _hulk_ground_slam() -> void:
    if team_a_alive <= 0:
        return
    team_a_alive = maxi(0, team_a_alive - 18)
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.30
    torus.outer_radius = 0.48
    ring.mesh = torus
    ring.position = Vector3(0, _height_approx(0.0, -8.0) + 0.16, -8.0)
    ring.rotation.x = PI * 0.5
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.50, 1.0, 0.28, 0.85)
    material.emission_enabled = true
    material.emission = Color(0.25, 0.9, 0.12)
    material.emission_energy_multiplier = 2.5
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring.material_override = material
    add_child(ring)
    var tween := create_tween()
    tween.tween_property(ring, "scale", Vector3(16.0, 16.0, 16.0), 0.38)
    tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.38)
    tween.tween_callback(ring.queue_free)
    _apply_visible_counts()

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "GameUI"
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(14, 14)
    panel.custom_minimum_size = Vector2(290, 0)
    layer.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 5)
    panel.add_child(column)
    var title := Label.new()
    title.text = "MASS BATTLE"
    title.add_theme_font_size_override("font_size", 22)
    column.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "CHOOSE HEROES • BUILD YOUR TEAMS"
    subtitle.add_theme_font_size_override("font_size", 9)
    column.add_child(subtitle)
    column.add_child(HSeparator.new())
    column.add_child(_make_label("BLUE TEAM — CHARACTER"))
    a_character_option = _make_character_option("Iron Man")
    column.add_child(a_character_option)
    column.add_child(_make_label("BLUE TEAM — NUMBER OF CHARACTERS"))
    a_spin = _make_spin(3)
    column.add_child(a_spin)
    column.add_child(_make_label("RED TEAM — CHARACTER"))
    b_character_option = _make_character_option("Hulk")
    column.add_child(b_character_option)
    column.add_child(_make_label("RED TEAM — NUMBER OF CHARACTERS"))
    b_spin = _make_spin(3)
    column.add_child(b_spin)
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 11)
    column.add_child(status_label)
    start_button = Button.new()
    start_button.text = "START BATTLE"
    start_button.custom_minimum_size.y = 40
    start_button.pressed.connect(_start_battle)
    column.add_child(start_button)

func _make_character_option(selected_name: String) -> OptionButton:
    var option := OptionButton.new()
    option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for character_name in CHARACTER_NAMES:
        option.add_item(character_name)
    option.select(CHARACTER_NAMES.find(selected_name))
    return option

func _make_label(value: String) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", 10)
    return label

func _make_spin(initial: int) -> SpinBox:
    var spin := SpinBox.new()
    spin.min_value = 1
    spin.max_value = 50
    spin.step = 1
    spin.value = initial
    spin.custom_minimum_size.x = 250
    return spin

func _create_soldier_previews() -> void:
    # One rigged GLB showcase per side. The mass formations remain MultiMesh
    # instances so large battles do not create thousands of Skeleton3D nodes.
    var model_path := "res://assets/characters/male_soldier_03.glb"
    if not ResourceLoader.exists(model_path):
        push_warning("Soldier GLB is not present; using the built-in MultiMesh soldiers.")
        return
    var packed := load(model_path) as PackedScene
    if packed == null:
        push_warning("Could not load soldier GLB scene: " + model_path)
        return
    for side in [-1, 1]:
        var soldier := packed.instantiate() as Node3D
        if soldier == null:
            continue
        soldier.name = "RiggedSoldierPreview_%s" % ("Blue" if side < 0 else "Red")
        soldier.scale = Vector3.ONE
        soldier.position = Vector3(-FIELD_WIDTH * 0.5 - 2.0, _height_approx(-FIELD_WIDTH * 0.5 - 2.0, float(side) * 9.0), float(side) * 9.0)
        soldier.rotation.y = 0.0 if side < 0 else PI
        add_child(soldier)
        soldier_preview_nodes.append(soldier)
        var animation_player := soldier.find_child("AnimationPlayer", true, false) as AnimationPlayer
        if animation_player != null:
            var idle_name := ""
            for animation_name in animation_player.get_animation_list():
                if String(animation_name).to_lower().contains("idle"):
                    idle_name = String(animation_name)
                    break
            if idle_name != "":
                animation_player.play(idle_name)


func _setup_armies() -> void:
    team_a_mesh = _create_army(Color(0.18, 0.38, 0.70), -1)
    team_b_mesh = _create_army(Color(0.70, 0.20, 0.16), 1)
    add_child(team_a_mesh)
    add_child(team_b_mesh)

func _create_army(color: Color, side: int) -> MultiMeshInstance3D:
    var instance := MultiMeshInstance3D.new()
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_colors = true
    multimesh.mesh = _make_soldier_mesh()
    multimesh.instance_count = MAX_UNITS
    for i in range(MAX_UNITS):
        var columns := 100
        var row := int(i / columns)
        var col := i % columns
        var x := (float(col) / float(columns - 1) - 0.5) * (FIELD_WIDTH - 16.0)
        var z := float(side) * (5.5 + float(row) * 0.40)
        var angle := 0.0 if side < 0 else PI
        var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * rng.randf_range(0.88, 1.08))
        multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x + rng.randf_range(-0.12, 0.12), _height_approx(x, z), z + rng.randf_range(-0.12, 0.12))))
        multimesh.set_instance_color(i, color.lightened(rng.randf_range(-0.08, 0.12)))
    instance.multimesh = multimesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    material.vertex_color_use_as_albedo = true
    material.metallic = 0.0
    material.roughness = 0.94
    material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
    instance.material_override = material
    return instance

func _make_soldier_mesh() -> Mesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)

    # Layered tactical silhouette: armored vest, webbing, helmet and reinforced limbs.
    var torso := CapsuleMesh.new()
    torso.radius = 0.22
    torso.height = 0.96
    torso.radial_segments = 12
    torso.rings = 6
    _append_part(surface, torso, Vector3(0, 1.08, 0), Vector3(0.92, 1.0, 0.66), Vector3.ZERO)

    var head := SphereMesh.new()
    head.radius = 0.17
    head.height = 0.34
    head.radial_segments = 12
    head.rings = 8
    _append_part(surface, head, Vector3(0, 1.73, 0.015), Vector3.ONE, Vector3.ZERO)

    var helmet := SphereMesh.new()
    helmet.radius = 0.20
    helmet.height = 0.21
    helmet.radial_segments = 12
    helmet.rings = 6
    _append_part(surface, helmet, Vector3(0, 1.86, 0.005), Vector3(1.0, 0.58, 1.0), Vector3.ZERO)
    var helmet_rim := BoxMesh.new()
    helmet_rim.size = Vector3(0.39, 0.045, 0.30)
    _append_part(surface, helmet_rim, Vector3(0, 1.79, 0.10), Vector3.ONE, Vector3.ZERO)
    var goggles := BoxMesh.new()
    goggles.size = Vector3(0.30, 0.055, 0.035)
    _append_part(surface, goggles, Vector3(0, 1.72, 0.17), Vector3.ONE, Vector3.ZERO)

    var vest := BoxMesh.new()
    vest.size = Vector3(0.48, 0.60, 0.16)
    _append_part(surface, vest, Vector3(0, 1.14, 0.245), Vector3.ONE, Vector3.ZERO)
    var chest_plate := BoxMesh.new()
    chest_plate.size = Vector3(0.34, 0.22, 0.045)
    _append_part(surface, chest_plate, Vector3(0, 1.28, 0.34), Vector3.ONE, Vector3.ZERO)
    var belt := BoxMesh.new()
    belt.size = Vector3(0.47, 0.10, 0.25)
    _append_part(surface, belt, Vector3(0, 0.82, 0.02), Vector3.ONE, Vector3.ZERO)
    var pouch := BoxMesh.new()
    pouch.size = Vector3(0.13, 0.17, 0.12)
    for side in [-1.0, 1.0]:
        _append_part(surface, pouch, Vector3(side * 0.20, 0.91, 0.20), Vector3.ONE, Vector3.ZERO)
        _append_part(surface, pouch, Vector3(side * 0.23, 1.27, 0.23), Vector3(0.9, 0.8, 0.8), Vector3.ZERO)

    var backpack := BoxMesh.new()
    backpack.size = Vector3(0.31, 0.43, 0.20)
    _append_part(surface, backpack, Vector3(0, 1.12, -0.22), Vector3.ONE, Vector3.ZERO)
    var shoulder := SphereMesh.new()
    shoulder.radius = 0.17
    shoulder.height = 0.25
    for side in [-1.0, 1.0]:
        _append_part(surface, shoulder, Vector3(side * 0.31, 1.42, 0), Vector3(1.0, 0.85, 1.0), Vector3(0, 0, side * -0.12))

    var limb := CapsuleMesh.new()
    limb.radius = 0.075
    limb.height = 0.62
    limb.radial_segments = 10
    limb.rings = 6
    _append_part(surface, limb, Vector3(-0.27, 1.10, 0.0), Vector3(1.08, 1.0, 1.0), Vector3(0, 0, -0.22))
    _append_part(surface, limb, Vector3(0.27, 1.10, 0.0), Vector3(1.08, 1.0, 1.0), Vector3(0, 0, 0.22))
    var forearm := CapsuleMesh.new()
    forearm.radius = 0.085
    forearm.height = 0.40
    _append_part(surface, forearm, Vector3(-0.34, 0.83, 0.10), Vector3.ONE, Vector3(0, 0, -0.16))
    _append_part(surface, forearm, Vector3(0.34, 0.83, 0.10), Vector3.ONE, Vector3(0, 0, 0.16))
    _append_part(surface, limb, Vector3(-0.12, 0.39, 0.0), Vector3(0.96, 1.12, 0.96), Vector3(0, 0, -0.08))
    _append_part(surface, limb, Vector3(0.12, 0.39, 0.0), Vector3(0.96, 1.12, 0.96), Vector3(0, 0, 0.08))
    var knee := SphereMesh.new()
    knee.radius = 0.105
    knee.height = 0.12
    _append_part(surface, knee, Vector3(-0.12, 0.37, 0.13), Vector3(1.0, 0.8, 0.65), Vector3.ZERO)
    _append_part(surface, knee, Vector3(0.12, 0.37, 0.13), Vector3(1.0, 0.8, 0.65), Vector3.ZERO)
    var boot := BoxMesh.new()
    boot.size = Vector3(0.23, 0.18, 0.40)
    _append_part(surface, boot, Vector3(-0.12, 0.12, 0.12), Vector3.ONE, Vector3.ZERO)
    _append_part(surface, boot, Vector3(0.12, 0.12, 0.12), Vector3.ONE, Vector3.ZERO)

    # Detailed rifle silhouette with stock, receiver, barrel, grip and optic.
    var rifle := BoxMesh.new()
    rifle.size = Vector3(0.085, 0.105, 0.48)
    _append_part(surface, rifle, Vector3(0.19, 1.22, 0.26), Vector3.ONE, Vector3(-0.12, 0, 0))
    var stock := BoxMesh.new()
    stock.size = Vector3(0.10, 0.12, 0.20)
    _append_part(surface, stock, Vector3(0.19, 1.22, -0.08), Vector3.ONE, Vector3.ZERO)
    var barrel := CylinderMesh.new()
    barrel.top_radius = 0.022
    barrel.bottom_radius = 0.028
    barrel.height = 0.42
    _append_part(surface, barrel, Vector3(0.19, 1.23, 0.70), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
    var grip := BoxMesh.new()
    grip.size = Vector3(0.07, 0.18, 0.10)
    _append_part(surface, grip, Vector3(0.19, 1.09, 0.30), Vector3.ONE, Vector3(-0.22, 0, 0))
    var optic := CylinderMesh.new()
    optic.top_radius = 0.035
    optic.bottom_radius = 0.035
    optic.height = 0.15
    _append_part(surface, optic, Vector3(0.19, 1.31, 0.28), Vector3.ONE, Vector3(PI * 0.5, 0, 0))

    surface.generate_normals()
    return surface.commit()

func _append_part(surface: SurfaceTool, mesh: Mesh, position: Vector3, scale: Vector3, rotation: Vector3) -> void:
    var transform := Transform3D(Basis.from_euler(rotation).scaled(scale), position)
    surface.append_from(mesh, 0, transform)

func _start_battle() -> void:
    _clear_units()
    battle_time = 0.0
    team_a_count = clampi(int(a_spin.value), 1, 50)
    team_b_count = clampi(int(b_spin.value), 1, 50)
    team_a_alive = team_a_count
    team_b_alive = team_b_count
    _spawn_team(CHARACTER_NAMES[a_character_option.selected], -1, team_a_count)
    _spawn_team(CHARACTER_NAMES[b_character_option.selected], 1, team_b_count)
    battle_running = true
    start_button.text = "RESTART BATTLE"
    _refresh_ui()

func _reset_battle() -> void:
    battle_running = false
    _clear_units()
    battle_time = 0.0
    team_a_alive = 0
    team_b_alive = 0
    start_button.text = "START BATTLE"
    _refresh_ui()

func _clear_units() -> void:
    for actor in team_a_units + team_b_units:
        if is_instance_valid(actor):
            actor.queue_free()
    team_a_units.clear()
    team_b_units.clear()
    unit_data.clear()

func _spawn_team(character_name: String, side: int, amount: int) -> void:
    for i in range(amount):
        var actor := _spawn_character(character_name, side, i, amount)
        if actor == null:
            continue
        if side < 0:
            team_a_units.append(actor)
        else:
            team_b_units.append(actor)
        unit_data[actor.get_instance_id()] = {"health": 100.0, "cooldown": rng.randf_range(0.1, 0.8), "team": side}

func _spawn_character(character_name: String, side: int, index: int, amount: int) -> Node3D:
    var actor: Node3D
    var model_path: String = CHARACTER_MODELS.get(character_name, "")
    if model_path != "" and ResourceLoader.exists(model_path):
        var packed := load(model_path) as PackedScene
        if packed != null:
            actor = packed.instantiate() as Node3D
    if actor == null:
        actor = _create_character_placeholder(character_name, side)
    var row := int(index / 5)
    var col := index % 5
    var spread := minf(float(amount), 5.0)
    var x := (float(col) - (spread - 1.0) * 0.5) * 2.2
    var z := float(side) * (12.0 + float(row) * 2.4)
    actor.name = "%s_Team_%s_%02d" % [character_name.replace(" ", ""), "Blue" if side < 0 else "Red", index]
    actor.position = Vector3(x, _height_approx(x, z), z)
    actor.scale = Vector3.ONE
    actor.look_at(Vector3(x, _height_approx(x, -float(side) * 12.0), -float(side) * 12.0), Vector3.UP)
    add_child(actor)
    return actor

func _create_character_placeholder(character_name: String, side: int) -> Node3D:
    var actor := Node3D.new()
    var team_color := Color(0.16, 0.38, 0.95) if side < 0 else Color(0.88, 0.16, 0.12)
    var body_material := StandardMaterial3D.new()
    body_material.albedo_color = team_color
    body_material.roughness = 0.58
    var body := MeshInstance3D.new()
    var torso := CapsuleMesh.new()
    torso.radius = 0.42
    torso.height = 1.35
    torso.radial_segments = 20
    torso.rings = 10
    body.mesh = torso
    body.position.y = 1.05
    body.material_override = body_material
    actor.add_child(body)
    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.31
    head_mesh.height = 0.62
    head_mesh.radial_segments = 20
    head_mesh.rings = 12
    head.mesh = head_mesh
    head.position.y = 1.95
    head.material_override = body_material
    actor.add_child(head)
    var label := Label3D.new()
    label.text = character_name.to_upper() + " • MODEL NEEDED"
    label.position.y = 2.55
    label.font_size = 24
    label.modulate = Color(1.0, 0.9, 0.65)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    actor.add_child(label)
    return actor

func _apply_visible_counts() -> void:
    team_a_alive = team_a_units.size()
    team_b_alive = team_b_units.size()

func _update_combat(delta: float) -> void:
    for is_blue in [true, false]:
        var allies: Array[Node3D] = team_a_units if is_blue else team_b_units
        var enemies: Array[Node3D] = team_b_units if is_blue else team_a_units
        for actor in allies.duplicate():
            if not is_instance_valid(actor):
                allies.erase(actor)
                continue
            if enemies.is_empty():
                break
            var nearest: Node3D = null
            var nearest_distance := INF
            for enemy in enemies:
                if not is_instance_valid(enemy):
                    continue
                var distance := Vector2(actor.position.x - enemy.position.x, actor.position.z - enemy.position.z).length()
                if distance < nearest_distance:
                    nearest_distance = distance
                    nearest = enemy
            if nearest == null:
                continue
            var direction := Vector3(nearest.position.x - actor.position.x, 0.0, nearest.position.z - actor.position.z)
            if nearest_distance > 2.0:
                actor.position += direction.normalized() * 2.8 * delta
                actor.position.y = _height_approx(actor.position.x, actor.position.z)
                actor.look_at(Vector3(nearest.position.x, actor.position.y, nearest.position.z), Vector3.UP)
            else:
                var actor_id := actor.get_instance_id()
                var data: Dictionary = unit_data.get(actor_id, {})
                var cooldown := float(data.get("cooldown", 0.0)) - delta
                if cooldown <= 0.0:
                    var enemy_id := nearest.get_instance_id()
                    var enemy_data: Dictionary = unit_data.get(enemy_id, {})
                    enemy_data["health"] = float(enemy_data.get("health", 100.0)) - 22.0
                    unit_data[enemy_id] = enemy_data
                    cooldown = 0.85
                    if float(enemy_data["health"]) <= 0.0:
                        enemies.erase(nearest)
                        unit_data.erase(enemy_id)
                        nearest.queue_free()
                data["cooldown"] = cooldown
                unit_data[actor_id] = data

func _process(delta: float) -> void:
    _update_flight_camera(delta)
    if not battle_running:
        return
    battle_time += delta
    _update_combat(delta)
    team_a_alive = team_a_units.size()
    team_b_alive = team_b_units.size()
    ui_refresh_timer += delta
    if ui_refresh_timer >= 0.2:
        ui_refresh_timer = 0.0
        _refresh_ui()
    if team_a_units.is_empty() or team_b_units.is_empty():
        battle_running = false
        start_button.text = "START NEW BATTLE"
        _refresh_ui()

func _winner_text() -> String:
    if team_a_alive > team_b_alive:
        return "BLUE TEAM WINS!  •  %d survivors" % team_a_alive
    if team_b_alive > team_a_alive:
        return "RED TEAM WINS!  •  %d survivors" % team_b_alive
    return "DRAW — BOTH ARMIES ELIMINATED"

func _refresh_ui() -> void:
    if status_label == null:
        return
    team_a_alive = team_a_units.size()
    team_b_alive = team_b_units.size()
    if not battle_running and battle_time > 0.0:
        status_label.text = _winner_text() + "\nBlue: %d  •  Red: %d  •  %.1fs" % [team_a_alive, team_b_alive, battle_time]
    else:
        status_label.text = "BLUE: %d / %d     RED: %d / %d\nLeft joystick: move • Right swipe: look" % [team_a_alive, team_a_count, team_b_alive, team_b_count]

func _update_flight_camera(delta: float) -> void:
    if battle_camera == null:
        return
    var move := Vector3.ZERO
    if touch_joy_vector.length() > 0.08:
        move -= battle_camera.global_basis.z * touch_joy_vector.y
        move += battle_camera.global_basis.x * touch_joy_vector.x
    if Input.is_key_pressed(KEY_W):
        move -= battle_camera.global_basis.z
    if Input.is_key_pressed(KEY_S):
        move += battle_camera.global_basis.z
    if Input.is_key_pressed(KEY_D):
        move += battle_camera.global_basis.x
    if Input.is_key_pressed(KEY_A):
        move -= battle_camera.global_basis.x
    if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
        move += Vector3.UP
    if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
        move -= Vector3.UP
    if move.length_squared() > 0.0:
        battle_camera.global_position += move.normalized() * camera_flight_speed * delta
    var pos := battle_camera.global_position
    var radius := Vector2(pos.x, pos.z).length()
    if radius > MAP_RADIUS - 3.0:
        var factor := (MAP_RADIUS - 3.0) / radius
        pos.x *= factor
        pos.z *= factor
    pos.y = clampf(pos.y, _height_approx(pos.x, pos.z) + 1.8, 250.0)
    battle_camera.global_position = pos

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            camera_drag_active = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            battle_camera.fov = maxf(28.0, battle_camera.fov - 3.0)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            battle_camera.fov = minf(82.0, battle_camera.fov + 3.0)
    elif event is InputEventMouseMotion and camera_drag_active:
        _rotate_flight_camera(event.relative)
    elif event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < get_viewport().get_visible_rect().size.x * 0.45:
                touch_joy_id = event.index
                touch_joy_origin = event.position
                touch_joy_vector = Vector2.ZERO
            else:
                touch_look_id = event.index
        else:
            if event.index == touch_joy_id:
                touch_joy_id = -1
                touch_joy_vector = Vector2.ZERO
            if event.index == touch_look_id:
                touch_look_id = -1
    elif event is InputEventScreenDrag:
        if event.index == touch_joy_id:
            touch_joy_vector = ((event.position - touch_joy_origin) / 92.0).limit_length(1.0)
        elif event.index == touch_look_id:
            _rotate_flight_camera(event.relative)

func _rotate_flight_camera(relative: Vector2) -> void:
    if battle_camera == null:
        return
    battle_camera.rotation.y -= relative.x * camera_look_sensitivity
    battle_camera.rotation.x = clampf(battle_camera.rotation.x - relative.y * camera_look_sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))
