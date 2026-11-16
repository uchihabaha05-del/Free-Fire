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

func _ready() -> void:
    rng.randomize()
    _build_world()
    _build_ui()
    _setup_armies()
    _apply_visible_counts()
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
    environment.ambient_light_energy = 0.72
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.0
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.65, 0.68, 0.65)
    environment.fog_density = 0.0022
    environment.fog_sky_affect = 0.5
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_energy = 1.35
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
    material.roughness = 1.0
    material.uv1_scale = Vector3(18.0, 18.0, 1.0)
    terrain.material_override = material
    terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(terrain)

func _terrain_vertex(surface: SurfaceTool, point: Vector3, uv: Vector2, noise: FastNoiseLite) -> void:
    var patch := noise.get_noise_2d(point.x * 0.055 + 170.0, point.z * 0.055 - 90.0)
    var moisture := noise.get_noise_2d(point.x * 0.025 - 300.0, point.z * 0.025 + 200.0)
    var dirt := Color(0.39, 0.32, 0.23)
    var dry_grass := Color(0.34, 0.39, 0.22)
    var dusty := Color(0.56, 0.51, 0.39)
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
    battle_camera.position = Vector3(0, 29, 88)
    battle_camera.rotation_degrees = Vector3(-17, 0, 0)
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

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "GameUI"
    add_child(layer)

    var panel := PanelContainer.new()
    panel.position = Vector2(14, 14)
    panel.custom_minimum_size = Vector2(270, 0)
    layer.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 5)
    panel.add_child(column)

    var title := Label.new()
    title.text = "MASS BATTLE"
    title.add_theme_font_size_override("font_size", 23)
    column.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "WASTELAND • REAL-TIME BATTLE"
    subtitle.add_theme_font_size_override("font_size", 9)
    column.add_child(subtitle)
    column.add_child(HSeparator.new())

    column.add_child(_make_label("BLUE ARMY — SOLDIERS"))
    a_spin = _make_spin(500)
    column.add_child(a_spin)
    column.add_child(_make_label("RED ARMY — SOLDIERS"))
    b_spin = _make_spin(500)
    column.add_child(b_spin)

    var speed_row := HBoxContainer.new()
    var speed_text := Label.new()
    speed_text.text = "Battle speed"
    speed_row.add_child(speed_text)
    speed_slider = HSlider.new()
    speed_slider.min_value = 0.25
    speed_slider.max_value = 4.0
    speed_slider.step = 0.25
    speed_slider.value = 1.0
    speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    speed_slider.value_changed.connect(func(value: float) -> void: battle_speed = value)
    speed_row.add_child(speed_slider)
    column.add_child(speed_row)

    status_label = Label.new()
    status_label.text = "Ready"
    status_label.add_theme_font_size_override("font_size", 12)
    column.add_child(status_label)

    start_button = Button.new()
    start_button.text = "START BATTLE"
    start_button.custom_minimum_size.y = 38
    start_button.pressed.connect(_start_battle)
    column.add_child(start_button)
    var reset_button := Button.new()
    reset_button.text = "RESET ARMIES"
    reset_button.pressed.connect(_reset_battle)
    column.add_child(reset_button)

    var camera_title := _make_label("FREE-FLIGHT CAMERA")
    camera_title.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
    column.add_child(camera_title)
    var camera_help := Label.new()
    camera_help.text = "Swipe to look • WASD / buttons to fly\nQ/E or DOWN/UP for altitude"
    camera_help.add_theme_font_size_override("font_size", 9)
    column.add_child(camera_help)
    _build_flight_controls(layer)

func _build_flight_controls(layer: CanvasLayer) -> void:
    var panel := PanelContainer.new()
    panel.name = "FlightControls"
    panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    panel.offset_left = -214
    panel.offset_top = -150
    panel.offset_right = -10
    panel.offset_bottom = -10
    layer.add_child(panel)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 3)
    panel.add_child(stack)

    var forward_row := HBoxContainer.new()
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    forward_row.add_child(spacer)
    forward_row.add_child(_make_flight_button("▲", "forward"))
    forward_row.add_child(_make_flight_button("UP", "up"))
    stack.add_child(forward_row)
    var middle_row := HBoxContainer.new()
    middle_row.add_child(_make_flight_button("◀", "left"))
    middle_row.add_child(_make_flight_button("▼", "back"))
    middle_row.add_child(_make_flight_button("▶", "right"))
    middle_row.add_child(_make_flight_button("DOWN", "down"))
    stack.add_child(middle_row)

func _make_flight_button(caption: String, action: String) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(43, 43)
    button.button_down.connect(func() -> void: camera_move[action] = true)
    button.button_up.connect(func() -> void: camera_move[action] = false)
    return button

func _make_label(value: String) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", 10)
    return label

func _make_spin(initial: int) -> SpinBox:
    var spin := SpinBox.new()
    spin.min_value = 1
    spin.max_value = MAX_UNITS
    spin.step = 50
    spin.value = initial
    spin.custom_minimum_size.x = 220
    return spin

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
    material.roughness = 0.88
    instance.material_override = material
    return instance

func _make_soldier_mesh() -> Mesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var torso := CapsuleMesh.new()
    torso.radius = 0.22
    torso.height = 0.92
    torso.radial_segments = 8
    torso.rings = 4
    _append_part(surface, torso, Vector3(0, 1.05, 0), Vector3(0.88, 1.0, 0.58), Vector3.ZERO)
    var head := SphereMesh.new()
    head.radius = 0.17
    head.height = 0.34
    _append_part(surface, head, Vector3(0, 1.72, 0.015), Vector3.ONE, Vector3.ZERO)
    var helmet := SphereMesh.new()
    helmet.radius = 0.19
    helmet.height = 0.19
    _append_part(surface, helmet, Vector3(0, 1.84, 0.015), Vector3(1.0, 0.58, 1.0), Vector3.ZERO)
    var backpack := BoxMesh.new()
    backpack.size = Vector3(0.28, 0.40, 0.18)
    _append_part(surface, backpack, Vector3(0, 1.10, -0.22), Vector3.ONE, Vector3.ZERO)
    var limb := CapsuleMesh.new()
    limb.radius = 0.075
    limb.height = 0.62
    limb.radial_segments = 6
    _append_part(surface, limb, Vector3(-0.25, 1.10, 0.0), Vector3.ONE, Vector3(0, 0, -0.22))
    _append_part(surface, limb, Vector3(0.25, 1.10, 0.0), Vector3.ONE, Vector3(0, 0, 0.22))
    _append_part(surface, limb, Vector3(-0.12, 0.38, 0.0), Vector3(0.92, 1.1, 0.92), Vector3(0, 0, -0.08))
    _append_part(surface, limb, Vector3(0.12, 0.38, 0.0), Vector3(0.92, 1.1, 0.92), Vector3(0, 0, 0.08))
    var rifle := BoxMesh.new()
    rifle.size = Vector3(0.09, 0.10, 0.76)
    _append_part(surface, rifle, Vector3(0.19, 1.22, 0.36), Vector3.ONE, Vector3(-0.12, 0, 0))
    var barrel := CylinderMesh.new()
    barrel.top_radius = 0.025
    barrel.bottom_radius = 0.025
    barrel.height = 0.34
    _append_part(surface, barrel, Vector3(0.19, 1.23, 0.86), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
    surface.generate_normals()
    return surface.commit()

func _append_part(surface: SurfaceTool, mesh: Mesh, position: Vector3, scale: Vector3, rotation: Vector3) -> void:
    var transform := Transform3D(Basis.from_euler(rotation).scaled(scale), position)
    surface.append_from(mesh, 0, transform)

func _start_battle() -> void:
    if battle_running:
        battle_running = false
        start_button.text = "RESUME BATTLE"
        return
    if team_a_alive <= 0 or team_b_alive <= 0:
        _reset_battle()
    else:
        team_a_count = clampi(int(a_spin.value), 1, MAX_UNITS)
        team_b_count = clampi(int(b_spin.value), 1, MAX_UNITS)
        if battle_time == 0.0:
            team_a_alive = team_a_count
            team_b_alive = team_b_count
            _apply_visible_counts()
    battle_running = true
    start_button.text = "PAUSE BATTLE"
    _refresh_ui()

func _reset_battle() -> void:
    battle_running = false
    battle_time = 0.0
    team_a_count = clampi(int(a_spin.value), 1, MAX_UNITS)
    team_b_count = clampi(int(b_spin.value), 1, MAX_UNITS)
    team_a_alive = team_a_count
    team_b_alive = team_b_count
    start_button.text = "START BATTLE"
    _apply_visible_counts()
    _refresh_ui()

func _apply_visible_counts() -> void:
    team_a_mesh.multimesh.visible_instance_count = team_a_alive
    team_b_mesh.multimesh.visible_instance_count = team_b_alive

func _process(delta: float) -> void:
    _update_flight_camera(delta)
    if not battle_running:
        return
    battle_time += delta * battle_speed
    var a_power := sqrt(float(team_a_alive)) * 2.0
    var b_power := sqrt(float(team_b_alive)) * 2.0
    var damage_to_a := maxf(1.0, b_power * delta * battle_speed * 0.8)
    var damage_to_b := maxf(1.0, a_power * delta * battle_speed * 0.8)
    team_a_alive = maxi(0, team_a_alive - int(damage_to_a))
    team_b_alive = maxi(0, team_b_alive - int(damage_to_b))
    _apply_visible_counts()
    ui_refresh_timer += delta
    if ui_refresh_timer >= 0.15:
        ui_refresh_timer = 0.0
        _refresh_ui()
    if team_a_alive == 0 or team_b_alive == 0:
        battle_running = false
        start_button.text = "BATTLE FINISHED — RESET"
        status_label.text = _winner_text()

func _winner_text() -> String:
    if team_a_alive > team_b_alive:
        return "BLUE TEAM WINS!  •  %d survivors" % team_a_alive
    if team_b_alive > team_a_alive:
        return "RED TEAM WINS!  •  %d survivors" % team_b_alive
    return "DRAW — BOTH ARMIES ELIMINATED"

func _refresh_ui() -> void:
    if status_label == null:
        return
    if not battle_running and (team_a_alive == 0 or team_b_alive == 0):
        status_label.text = _winner_text()
    else:
        status_label.text = "BLUE: %d / %d     RED: %d / %d\nTime: %.1fs" % [team_a_alive, team_a_count, team_b_alive, team_b_count, battle_time]

func _update_flight_camera(delta: float) -> void:
    if battle_camera == null:
        return
    var move := Vector3.ZERO
    if camera_move["forward"] or Input.is_key_pressed(KEY_W):
        move -= battle_camera.global_basis.z
    if camera_move["back"] or Input.is_key_pressed(KEY_S):
        move += battle_camera.global_basis.z
    if camera_move["right"] or Input.is_key_pressed(KEY_D):
        move += battle_camera.global_basis.x
    if camera_move["left"] or Input.is_key_pressed(KEY_A):
        move -= battle_camera.global_basis.x
    if camera_move["up"] or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
        move += Vector3.UP
    if camera_move["down"] or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
        move -= Vector3.UP
    if move.length_squared() > 0.0:
        var boost := 2.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0
        battle_camera.global_position += move.normalized() * camera_flight_speed * boost * delta
    var pos := battle_camera.global_position
    var radius := Vector2(pos.x, pos.z).length()
    if radius > MAP_RADIUS - 3.0:
        var scale := (MAP_RADIUS - 3.0) / radius
        pos.x *= scale
        pos.z *= scale
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
            touch_look_id = event.index
        elif event.index == touch_look_id:
            touch_look_id = -1
    elif event is InputEventScreenDrag:
        if touch_look_id == -1 or event.index == touch_look_id:
            _rotate_flight_camera(event.relative)

func _rotate_flight_camera(relative: Vector2) -> void:
    if battle_camera == null:
        return
    battle_camera.rotation.y -= relative.x * camera_look_sensitivity
    battle_camera.rotation.x = clampf(battle_camera.rotation.x - relative.y * camera_look_sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))
