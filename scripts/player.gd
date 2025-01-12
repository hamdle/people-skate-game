extends CharacterBody2D

@export var speed = 300
@export var gravity = 30
@export var jump_force = 300

func _physics_process(delta: float) -> void:
	if !is_on_floor():
		velocity.y += gravity
		if velocity.y > 1000:
			velocity.y = 1000
	
	if Input.is_action_just_pressed("jump"): # && is_on_floor():
		velocity.y = -jump_force
	
	# if first pressed return -1, second 1, none or both 0
	var h_dir = Input.get_axis('move_left', 'move_right')
	velocity.x = speed * h_dir
	
	move_and_slide()
	
	print(velocity)
