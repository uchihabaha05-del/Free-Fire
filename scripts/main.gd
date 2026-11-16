extends Node3D

# MASS BATTLE: lightweight crowd-rendering and group-combat prototype.
# Visual soldiers are GPU-instanced; combat is currently simulated in groups.

const MAX_UNITS := 10000
const FIELD_WIDTH := 90.0
const FIELD_DEPTH := 54.0

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
var reset_button: Button

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
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.62, 0.68, 0.78)
    environment.ambient_light_energy = 0.8
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.4
    add_child(sun)

    var ground := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(FIELD_WIDTH, FIELD_DEPTH)
    ground.mesh = plane
    var ground_mat := StandardMaterial3D.new()
    ground_mat.albedo_color = Color(0.16, 0.19, 0.22)
    ground_mat.roughness = 1.0
    ground.material_override = ground_mat
    ground.position.y = -0.15
    add_child(ground)

    _add_box(Vector3(0.12, 0.03, FIELD_DEPTH), Vector3(0, 0.01, 0), Color(0.9, 0.9, 0.9, 0.45))
    _add_box(Vector3(FIELD_WIDTH, 0.2, 0.25), Vector3(0, 0.0, -FIELD_DEPTH / 2), Color(0.35, 0.38, 0.42))
    _add_box(Vector3(FIELD_WIDTH, 0.2, 0.25), Vector3(0, 0.0, FIELD_DEPTH / 2), Color(0.35, 0.38, 0.42))

    var camera := Camera3D.new()
    camera.position = Vector3(0, 62, 67)
    camera.rotation_degrees = Vector3(-43, 0, 0)
    camera.current = true
    camera.fov = 48
    add_child(camera)

func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    node.material_override = mat
    node.position = pos
    add_child(node)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var panel := PanelContainer.new()
    panel.position = Vector2(18, 18)
    panel.custom_minimum_size = Vector2(310, 0)
    layer.add_child(panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    panel.add_child(column)

    var title := Label.new()
    title.text = "MASS BATTLE"
    title.add_theme_font_size_override("font_size", 26)
    column.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "BUILD TWO ARMIES • WATCH THE BATTLE"
    subtitle.add_theme_font_size_override("font_size", 10)
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
    speed_slider.value_changed.connect(func(value: float) -> void:
        battle_speed = value
    )
    speed_row.add_child(speed_slider)
    column.add_child(speed_row)

    status_label = Label.new()
    status_label.text = "Ready"
    status_label.add_theme_font_size_override("font_size", 14)
    column.add_child(status_label)

    start_button = Button.new()
    start_button.text = "START BATTLE"
    start_button.custom_minimum_size.y = 42
    start_button.pressed.connect(_start_battle)
    column.add_child(start_button)

    reset_button = Button.new()
    reset_button.text = "RESET ARMIES"
    reset_button.pressed.connect(_reset_battle)
    column.add_child(reset_button)

    var note := Label.new()
    note.text = "Prototype: group-based combat simulation\nVisual crowd uses MultiMesh instancing."
    note.add_theme_font_size_override("font_size", 10)
    column.add_child(note)

func _make_label(value: String) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", 11)
    return label

func _make_spin(initial: int) -> SpinBox:
    var spin := SpinBox.new()
    spin.min_value = 1
    spin.max_value = MAX_UNITS
    spin.step = 50
    spin.value = initial
    spin.custom_minimum_size.x = 260
    return spin

func _setup_armies() -> void:
    team_a_mesh = _create_army(Color(0.12, 0.48, 1.0), -1)
    team_b_mesh = _create_army(Color(1.0, 0.19, 0.16), 1)
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
        var columns: int = 100
        var row: int = int(i / columns)
        var col: int = i % columns
        var x := (float(col) / float(columns - 1) - 0.5) * (FIELD_WIDTH - 8.0)
        var z := side * (5.0 + float(row) * 0.38)
        multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(x, 0.0, z)))
        multimesh.set_instance_color(i, color.lightened(rng.randf_range(-0.08, 0.12)))

    instance.multimesh = multimesh
    return instance

func _make_soldier_mesh() -> Mesh:
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.16
    capsule.height = 0.72
    capsule.radial_segments = 5
    capsule.rings = 2
    return capsule

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
        status_label.text = "BLUE: %d / %d     RED: %d / %d\nTime: %.1fs" % [
            team_a_alive, team_a_count, team_b_alive, team_b_count, battle_time
        ]
