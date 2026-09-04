import { useState } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import "./auth.css";

// Login page: collects username + password, asks Django to verify them,
// and stores the token it gets back (via AuthContext.login).
export default function Login() {
  const { user, login } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ username: "", password: "" });
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  // Already logged in? Nothing to do here.
  if (user) return <Navigate to="/dashboard" replace />;

  function handleChange(e) {
    setForm({ ...form, [e.target.name]: e.target.value });
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");
    setSubmitting(true);
    try {
      await login(form.username, form.password);
      navigate("/dashboard");
    } catch (err) {
      setError(err.message); // e.g. "Invalid username or password."
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="auth-page">
      <form className="auth-card" onSubmit={handleSubmit}>
        <h1 className="logo">ORIGIN</h1>
        <p className="tagline">Welcome back, traveler.</p>

        {error && <div className="error-banner">{error}</div>}

        <label htmlFor="username">Username</label>
        <input
          id="username"
          name="username"
          value={form.username}
          onChange={handleChange}
          autoComplete="username"
          autoFocus
          required
        />

        <label htmlFor="password">Password</label>
        <input
          id="password"
          name="password"
          type="password"
          value={form.password}
          onChange={handleChange}
          autoComplete="current-password"
          required
        />

        <button className="btn-primary" type="submit" disabled={submitting}>
          {submitting ? "Opening the gates…" : "Enter the village"}
        </button>

        <p className="auth-switch">
          New here? <Link to="/signup">Begin your story</Link>
        </p>
      </form>
    </div>
  );
}
