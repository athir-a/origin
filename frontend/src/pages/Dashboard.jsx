import { useEffect, useState } from "react";
import VillageScene from "../components/VillageScene";
import { useAuth } from "../context/AuthContext";
import { api } from "../services/api";
import "./dashboard.css";

// Placeholder stats — real progression arrives in Phase 2.
const STATS = [
  { label: "Level", value: "1" },
  { label: "XP", value: "0" },
  { label: "Study time", value: "0h" },
  { label: "Consistency", value: "—" },
];

// Everything except auth is still being built. Clicking one shows an honest
// placeholder instead of pretending the feature exists.
const ACTIONS = [
  { icon: "📚", label: "Start Studying" },
  { icon: "🏘️", label: "Village" },
  { icon: "📈", label: "My Progress" },
  { icon: "🗓️", label: "Study History" },
  { icon: "🏅", label: "Achievements" },
  { icon: "👤", label: "Profile" },
  { icon: "⚙️", label: "Settings" },
];

export default function Dashboard() {
  const { user, logout } = useAuth();
  const [notice, setNotice] = useState("");
  const [backend, setBackend] = useState("checking"); // checking | up | down

  // The demo round trip: React asks Django "are you awake?", which makes
  // Django touch the database. If this succeeds, the whole stack works.
  useEffect(() => {
    api
      .get("/health/")
      .then(() => setBackend("up"))
      .catch(() => setBackend("down"));
  }, []);

  function handleAction(label) {
    setNotice('"' + label + '" — this part of Origin is still being built.');
  }

  return (
    <div className="dashboard">
      <header className="topbar">
        <span className="logo">ORIGIN</span>
        <div className="topbar-right">
          <span className="username">Welcome, {user?.username}</span>
          <button className="btn-ghost" onClick={logout}>
            Log out
          </button>
        </div>
      </header>

      {notice && (
        <div className="notice" onClick={() => setNotice("")}>
          {notice}
        </div>
      )}

      <main className="dashboard-main">
        <section className="card village-card">
          <h2>The Village</h2>
          <VillageScene />
          <p className="card-note">
            Where your story starts. The village will grow as you do.
          </p>
        </section>

        <section className="card progress-card">
          <h2>Your Journey</h2>
          <div className="stats-grid">
            {STATS.map((s) => (
              <div className="stat" key={s.label}>
                <span className="stat-value">{s.value}</span>
                <span className="stat-label">{s.label}</span>
              </div>
            ))}
          </div>
          <p className="card-note">
            These are placeholders for now. Real progress arrives in Phase 2.
          </p>
        </section>

        <section className="card actions-card">
          <h2>What would you like to do?</h2>
          <div className="actions-grid">
            {ACTIONS.map((a) => (
              <button
                key={a.label}
                className="action"
                onClick={() => handleAction(a.label)}
              >
                <span className="action-icon">{a.icon}</span>
                <span className="action-label">{a.label}</span>
                <span className="action-badge">soon</span>
              </button>
            ))}
          </div>
        </section>
      </main>

      <footer className="status-bar">
        {backend === "checking" && "Checking the village…"}
        {backend === "up" && "✅ The village is awake — backend connected."}
        {backend === "down" &&
          "⚠️ Backend unreachable — is Django running? (cd backend && .venv/bin/python manage.py runserver)"}
      </footer>
    </div>
  );
}
