extends SceneTree
## 360 degree stereo test clip of the story world (the user, 2026-11-17: the story as a pre-rendered panorama video;
## test clip first). Renders a cube of 6 cameras per eye and folds them into one equirect frame: left eye on top,
## right eye below. Run through Godot's movie maker writing PNG frames (its own .ogv writer cannot handle 4096x4096), then encode with ffmpeg:
##   godot --xr-mode off --path godot --resolution 4096x4096 --fixed-fps 72 --write-movie <abs>/_work/pano/f.png \
##         -s res://tools/pano_clip.gd -- <seconds> <width>
## The clip is for the Quest decode test: real story content, slowly turning so the encoder sees motion.

const IPD := 0.064
const STAND := Vector3(0, 1.6, 0)

var _rigs: Array = []  # per eye: Array of [SubViewport, Camera3D]
var _secs := 6.0
var _t := 0.0
var _world: StoryWorld


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_secs = float(a[0])
	var w := int(a[1]) if a.size() > 1 else 4096
	_world = StoryWorld.new()
	root.add_child(_world)
	var face := int(w / 4)
	var faces := [  # forward, up (camera looks along forward)
		[Vector3.FORWARD, Vector3.UP], [Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.UP],
		[Vector3.RIGHT, Vector3.UP], [Vector3.UP, Vector3.BACK], [Vector3.DOWN, Vector3.FORWARD]]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://tools/pano_fold.gdshader")
	for eye in 2:
		var rig := []
		for i in 6:
			var vp := SubViewport.new()
			vp.size = Vector2i(face, face)
			vp.world_3d = root.world_3d
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			vp.msaa_3d = Viewport.MSAA_4X
			root.add_child(vp)
			var cam := Camera3D.new()
			cam.fov = 90.0
			cam.near = 0.05
			cam.far = 600.0
			vp.add_child(cam)
			cam.current = true
			rig.append([vp, cam, faces[i]])
			mat.set_shader_parameter("face_%d_%d" % [eye, i], vp.get_texture())
		_rigs.append(rig)
	for i in 6:
		var f: Vector3 = faces[i][0]
		var u: Vector3 = faces[i][1]
		mat.set_shader_parameter("fwd_%d" % i, f)
		mat.set_shader_parameter("up_%d" % i, u)
		mat.set_shader_parameter("right_%d" % i, f.cross(u))
	var rect := ColorRect.new()
	rect.material = mat
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(rect)


func _process(delta: float) -> bool:
	if _t == 0.0:
		_world.set_mood("morning", 0.0)  # after StoryWorld._ready, which runs once the tree is live
	_t += delta
	var yaw := _t * 0.25  # slow turn: real motion for the encoder
	var b := Basis(Vector3.UP, yaw)
	for eye in 2:
		var off := b * Vector3((-0.5 if eye == 0 else 0.5) * IPD, 0, 0)
		for r in _rigs[eye]:
			var cam: Camera3D = r[1]
			var f: Vector3 = b * (r[2][0] as Vector3)
			var u: Vector3 = b * (r[2][1] as Vector3)
			cam.global_transform = Transform3D(Basis.looking_at(f, u), STAND + off)
	return _t >= _secs
