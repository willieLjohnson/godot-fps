extends KinematicBody

var camera_angle = 0
var mouse_sensitivity = 0.3
var camera_change = Vector2()

var velocity = Vector3()
var direction = Vector3()

# Fly variables
const FLY_SPEED = 18
const FLY_ACCEL = 4
var flying = false

# Walk variables
var gravity = -9.8 * 3
const MAX_SPEED = 20
const MAX_RUNNING_SPEED = 30
const ACCEL = 2
const DEACCEL = 6

# Jumping
var jump_height = 15
var in_air = 0
var has_contact = false

# Slope variables
const MAX_SLOPE_ANGLE = 35

# Stair variables
const MAX_STAIR_SLOPE = 20
const STAIR_JUMP_HEIGHT = 6

# Shooting
var shoot_range = 1000
var camera_width_center = 0
var camera_height_center = 0
var shoot_origin = Vector3()
var shoot_normal = Vector3()
var shooting = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	camera_width_center = OS.get_window_size().x / 2
	camera_height_center = OS.get_window_size().y /2

func _physics_process(delta):
	aim()
	if flying:
		fly(delta)
	else:
		walk(delta)
	
	if shooting > 0:
		var space_state = get_world().direct_space_state
		var result = space_state.intersect_ray(shoot_origin, shoot_normal, [self], 1)
		var impulse
		var impact_position
		if result:
			impulse = (result.position - global_transform.origin).normalized()
			impact_position = result.position
			var position = result.position - result.collider.global_transform.origin
			if shooting == 1 and result.collider is RigidBody:
				result.collider.apply_impulse(position, impulse * 10)


	shooting = 0

func _input(event):
	if event is InputEventMouseMotion:
		camera_change = event.relative
	if event is InputEventMouseButton and event.pressed:
		var camera = $Head/Camera
		shoot_origin = camera.project_ray_origin(Vector2(camera_width_center, camera_height_center))
		shoot_normal = camera.project_ray_normal(Vector2(camera_width_center, camera_height_center)) * shoot_range
		if event.button_index == 1:
			shooting = 1
		if event.button_index == 2:
			shooting =2

func walk(delta):
	# Set the direction of the player
	direction = Vector3()

	# Get the rotation of the camera
	var aim = $Head/Camera.get_global_transform().basis
	if Input.is_action_pressed("move_forward"):
		direction -= aim.z
	if Input.is_action_pressed("move_backward"):
		direction += aim.z
	if Input.is_action_pressed("move_left"):
		direction -= aim.x
	if Input.is_action_pressed("move_right"):
		direction += aim.x
	direction.y = 0
	direction = direction.normalized()

	if (is_on_floor()):
		has_contact = true
		var n = $Tail.get_collision_normal()
		var floor_angle = rad2deg(acos(n.dot(Vector3(0, 1, 0))))
		if floor_angle > MAX_SLOPE_ANGLE:
			velocity.y += gravity * delta
	else:
		if !$Tail.is_colliding():
			has_contact = false
		velocity.y += gravity * delta

	if (has_contact and !is_on_floor()):
		move_and_collide(Vector3(0, -1, 0))

	if (direction.length() > 0 and $StairCatcher.is_colliding()):
		var stair_normal = $StairCatcher.get_collision_normal()
		var stair_angle = rad2deg(acos(stair_normal.dot(Vector3(0, 1, 0))))
		if stair_angle< MAX_STAIR_SLOPE:
			velocity.y = STAIR_JUMP_HEIGHT
			has_contact = false

	var temp_velocity = velocity
	temp_velocity.y = 0

	var speed
	if Input.is_action_pressed("move_sprint"):
		speed = MAX_RUNNING_SPEED
	else:
		speed = MAX_SPEED

	# where would the play go at max speed
	var target = direction * speed
	
	var acceleration
	if direction.dot(temp_velocity) > 0:
		acceleration = ACCEL
	else:
		acceleration = DEACCEL

	# Calculate a portion of the distance to go
	temp_velocity = velocity.linear_interpolate(target, acceleration * delta)

	velocity.x = temp_velocity.x
	velocity.z = temp_velocity.z

	if has_contact and Input.is_action_just_pressed("jump"):
		velocity.y = jump_height
		has_contact = false

	# move
	velocity = move_and_slide(velocity, Vector3(0, 1, 0))

	if !has_contact:
		print(in_air)
		in_air += 1

	$StairCatcher.translation.x = direction.x
	$StairCatcher.translation.z = direction.z

func fly(delta):
	# Set the direction of the player
	direction = Vector3()

	# Get the rotation of the camera
	var aim = $Head/Camera.get_global_transform().basis
	if Input.is_action_pressed("move_forward"):
		direction -= aim.z
	if Input.is_action_pressed("move_backward"):
		direction += aim.z
	if Input.is_action_pressed("move_forward"):
		direction -= aim.x
	if Input.is_action_pressed("move_forward"):
		direction += aim.x

	direction = direction.normalized()

	# where would the play go at max speed
	var target = direction * FLY_SPEED
	
	# Calculate a portion of the distance to go
	velocity = velocity.linear_interpolate(target, FLY_ACCEL * delta)

	# move
	move_and_slide(velocity)

func aim():
	if camera_change.length() > 0:
		$Head.rotate_y(deg2rad(-camera_change.x * mouse_sensitivity))
		
		var change = -camera_change.y * mouse_sensitivity
		if change + camera_angle < 90 and change + camera_angle > -90:
			$Head/Camera.rotate_x(deg2rad(change))
			camera_angle += change
		camera_change = Vector2()

func _on_Area_body_entered(body):
	if body.name == "Gary":
		flying = true

func _on_Area_body_exited(body):
	if body.name == "Gary":
		flying = false