extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Probe = preload("res://tests/planted_snow_probe.gd")
const Response = preload("res://scripts/core/snow_contact_response.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const OUTPUT = "res://artifacts/planted_snow"
var checks = 0
var failures: Array = []
var results: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func run() -> void:
	var args = OS.get_cmdline_user_args()
	if "--steering" in args: steering()
	elif "--isolation" in args: isolation()
	elif "--mountain" in args or "--sweep" in args: mountain("--sweep" in args)
	else:
		material_law()
		ripples()
		lifecycle()
	results.checks = checks; results.failures = failures; results.model = Sim.MODEL_VERSION; results.unranked = true
	var label = "mountain" if "--mountain" in args else ("sweep" if "--sweep" in args else "contact")
	if "--steering" in args: label = "steering"
	if "--isolation" in args: label = "isolation"
	FileAccess.open(OUTPUT+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("PLANTED_SNOW ",label," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func material_law() -> void:
	var tuning = SkiTuning.new(); var response = Response.new()
	for depth in [0.0,.04,.16,.30]:
		for displacement in [-.28,-.15,0.0,.15,.28]:
			for velocity in [-8.0,-2.0,-.1,0.0,.1,2.0,8.0]:
				response.evaluate(displacement,.86,velocity,-8.4366,depth,30.0,12.0,4.0,tuning)
				check(response.reaction>=0.0,"Non-tensile material reaction")
				check(response.damper_acceleration*velocity>=0.0,"Damping always opposes motion")
				check(response.compression_m>=0 and response.compression_m<=depth,"Normal compression within local snow depth")
	# Mechanical energy on horizontal snow includes the progressive spring's
	# exact integral. Gravity is disabled to separate dissipation from slope work.
	var surface = Probe.SnowRipple.new(0,32,.30)
	for z in surface.NZ:
		for x in surface.NX: surface.heights[z*surface.NX+x] = 0.0
	var sim = Sim.new(); sim.tuning.gravity_multiplier = 0; sim.tuning.aerodynamic_drag = 0
	sim.reset(Vector3(0,-.22,0)); sim.prime_contacts(surface)
	var initial = potential(.22,sim.tuning)
	var peak = initial
	for tick in 240:
		sim.step(Probe.DT,RiderInput.new(),surface)
		peak = maxf(peak,.5*sim.velocity.length_squared()+potential(maxf(0,-sim.position.y),sim.tuning))
	check(peak<=initial*1.03,"Snow compression does not create mechanical energy")
	results.energy = {"initial_per_kg":initial,"peak_per_kg":peak}

func potential(compression: float,tuning) -> float:
	var start: float = tuning.leg_extension*.65
	return .5*tuning.support_stiffness*tuning.snow_spring_ratio*compression*compression+tuning.support_stiffness*tuning.snow_stop_progression*pow(maxf(0,compression-start),3)/(3*(tuning.leg_extension-start))

func ripples() -> void:
	var rows: Array = []
	for amplitude in [.05,.15,.30,.60]:
		for speed in [60.0,120.0,160.0,200.0]:
			for depth in [.04,.16,.30]:
				var field = Probe.SnowRipple.new(amplitude,32,depth,.35)
				var fixture = {"kmh":speed,"input":"ripple","steer":.15}
				var row = Probe.measure(Sim,field,fixture)
				row.erase("samples"); row.amplitude = amplitude; row.depth = depth; row.kmh = speed; rows.append(row)
				check(row.crash.is_empty(),"Snow ripple completes %.2f m / %.0f km/h / %.2f m depth"%[amplitude,speed,depth])
				check(row.min_load_n>=0 and row.unsupported_grip_n==0,"Physical support limits on ripple")
				check(row.reach_m<=.281 and row.foot_error_m<.001,"Exact contact and bounded reach on ripple")
				if amplitude<=.15 and speed<=160: check(row.airtime_s<=.10,"Gentle snow ripple retains support")
	results.ripples = rows
	if FileAccess.file_exists(OUTPUT+"/baseline/core/ski_simulation.gd"):
		var old = load(OUTPUT+"/baseline/core/ski_simulation.gd")
		var glide: Array = []
		for depth in [.04,.16,.30]:
			var field = Probe.SnowRipple.new(0,32,depth)
			var fixture = {"kmh":120.0,"seconds":10.0,"input":"glide"}
			var before = Probe.measure(old,field,fixture); var after = Probe.measure(Sim,field,fixture)
			check(absf(after.exit_kmh/before.exit_kmh-1.0)<=.05,"Straight glide remains within 5%% at depth %.2f"%depth)
			glide.append({"depth":depth,"before":before.exit_kmh,"after":after.exit_kmh})
		results.glide = glide

func lifecycle() -> void:
	var field = Probe.SnowRipple.new(.15)
	var a = Sim.new(); var b = Sim.new()
	for sim in [a,b]: sim.reset(Vector3(0,field.sample(0,0).height-.1,0)); sim.prime_contacts(field); sim.velocity = sim.support_basis().z*30
	var intent = RiderInput.new(); intent.steer = .3
	for tick in 360: a.step(Probe.DT,intent,field); b.step(Probe.DT,intent,field)
	check(a.position==b.position and a.velocity==b.velocity,"Identical tick input reproduces snow state")
	for ski in a.skis:
		var work: float = ski.normal_dissipated_j
		a._update_contacts(field,Probe.DT,false)
		check(ski.normal_dissipated_j==work,"Second contact probe cannot integrate normal work twice")
	a.reset(Vector3.ZERO)
	for ski in a.skis: check(ski.compression_m==0 and ski.normal_dissipated_j==0 and ski.traction_utilization==0,"Restart clears snow telemetry")
	# A different surface and an explicit teleport must not retain contact work.
	field.rock_fraction = 1.0
	b._update_contacts(field,Probe.DT,false)
	for ski in b.skis: check(ski.compression_m==0 and ski.normal_dissipated_j==0 and ski.penetration==0,"Rock transition clears snow history")
	field.rock_fraction = 0.0
	b.position = Vector3(0,field.sample(0,32).height,32)
	b.prime_contacts(field)
	for ski in b.skis: check(ski.normal_dissipated_j==0 and ski.traction_utilization==0,"Teleport primes fresh contact history")

func mountain(sweep: bool) -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"/baseline/mountain.json"))
	var field = Definition.generate(849205174,13)
	check(field.height_checksum==baseline.height_sha256 and field.obstacle_checksum==baseline.obstacle_sha256,"Frozen v13 terrain identity")
	check(baseline.fixtures.size()==18,"All six faces and three elevation bands frozen")
	var candidates: Array = [{}]
	if sweep:
		for spring in [.15,.35,.6,1.0]:
			for compression in [.25,.75,1.5]:
				candidates.append({"snow_spring_ratio":spring,"snow_compression_limit_ratio":compression})
	var trials: Array = []
	for overrides in candidates:
		var old_short = 0; var new_short = 0; var old_air = 0.0; var new_air = 0.0
		var rows: Array = []; var crashes = 0
		for fixture in baseline.fixtures:
			var row = Probe.measure(Sim,field,fixture,overrides)
			old_short += int(fixture.baseline.short_events); new_short += int(row.short_events)
			old_air += fixture.baseline.airtime_s; new_air += row.airtime_s
			if not row.crash.is_empty(): crashes += 1
			if not sweep:
				check(row.min_load_n>=0 and row.unsupported_grip_n==0,"Supported traction: "+fixture.name)
				check(row.reach_m<=.281 and row.foot_error_m<.001,"Contact geometry: "+fixture.name)
			row.fixture = fixture.name; rows.append(row)
		var trial = {"overrides":overrides,"old_short":old_short,"new_short":new_short,"old_air":old_air,"new_air":new_air,"crashes":crashes,"rows":rows}
		trials.append(trial)
		print("CONTACT_TRIAL ",JSON.stringify({"overrides":overrides,"old_short":old_short,"new_short":new_short,"old_air":old_air,"new_air":new_air,"crashes":crashes}))
		if not sweep: check(new_short<=old_short*.30,"At least 70% fewer short incidental flights on fixed v13 fixtures")
	results.trials = trials

func steering() -> void:
	var old = load(OUTPUT+"/baseline/core/ski_simulation.gd")
	var rows: Array = []
	var old_turn = 0.0; var new_turn = 0.0; var old_air = 0.0; var new_air = 0.0
	for amplitude in [0.0,.15,.30]:
		for speed in [120.0,160.0,200.0]:
			for direction in [-1.0,1.0]:
				var field = Probe.SnowRipple.new(amplitude,32,.16)
				var fixture = {"kmh":speed,"seconds":4.0,"input":"reversal","steer":direction}
				var before = Probe.measure(old,field,fixture); var after = Probe.measure(Sim,field,fixture)
				old_turn += before.turn_2s_deg; new_turn += after.turn_2s_deg
				old_air += before.airtime_s; new_air += after.airtime_s
				check(after.crash.is_empty() and after.unsupported_grip_n==0,"High-speed reversal retains valid support")
				# Detect the first actual angular response (>0.03 rad/s under
				# support). The separately reported 1-degree threshold includes
				# intervening ballistic flight and is not input-response latency.
				check(after.response_s>=0 and after.response_s<=before.response_s+Probe.DT*2.01,"Actual steering force responds within two baseline ticks")
				check(after.reversal_s>=0 and after.reversal_s<=before.reversal_s+.1,"Actual travel reverses within 100 ms of baseline")
				rows.append({"amplitude":amplitude,"kmh":speed,"direction":direction,"before":before,"after":after})
	results.steering = {"old_turn_2s_sum":old_turn,"new_turn_2s_sum":new_turn,"old_air_s":old_air,"new_air_s":new_air,"rows":rows}
	check(new_turn>=old_turn,"High-speed travel redirection improves in aggregate")
	print("STEERING_COMPARISON ",JSON.stringify({"old_turn":old_turn,"new_turn":new_turn,"old_air":old_air,"new_air":new_air}))

func isolation() -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/planted_snow_v22.json"))
	var field = Definition.generate(849205174,13)
	var surface = Probe.ContactOnly.new(field)
	var old = load(OUTPUT+"/baseline/core/ski_simulation.gd")
	check(field.height_checksum==baseline.height_sha256,"Isolated contact uses unchanged frozen v13 snow")
	var before_short = 0; var after_short = 0; var before_air = 0.0; var after_air = 0.0
	var rows: Array = []
	for fixture in baseline.fixtures:
		# Nonfatal scenery deflections can alter the frozen world trajectory.
		# Reproduce that original separately; both contact-only runs then remove
		# exactly the same obstacle responses at the already frozen origins.
		var original_world = Probe.measure(old,field,fixture)
		var before = Probe.measure(old,surface,fixture); var after = Probe.measure(Sim,surface,fixture)
		check(before.crash.is_empty() and after.crash.is_empty(),"Complete paired snow trajectory: "+fixture.name)
		check(before.duration_s==after.duration_s and after.duration_s==fixture.get("seconds",6.0),"Equal measured duration: "+fixture.name)
		check(original_world.short_events==fixture.baseline.short_events and absf(original_world.exit_kmh-fixture.baseline.exit_kmh)<.001,"Frozen world baseline reproduces: "+fixture.name)
		before_short += before.short_events; after_short += after.short_events
		before_air += before.airtime_s; after_air += after.airtime_s
		rows.append({"fixture":fixture.name,"before":before,"after":after,"world_baseline":original_world})
	check(after_short<=before_short*.30,"70% fewer short flights without obstacle truncation")
	results.comparison = {"before_short":before_short,"after_short":after_short,"before_air_s":before_air,"after_air_s":after_air,"rows":rows,"obstacles":false}
	print("ISOLATED_SNOW ",before_short," -> ",after_short," short flights; ",before_air," -> ",after_air," air seconds")
