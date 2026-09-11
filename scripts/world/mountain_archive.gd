extends RefCounted
## Bounded independent sections. Integrity is checked on bytes before decoding.
## Writers never replace the live file until the complete archive is flushed.
const MAGIC = "APEXV15\n"
const FORMAT = 1
const MAX_SECTION = 16*1024*1024
const MAX_FILE = 1536*1024*1024
const MAX_SECTIONS = 65536
const DIRECTORY = "user://mountain_cache_v15"
const DEFAULT_BUDGET = 2*1024*1024*1024
static var mutex = Mutex.new()

static func digest(bytes: PackedByteArray) -> PackedByteArray:
	var hash_value = HashingContext.new(); hash_value.start(HashingContext.HASH_SHA256); hash_value.update(bytes); return hash_value.finish()

static func write(path: String, key: String, sections: Array, job = null) -> bool:
	if sections.size()>MAX_SECTIONS or key.length()!=64: return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK: return false
	var temp = path+".%d.%d.tmp" % [OS.get_process_id(),Time.get_ticks_usec()]
	var file = FileAccess.open(temp,FileAccess.WRITE)
	if not file: return false
	file.store_buffer(MAGIC.to_ascii_buffer()); file.store_32(FORMAT); file.store_buffer(key.to_ascii_buffer()); file.store_32(sections.size())
	var good = true
	for section in sections:
		if job and job.is_cancelled(): good = false; break
		var name_bytes: PackedByteArray = section.name.to_utf8_buffer()
		var payload = var_to_bytes(section.value)
		if payload.size()>MAX_SECTION or name_bytes.size()>256 or name_bytes.is_empty(): good = false; break
		file.store_32(name_bytes.size()); file.store_buffer(name_bytes)
		file.store_32(payload.size()); file.store_buffer(digest(payload)); file.store_buffer(payload)
		if file.get_error()!=OK or file.get_position()>MAX_FILE: good = false; break
		if job: job.advance(payload.size())
	file.flush(); good = good and file.get_error()==OK; file.close()
	mutex.lock()
	if job and job.is_cancelled(): good = false
	if good: good = DirAccess.rename_absolute(temp,path)==OK
	if not good: DirAccess.remove_absolute(temp)
	mutex.unlock()
	return good

static func read(path: String, key: String, job = null) -> Dictionary:
	if key.length()!=64 or not FileAccess.file_exists(path): return {}
	var file = FileAccess.open(path,FileAccess.READ)
	if not file or file.get_length()<80 or file.get_length()>MAX_FILE: return {}
	if file.get_buffer(8).get_string_from_ascii()!=MAGIC or file.get_32()!=FORMAT or file.get_buffer(64).get_string_from_ascii()!=key: return {}
	var count = file.get_32()
	if count<1 or count>MAX_SECTIONS: return {}
	var result: Dictionary = {}
	for i in count:
		if job and job.is_cancelled(): return {}
		if file.get_length()-file.get_position()<4: return {}
		var name_size = file.get_32()
		if name_size<1 or name_size>256 or file.get_length()-file.get_position()<name_size+36: return {}
		var name = file.get_buffer(name_size).get_string_from_utf8()
		if result.has(name): return {}
		var size = file.get_32(); var expected = file.get_buffer(32)
		if size<4 or size>MAX_SECTION or file.get_length()-file.get_position()<size: return {}
		var bytes = file.get_buffer(size)
		if bytes.size()!=size or digest(bytes)!=expected: return {}
		var value = bytes_to_var(bytes)
		if value==null: return {}
		result[name] = value
		if job: job.advance(size)
	if file.get_position()!=file.get_length(): return {}
	return result

static func append_packed(sections: Array, name: String, values, stride: int = 65536) -> void:
	sections.append({"name":name+"/count","value":values.size()})
	for first in range(0,values.size(),stride): sections.append({"name":name+"/%d" % (first/stride),"value":values.slice(first,first+stride)})

static func unpack(data: Dictionary, name: String, empty, maximum: int, stride: int = 65536):
	var count = data.get(name+"/count",-1)
	if not count is int or count<0 or count>maximum: return null
	var result = empty
	for first in range(0,count,stride):
		var section = data.get(name+"/%d" % (first/stride))
		if typeof(section)!=typeof(empty) or section.size()!=mini(stride,count-first): return null
		result.append_array(section)
	return result

static func touch(recipe: String) -> void:
	if recipe.length()!=64: return
	mutex.lock()
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var file = FileAccess.open(DIRECTORY.path_join(recipe+".used"),FileAccess.WRITE)
	if file: file.store_64(int(Time.get_unix_time_from_system())); file.close()
	mutex.unlock()

static func evict(protected_recipe: String, budget: int = -1, active_recipe: String = "", directory: String = DIRECTORY) -> Dictionary:
	if budget<0: budget = maxi(0,int(ProjectSettings.get_setting("generation/cache_budget_mib",2048)))*1024*1024
	mutex.lock()
	var entries: Dictionary = {}; var total_bytes: int = 0; var evicted: Array = []
	for name in DirAccess.get_files_at(directory):
		if not (name.ends_with(".physical") or name.ends_with(".scenery")): continue
		var key = name.get_basename()
		if key.length()!=64: continue
		var file = FileAccess.open(directory.path_join(name),FileAccess.READ)
		if not file: continue
		var size = file.get_length(); file.close(); total_bytes += size
		if not entries.has(key): entries[key] = {"key":key,"bytes":0,"files":[],"used":FileAccess.get_modified_time(directory.path_join(key+".used"))}
		entries[key].bytes += size; entries[key].files.append(name)
	var ordered = entries.values()
	ordered.sort_custom(func(a,b): return a.used<b.used if a.used!=b.used else a.key<b.key)
	for entry in ordered:
		if total_bytes<=budget: break
		if entry.key in [protected_recipe,active_recipe]: continue
		var removed: int = 0
		for name in entry.files:
			var path = directory.path_join(name)
			var file = FileAccess.open(path,FileAccess.READ); var size = file.get_length() if file else 0; file = null
			if DirAccess.remove_absolute(path)==OK: removed += size
		total_bytes -= removed
		DirAccess.remove_absolute(directory.path_join(entry.key+".used"))
		evicted.append(entry.key)
	mutex.unlock()
	return {"bytes":total_bytes,"budget":budget,"evicted":evicted,"over_budget":total_bytes>budget}
