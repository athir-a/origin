extends Node2D
## A character or animal in the village. Origin is the feet-centre so y-sorting just works.

var vid := ""
var display_name := ""
var tex_front: Texture2D
var tex_back: Texture2D
var tex_side: Texture2D
var sprite: Sprite2D
var facing := "front"
var flip := false
var moving := false
var bob_t := 0.0
var speed := 18.0
var home := Vector2.ZERO
var wander_radius := 0.0
var target := Vector2.ZERO
var wait := 0.0
var has_target := false
var has_news := false
var is_animal := false
var shadow_w := 9.0
var talk_pause := 0.0
var look_at_player := false
var static_pose := false
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func setup(id: String, nm: String, front: Texture2D, back: Texture2D, side: Texture2D) -> void:
	vid = id
	display_name = nm
	tex_front = front
	tex_back = back if back else front
	tex_side = side if side else front
	_rng.randomize()
	sprite = Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	_apply_pose("front")
	_t = _rng.randf() * 10.0


func _apply_pose(pose: String) -> void:
	var tx: Texture2D = tex_front
	match pose:
		"back": tx = tex_back
		"side": tx = tex_side
	sprite.texture = tx
	var s := tx.get_size()
	sprite.position = Vector2(-s.x * 0.5, -s.y)
	facing = pose
	sprite.flip_h = flip if pose == "side" else false


func face_dir(dir: Vector2) -> void:
	if dir.length() < 0.01:
		return
	if absf(dir.x) > absf(dir.y) * 0.9:
		flip = dir.x < 0.0
		_apply_pose("side")
	elif dir.y < 0.0:
		_apply_pose("back")
	else:
		_apply_pose("front")


func set_textures(front: Texture2D, back: Texture2D, side: Texture2D) -> void:
	tex_front = front
	tex_back = back
	tex_side = side
	_apply_pose(facing)


func _process(delta: float) -> void:
	_t += delta
	var ts := sprite.texture.get_size() if sprite and sprite.texture else Vector2(16, 32)
	if moving:
		bob_t += delta * (11.0 if not is_animal else 16.0)
		var b := absf(sin(bob_t))
		sprite.position.y = -ts.y - b * (1.6 if not is_animal else 1.4)
		sprite.scale = Vector2(1.0 + 0.03 * sin(bob_t * 2.0), 1.0 - 0.03 * sin(bob_t * 2.0))
		sprite.offset = Vector2.ZERO
	else:
		bob_t = 0.0
		var breathe := sin(_t * 2.0) * 0.5
		sprite.position.y = -ts.y + (0.0 if breathe < 0.0 else -0.7)
		sprite.scale = Vector2.ONE
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, shadow_w, Color(0, 0, 0, 0.26))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if has_news:
		var ts := sprite.texture.get_size()
		var y := -ts.y - 9.0 + sin(_t * 4.0) * 1.5
		draw_rect(Rect2(-3, y - 1, 6, 9), Color("3b2a1a"))
		draw_rect(Rect2(-2, y, 4, 5), Color("ffd35a"))
		draw_rect(Rect2(-2, y + 6, 4, 2), Color("ffd35a"))


## Simple wander AI. world.try_move(actor, delta_vec) returns true if movement succeeded.
func think(delta: float, world: Node, player_pos: Vector2) -> void:
	if static_pose:
		moving = false
		return
	if talk_pause > 0.0:
		talk_pause -= delta
		moving = false
		return
	if look_at_player and player_pos.distance_to(position) < 70.0:
		moving = false
		face_dir(player_pos - position)
		if wander_radius <= 0.0:
			return
	if wander_radius <= 0.0:
		moving = false
		return
	if has_target:
		var to := target - position
		if to.length() < 1.5:
			has_target = false
			moving = false
			wait = _rng.randf_range(1.5, 5.0)
		else:
			var step := to.normalized() * speed * delta
			if step.length() > to.length():
				step = to
			if world.try_move(self, step):
				moving = true
				face_dir(step)
			else:
				has_target = false
				moving = false
				wait = _rng.randf_range(0.4, 1.4)
	else:
		moving = false
		wait -= delta
		if wait <= 0.0:
			var ang := _rng.randf() * TAU
			var r := _rng.randf_range(wander_radius * 0.3, wander_radius)
			target = home + Vector2(cos(ang), sin(ang) * 0.6) * r
			has_target = true
