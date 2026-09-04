"""Top-level URL table: every request URL is matched here first."""

from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include("apps.core.urls")),       # public demo endpoints
    path("api/auth/", include("apps.users.urls")), # signup / login / logout / me
]
