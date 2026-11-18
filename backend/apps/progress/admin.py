from django.contrib import admin

from .models import GameSave


@admin.register(GameSave)
class GameSaveAdmin(admin.ModelAdmin):
    list_display = ("user", "updated_at")
    readonly_fields = ("updated_at",)
