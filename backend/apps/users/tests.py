"""Tests for the auth API.

Each test creates a clean database, makes a request through the test client,
and asserts on the response. Run with: python manage.py test
"""

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

User = get_user_model()


class SignupTests(APITestCase):
    def test_signup_creates_user_and_token(self):
        response = self.client.post(
            "/api/auth/signup/",
            {
                "username": "buffy",
                "email": "buffy@example.com",
                "password": "village-pass-123",
                "password2": "village-pass-123",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(User.objects.filter(username="buffy").exists())
        self.assertIn("token", response.data)
        self.assertEqual(response.data["user"]["username"], "buffy")
        # The password must be stored hashed, never in plaintext.
        user = User.objects.get(username="buffy")
        self.assertNotEqual(user.password, "village-pass-123")

    def test_signup_rejects_mismatched_passwords(self):
        response = self.client.post(
            "/api/auth/signup/",
            {
                "username": "buffy",
                "password": "village-pass-123",
                "password2": "different-pass-456",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_signup_rejects_duplicate_username(self):
        User.objects.create_user(username="buffy", password="village-pass-123")
        response = self.client.post(
            "/api/auth/signup/",
            {
                "username": "buffy",
                "password": "village-pass-123",
                "password2": "village-pass-123",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("username", response.data)


class LoginTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="buffy", password="village-pass-123"
        )

    def test_login_returns_token_for_valid_credentials(self):
        response = self.client.post(
            "/api/auth/login/",
            {"username": "buffy", "password": "village-pass-123"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("token", response.data)
        self.assertEqual(response.data["user"]["username"], "buffy")

    def test_login_rejects_wrong_password(self):
        response = self.client.post(
            "/api/auth/login/",
            {"username": "buffy", "password": "wrong-password"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class MeTests(APITestCase):
    def test_me_requires_token(self):
        # No Authorization header -> Django must refuse, even though the
        # frontend would normally hide this page. This is backend security.
        response = self.client.get("/api/auth/me/")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_me_returns_current_user(self):
        user = User.objects.create_user(username="buffy", password="village-pass-123")
        token = Token.objects.create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        response = self.client.get("/api/auth/me/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["username"], "buffy")


class LogoutTests(APITestCase):
    def test_logout_invalidates_token(self):
        user = User.objects.create_user(username="buffy", password="village-pass-123")
        token = Token.objects.create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

        response = self.client.post("/api/auth/logout/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Token.objects.filter(key=token.key).exists())

        # The same token must no longer work.
        response = self.client.get("/api/auth/me/")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
