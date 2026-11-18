"""Tests for the game save API. Run with: python manage.py test"""

from datetime import timedelta

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import GameSave
from .rules import level_from_xp, max_xp_for, xp_for_level

User = get_user_model()


def make_save(seconds=0, xp=0, name="Asha"):
    """A minimal save in the shape Origin/scripts/origin/state.gd writes."""
    days = {"2026-11-09": seconds} if seconds else {}
    subjects = {"Mathematics": seconds} if seconds else {}
    return {
        "version": 1, "name": name, "created": 1, "xp": xp, "seconds": seconds,
        "mentor_seconds": 0, "sessions": [], "days": days, "subjects": subjects,
        "achievements": {}, "flags": {"ending_seen": False},
    }


class RulesTests(APITestCase):
    def test_level_curve_matches_game(self):
        # content.gd: level n needs 60*(n-1)^2 XP.
        self.assertEqual(level_from_xp(0), 1)
        self.assertEqual(level_from_xp(59), 1)
        self.assertEqual(level_from_xp(60), 2)
        self.assertEqual(level_from_xp(240), 3)
        self.assertEqual(xp_for_level(9), 3840)

    def test_max_xp_allows_goal_and_return_bonus(self):
        # 25 min at 10 XP/min = 250, +20% goal bonus, +30 welcome back, + achievements.
        self.assertGreaterEqual(max_xp_for(25 * 60, 1), 250 + 50 + 30)


class ProgressApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user("meera", password="village-pass-123")
        # Pretend the account is a day old so there's real time to study in.
        User.objects.filter(pk=self.user.pk).update(date_joined=timezone.now() - timedelta(days=1))
        self.client.credentials(HTTP_AUTHORIZATION="Token " + Token.objects.create(user=self.user).key)

    def put(self, data):
        return self.client.put("/api/progress/", {"data": data}, format="json")

    def test_requires_login(self):
        self.client.credentials()
        self.assertEqual(self.client.get("/api/progress/").status_code, status.HTTP_401_UNAUTHORIZED)

    def test_empty_progress(self):
        response = self.client.get("/api/progress/")
        self.assertEqual(response.status_code, 200)
        self.assertIsNone(response.data["data"])
        self.assertEqual(response.data["summary"]["level"], 1)
        self.assertFalse(response.data["summary"]["has_started"])

    def test_save_and_load_round_trip(self):
        response = self.put(make_save(seconds=1500, xp=300))
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["summary"]["level"], 3)
        loaded = self.client.get("/api/progress/").data
        self.assertEqual(loaded["data"]["seconds"], 1500)
        self.assertEqual(loaded["summary"]["study_seconds"], 1500)

    def test_users_cannot_see_each_others_saves(self):
        self.put(make_save(seconds=600, xp=100))
        other = User.objects.create_user("kabir", password="village-pass-123")
        self.client.credentials(HTTP_AUTHORIZATION="Token " + Token.objects.create(user=other).key)
        self.assertIsNone(self.client.get("/api/progress/").data["data"])

    def test_rejects_inflated_xp(self):
        response = self.put(make_save(seconds=600, xp=99999))
        self.assertEqual(response.status_code, 400)
        self.assertIn("XP", response.data["detail"])

    def test_rejects_more_study_than_real_time(self):
        response = self.put(make_save(seconds=3 * 86400, xp=100))
        self.assertEqual(response.status_code, 400)
        self.assertIn("real time", response.data["detail"])

    def test_rejects_time_going_backwards(self):
        self.put(make_save(seconds=1200, xp=200))
        response = self.put(make_save(seconds=600, xp=100))
        self.assertEqual(response.status_code, 400)

    def test_rejects_totals_that_dont_add_up(self):
        data = make_save(seconds=600, xp=100)
        data["days"] = {"2026-11-09": 60}
        self.assertEqual(self.put(data).status_code, 400)

    def test_rejects_non_object(self):
        self.assertEqual(self.put([1, 2, 3]).status_code, 400)

    def test_erase_restarts_the_clock(self):
        self.put(make_save(seconds=1200, xp=200))
        self.assertEqual(self.client.delete("/api/progress/").status_code, 204)
        self.assertIsNone(self.client.get("/api/progress/").data["data"])
        # A new journey starts from zero...
        self.assertEqual(self.put(make_save()).status_code, 200)
        # ...and can't claim the study time from before the erase.
        self.assertEqual(self.put(make_save(seconds=3600, xp=600)).status_code, 400)
        self.assertEqual(GameSave.objects.count(), 1)
