import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import VillageScene from "../components/VillageScene";
import { useAuth } from "../context/AuthContext";
import { api } from "../services/api";
import "./dashboard.css";

function formatStudyTime(seconds) {
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return minutes + "m";
  return Math.floor(minutes / 60) + "h " + (minutes % 60) + "m";
}

// Stats come from Django (/api/progress/), which derives them from the saved game.
function statsFrom(summary) {
  return [
    { label: "Level", value: summary ? String(summary.level) : "…" },
    { label: "XP", value: summary ? String(summary.xp) : "…" },
    { label: "Study time", value: summary ? formatStudyTime(summary.study_seconds) : "…" },
    { label: "Study days", value: summary ? String(summary.study_days) : "…" },
  ];
}

// Studying, progress, history and achievements all live inside the game
// (the journal opens with J). Profile and settings are still to come.
const ACTIONS = [
  { icon: "📚", label: "Start Studying", to: "/village" },
  { icon: "🏘️", label: "Village", to: "/village" },
  { icon: "📈", label: "My Progress", to: "/village", hint: "Journal (J)" },
  { icon: "🗓️", label: "Study History", to: "/village", hint: "Journal (J)" },
  { icon: "🏅", label: "Achievements", to: "/village", hint: "Journal (J)" },
  { icon: "👤", label: "Profile" },
  { icon: "⚙️", label: "Settings" },
];

export default function Dashboard() {
  const { user, logout } = useAuth();
  const [notice, setNotice] = useState("");
  const [backend, setBackend] = useState("checking"); // checking | up | down
  const [summary, setSummary] = useState(null);
  const navigate = useNavigate();

  // The demo round trip: React asks Django "are you awake?", which makes
  // Django touch the database. If this succeeds, the whole stack works.
  useEffect(() => {
    api
      .get("/health/")
      .then(() => setBackend("up"))
      .catch(() => setBackend("down"));
    api
      .get("/progress/")
      .then((data) => setSummary(data.summary))
      .catch(() => {});
  }, []);

  function handleAction(action) {
    if (action.to) navigate(action.to);
    else setNotice('"' + action.label + '" — this part of Origin is still being built.');
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
          <button className="village-enter" onClick={() => navigate("/village")} title="Enter the village">
            <VillageScene />
          </button>
          <p className="card-note">
            Where your story starts. The village will grow as you do.
          </p>
        </section>

        <section className="card progress-card">
          <h2>Your Journey</h2>
          <div className="stats-grid">
            {statsFrom(summary).map((s) => (
              <div className="stat" key={s.label}>
                <span className="stat-value">{s.value}</span>
                <span className="stat-label">{s.label}</span>
              </div>
            ))}
          </div>
          <p className="card-note">
            {summary && !summary.has_started
              ? "Your journey hasn't started yet. Head to the village to begin."
              : summary
                ? summary.xp_into_level + " / " + summary.xp_for_next_level + " XP to the next level · " + summary.achievements + " achievements"
                : "Loading your journey…"}
          </p>
        </section>

        <section className="card actions-card">
          <h2>What would you like to do?</h2>
          <div className="actions-grid">
            {ACTIONS.map((a) => (
              <button
                key={a.label}
                className="action"
                onClick={() => handleAction(a)}
              >
                <span className="action-icon">{a.icon}</span>
                <span className="action-label">{a.label}</span>
                <span className="action-badge">{a.to ? a.hint || "open" : "soon"}</span>
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
