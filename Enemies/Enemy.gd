extends CharacterBody3D

const SPEED = 4.5
const JUMP_VELOCITY = 4.5
const ATTACK_RANGE = 2.0
const DETECTION_RANGE = 12.0
const KNOCKBACK_FORCE = 8.0
const PLAYER_KNOCKBACK_FORCE = 10.0

var target: Node3D = null
var hits_taken := 0
var can_attack := true
var is_stunned := false
var parry_window := false

@onready var detection_area: Area3D = $DetectionArea
@onready var attack_area: Area3D = $AttackArea
@onready var attack_timer: Timer = $AttackTimer
@onready var hit_timer: Timer = $HitTimer
@onready var stun_timer: Timer = $StunTimer

func _ready() -> void:
	if detection_area:
		detection_area.body_entered.connect(_on_detection_entered)
		detection_area.body_exited.connect(_on_detection_exited)
	if attack_area:
		attack_area.body_entered.connect(_on_attack_entered)
	if attack_timer:
		attack_timer.timeout.connect(_on_attack_timeout)
	if stun_timer:
		stun_timer.timeout.connect(_on_stun_timeout)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if is_stunned:
		move_and_slide()
		return
	
	if target == null or not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		move_and_slide()
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	if dist > ATTACK_RANGE:
		var dir = (target.global_position - global_position).normalized()
		dir.y = 0
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		if can_attack:
			attack()
	
	move_and_slide()

func attack() -> void:
	can_attack = false
	parry_window = true
	if attack_timer:
		attack_timer.start()
	
	# Try to damage player
	if target and is_instance_valid(target):
		if target.has_method("take_damage"):
			target.take_damage(self)
		elif target is CharacterBody3D:
			var dir = (target.global_position - global_position).normalized()
			dir.y = 0
			target.velocity = dir * PLAYER_KNOCKBACK_FORCE + Vector3.UP * 3.0
			if target.has_method("knockback"):
				target.knockback(dir * PLAYER_KNOCKBACK_FORCE + Vector3.UP * 3.0)

func _on_attack_timeout() -> void:
	can_attack = true
	parry_window = false

func _on_stun_timeout() -> void:
	is_stunned = false
	hits_taken = 0

func _on_detection_entered(body: Node3D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		target = body

func _on_detection_exited(body: Node3D) -> void:
	if body == target:
		target = null

func _on_attack_entered(body: Node3D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		if not can_attack and parry_window and hits_taken < 3:
			# Player spamming - parry
			if body.has_method("knockback"):
				var dir = (body.global_position - global_position).normalized()
				dir.y = 0
				body.knockback(dir * PLAYER_KNOCKBACK_FORCE + Vector3.UP * 4.0)
			elif body is CharacterBody3D:
				var dir = (body.global_position - global_position).normalized()
				dir.y = 0
				body.velocity = dir * PLAYER_KNOCKBACK_FORCE + Vector3.UP * 4.0
			is_stunned = true
			can_attack = false
			if stun_timer:
				stun_timer.start()
			hits_taken = 0
			return

func register_hit() -> void:
	hits_taken += 1
	if hits_taken >= 3:
		# Knock back enemy
		var dir = Vector3.ZERO
		if target and is_instance_valid(target):
			dir = (global_position - target.global_position).normalized()
		dir.y = 0
		velocity = dir * KNOCKBACK_FORCE + Vector3.UP * 4.0
		hits_taken = 0
		if stun_timer:
			stun_timer.start()
		is_stunned = true
		can_attack = false
		if attack_timer:
			attack_timer.stop()

