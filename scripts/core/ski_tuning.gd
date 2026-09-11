class_name SkiTuning
extends Resource
## SI units: metres, seconds, radians, acceleration in m/s². No speed cap.
@export_group("Gravity and resistance")
@export_range(0.3, 2.0) var gravity_multiplier: float = 1.0
@export_range(0.001, 0.15) var ski_friction: float = 0.022
@export_range(0.0, 2.0) var snow_resistance: float = 0.08
# Additional passive ploughing through the surface's loose layer (1/m).
@export_range(0.0, 8.0) var snow_ploughing: float = 2.8
# Quadratic drag coefficient in 1/m. Racing speed needs a sustained steep pitch.
@export_range(0.0001, 0.02) var aerodynamic_drag: float = 0.0058
@export_range(0.1, 1.0) var tuck_drag_ratio: float = 0.43
@export var tuck_response: float = 3.5
@export var tuck_open_response: float = 12.0 # 1/s; open promptly to turn or brake
@export_range(0.0, 0.3) var tuck_steering_window: float = 0.15 # s, brief taps retain the aerodynamic tuck
@export_range(0.0, 0.4) var tuck_correction_window: float = 0.20 # normalized steering, small corrections stay tucked
@export_range(0.1, 1.0) var tuck_grip_ratio: float = 1.0 # neutral in the default model
@export_range(0.1, 1.0) var tuck_edge_response_ratio: float = 1.0

@export_group("Edges and steering")
@export_range(0.2, 4.0) var edge_grip: float = 1.6
@export_range(1.0, 25.0) var carving_strength: float = 9.0
@export_range(0.0, 3.0) var skidding_friction: float = 0.6
@export_range(20.0, 80.0) var maximum_edge_angle: float = 62.0
@export_range(0.3, 3.0) var steering_sensitivity: float = 1.85
@export var high_speed_steering_reduction: float = 0.024
@export var edge_response: float = 18.0
@export var steering_input_exponent: float = 1.15 # precise centre, progressive full command
@export_range(0.1, 1.0) var skid_steering_authority: float = 0.65 # minimum manual yaw fraction in an established skid
@export_range(0.0, 1.0) var turn_anticipation: float = 0.65
@export var bank_pressure_reserve: float = 0.14 # m, support width reserved for initiating bank
@export var transfer_pressure_reserve: float = 0.0 # m, retain old edge reaction during reversal
# Begin changing ski yaw while transferring weight; pressure and cuff limits still apply.
@export_range(0.0, 1.0) var turn_transfer_yaw_fraction: float = 0.25
@export_range(0.0, 1.0) var high_speed_transfer_yaw_fraction: float = 0.35
@export_range(0.0, 0.85) var turn_transfer_bank: float = 0.55 # rad, requested bank only
@export var braking_deceleration: float = 8.2

@export_group("Arcade carving")
# Developer calibration; zero disables carving amplification, retaining current tuck/contact.
@export_range(0.0, 1.0) var arcade_carve_strength: float = 1.0
@export var arcade_yaw_ratio: float = 1.20
@export var arcade_transfer_yaw_fraction: float = 0.17 # retain the supporting edge during COM transfer
@export var arcade_transfer_low_speed_fraction: float = 0.06
@export var arcade_transfer_release_bank: float = 0.65 # rad, begin releasing yaw as COM approaches support
@export var arcade_transfer_finish_bank: float = 0.15 # rad, full manual yaw near neutral
@export var arcade_transfer_shift_m: float = 0.08 # m, bounded active pelvis transfer through leg fitting
@export var arcade_transfer_shift_speed: float = 0.8 # m/s
@export var arcade_grip_ratio: float = 1.40
@export var arcade_carving_ratio: float = 1.65
@export_range(0.0, 1.0) var arcade_anticipation: float = 0.95
@export var arcade_body_lean: float = 1.238 # rad, supported high-input bank target
@export var arcade_roll_limit: float = 1.25 # rad, supported recovery envelope
@export var arcade_initiation_reserve: float = 0.15 # m, pressure available to build bank
@export var arcade_build_reserve: float = 0.25 # m, mid-bank torque before established grip
@export var arcade_build_start: float = 0.18 # rad, preserve the first steering response
@export var arcade_build_full: float = 0.35 # rad
@export var arcade_carve_crouch: float = 0.28 # m, supported athletic stance lowers COM/inertia
@export var arcade_pressure_reserve: float = 0.01 # m, only after bank establishes
@export var arcade_bank_start: float = 0.35 # rad, retain initiation torque below this
@export var arcade_bank_full: float = 0.85 # rad, established bank

@export_group("Exposed rock")
@export_range(0.0, 0.3) var rock_friction: float = 0.11 # coefficient, dry sliding contact
@export_range(0.0, 3.0) var rock_resistance: float = 0.45 # m/s², roughness loss
@export_range(0.0, 2.0) var rock_skidding_friction: float = 0.35
@export_range(0.1, 1.0) var rock_steering_ratio: float = 0.70
@export_range(0.1, 1.0) var rock_grip_ratio: float = 0.60
@export_range(0.0, 0.2) var rock_reserve_drain: float = 0.04 # fraction/s at full rock support

@export_group("Contact and impacts")
@export var jump_impulse: float = 3.2 # m/s along supported snow normal
@export_range(0.0, 0.15) var jump_buffer_time: float = 0.075 # s; release just before landing
@export var landing_tolerance: float = 10.5
@export var landing_absorption: float = 0.25
@export_range(0.0, 1.0) var landing_clean_damage_scale: float = 0.10 # residual damage above clean tolerance
@export var landing_tilt_full: float = 0.174532925 # rad, 10 degrees from surface normal
@export var landing_tilt_none: float = 0.872664626 # rad, 50 degrees
@export var landing_travel_full: float = 0.261799388 # rad, 15 degrees from either ski tip
@export var landing_travel_none: float = 1.047197551 # rad, 60 degrees
@export var landing_travel_min_speed: float = 0.5 # m/s; below this only slope fit matters
# Original Alpine Apex warning/recovery tuning; not decoded Steep constants.
@export var obstacle_impact_reference: float = 7.0 # normal closing speed, m/s
@export var impact_soft_ratio: float = 0.55 # below this fraction of reference: no damage
@export var impact_reference_damage: float = 0.30 # reserve spent at reference severity
@export var impact_max_damage: float = 0.65 # one impact cannot empty a full reserve
@export var impact_contact_grace: float = 0.30 # s, group ski/terrain contacts into one hit
@export var impact_recovery_delay: float = 1.25 # s without a rough impact before recovery
@export var impact_recovery_time: float = 6.0 # supported seconds to restore a full bar
@export var minimum_load: float = 0.0 # m/s²; unilateral support cannot be tensile
@export var support_stiffness: float = 30.0 # 1/s², spring stiffness divided by rider mass
@export var support_damping: float = 12.0 # 1/s, settles small suspension motion
@export var support_damping_limit: float = 4.0 # m/s², passive damper force/mass limit on sharp bumps
@export var support_recatch_time: float = 0.18 # s, descending unloaded skis can regain reachable support
@export var support_recatch_speed: float = 2.0 # m/s normal closing speed; hard landings retain impact handling

@export_group("Loose snow contact")
@export_range(0.0,1.0) var snow_compliance: float = 1.0
@export var snow_spring_ratio: float = 0.25 # deep snow / firm suspension stiffness
@export var snow_stop_progression: float = 0.50 # progressive last 35% of compression travel
@export var snow_compression_damping_ratio: float = 1.0
@export var snow_rebound_damping_ratio: float = 2.0
@export var snow_compression_limit_ratio: float = 0.75
@export var snow_rebound_limit_ratio: float = 2.0
@export_range(0.0,6.0) var snow_edge_cutting: float = 4.2 # normal-load ratio, embedded ski sidewall resistance
@export var snow_lateral_response: float = 26.0 # 1/s, passive sideways relaxation in thick snow
@export var snow_control_crouch: float = 0.08 # m, supported high-speed snow stance lowers COM/inertia
@export var snow_crush_max_m: float = 0.30 # maximum bank height; also bounded by normal loose depth
@export var snow_crush_start_kmh: float = 0.0
@export var snow_crush_full_kmh: float = 30.0

@export_group("Grounded snow")
@export var snow_contact_assist_enabled: bool = true
@export var snow_contact_max_correction_m_s: float = 3.0 # per 120 Hz tick, separating velocity only
@export var snow_contact_full_depth_m: float = 0.12
@export var snow_contact_lip_angle: float = 0.174532925 # radians, 10 degrees over 4 m
@export var snow_contact_settle_time: float = 0.15 # continuous loaded non-separating seconds

@export_group("Neutral steering landing help")
@export var landing_assist_enabled: bool = false # independent airborne option
@export var ground_assist_enabled: bool = false
@export var air_assist_acceleration: float = 1.047197551 # rad/s² (60 deg/s²)
@export var ground_assist_acceleration: float = 0.209439510 # rad/s² (12 deg/s²)
@export var landing_assist_delay: float = 0.10 # s of centered steering
@export var landing_assist_blend: float = 0.40 # s to full assistance
@export var landing_assist_horizon: float = 1.0 # s, bounded trajectory prediction
@export var landing_assist_rate: float = 0.349065850 # rad/s; legacy diagnostic ceiling, no separate body correction
@export var neutral_ground_alignment_rate: float = 0.104719755 # rad/s (6 degrees/s)
@export var neutral_air_alignment_rate: float = 0.349065850 # rad/s (20 degrees/s), same ceiling with/without prediction

@export_group("Manual airborne rotation")
@export var air_spin_rate: float = 5.4 # rad/s
@export var air_flip_rate: float = 3.8 # rad/s, about 1.7 s per turn from rest
@export var air_steer_rate: float = 1.56 # rad/s, 89 degrees/s
@export var air_tilt_rate: float = 1.08 # rad/s, ordinary pitch correction
@export var air_tilt_limit: float = 0.872664626 # rad, 50 degrees either side of reference
@export var air_rotation_acceleration: float = 36.0 # rad/s²
@export var air_rotation_braking: float = 48.0 # rad/s², release and reversal
@export var air_rotation_rate_limit: float = 7.2 # rad/s, combined rotation ceiling

@export_group("Articulated rider and separate skis")
@export var rider_mass: float = 80.0 # kg, including equipment carried by the rider
@export var half_stance: float = 0.19 # m; 38 cm ski centres, reviewed downhill stance
@export var ski_length: float = 1.80 # m
@export var ski_width: float = 0.11 # m
@export var leg_extension: float = 0.28 # m of differential terrain reach
@export var balance_stiffness: float = 3000.0 # N m / rad
@export var balance_damping: float = 380.0 # N m s / rad
@export var balance_recovery_damping: float = 1000.0 # N m s / rad, settling after release
@export var balance_max_torque: float = 600.0 # N m
@export var maximum_body_lean: float = 0.85 # rad at low speed
# Blend into a deeper supported bank from 30 to 60 km/h. Existing pressure,
# torque and cuff-rate limits still control engagement and reversals.
@export var high_speed_body_lean: float = 1.05 # rad (60.2 degrees)

@export_group("Presentation")
@export var vibration_intensity: float = 0.5
@export var speed_thresholds: PackedFloat32Array = PackedFloat32Array([30, 60, 90, 120, 150, 165, 200])

func carving_blend(steer: float, speed_mps: float) -> float:
	return arcade_carve_strength*smoothstep(.25,1.0,absf(steer))*smoothstep(30.0/3.6,60.0/3.6,speed_mps)

func carving_transfer_yaw(speed_mps: float) -> float:
	return lerpf(arcade_transfer_low_speed_fraction,arcade_transfer_yaw_fraction,smoothstep(50.0/3.6,80.0/3.6,speed_mps))
