extends CharacterBody3D

@onready var camera_pivot: Node3D = $CameraRoot
@onready var cspring: SpringArm3D = $CameraRoot/SpringArm3D
@onready var cam: Camera3D = $CameraRoot/SpringArm3D/Camera3D
@onready var playermesh: MeshInstance3D = $MeshInstance3D


# Keep the original exported values so saved scenes / future tweaks keep working.
@export_group("Movement")
@export var SPEED := 5.0
@export var JUMP_VELOCITY := 4.5
@export var acceleration := 20.0
@export var rotation_speed := 12.0
@export var sprint_speed := 8.0
@export var sprint_acceleration := 30.0

# Third-person orbit camera, adapted from the GDQuest 3D character
# controller guide. The camera looks down its local -Z, so -Z is "forward".
@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var tilt_upper_limit := deg_to_rad(80.0)
@export var tilt_lower_limit := deg_to_rad(-70.0)

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK


func _ready() -> void:
	# Don't let the spring arm collide with the player's own body,
	# otherwise the camera would clip into the capsule.
	cspring.add_excluded_object(get_rid())
	# Grab the mouse immediately so the orbit camera works from the start.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var is_camera_motion := (
		event is InputEventMouseMotion
		and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity


func _physics_process(delta: float) -> void:
	# Orbit the camera around the character. Mouse up = look up, mouse down =
	# look down (the -= keeps the vertical axis from feeling inverted).
	camera_pivot.rotation.x -= _camera_input_direction.y * delta
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, tilt_lower_limit, tilt_upper_limit)
	camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Camera-relative movement: W walks "forward on screen" (away from the
	# camera). The camera's +Z points out its back, and pressing the
	# "move_forward" action gives raw_input.y == -1.0, so together they move
	# the character toward the camera's forward (-Z).
	var raw_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var forward := cam.global_basis.z
	var right := cam.global_basis.x
	var move_direction := forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	move_direction = move_direction.normalized()

	# Sprint while holding the sprint action (Left Shift) and moving. Touching
	# the ground is not required, so you keep sprinting when you jump.
	var is_sprinting := Input.is_action_pressed("sprint") and move_direction.length() > 0.0
	var target_speed := sprint_speed if is_sprinting else SPEED
	var target_acceleration := sprint_acceleration if is_sprinting else acceleration

	# Accelerate horizontally toward the target without touching vertical
	# velocity, so gravity and jumping stay clean.
	var y_velocity := velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(move_direction * target_speed, target_acceleration * delta)
	velocity.y = y_velocity

	move_and_slide()

	# Turn the character to face where it's moving (only the visual mesh, so
	# the camera and collision stay independent).
	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	playermesh.rotation.y = lerp_angle(playermesh.rotation.y, target_angle, rotation_speed * delta)
