"""Game rules ported from the Godot client, so the server can check a save.

Source of truth for the numbers: Origin/scripts/origin/state.gd and content.gd.
If you change XP rules in the game, change them here too.

The game still calculates progress on the player's machine. The server does
not replay every session; it rejects saves that are impossible:
  * study time that grew faster than real time passed,
  * study time that went backwards (progress never regresses),
  * more XP than the recorded study time could ever earn,
  * totals that don't add up.
"""

import math

XP_PER_MINUTE = 10
TARGET_BONUS = 0.2
RETURN_BONUS_XP = 30
ACHIEVEMENT_XP = 40
ACHIEVEMENT_COUNT = 14

# Slack for clock jitter and the time between "session ended" and "save sent".
TIME_SLACK_SECONDS = 120
MAX_NAME_LENGTH = 40


def xp_for_level(level):
    return 60 * (level - 1) ** 2


def level_from_xp(xp):
    return math.floor(math.sqrt(max(xp, 0) / 60)) + 1


def max_xp_for(seconds, study_days):
    """The most XP a save with this much study time could legitimately hold."""
    base = math.floor(seconds / 60 * XP_PER_MINUTE)
    with_goal_bonus = math.ceil(base * (1 + TARGET_BONUS))
    # One "welcome back" bonus is possible at most once per study day, and
    # per-session rounding can add up to 1 XP per day as well.
    return with_goal_bonus + study_days * (RETURN_BONUS_XP + 1) + ACHIEVEMENT_COUNT * ACHIEVEMENT_XP


def _non_negative_int(value):
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_save(data, previous_seconds, elapsed_seconds):
    """Return a list of human-readable problems; an empty list means the save is accepted.

    previous_seconds: study time in the last accepted save (0 if none).
    elapsed_seconds:  real time since that save (or since signup).
    """
    if not isinstance(data, dict):
        return ["Save must be a JSON object."]

    errors = []
    for key in ("seconds", "xp", "mentor_seconds"):
        if not _non_negative_int(data.get(key, 0)):
            errors.append(f"'{key}' must be a non-negative whole number.")
    name = data.get("name", "")
    if not isinstance(name, str) or len(name) > MAX_NAME_LENGTH:
        errors.append(f"'name' must be text of at most {MAX_NAME_LENGTH} characters.")
    days = data.get("days", {})
    subjects = data.get("subjects", {})
    for key, mapping in (("days", days), ("subjects", subjects)):
        if not isinstance(mapping, dict) or not all(_non_negative_int(v) for v in mapping.values()):
            errors.append(f"'{key}' must map names to non-negative whole numbers of seconds.")
    if errors:
        return errors

    seconds = data.get("seconds", 0)
    xp = data.get("xp", 0)

    if sum(days.values()) != seconds:
        errors.append("Daily study totals don't add up to total study time.")
    if sum(subjects.values()) != seconds:
        errors.append("Subject study totals don't add up to total study time.")
    if data.get("mentor_seconds", 0) > seconds:
        errors.append("Mentoring time can't exceed total study time.")
    if seconds < previous_seconds:
        errors.append("Study time can't go backwards.")
    if seconds - previous_seconds > elapsed_seconds + TIME_SLACK_SECONDS:
        errors.append("More study time was recorded than real time has passed.")
    if xp > max_xp_for(seconds, len(days)):
        errors.append("XP is higher than the recorded study time allows.")
    return errors


def summarize(data):
    """Numbers the dashboard shows. Derived from the save, never trusted blindly."""
    xp = data.get("xp", 0) if isinstance(data, dict) else 0
    level = level_from_xp(xp)
    sessions = data.get("sessions", []) if isinstance(data, dict) else []
    days = data.get("days", {}) if isinstance(data, dict) else {}
    achievements = data.get("achievements", {}) if isinstance(data, dict) else {}
    return {
        "has_started": bool(isinstance(data, dict) and data.get("name")),
        "name": data.get("name", "") if isinstance(data, dict) else "",
        "level": level,
        "xp": xp,
        "xp_into_level": xp - xp_for_level(level),
        "xp_for_next_level": xp_for_level(level + 1) - xp_for_level(level),
        "study_seconds": data.get("seconds", 0) if isinstance(data, dict) else 0,
        "sessions": len(sessions) if isinstance(sessions, list) else 0,
        "study_days": len(days) if isinstance(days, dict) else 0,
        "achievements": len(achievements) if isinstance(achievements, dict) else 0,
        "ending_seen": bool(isinstance(data, dict) and data.get("flags", {}).get("ending_seen")),
    }
