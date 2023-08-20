extends CharacterBody3D

@onready var camera = $Head/Camera3D
@onready var chest_ray = $WallCheckChest
@onready var head_rays = $HeadRays
@onready var ground_check = $GroundCheck
@onready var jump_cayote_timer = $JumpCayoteTimer
@onready var head_bumper_cast = $HeadBumperCast
@onready var jump_buffer_timer = $JumpBufferTimer
@onready var sprint_timer = $SprintTimer
@onready var wall_run_timer = $WallRunTimer
@onready var head = $Head
@onready var grapple_cast = $Head/Camera3D/GrappleCast

var full_contact = false
var sprinting = false
var w_runnable = false
var called_climb = false
var can_climb = false
var can_jump = false
var grappling = false
var hookpoint_get = false
var falling_height = -25
var reset_location = Vector3(-3.039, 2.373, 6.589)

@export var gravity = 20
@export var jump_speed = 10
@export var wall_friction = 10
@export var default_speed = 7
@export var sprint_speed = 14
@export var air_accel = 2
@export var normal_accel = 8

@export var mouse_sens = .08


var speed
var h_accel = 0
var v_vel = 0
var cur_weapon = 1

var hook_point = Vector3()
var wall_normal = Vector3()
var gravity_direction = Vector3()
var h_vel = Vector3()
var movement = Vector3()
var dir = Vector3()

enum{
	IDLE,
	MOVING,
	CLIMBING
}
var cur_state = IDLE

func _input(event):
	
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if cur_weapon < 3:
					cur_weapon += 1
				else:
					cur_weapon = 1
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if cur_weapon > 1:
					cur_weapon -= 1
				else:
					cur_weapon = 3
	# CAPTURE MOUSE SYSTEM
	if event is InputEventMouseMotion and cur_state != CLIMBING:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	if Input.is_mouse_button_pressed(1):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if Input.is_action_just_pressed("respawn"):
		get_tree().reload_current_scene()


func _physics_process(delta):
	
	
	if transform.origin.y < falling_height:
		transform.origin = reset_location
	

	# SET DEFAULT VARS
	speed = default_speed
	dir = Vector3()
	
	# GET INPUT
	dir = get_input_dir()
	
	
	
	# FIRE GUN
#	fire_gun()
	
	match cur_state:
		IDLE:
			if dir.length() != 0 and gravity_direction.y != 0:
				cur_state = MOVING
			# APPLY GRAVITY
			apply_gravity(delta)
			# JUMP
			jump()
			# CLIMB
			
				
			grapple()
			
			pass
		MOVING:
			if dir.length() == 0:
				cur_state = IDLE
			# SRPINT
			sprint()
			# APPLY GRAVITY
			apply_gravity(delta)
			# WALL RUN
			wall_run()
			# JUMP
			jump()
			# CLIMB
			
			grapple()
			pass
		

			# Climb
			
	# APPLY VELOCITY
	h_vel = h_vel.lerp(dir * speed, h_accel * delta)
	movement.z = h_vel.z + gravity_direction.z
	movement.x = h_vel.x + gravity_direction.x
	movement.y = gravity_direction.y
	
	set_velocity(movement)
	set_up_direction(Vector3.UP)
	move_and_slide()


	
	
		

#func fire_gun():
#	if Input.is_action_pressed("shoot"):
#		if not animation_player.is_playing():
#			gun_fire_sfx.pitch_scale = rand_range(1,.8)
#			gun_fire_sfx.play()
#			camera.translation = lerp(camera.translation, Vector3(rand_range(MAX_CAM_SHAKE, -MAX_CAM_SHAKE),rand_range(MAX_CAM_SHAKE, -MAX_CAM_SHAKE),0), .5)
#			if gun_cast.is_colliding():
#				var target = gun_cast.get_collider()
#				if target.is_in_group('Enemy'):
#					target.health -= damage
#		animation_player.play("fire")
#	else:
#		camera.translation = Vector3()
#		animation_player.stop()
func apply_gravity(delta):
	if ground_check.is_colliding():
		full_contact = true
	else: 
		full_contact = false
		
	if not is_on_floor():
		gravity_direction += gravity * Vector3.DOWN * delta
		h_accel = air_accel
		jump_cayote()
	elif is_on_floor() and full_contact:
		can_jump = true
		gravity_direction = -get_floor_normal() * gravity
		h_accel = normal_accel
		w_runnable = false
	else:
		can_jump = true
		gravity_direction = -get_floor_normal()
		h_accel = normal_accel


func get_input_dir():
	if Input.is_action_pressed("move_up"):
		dir -= transform.basis.z
	if Input.is_action_pressed("move_down"):
		dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		dir += transform.basis.x
	dir = dir.normalized()
	return dir

func sprint():
	if Input.is_action_just_pressed("ability") and not sprinting:
		sprinting = true
#		sprint_timer.start()
	elif Input.is_action_just_pressed("ability") and sprinting:
		sprinting = false
		
	if sprinting:
		speed = sprint_speed

func wall_run():
	if w_runnable:
		if Input.is_action_pressed("move_up"):
			if is_on_wall():
				wall_normal = get_slide_collision(0)
				await get_tree().create_timer(.15).timeout
				gravity_direction.y = gravity_direction.y/2
				dir = -wall_normal.get_normal()
				await get_tree().create_timer(.15).timeout
				gravity_direction.y = gravity_direction.y
				


func jump():
	# JUMP BUFFER (IF YOU PRESS JUMP .2 SECONDS BEFORE LANDING IT WILL APPLY YOUR INPUT)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer.start()
	if !jump_buffer_timer.is_stopped() and is_on_floor():
		gravity_direction = jump_speed * Vector3.UP
		w_runnable = true
		wall_run_timer.start()
	# MAIN JUMP CODE
	if Input.is_action_just_pressed("jump") and can_jump:
		gravity_direction = jump_speed * Vector3.UP
		w_runnable = true
		wall_run_timer.start()
	# WALL JUMP
	if Input.is_action_just_pressed("jump") and is_on_wall() and w_runnable :
		wall_run_timer.stop()
		wall_run_timer.start()
		wall_normal = get_slide_collision(0)
		
#		gravity_vec.y = jump_speed/2

func jump_cayote():
	await get_tree().create_timer(.1).timeout
	can_jump = false


 




func grapple():
	if Input.is_action_just_pressed("grapple"):
		if grapple_cast.is_colliding():
			if not grappling:
				grappling = true
	if grappling:
		gravity_direction.y = 0
		if not hookpoint_get:
			hook_point = grapple_cast.get_collision_point() + Vector3(0,1.5,0)
			hookpoint_get = true
		if hook_point.distance_to(transform.origin) > 1:
			if hookpoint_get:
				transform.origin = lerp(transform.origin, hook_point, .2)
		else:
			grappling = false
			hookpoint_get = false
	if head_bumper_cast.is_colliding():
		grappling = false
		hook_point = null
		hookpoint_get = false
		global_translate(Vector3(0,-1,0))
	pass


func _on_SprintTimer_timeout():
	sprinting = false


func _on_WallRunTimer_timeout():
	w_runnable = false

