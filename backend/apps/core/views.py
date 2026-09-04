"""The "demo" endpoint: proof that React -> Django -> database works."""

from django.db import connection
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response


@api_view(["GET"])
@permission_classes([AllowAny])
def health(request):
    """Run a trivial query so the database is genuinely touched.

    If this endpoint responds, then the browser talked to Django,
    and Django talked to SQLite. The whole stack is alive.
    """
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
        cursor.fetchone()
    return Response({"status": "ok", "message": "The village is awake."})
