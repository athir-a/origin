import { Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

// Frontend protection: redirects logged-out visitors to /login.
// IMPORTANT: this is only a UX nicety. The real security lives in Django —
// every API endpoint behind IsAuthenticated rejects requests without a valid
// token, so even someone who hand-crafts requests can not reach the data.
export default function ProtectedRoute({ children }) {
  const { user, loading } = useAuth();

  if (loading) {
    return <div className="loading-screen">Loading your village…</div>;
  }
  if (!user) {
    return <Navigate to="/login" replace />;
  }
  return children;
}
