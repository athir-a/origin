extends RefCounted
## Static content for Origin: subjects, building rules, achievements, villagers and their evolving dialogue.
## Everything here is pure data / pure functions of a progress "metrics" dictionary so it is easy to test.

const SUBJECTS := [
	{"id": "math", "name": "Mathematics", "code": "MA", "color": Color("e8a33d")},
	{"id": "science", "name": "Science", "code": "SC", "color": Color("5fb3a1")},
	{"id": "literature", "name": "Literature", "code": "LI", "color": Color("c96f6f")},
	{"id": "history", "name": "History", "code": "HI", "color": Color("a58452")},
	{"id": "languages", "name": "Languages", "code": "LA", "color": Color("7a8fd8")},
	{"id": "code", "name": "Computer Science", "code": "CS", "color": Color("4fa6d9")},
	{"id": "arts", "name": "Art & Music", "code": "AM", "color": Color("b985d1")},
	{"id": "general", "name": "General Reading", "code": "GR", "color": Color("86b35a")},
]
const CUSTOM_COLORS := [Color("d98b5f"), Color("6fb98f"), Color("c7a24b"), Color("8d9bd0"), Color("d77fa1"), Color("7fb3c9")]

const DURATIONS := [
	{"minutes": 0, "label": "Free"},
	{"minutes": 5, "label": "5 min"},
	{"minutes": 15, "label": "15 min"},
	{"minutes": 25, "label": "25 min"},
	{"minutes": 45, "label": "45 min"},
	{"minutes": 60, "label": "60 min"},
]

const LEVEL_TITLES := [
	"Curious Newcomer", "Page Turner", "Steady Learner", "Lamp Keeper", "Bright Mind", "Scholar",
	"Pathfinder", "Village Pillar", "Teacher's Pride", "Torchbearer", "Guiding Light", "Origin Keeper",
]
const VILLAGE_TITLES := [
	"Quiet Hamlet", "Waking Hamlet", "Little Village", "Hopeful Village", "Busy Village",
	"Growing Village", "Bright Village", "Thriving Village", "Beacon Village", "Village of Origin",
]

# ---------------------------------------------------------------------------------------------
# Buildings: each one stands for a quality the player is building in themselves.
# ---------------------------------------------------------------------------------------------
const BUILDING_ORDER := ["farm", "library", "electricity", "roads", "school", "clinic", "computer", "internet", "shop"]
const BUILDINGS := {
	"farm": {
		"name": "The Farms", "pillar": "Consistency",
		"levels": ["Bare soil", "Seeds planted", "Growing fields", "Harvest season"],
		"meaning": "You cannot harvest what you never planted. Crops grow with every day you show up.",
		"req": [{"days": 1}, {"days": 3}, {"days": 7}],
	},
	"library": {
		"name": "The Library", "pillar": "Knowledge",
		"levels": ["A lone bookshelf", "Reading hut", "Village library", "Community learning center"],
		"meaning": "Everything you learn stays on the shelf. It starts small and becomes a place for everyone.",
		"req": [{"minutes": 45}, {"minutes": 180}, {"minutes": 600}],
	},
	"electricity": {
		"name": "Electricity", "pillar": "Progress",
		"levels": ["Oil lamps and candles", "Power reaches the village", "Every home is lit"],
		"meaning": "Better living conditions change everything: longer shop hours, brighter homes, evenings that belong to learning.",
		"req": [{"minutes": 90, "sessions": 3}, {"minutes": 480}],
	},
	"roads": {
		"name": "The Roads", "pillar": "Connection",
		"levels": ["Dirt tracks", "Gravel roads", "Paved roads"],
		"meaning": "Roads connect the village to the people and opportunities beyond it.",
		"req": [{"sessions": 5}, {"sessions": 15}],
	},
	"school": {
		"name": "The School", "pillar": "Opportunity",
		"levels": ["An empty plot", "One-room school", "Village schoolhouse"],
		"meaning": "Education opens doors that your growth can hold open for everyone.",
		"req": [{"pl": 3}, {"pl": 6}],
	},
	"clinic": {
		"name": "The Clinic", "pillar": "Well-being",
		"levels": ["An empty plot", "Village clinic", "Clinic and healing garden"],
		"meaning": "Progress should improve people's lives, not only their circumstances.",
		"req": [{"days": 3, "minutes": 120}, {"days": 8, "minutes": 480}],
	},
	"computer": {
		"name": "The Computer Center", "pillar": "Skills",
		"levels": ["An empty plot", "Computer room", "Technology hub"],
		"meaning": "Digital skills carry a small village into a very large world.",
		"req": [{"minutes": 360, "electricity": 1, "roads": 1}, {"minutes": 1000}],
	},
	"internet": {
		"name": "The Internet", "pillar": "Access",
		"levels": ["Offline", "Connected"],
		"meaning": "Barriers to information fall away. Anyone can learn anything.",
		"req": [{"minutes": 600, "computer": 1}],
	},
	"shop": {
		"name": "The Market", "pillar": "Community",
		"levels": ["Kabir's little shop", "Shop open late", "Bustling market"],
		"meaning": "When power and roads arrive, local business can finally breathe.",
		"req": [{"electricity": 1}, {"roads": 2}],
	},
}

const ZONES := {
	"north": {"name": "Hill Path", "hint": "Reach Learner Level 2 to clear the Hill Path.", "pl": 2},
	"east": {"name": "East Road", "hint": "Reach 5 study sessions so a proper road can be laid east.", "roads": 1},
}

# ---------------------------------------------------------------------------------------------
# Achievements
# ---------------------------------------------------------------------------------------------
const ACHIEVEMENTS := [
	{"id": "first_step", "name": "First Step", "desc": "Complete your first study session."},
	{"id": "getting_serious", "name": "Getting Serious", "desc": "Show up on 3 different days."},
	{"id": "seven_lamps", "name": "Seven Lamps", "desc": "Show up on 7 different days."},
	{"id": "bookworm", "name": "Bookworm", "desc": "Study for 5 hours in total."},
	{"id": "deep_roots", "name": "Deep Roots", "desc": "Study for 20 hours in total."},
	{"id": "builder", "name": "Builder", "desc": "Help bring a library, power line or road to the village."},
	{"id": "community_first", "name": "Community First", "desc": "Open the village school."},
	{"id": "light_up", "name": "Let There Be Light", "desc": "Bring electricity to the village."},
	{"id": "window_world", "name": "Window to the World", "desc": "Connect the village to the internet."},
	{"id": "welcome_back", "name": "Welcome Back", "desc": "Return to your studies after a break. That matters."},
	{"id": "deep_focus", "name": "Deep Focus", "desc": "Finish a single session of 45 minutes or more."},
	{"id": "many_paths", "name": "Many Paths", "desc": "Study 3 different subjects."},
	{"id": "you_made_it", "name": "You Made It", "desc": "Return to where it began, and meet the next student."},
	{"id": "passing_lamp", "name": "Passing the Lamp", "desc": "Study beside Asha for 3 sessions."},
]
const ACHIEVEMENT_XP := 40

# ---------------------------------------------------------------------------------------------
# Villagers
# ---------------------------------------------------------------------------------------------
const VILLAGERS := {
	"grandma": {"name": "Nani Savitri", "role": "Your grandmother", "color": Color("c9885a")},
	"mother": {"name": "Meera", "role": "Your mother", "color": Color("d98b5f")},
	"shopkeeper": {"name": "Kabir", "role": "Shopkeeper", "color": Color("b8553f")},
	"child": {"name": "Tiya", "role": "The child who watches you study", "color": Color("e6b84d")},
	"farmer": {"name": "Old Hari", "role": "Farmer", "color": Color("8aa14c")},
	"teacher": {"name": "Ms. Anika", "role": "Teacher", "color": Color("a46a98")},
	"doctor": {"name": "Dr. Farah", "role": "Village doctor", "color": Color("5fb3a1")},
	"tech": {"name": "Rohan", "role": "Tech volunteer", "color": Color("4fa6d9")},
	"asha": {"name": "Asha", "role": "The next student", "color": Color("e07f9a")},
}

## Short lines villagers say right after something changes. Key: "<building>:<level>".
const REACTIONS := {
	"farm:1": {"farmer": "Look at that. Seeds in the ground. Funny, it was you who made me want to plant again."},
	"farm:2": {"mother": "The beans are climbing the poles already! Hari says it is all the showing up. I told him that is what I tell you."},
	"farm:3": {"farmer": "Harvest! The biggest pumpkin is for your mother. You cannot harvest what you never planted, and you planted plenty."},
	"library:1": {"child": "There is a little house for books now! I can touch them if I wash my hands. I washed twice."},
	"library:2": {"grandma": "A real library, in our village. I dust the shelves when nobody is watching. Somebody has to keep your books warm."},
	"library:3": {"mother": "A learning center. Whole families reading together. I never imagined such a thing for us."},
	"electricity:1": {"shopkeeper": "The new electricity line finally reached my shop. They say you're the reason we could afford it.", "mother": "No more soot on the ceiling. Do you know how long I have wanted that?"},
	"electricity:2": {"grandma": "Every window glowing at night... I used to be afraid of the dark evenings. Now I just watch the lights."},
	"roads:1": {"shopkeeper": "Carts come through without losing a wheel now. Gravel! You have no idea what that does for business."},
	"roads:2": {"child": "The road is so smooth I can ride my little cart all the way to the East Road without falling."},
	"school:1": {"teacher": "I have wanted to teach in this village for years. A school, built from one student's lamp. I am Ms. Anika. I would love to hear your story."},
	"school:2": {"teacher": "Twenty-two students enrolled this term. Twenty-two! And they all know the story of the lamp."},
	"clinic:1": {"doctor": "I am Dr. Farah. A clinic means nobody has to walk two days when they are sick. Rest is part of studying too, remember."},
	"clinic:2": {"grandma": "Dr. Farah looked at my knees. First time anyone has. I told her they are older than she is."},
	"computer:1": {"tech": "Welcome to the computer center! Lesson one: if it does not work, turn it off and on again.", "child": "I want to become a programmer like you."},
	"computer:2": {"tech": "A technology hub! We are teaching three villages how to code now. You started this."},
	"internet:1": {"tech": "We are online! Ask me anything. Anything at all. I will search it.", "grandma": "Tiya showed me a photograph of the sea, on a little glass. I cried. Do not tell anybody."},
	"shop:1": {"shopkeeper": "The shop stays open late now. Students buy pencils after dark, and I do not mind a bit."},
	"shop:2": {"shopkeeper": "Look at this market! I used to sit alone all afternoon. Now I run out of change."},
}


static func subject_by_name(subject_name: String, custom: Array) -> Dictionary:
	for s: Dictionary in SUBJECTS:
		if s.name == subject_name:
			return s
	var idx := custom.find(subject_name)
	if idx >= 0:
		return {"id": "custom", "name": subject_name, "code": subject_name.substr(0, 2).to_upper(), "color": CUSTOM_COLORS[idx % CUSTOM_COLORS.size()]}
	return {"id": "custom", "name": subject_name, "code": subject_name.substr(0, 2).to_upper(), "color": Color("9aa3a8")}


static func level_title(level: int) -> String:
	return LEVEL_TITLES[mini(level - 1, LEVEL_TITLES.size() - 1)] if level <= LEVEL_TITLES.size() else "%s %d" % [LEVEL_TITLES[-1], level - LEVEL_TITLES.size() + 1]


static func village_title(vl: int) -> String:
	return VILLAGE_TITLES[clampi(vl - 1, 0, VILLAGE_TITLES.size() - 1)]


static func xp_for_level(level: int) -> int:
	return 60 * (level - 1) * (level - 1)


static func level_from_xp(xp: int) -> int:
	return int(floor(sqrt(float(xp) / 60.0))) + 1


## ---- building levels (derived, monotonic) ----------------------------------------------------
static func meets(req: Dictionary, m: Dictionary, lv: Dictionary) -> bool:
	for key: String in req:
		var need: float = req[key]
		var have: float
		match key:
			"minutes": have = m.minutes
			"days": have = m.days
			"sessions": have = m.sessions
			"pl": have = m.pl
			_: have = float(lv.get(key, 0))
		if have < need:
			return false
	return true


static func building_levels(m: Dictionary) -> Dictionary:
	var lv := {}
	for id: String in BUILDING_ORDER:
		var level := 0
		var reqs: Array = BUILDINGS[id].req
		for i in reqs.size():
			if meets(reqs[i], m, lv):
				level = i + 1
			else:
				break
		lv[id] = level
	return lv


static func max_level(id: String) -> int:
	return (BUILDINGS[id].req as Array).size()


## Describes the next unmet goal for a building as {text, frac}. frac is 0..1 progress to next level.
static func next_goal(id: String, m: Dictionary, lv: Dictionary) -> Dictionary:
	var level: int = lv.get(id, 0)
	if level >= max_level(id):
		return {"text": "Fully developed", "frac": 1.0, "done": true}
	var req: Dictionary = BUILDINGS[id].req[level]
	var parts: PackedStringArray = []
	var fracs: Array[float] = []
	for key: String in req:
		var need: float = req[key]
		var have: float
		var label := ""
		match key:
			"minutes":
				have = m.minutes
				label = "%s of study" % _fmt_minutes(need)
			"days":
				have = m.days
				label = "%d days showing up" % int(need)
			"sessions":
				have = m.sessions
				label = "%d study sessions" % int(need)
			"pl":
				have = m.pl
				label = "Learner Level %d" % int(need)
			_:
				have = float(lv.get(key, 0))
				label = "%s level %d" % [BUILDINGS[key].name, int(need)]
		fracs.append(clampf(have / need, 0.0, 1.0))
		if have < need:
			if key == "minutes":
				parts.append("%s (%s so far)" % [label, _fmt_minutes(have)])
			elif key in ["days", "sessions", "pl"]:
				parts.append("%s (%d/%d)" % [label, int(have), int(need)])
			else:
				parts.append(label)
	var frac := 1.0
	for f in fracs:
		frac = minf(frac, f)
	if fracs.size() > 0:
		var total := 0.0
		for f in fracs:
			total += f
		frac = total / fracs.size()
	return {"text": ", ".join(parts), "frac": frac, "done": false}


static func _fmt_minutes(mins: float) -> String:
	if mins >= 60.0:
		var h := mins / 60.0
		if absf(h - roundf(h)) < 0.05:
			return "%dh" % int(roundf(h))
		return "%.1fh" % h
	return "%dm" % int(mins)


static func village_level(lv: Dictionary) -> int:
	var total := 0
	for id: String in lv:
		total += int(lv[id])
	return 1 + total / 2


static func zone_open(zone: String, m: Dictionary, lv: Dictionary) -> bool:
	var z: Dictionary = ZONES[zone]
	if z.has("pl"):
		return m.pl >= z.pl
	if z.has("roads"):
		return lv.get("roads", 0) >= z.roads
	return true


static func finale_ready(m: Dictionary, lv: Dictionary) -> bool:
	return (lv.farm >= 2 and lv.library >= 2 and lv.school >= 1 and lv.electricity >= 1 and lv.roads >= 1
		and lv.clinic >= 1 and lv.computer >= 1 and lv.internet >= 1 and m.pl >= 9)


static func finale_goal_text(m: Dictionary, lv: Dictionary) -> String:
	var missing: PackedStringArray = []
	if lv.farm < 2: missing.append("growing fields")
	if lv.library < 2: missing.append("a village library")
	if lv.school < 1: missing.append("the school")
	if lv.electricity < 1: missing.append("electricity")
	if lv.roads < 1: missing.append("roads")
	if lv.clinic < 1: missing.append("the clinic")
	if lv.computer < 1: missing.append("the computer center")
	if lv.internet < 1: missing.append("the internet")
	if m.pl < 9: missing.append("Learner Level 9")
	return "Still to come: " + ", ".join(missing) if missing.size() > 0 else "Everything is ready."


# ---------------------------------------------------------------------------------------------
# Dialogue
# ---------------------------------------------------------------------------------------------
## Each villager returns a list of "topics", newest first. Every topic is an Array of text pages.
## {n} is replaced by the player's name.
static func topics(id: String, s: Dictionary) -> Array:
	var out: Array = []
	var lv: Dictionary = s.lv
	var sessions: int = s.sessions
	var ended: bool = s.ended
	match id:
		"grandma":
			out.append(["{n}, you are under that old lamp again? Good. A lamp is only useful if someone sits beneath it.", "I never went to school, you know. But I know the sound of somebody trying. It sounds like hope."])
			if sessions >= 1:
				out.append(["You're studying again? Good. Your mother saved some money so you could buy that book.", "Do not tell her I told you. She wants it to be a surprise that you were never worried about money."])
			if lv.library >= 1:
				out.append(["A library in our village. I dust the shelves when no one is looking.", "Somebody has to keep all those books warm."])
			if lv.electricity >= 1:
				out.append(["Light with the touch of a switch. At my age I had given up on seeing the evening so clearly."])
			if lv.school >= 1:
				out.append(["They built a school on the old threshing floor. I sit by its window sometimes. Nobody has asked me to leave."])
			if lv.clinic >= 1:
				out.append(["Dr. Farah looked at my knees. Nobody has done that before. I told her they are older than she is."])
			if lv.internet >= 1:
				out.append(["Tiya showed me a photograph of the sea, on a little glass screen. I had to sit down."])
			if ended:
				out.append(["You stand straight like your grandfather did. He would be proud. I am.", "Go on. That girl by the lamp is looking at you the way you once looked at the stars."])
		"mother":
			out.append(["Eat something before you study, {n}. The book will wait. Your stomach will not.", "The coin jar is lighter this month. It is for you. Do not look at me like that."])
			if sessions >= 1:
				out.append(["I saw the lamp lit late last night. I will not say anything. Only... thank you for trying."])
			if lv.farm >= 2:
				out.append(["The beans are climbing already. Hari says it is all about showing up. I told him that is what I tell you."])
			if lv.library >= 1:
				out.append(["A shelf of books in our village. I used to hide my old schoolbook under the mattress. I might borrow one after you."])
			if lv.electricity >= 1:
				out.append(["No more soot on the ceiling. Do you know how long I have wanted that?"])
			if lv.school >= 1:
				out.append(["I signed up for the evening class. Do not laugh. Ms. Anika says I am good with fractions."])
			if ended:
				out.append(["You made it, {n}. I am so proud I could burst.", "Go on. Someone is waiting under that lamp."])
		"shopkeeper":
			out.append(["Pencils are free for anyone studying under that lamp. Do not tell the other customers."])
			if sessions >= 3:
				out.append(["I have started noticing when the lamp is on. It's like having a neighbor who never sleeps. I like it."])
			if lv.electricity >= 1:
				out.append(["The new electricity line finally reached my shop. They say you're the reason we could afford it."])
			if lv.roads >= 1:
				out.append(["Carts come through without losing a wheel now. Business, {n}! Real business!"])
			if lv.shop >= 2:
				out.append(["Look at my market! I used to sit alone all afternoon. Now I run out of change."])
			if lv.internet >= 1:
				out.append(["I check prices in the city on the little screen now. Nobody has cheated me since."])
			if ended:
				out.append(["Whatever you need, {n}, it is on the house. Forever. I mean it. Almost."])
		"child":
			out.append(["I watch you from the fence. Are you doing sums? Can I see?", "What's it like to know what's inside books?"])
			if sessions >= 2:
				out.append(["I tried to sit very still like you do. Mama said I lasted a whole minute!"])
			if lv.library >= 1:
				out.append(["The books! I may touch them if I wash my hands. I washed twice."])
			if lv.school >= 1:
				out.append(["Ms. Anika says I can start in the spring. Do you think I will be good?"])
			if lv.computer >= 1:
				out.append(["I want to become a programmer like you.", "I do not even know what that is yet. But I want it."])
			if ended:
				out.append(["Asha is sitting where you used to! Does that mean one day I get to sit there and teach someone, too?"])
		"farmer":
			out.append(["Dry soil, dry hopes. But a seed does not care how it starts, {n}.", "Come by tomorrow. Crops are like folks. They grow when you show up."])
			if lv.farm >= 1:
				out.append(["See those sprouts? You cannot harvest what you never planted."])
			if lv.farm >= 2:
				out.append(["Greener every week. It works the same for crops and for learning, I think."])
			if lv.farm >= 3:
				out.append(["Take a pumpkin, the biggest one. No, argue and I will give you two."])
			if ended:
				out.append(["My granddaughter is reading at the lamp. Never thought I would live to see it."])
		"teacher":
			out.append(["They say this school began with a student and a street lamp. I would like to hear it from you.", "I do not teach pupils. I teach people who have been waiting for permission to start."])
			if lv.school >= 2:
				out.append(["Twenty-two students this term. And they all know the story of the lamp."])
			if ended:
				out.append(["Asha is the brightest I have seen since you. But she is also scared, like you were. Be kind."])
		"doctor":
			out.append(["Sleep is part of studying, {n}. Rest isn't wasted time. It is when the brain files everything away.", "Come by if you ever get headaches from reading in dim light."])
			if lv.clinic >= 2:
				out.append(["The healing garden is for everyone. Lavender helps with exam nerves, I promise."])
			if ended:
				out.append(["I check on Asha every week. She forgets to eat when she is studying. Reminds me of someone."])
		"tech":
			out.append(["Welcome to the computer center! Lesson one: if it does not work, turn it off and on again."])
			if lv.internet >= 1:
				out.append(["We are online. I can look up anything. Ask me something hard."])
			if lv.computer >= 2:
				out.append(["The technology hub is teaching three other villages how to code. Because of you."])
			if ended:
				out.append(["I made Asha a tiny program that plays a bell when her study timer ends. She said it's the best present ever."])
		"asha":
			if s.mentor_minutes < 30:
				out.append(["I'm Asha. Everyone says you started right where I'm sitting.", "Is it okay if I just... sit here and read with you?"])
			else:
				out.append(["Look, I read a whole page without stopping. The words stay still when you are beside me."])
			if s.mentor_minutes >= 90:
				out.append(["I asked Ms. Anika a big question today. She said it was a good one. I think she meant it."])
			if s.mentor_minutes >= 180:
				out.append(["Tiya and I are making a little library for the little ones. We need a shelf, and a lantern."])
			if s.mentor_minutes >= 360:
				out.append(["One day I want to hold the light for someone too."])
		_:
			out.append(["..."])
	out.reverse()
	return out


## Mentoring milestones for Asha (minutes of study beside her).
const ASHA_MILESTONES := [
	{"minutes": 30, "title": "First full page", "text": "Asha reads an entire page aloud without stopping. 'It stays still when you are next to me,' she says."},
	{"minutes": 90, "title": "A big question", "text": "Asha asks Ms. Anika a question nobody knew the answer to. The whole class goes quiet, then starts writing."},
	{"minutes": 180, "title": "A shelf for the little ones", "text": "Asha and Tiya build a small shelf of picture books for the youngest children."},
	{"minutes": 360, "title": "The lamp passes on", "text": "Asha tells the new child by the fence, 'Come sit. There is room under the lamp.'"},
	{"minutes": 600, "title": "The cycle continues", "text": "Asha holds the light for someone else. Where you begin does not have to be where you end. And how far you go can change how far someone else gets to go."},
]

const INTRO_PAGES := [
	"You begin with almost nothing.\n\nA street lamp. A few houses. Some farms and dirt roads.\nAnd a small community that believes in you.",
	"Your grandmother encourages you. Your mother saves coins for your books.\nThe shopkeeper knows you are working hard.\nA little child watches you study under the lamp, dreaming of doing the same.",
	"As you learn, the village will grow. Not as numbers on a chart, but as farms, a library, a school, light in the windows.\n\nEvery improvement is something you have grown within yourself.",
]
