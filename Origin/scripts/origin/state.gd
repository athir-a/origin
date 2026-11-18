extends Node
## OriginState: the single source of truth for the player's journey.
## All village development is DERIVED from study metrics, so it can never regress.

signal changed

const Content = preload("res://scripts/origin/content.gd")
const SAVE_MAIN := "user://origin_save.json"
const SAVE_PREVIEW := "user://origin_preview.json"
const MIN_RECORD_SECONDS := 60
const XP_PER_MINUTE := 10
const RETURN_BONUS_XP := 30
const TARGET_BONUS := 0.2
const MAX_SESSIONS_KEPT := 400

var slot := "main"
var d: Dictionary = {}


func _ready() -> void:
	load_slot("main")


# ---------------------------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------------------------
func _path() -> String:
	return SAVE_PREVIEW if slot == "preview" else SAVE_MAIN


func default_data() -> Dictionary:
	return {
		"version": 1, "name": "", "created": 0,
		"xp": 0, "seconds": 0, "mentor_seconds": 0,
		"sessions": [], "days": {}, "subjects": {}, "custom_subjects": [],
		"achievements": {}, "seen_levels": {}, "seen_zones": [], "shown_levels": {}, "shown_zones": [],
		"events": [], "pending": {}, "talks": {},
		"flags": {"intro_done": false, "ending_seen": false, "tutorial_done": false, "milestones": []},
		"last_subject": "Mathematics", "last_target": 25,
		"settings": {"reduced_motion": false},
		"world": {"hour": -1.0},
	}


# ---------------------------------------------------------------------------------------------
# Account bridge: when the Web build is embedded in the Origin site (frontend/src/pages/Village.jsx),
# the parent page exposes window.originBridge and the main save lives on the user's account instead
# of in browser storage (which every account on the same browser would share).
# The preview slot always stays local so story previews never touch real progress.
# ---------------------------------------------------------------------------------------------
var _bridge_checked := false
var _has_bridge := false


func _use_bridge() -> bool:
	if slot != "main":
		return false
	if not _bridge_checked:
		_bridge_checked = true
		if OS.has_feature("web"):
			_has_bridge = bool(JavaScriptBridge.eval("!!(window.parent && window.parent !== window && window.parent.originBridge)", true))
	return _has_bridge


func _bridge_call(method: String, arg: String = "") -> Variant:
	# JSON.stringify of a String yields a valid JS string literal, so the save text is passed safely.
	var js := "window.parent.originBridge.%s(%s)" % [method, JSON.stringify(arg) if arg != "" else ""]
	return JavaScriptBridge.eval(js, true)


func load_slot(slot_name: String) -> void:
	slot = slot_name
	d = default_data()
	if _use_bridge():
		var text: Variant = _bridge_call("loadSave")
		if text is String and text != "":
			var remote: Variant = JSON.parse_string(text)
			if remote is Dictionary:
				_merge(d, remote)
		changed.emit()
		return
	if FileAccess.file_exists(_path()):
		var f := FileAccess.open(_path(), FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_merge(d, parsed)
	changed.emit()


func _merge(base: Dictionary, extra: Dictionary) -> void:
	for k: String in extra:
		if base.has(k) and base[k] is Dictionary and extra[k] is Dictionary and k != "days" and k != "subjects" and k != "achievements" and k != "seen_levels" and k != "pending" and k != "talks":
			_merge(base[k], extra[k])
		else:
			base[k] = extra[k]


func save() -> void:
	if _use_bridge():
		_bridge_call("saveGame", JSON.stringify(d))
		return
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()


func has_save() -> bool:
	return str(d.name) != "" and int(d.created) > 0


func wipe(slot_name: String = "") -> void:
	var s := slot_name if slot_name != "" else slot
	var p := SAVE_PREVIEW if s == "preview" else SAVE_MAIN
	if s == "main" and slot == "main" and _use_bridge():
		_bridge_call("resetSave")
	elif FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if s == slot:
		d = default_data()
	changed.emit()


func new_game(player_name: String) -> void:
	if _use_bridge():
		# The server never lets study time go backwards, so a fresh journey starts with an explicit reset.
		_bridge_call("resetSave")
	d = default_data()
	d.name = player_name.strip_edges() if player_name.strip_edges() != "" else "Traveler"
	d.created = int(Time.get_unix_time_from_system())
	save()
	changed.emit()


func flag(key: String, default: Variant = false) -> Variant:
	return d.flags.get(key, default)


func set_flag(key: String, value: Variant) -> void:
	d.flags[key] = value
	save()


# ---------------------------------------------------------------------------------------------
# Derived stats
# ---------------------------------------------------------------------------------------------
func today() -> String:
	return Time.get_date_string_from_system()


func xp() -> int:
	return int(d.xp)


func level() -> int:
	return Content.level_from_xp(xp())


func level_progress() -> Dictionary:
	var lvl := level()
	var base := Content.xp_for_level(lvl)
	var nxt := Content.xp_for_level(lvl + 1)
	return {"level": lvl, "into": xp() - base, "need": nxt - base, "frac": float(xp() - base) / float(nxt - base), "title": Content.level_title(lvl)}


func total_minutes() -> float:
	return float(d.seconds) / 60.0


func session_count() -> int:
	return (d.sessions as Array).size()


func days_count() -> int:
	return (d.days as Dictionary).size()


func metrics() -> Dictionary:
	return {"minutes": total_minutes(), "days": days_count(), "sessions": session_count(), "pl": level()}


func levels() -> Dictionary:
	return Content.building_levels(metrics())


func village_level() -> int:
	return Content.village_level(levels())


func zone_open(zone: String) -> bool:
	return Content.zone_open(zone, metrics(), levels())


func ended() -> bool:
	return bool(d.flags.get("ending_seen", false))


func mentor_minutes() -> float:
	return float(d.mentor_seconds) / 60.0


func finale_ready() -> bool:
	return Content.finale_ready(metrics(), levels())


## Snapshot used by dialogue topics
func dialogue_state() -> Dictionary:
	return {"lv": levels(), "sessions": session_count(), "ended": ended(), "mentor_minutes": mentor_minutes()}


func subjects_all() -> Array:
	var out: Array = []
	for s: Dictionary in Content.SUBJECTS:
		out.append(s)
	for name: String in d.custom_subjects:
		out.append(Content.subject_by_name(name, d.custom_subjects))
	return out


func add_custom_subject(subject_name: String) -> String:
	var n := subject_name.strip_edges().substr(0, 22)
	if n == "":
		return ""
	for s: Dictionary in Content.SUBJECTS:
		if s.name.to_lower() == n.to_lower():
			return s.name
	for c: String in d.custom_subjects:
		if c.to_lower() == n.to_lower():
			return c
	if (d.custom_subjects as Array).size() >= 10:
		return ""
	(d.custom_subjects as Array).append(n)
	save()
	return n


func week_days() -> Array:
	var out: Array = []
	var now := Time.get_unix_time_from_system()
	for i in range(6, -1, -1):
		var t := now - i * 86400
		var key := Time.get_date_string_from_unix_time(int(t + _utc_offset()))
		var dt := Time.get_datetime_dict_from_unix_time(int(t + _utc_offset()))
		out.append({"date": key, "label": ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][dt.weekday], "seconds": int(d.days.get(key, 0)), "today": i == 0})
	return out


func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().bias) * 60


func week_seconds() -> int:
	var total := 0
	for w: Dictionary in week_days():
		total += w.seconds
	return total


func days_this_week() -> int:
	var n := 0
	for w: Dictionary in week_days():
		if w.seconds > 0:
			n += 1
	return n


func today_seconds() -> int:
	return int(d.days.get(today(), 0))


## Gentle "rhythm": consecutive days that include study, counted back from today or yesterday.
func rhythm() -> int:
	var now := Time.get_unix_time_from_system()
	var n := 0
	var start := 0
	if not d.days.has(Time.get_date_string_from_unix_time(int(now + _utc_offset()))):
		start = 1
	for i in range(start, 400):
		var key := Time.get_date_string_from_unix_time(int(now - i * 86400 + _utc_offset()))
		if d.days.has(key):
			n += 1
		else:
			break
	return n


func subject_totals() -> Array:
	var arr: Array = []
	for k: String in d.subjects:
		arr.append({"name": k, "seconds": int(d.subjects[k])})
	arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.seconds > b.seconds)
	return arr


func days_since_last_study() -> int:
	var sessions: Array = d.sessions
	if sessions.is_empty():
		return -1
	var last: Dictionary = sessions[sessions.size() - 1]
	var now := int(Time.get_unix_time_from_system())
	var a := Time.get_datetime_dict_from_unix_time(int(last.ts) + _utc_offset())
	var b := Time.get_datetime_dict_from_unix_time(now + _utc_offset())
	var da := Time.get_unix_time_from_datetime_dict({"year": a.year, "month": a.month, "day": a.day, "hour": 0, "minute": 0, "second": 0})
	var db := Time.get_unix_time_from_datetime_dict({"year": b.year, "month": b.month, "day": b.day, "hour": 0, "minute": 0, "second": 0})
	return int((db - da) / 86400)


# ---------------------------------------------------------------------------------------------
# Recording a session
# ---------------------------------------------------------------------------------------------
func record_session(subject: String, seconds: int, target_min: int, mentor: bool = false) -> Dictionary:
	var res := {"ok": false}
	if seconds < MIN_RECORD_SECONDS:
		return res
	var before_lv := levels()
	var before_pl := level()
	var gap := days_since_last_study()
	var minutes := float(seconds) / 60.0
	var bonuses: Array = []
	var base_xp := int(floor(minutes * XP_PER_MINUTE))
	var xp_gain := base_xp
	if target_min > 0 and seconds >= target_min * 60 - 5:
		var tb := int(round(base_xp * TARGET_BONUS))
		xp_gain += tb
		bonuses.append({"label": "Goal reached", "xp": tb})
	var returned := gap >= 2
	if returned:
		xp_gain += RETURN_BONUS_XP
		bonuses.append({"label": "Welcome back", "xp": RETURN_BONUS_XP})

	var key := today()
	var sess := {"ts": int(Time.get_unix_time_from_system()), "date": key, "subject": subject, "seconds": seconds, "xp": xp_gain, "target": target_min, "mentor": mentor}
	(d.sessions as Array).append(sess)
	if (d.sessions as Array).size() > MAX_SESSIONS_KEPT:
		(d.sessions as Array).pop_front()
	d.days[key] = int(d.days.get(key, 0)) + seconds
	d.subjects[subject] = int(d.subjects.get(subject, 0)) + seconds
	d.seconds = int(d.seconds) + seconds
	d.xp = int(d.xp) + xp_gain
	d.last_subject = subject
	d.last_target = target_min
	if mentor:
		d.mentor_seconds = int(d.mentor_seconds) + seconds
	res = _finish_recording(res, before_lv, before_pl, xp_gain, base_xp, bonuses, returned, minutes, seconds)
	return res


func _finish_recording(res: Dictionary, before_lv: Dictionary, before_pl: int, xp_gain: int, base_xp: int, bonuses: Array, returned: bool, minutes: float, seconds: int) -> Dictionary:
	var ach := _check_achievements(returned, minutes)
	var ach_xp := ach.size() * Content.ACHIEVEMENT_XP
	if ach_xp > 0:
		d.xp = int(d.xp) + ach_xp
		xp_gain += ach_xp
		for a_id in ach:
			bonuses.append({"label": "Achievement: " + _ach_name(a_id), "xp": Content.ACHIEVEMENT_XP})
	var after_lv := levels()
	var new_levels: Array = []
	for id: String in Content.BUILDING_ORDER:
		var seen: int = int(d.seen_levels.get(id, 0))
		if after_lv[id] > seen:
			for l in range(seen + 1, int(after_lv[id]) + 1):
				new_levels.append({"id": id, "level": l})
			d.seen_levels[id] = after_lv[id]
	var new_zones: Array = []
	for z: String in Content.ZONES:
		if zone_open(z) and not (d.seen_zones as Array).has(z):
			(d.seen_zones as Array).append(z)
			new_zones.append(z)
	# queue story events (survive a reload before they are shown)
	for z in new_zones:
		(d.events as Array).append({"type": "zone", "id": z})
	for nl: Dictionary in new_levels:
		(d.events as Array).append({"type": "building", "id": nl.id, "level": nl.level})
		_queue_reactions("%s:%d" % [nl.id, nl.level])
	var mentor_ms: Array = []
	if bool(d.flags.get("ending_seen", false)):
		for i in Content.ASHA_MILESTONES.size():
			var ms: Dictionary = Content.ASHA_MILESTONES[i]
			if mentor_minutes() >= ms.minutes and not (d.flags.milestones as Array).has(i):
				(d.flags.milestones as Array).append(i)
				mentor_ms.append(ms)
				(d.events as Array).append({"type": "milestone", "index": i})
	if finale_ready() and not ended() and not _has_event("finale"):
		(d.events as Array).append({"type": "finale"})
	var lp := level_progress()
	res = {
		"ok": true, "seconds": seconds, "minutes": minutes, "xp": xp_gain, "base_xp": base_xp, "bonuses": bonuses,
		"level_before": before_pl, "level_after": level(), "level_title": lp.title, "level_frac": lp.frac,
		"returned": returned, "new_levels": new_levels, "new_zones": new_zones, "achievements": ach, "milestones": mentor_ms,
		"village_level": Content.village_level(after_lv),
	}
	save()
	changed.emit()
	return res


func _has_event(t: String) -> bool:
	for e: Dictionary in d.events:
		if e.type == t:
			return true
	return false


func _ach_name(id: String) -> String:
	for a: Dictionary in Content.ACHIEVEMENTS:
		if a.id == id:
			return a.name
	return id


func has_achievement(id: String) -> bool:
	return d.achievements.has(id)


func grant_achievement(id: String) -> bool:
	if d.achievements.has(id):
		return false
	d.achievements[id] = int(Time.get_unix_time_from_system())
	return true


func _check_achievements(returned: bool, session_minutes: float) -> Array:
	var got: Array = []
	var lv := levels()
	var checks := {
		"first_step": session_count() >= 1,
		"getting_serious": days_count() >= 3,
		"seven_lamps": days_count() >= 7,
		"bookworm": total_minutes() >= 300.0,
		"deep_roots": total_minutes() >= 1200.0,
		"builder": lv.library >= 1 or lv.electricity >= 1 or lv.roads >= 1,
		"community_first": lv.school >= 1,
		"light_up": lv.electricity >= 1,
		"window_world": lv.internet >= 1,
		"welcome_back": returned,
		"deep_focus": session_minutes >= 45.0,
		"many_paths": (d.subjects as Dictionary).size() >= 3,
		"you_made_it": ended(),
		"passing_lamp": _mentor_session_count() >= 3,
	}
	for id: String in checks:
		if checks[id] and grant_achievement(id):
			got.append(id)
	return got


func _mentor_session_count() -> int:
	var n := 0
	for s: Dictionary in d.sessions:
		if s.get("mentor", false):
			n += 1
	return n


func achievements_unlocked() -> int:
	return (d.achievements as Dictionary).size()


# ---------------------------------------------------------------------------------------------
# Villager memory / reactions
# ---------------------------------------------------------------------------------------------
func _queue_reactions(key: String) -> void:
	if not Content.REACTIONS.has(key):
		return
	var r: Dictionary = Content.REACTIONS[key]
	for vid: String in r:
		if not d.pending.has(vid):
			d.pending[vid] = []
		(d.pending[vid] as Array).append(r[vid])


func pending_for(vid: String) -> Array:
	return d.pending.get(vid, [])


func clear_pending(vid: String) -> void:
	d.pending.erase(vid)
	save()


func talk_count(vid: String) -> int:
	return int(d.talks.get(vid, 0))


func bump_talk(vid: String) -> void:
	d.talks[vid] = talk_count(vid) + 1
	save()


func next_event() -> Dictionary:
	var ev: Array = d.events
	return ev[0] if ev.size() > 0 else {}


func pop_event() -> void:
	var ev: Array = d.events
	if ev.size() > 0:
		ev.pop_front()
		save()


func dialogue_pages(vid: String) -> Array:
	var pend := pending_for(vid)
	var pages: Array = []
	var nm: String = d.name
	if not pend.is_empty():
		for line: String in pend:
			pages.append(line.replace("{n}", nm))
		clear_pending(vid)
		bump_talk(vid)
		return pages
	var topics := Content.topics(vid, dialogue_state())
	var idx := talk_count(vid) % topics.size()
	for line: String in topics[idx]:
		pages.append(line.replace("{n}", nm))
	bump_talk(vid)
	return pages


# ---------------------------------------------------------------------------------------------
# Preview chapters: synthesize a believable history (kept in the separate preview slot).
# ---------------------------------------------------------------------------------------------
const CHAPTERS := [
	{"id": 1, "title": "First Light", "minutes": 25, "days": 1, "sessions": 1, "blurb": "Your very first session beneath the lamp."},
	{"id": 2, "title": "Roots", "minutes": 150, "days": 4, "sessions": 7, "blurb": "Fields are planted, a reading hut stands, the hill path is open."},
	{"id": 3, "title": "Growing", "minutes": 450, "days": 9, "sessions": 20, "blurb": "Power lines, roads, a school and a clinic."},
	{"id": 4, "title": "Connected", "minutes": 900, "days": 14, "sessions": 36, "blurb": "Computers, internet and a bustling market."},
	{"id": 5, "title": "The Return", "minutes": 1500, "days": 22, "sessions": 55, "blurb": "Everything is ready. The lamp is waiting."},
]


func synthesize(chapter: int, player_name: String) -> void:
	var ch: Dictionary = CHAPTERS[clampi(chapter, 1, CHAPTERS.size()) - 1]
	d = default_data()
	d.name = player_name if player_name != "" else "Traveler"
	d.created = int(Time.get_unix_time_from_system())
	d.flags.intro_done = true
	d.flags.tutorial_done = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + chapter
	var subjects := ["Mathematics", "Science", "Literature", "History", "Languages", "Computer Science"]
	var n_sessions: int = ch.sessions
	var total_sec: int = int(ch.minutes) * 60
	var per := maxi(120, total_sec / n_sessions)
	var now := int(Time.get_unix_time_from_system())
	var day_count: int = ch.days
	for i in n_sessions:
		var day_back := int(round(float(day_count - 1) * float(n_sessions - 1 - i) / float(maxi(1, n_sessions - 1))))
		var ts := now - day_back * 86400 - (n_sessions - i) * 60
		var dkey := Time.get_date_string_from_unix_time(ts + _utc_offset())
		var subj: String = subjects[rng.randi() % subjects.size()]
		var secs := int(per * rng.randf_range(0.7, 1.3))
		var xp_s := int(secs / 60.0 * XP_PER_MINUTE)
		(d.sessions as Array).append({"ts": ts, "date": dkey, "subject": subj, "seconds": secs, "xp": xp_s, "target": 25, "mentor": false})
		d.days[dkey] = int(d.days.get(dkey, 0)) + secs
		d.subjects[subj] = int(d.subjects.get(subj, 0)) + secs
		d.seconds = int(d.seconds) + secs
		d.xp = int(d.xp) + xp_s
	# make totals match the chapter closely
	var drift := total_sec - int(d.seconds)
	d.seconds = int(d.seconds) + drift
	d.xp = int(d.xp) + int(drift / 60.0 * XP_PER_MINUTE)
	var lv := levels()
	for id: String in lv:
		d.seen_levels[id] = lv[id]
		d.shown_levels[id] = lv[id]
	for z: String in Content.ZONES:
		if zone_open(z):
			(d.seen_zones as Array).append(z)
			(d.shown_zones as Array).append(z)
	_check_achievements(false, 20.0)
	if finale_ready() and chapter >= 5:
		(d.events as Array).append({"type": "finale"})
	save()
	changed.emit()


# ---------------------------------------------------------------------------------------------
# What the world is currently allowed to show (updated as story events are presented)
# ---------------------------------------------------------------------------------------------
func shown_levels() -> Dictionary:
	var out := {}
	for id: String in Content.BUILDING_ORDER:
		out[id] = int(d.shown_levels.get(id, 0))
	return out


func zone_shown(zone: String) -> bool:
	return (d.shown_zones as Array).has(zone)


func mark_shown_building(id: String, level: int) -> void:
	d.shown_levels[id] = maxi(int(d.shown_levels.get(id, 0)), level)
	save()


func mark_shown_zone(zone: String) -> void:
	if not (d.shown_zones as Array).has(zone):
		(d.shown_zones as Array).append(zone)
	save()


## 0 = on the ground under the lamp ... 4 = the village study hall
func study_tier() -> int:
	var lv := shown_levels()
	var t := 0
	if lv.library >= 1 or level() >= 3:
		t = 1
	if lv.electricity >= 1:
		t = 2
	if lv.computer >= 1:
		t = 3
	if lv.internet >= 1 and level() >= 7:
		t = 4
	return t
