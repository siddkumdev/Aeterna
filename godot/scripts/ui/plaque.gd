class_name Plaque
extends Node3D
## A carved wooden plaque you pinch, poke or click: "Wake", "The Tale", "Hands / Controllers". Wood and gold like the
## cards. Hit tests are plain geometry (a ray against its box, or a fingertip inside it), so it works with hands,
## controllers and the mouse. Joins the group 'ew_pokable' (the poke signal in GameHand).

signal pressed

const SIZE := Vector3(0.15, 0.052, 0.012)
const WOOD := Color("9A6538")  # wood_mid
const WOOD_HOT := Color("C6924C")  # wood_light
const EDGE := Color("5B2920")  # wood_dark
const GOLD := Color("E8B83A")  # shell_gold
const INK := Color("F4E4B8")  # wall_cream text on the dark wood

var text := ""
var _mat: StandardMaterial3D
var _label: Label3D
var hot := false:
	set(v):
		hot = v
		if _mat:
			_mat.albedo_color = WOOD_HOT if v else WOOD


static func make(label: String) -> Plaque:
	var p := Plaque.new()
	p.text = label
	p._build()
	return p


func _build() -> void:
	add_to_group("ew_pokable")
	set_meta("poke_radius", 0.03)
	var edge := MeshInstance3D.new()
	var eb := BoxMesh.new()
	eb.size = SIZE + Vector3(0.008, 0.008, -0.002)
	edge.mesh = eb
	edge.material_override = ModelUtil.flat_material(EDGE)
	add_child(edge)
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = SIZE
	body.mesh = bb
	_mat = ModelUtil.flat_material(WOOD)
	body.material_override = _mat
	body.position.z = 0.001
	add_child(body)
	for sx in [-1, 1]:  # little gold studs at the ends
		var stud := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.0034
		sm.height = 0.0068
		stud.mesh = sm
		stud.material_override = ModelUtil.flat_material(GOLD)
		stud.position = Vector3(sx * (SIZE.x / 2.0 - 0.009), 0, SIZE.z / 2.0 + 0.001)
		add_child(stud)
	_label = Label3D.new()
	_label.text = text
	_label.font_size = 56
	_label.pixel_size = 0.00042
	_label.modulate = INK
	_label.outline_size = 6
	_label.outline_modulate = EDGE
	_label.position = Vector3(0, 0, SIZE.z / 2.0 + 0.0015)
	add_child(_label)


func hit_ray(origin: Vector3, dir: Vector3) -> bool:
	var inv := global_transform.affine_inverse()
	return AABB(-SIZE / 2.0, SIZE).intersects_ray(inv * origin, inv.basis * dir) != null


func hit_point(world: Vector3, pad := 0.02) -> bool:
	var local := global_transform.affine_inverse() * world
	return AABB(-SIZE / 2.0 - Vector3.ONE * pad, SIZE + Vector3.ONE * pad * 2.0).has_point(local)
