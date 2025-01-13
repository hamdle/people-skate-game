extends CharacterBody2D

const JUMP_VELOCITY = -300.0
const SPEED = 270.0

const PUSH_FORCE := 80.0
const MIN_PUSH_FORCE := 30.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var ap = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var cshape = $CollisionShape2D
@onready var crouch_raycast_1 = $CrouchRayCast2D_1
@onready var crouch_raycast_2 = $CrouchRayCast2D_2
@onready var rotation_raycast = $RotationRayCast2D
@onready var coyote_timer = $CoyoteTimer
@onready var jump_buffer_timer = $JumpBufferTimer
@onready var jump_height_timer = $JumpHeightTimer

var is_crouch = false
var is_crouch_stuck = false
var is_coyote_jump = false
var is_jump_buffered = false
var is_carry = false

var stand_cshape = preload("res://resources/player_stand_col.tres")
var crouch_cshape = preload("res://resources/player_crouch_col.tres")

var xform: Transform2D

var carry_obj = null
var carry_name

func _process(delta: float) -> void:
	pass
	
func _physics_process(delta: float) -> void:
	if !is_on_floor(): # && is_coyote_jump == false:
		velocity.y += gravity * delta
		if velocity.y > 1000:
			velocity.y = 1000
	
	if Input.is_action_just_pressed("jump"):
		jump_height_timer.start()
		jump()
	
	# if first pressed return -1, second 1, none or both 0
	var h_dir = Input.get_axis('move_left', 'move_right')
	if h_dir:
		velocity.x = h_dir * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	if h_dir != 0:
		switch_direction(h_dir)
		
	if Input.is_action_just_pressed("crouch"):
		crouch()
	elif Input.is_action_just_released("crouch"):
		if clear_to_stand():
			stand()
		else:
			if is_crouch_stuck != true:
				is_crouch_stuck = true
				
	if is_crouch_stuck && clear_to_stand() && !Input.is_action_pressed("crouch"):
		stand()
		is_crouch_stuck = false
		
	if rotation_raycast.is_colliding():
		var collider = rotation_raycast.get_collider()
		if collider is RigidBody2D:
			if Input.is_action_pressed("crouch"):
				collider.apply_central_impulse(Vector2(150,0))
			if Input.is_action_pressed("pick_up") && !is_carry:
				carry_obj = collider
				carry_name = carry_obj.name
				PhysicsServer2D.body_set_state(
					carry_obj.get_rid(),
					PhysicsServer2D.BODY_STATE_TRANSFORM,
					Transform2D.IDENTITY.translated(Vector2(0, 0))
				)
				collider.freeze = true
				is_carry = true
	
	if is_carry:
		carry_obj.position.x = position.x
		carry_obj.position.y = position.y - 48
		
	if Input.is_action_just_pressed("pick_up") && carry_obj != null:
		if  rotation_raycast.is_colliding():
			var col = rotation_raycast.get_collider()
			if col.name != carry_name:
				carry_obj.freeze = false
				is_carry = false
				PhysicsServer2D.body_set_state(
					carry_obj.get_rid(),
					PhysicsServer2D.BODY_STATE_TRANSFORM,
					Transform2D.IDENTITY.translated(Vector2(global_position.x+30, global_position.y-30))
				)
				carry_obj.apply_central_impulse(Vector2(150,0))
				carry_obj = null
		else:
			carry_obj.freeze = false
			is_carry = false
			PhysicsServer2D.body_set_state(
				carry_obj.get_rid(),
				PhysicsServer2D.BODY_STATE_TRANSFORM,
				Transform2D.IDENTITY.translated(Vector2(global_position.x+30, global_position.y-30))
			)
			carry_obj.apply_central_impulse(Vector2(150,0))
			carry_obj = null
		
	
	var last_is_on_floor = is_on_floor()
	
	move_and_slide()
	
	# Character rotation
	if rotation_raycast.is_colliding():
		var normal = rotation_raycast.get_collision_normal()
		var degree = rad_to_deg(normal.angle()) + 90
		if abs(degree) < 50:
			rotation_degrees = degree
		else:
			print(degree)
	else:
		rotation = 0
	
	# Object collision
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody2D:
			var push_force = (PUSH_FORCE * velocity.length() / SPEED) + MIN_PUSH_FORCE
			c.get_collider().apply_central_impulse(-c.get_normal() * push_force)
	
	# Started to fall
	if last_is_on_floor && !is_on_floor() && velocity.y >= 0:
		is_coyote_jump = true
		coyote_timer.start()
	
	# Touched ground
	if !last_is_on_floor && is_on_floor():
		if is_jump_buffered:
			is_jump_buffered = false
			print('buffered jump')
			jump()
	
	update_animations(h_dir)
	
func clear_to_stand() -> bool:
	return !crouch_raycast_1.is_colliding() && !crouch_raycast_2.is_colliding()
	
func update_animations(h_dir) -> void:
	if is_on_floor():
		if h_dir == 0:
			if is_crouch:
				ap.play("crouch")
			else:
				ap.play("idle")
		else:
			if is_crouch:
				ap.play("crouch")
			else:
				ap.play("run")
	else:
		if velocity.y < 0:
			ap.play("jump")
		elif velocity.y > 0:
			ap.play("fall")
			
func switch_direction(h_dir) -> void:
	sprite.flip_h = (h_dir < 0.0)
	# adjust sprite position based on flip direction
	if sprite.flip_h:
		sprite.position.x = h_dir * -1
	else:
		sprite.position.x = h_dir * -2
	
func crouch() -> void:
	if is_crouch:
		return
	is_crouch = true
	cshape.shape = crouch_cshape
	cshape.position.y = -13
	
func stand() -> void:
	if is_crouch == false:
		return
	is_crouch = false
	cshape.shape = stand_cshape
	cshape.position.y = -16
	
func jump() -> void:
	if is_on_floor() || is_coyote_jump:
		velocity.y = JUMP_VELOCITY
		if is_coyote_jump:
			is_coyote_jump = false
			print('coyote')
	else:
		if !is_jump_buffered:
			is_jump_buffered = true
			jump_buffer_timer.start()
		
func _on_coyote_timer_timeout() -> void:
	is_coyote_jump = false
	
func _on_jump_buffer_timer_timeout() -> void:
	is_jump_buffered = false
	
func _on_jump_height_timer_timeout() -> void:
	if !Input.is_action_pressed("jump"):
		if velocity.y < -100: # going up
			velocity.y = -100
			
