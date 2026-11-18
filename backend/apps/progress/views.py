"""The game's save slot, stored per user.

GET    /api/progress/  -> {"data": <save or null>, "summary": {...}}
PUT    /api/progress/  body {"data": <save>} -> validated, stored, summary returned
DELETE /api/progress/  -> erase the journey (the game's "Erase save" option)

Each user can only ever reach their own row: the save is looked up from
request.user (the token), never from an ID in the URL.
"""

import json

from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import GameSave
from .rules import summarize, validate_save

MAX_SAVE_BYTES = 512 * 1024


@api_view(["GET", "PUT", "DELETE"])
def progress(request):
    save = GameSave.objects.filter(user=request.user).first()

    if request.method == "GET":
        data = save.data if save and save.data else None
        return Response({"data": data, "summary": summarize(data or {})})

    if request.method == "DELETE":
        # Keep the row with an empty save rather than deleting it: its fresh
        # updated_at is the "clock start" for the next journey, so erasing
        # can't be used to claim study time from before the erase.
        GameSave.objects.update_or_create(user=request.user, defaults={"data": {}})
        return Response(status=status.HTTP_204_NO_CONTENT)

    data = request.data.get("data") if isinstance(request.data, dict) else None
    if len(json.dumps(data)) > MAX_SAVE_BYTES:
        return Response({"detail": "Save is too large."}, status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE)

    if save:
        previous_seconds = save.data.get("seconds", 0)
        since = save.updated_at
    else:
        previous_seconds = 0
        since = request.user.date_joined
    elapsed = (timezone.now() - since).total_seconds()

    errors = validate_save(data, previous_seconds, elapsed)
    if errors:
        return Response({"detail": " ".join(errors)}, status=status.HTTP_400_BAD_REQUEST)

    if save:
        save.data = data
        save.save()
    else:
        GameSave.objects.create(user=request.user, data=data)
    return Response({"summary": summarize(data)})
