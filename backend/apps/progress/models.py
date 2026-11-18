"""One saved journey per user.

The Godot game owns the shape of the save (see Origin/scripts/origin/state.gd).
We store it as JSON so the game can evolve without a migration for every new
flag, and validate the parts that matter (time and XP) in rules.py.
"""

from django.conf import settings
from django.db import models


class GameSave(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="game_save"
    )
    data = models.JSONField(default=dict)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"GameSave({self.user})"
