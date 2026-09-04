import { createContext, useCallback, useContext, useEffect, useState } from "react";
import { api, getToken, setToken } from "../services/api";

// AuthContext holds the single source of truth for "who is logged in".
// Components read it via useAuth(); only the functions below ever change it.
const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true); // true while we verify a saved token

  // On page load: if a token exists, ask Django who it belongs to.
  // This is what makes a refresh keep you logged in.
  useEffect(() => {
    const token = getToken();
    if (!token) {
      setLoading(false);
      return;
    }
    api
      .get("/auth/me/")
      .then((data) => setUser(data))
      .catch(() => setToken(null)) // stale or invalid token — discard it
      .finally(() => setLoading(false));
  }, []);

  const login = useCallback(async (username, password) => {
    const data = await api.post("/auth/login/", { username, password });
    setToken(data.token);
    setUser(data.user);
    return data.user;
  }, []);

  const signup = useCallback(async (form) => {
    const data = await api.post("/auth/signup/", form);
    setToken(data.token);
    setUser(data.user);
    return data.user;
  }, []);

  const logout = useCallback(async () => {
    try {
      await api.post("/auth/logout/", {});
    } catch {
      // Even if the server call fails (server down), log out locally.
    }
    setToken(null);
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider value={{ user, loading, login, signup, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
