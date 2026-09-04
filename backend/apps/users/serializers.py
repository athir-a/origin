"""Serializers: the translators between JSON (over the wire) and Django data.

A serializer decides:
  - which fields the API accepts / returns,
  - how incoming JSON is validated,
  - how validated data becomes a database object (and back).
"""

from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    """What a user looks like when sent to the frontend.

    NEVER return the password hash — only safe public fields.
    """

    class Meta:
        model = User
        fields = ["id", "username", "email", "date_joined"]
        read_only_fields = fields


class SignupSerializer(serializers.Serializer):
    """Validates a signup form and creates the user."""

    username = serializers.CharField(max_length=150)
    email = serializers.EmailField(required=False, allow_blank=True)
    password = serializers.CharField(write_only=True, min_length=8)
    password2 = serializers.CharField(write_only=True)

    def validate_username(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("This username is already taken.")
        return value

    def validate_password(self, value):
        # Django's built-in password rules (length, not common, not all digits...)
        validate_password(value)
        return value

    def validate(self, attrs):
        if attrs["password"] != attrs["password2"]:
            raise serializers.ValidationError({"password2": "Passwords do not match."})
        return attrs

    def create(self, validated_data):
        validated_data.pop("password2")
        # create_user hashes the password — plaintext never touches the database.
        return User.objects.create_user(**validated_data)


class LoginSerializer(serializers.Serializer):
    """Checks credentials and hands back the matching user object."""

    username = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        user = authenticate(username=attrs["username"], password=attrs["password"])
        if user is None:
            raise serializers.ValidationError("Invalid username or password.")
        return {"user": user}
