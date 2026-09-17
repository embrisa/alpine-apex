extends RefCounted
## Single source for numbered presets and editable presentation bounds.
## Rows: label, group, minimum, maximum, step. Booleans use false/true.
const MAX_TRACK_HISTORY = 6144
const CONTROLS = {
	"texture_tier":["Surface textures", "Textures & detail",0,2,1],
	"mesh_lod_bias":["Stone mesh detail", "Textures & detail",.25,1.6,.05],
	"tree_near_m":["Near tree detail (m)", "Scenery",20.0,160.0,5.0],
	"tree_mid_m":["Mid tree detail (m)", "Scenery",80.0,420.0,10.0],
	"tree_far_m":["Tree draw distance (m)", "Scenery",400.0,2000.0,50.0],
	"scrub_distance_m":["Ground foliage distance (m)", "Scenery",20.0,200.0,5.0],
	"scrub_density":["Decorative ground foliage", "Scenery",0.0,1.0,.05],
	"backdrop_tier":["Distant ridge detail", "Scenery",0,2,1],
	"offmap_snow_detail":["Distant snow deposits", "Scenery",false,true,1],
	"offmap_shadow_quality":["Distant mountain shadows", "Scenery",0,2,1],
	"offmap_prop_density":["Distant decorative density", "Scenery",0.0,1.0,.05],
	"offmap_tree_distance_m":["Distant trees (m)", "Scenery",1500.0,7500.0,250.0],
	"shadow_quality":["Shadow filtering", "Lighting & shadows",0,5,1],
	"shadow_distance_m":["Shadow distance (m)", "Lighting & shadows",60.0,320.0,10.0],
	"contact_shading":["Contact shading", "Lighting & shadows",false,true,1],
	"contact_intensity":["Contact shading in direct light", "Lighting & shadows",0.0,1.0,.05],
	"indirect_lighting":["Screen-space indirect light", "Lighting & shadows",false,true,1],
	"indirect_intensity":["Indirect light strength", "Lighting & shadows",0.0,2.0,.1],
	"terrain_gi":["Terrain global illumination", "Lighting & shadows",false,true,1],
	"volumetric_shafts":["Sun shafts", "Atmosphere",false,true,1],
	"shaft_strength":["Sun shaft strength", "Atmosphere",0.0,1.5,.05],
	"fog_strength":["Atmospheric fog", "Atmosphere",0.5,1.5,.05],
	"highlight_glow":["Highlight glow", "Atmosphere",false,true,1],
	"highlight_glow_intensity":["Glow strength", "Atmosphere",0.0,.6,.01],
	"normal_strength":["Snow and rock material detail", "Snow & particles",.1,.6,.01],
	"snow_sparkle":["Crystal sparkle", "Snow & particles",0.0,12.0,.5],
	"snow_crystal_density":["Crystal density", "Snow & particles",0.0,2.5,.05],
	"snow_sheen":["Snow sheen", "Snow & particles",0.0,.25,.01],
	"snow_track_capacity":["Track segments", "Snow & particles",400,MAX_TRACK_HISTORY,128],
	"snow_track_relief":["Track relief", "Snow & particles",false,true,1],
	"snow_local_deformation":["Local snow deformation", "Snow & particles",false,true,1],
	"spray_budget":["Spray per ski", "Snow & particles",48,640,16],
	"grain_budget":["Snow grains per ski", "Snow & particles",32,384,16],
	"mist_budget":["Snow mist per ski", "Snow & particles",0,192,16],
	"weather_quality":["Precipitation quality", "Weather effects",0,2,1],
	"weather_budget":["Precipitation density", "Weather effects",.25,1.5,.05]
}
const COLUMNS = ["tree_near_m","tree_mid_m","tree_far_m","scrub_distance_m","scrub_density","shadow_distance_m","normal_strength","spray_budget","grain_budget","mist_budget","snow_track_capacity","snow_sparkle","snow_crystal_density","snow_sheen","highlight_glow_intensity","offmap_prop_density","offmap_tree_distance_m","mesh_lod_bias"]
# Every adjacent row changes effective distances and particle/track budgets.
const TABLE = [
	[40,135,700,45,.45,100,.23,96,64,0,800,0,0,.06,0,.30,3000,.35],
	[50,160,800,55,.55,120,.27,128,80,16,1024,2,.60,.07,.12,.40,3500,.45],
	[60,190,900,70,.70,140,.31,160,96,32,1280,4,1.0,.085,.20,.50,4000,.50],
	[70,220,1000,85,1.0,170,.36,192,128,48,1600,6,1.35,.1008,.2772,.60,4500,.60],
	[78,240,1100,100,1.0,185,.38,256,160,64,2304,7,1.45,.12,.31,.70,5000,.70],
	[86,260,1200,115,1.0,200,.40,320,208,96,3072,8,1.60,.14,.35,.85,5500,.85],
	[95,280,1300,130,1.0,220,.42,384,256,128,4096,9,1.75,.1584,.385,1.0,6000,1.0],
	[110,320,1500,150,1.0,250,.44,448,288,144,4608,10,1.90,.17,.40,1.0,6500,1.15],
	[130,360,1750,175,1.0,280,.46,512,320,160,5376,11,2.10,.18,.42,1.0,7000,1.30],
	[150,400,2000,200,1.0,320,.48,640,384,192,MAX_TRACK_HISTORY,12,2.25,.19,.44,1.0,7500,1.50]
]

static func values(id: int) -> Dictionary:
	id = clampi(id,1,10)
	var tier = 0 if id<4 else (1 if id<7 else 2)
	# These effects require a normal/roughness depth prepass. Budget them together
	# above recommended High; individual user overrides remain available.
	var result = {"texture_tier":tier,"backdrop_tier":tier,"shadow_quality":0 if id<3 else (1 if id<7 else (2 if id<9 else 3)),
		"contact_shading":id>=8,"contact_intensity":.20,"indirect_lighting":id>=8,"indirect_intensity":.55,
		"offmap_snow_detail":false,"offmap_shadow_quality":0,"terrain_gi":false,"volumetric_shafts":id>=7,"shaft_strength":1.0,"fog_strength":1.0,
		"highlight_glow":id>1,"snow_track_relief":id>=3,"snow_local_deformation":id>=7,
		"weather_quality":1 if id<4 else 2,"weather_budget":.5 if id<4 else (1.0 if id<8 else 1.0+(id-7)*.15)}
	for i in COLUMNS.size(): result[COLUMNS[i]] = TABLE[id-1][i]
	return sanitize(result)

static func sanitize(values: Dictionary) -> Dictionary:
	var result = {}
	for key in values:
		if not CONTROLS.has(key): continue
		var row: Array = CONTROLS[key]
		var value = values[key]
		if row[2] is bool:
			if value is bool: result[key] = value
		elif (value is float or value is int) and is_finite(float(value)):
			result[key] = clampi(int(value),row[2],row[3]) if row[2] is int else clampf(float(value),row[2],row[3])
	return result

static func title(id: int) -> String:
	return "%d · %s" % [id,{1:"Low",4:"Balanced",7:"High · Recommended",10:"Ultra"}.get(id,"Detail "+str(id))]
