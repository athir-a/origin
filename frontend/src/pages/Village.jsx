import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../services/api";
import "./village.css";

// The Godot game (Origin/) is exported to frontend/public/game/ and runs in
// an iframe. Its OriginState autoload looks for window.parent.originBridge;
// when present, the save lives on the user's account (Django /api/progress/)
// instead of in browser storage.
//
// Bridge contract (called synchronously from GDScript via JavaScriptBridge):
//   loadSave()       -> save JSON string, or "" for a new player
//   saveGame(text)   -> the game saved; we debounce and PUT it to Django
//   resetSave()      -> the player erased or restarted their journey

const SAVE_DELAY_MS = 1500;
const GAME_URL = "/game/index.html";

async function gameIsBuilt() {
  // Vite answers unknown paths with index.html, so check the type, not just the status.
  try {
    const res = await fetch("/game/index.pck", { method: "HEAD" });
    return res.ok && !(res.headers.get("content-type") || "").includes("text/html");
  } catch {
    return false;
  }
}

export default function Village() {
  const [phase, setPhase] = useState("loading"); // loading | ready | missing | error
  const [saveState, setSaveState] = useState("idle"); // idle | saving | saved | error
  const [saveError, setSaveError] = useState("");
  const [loadError, setLoadError] = useState("");
  const flushRef = useRef(() => {});

  useEffect(() => {
    let cancelled = false;
    let current = "";
    let dirty = false;
    let timer = null;
    let chain = Promise.resolve(); // keep PUT/DELETE in order

    const enqueue = (task) => {
      chain = chain.then(task).catch((err) => {
        setSaveState("error");
        setSaveError(err.message);
      });
      return chain;
    };

    const flush = () => {
      clearTimeout(timer);
      timer = null;
      if (!dirty) return;
      dirty = false;
      const data = JSON.parse(current);
      enqueue(async () => {
        await api.put("/progress/", { data });
        setSaveState("saved");
        setSaveError("");
      });
    };
    flushRef.current = flush;

    const bridge = {
      loadSave: () => current,
      saveGame: (text) => {
        current = text;
        dirty = true;
        setSaveState("saving");
        clearTimeout(timer);
        timer = setTimeout(flush, SAVE_DELAY_MS);
      },
      resetSave: () => {
        current = "";
        dirty = false;
        clearTimeout(timer);
        enqueue(() => api.del("/progress/"));
      },
    };

    // Closing the tab: send what we have right away; keepalive lets it finish.
    const onPageHide = () => {
      if (!dirty) return;
      dirty = false;
      api.put("/progress/", { data: JSON.parse(current) }, { keepalive: true }).catch(() => {});
    };

    (async () => {
      if (!(await gameIsBuilt())) {
        if (!cancelled) setPhase("missing");
        return;
      }
      try {
        const res = await api.get("/progress/");
        if (cancelled) return;
        current = res.data ? JSON.stringify(res.data) : "";
        // Must exist before the iframe boots: the game reads it on startup.
        window.originBridge = bridge;
        window.addEventListener("pagehide", onPageHide);
        setPhase("ready");
      } catch (err) {
        if (!cancelled) {
          setLoadError(err.message);
          setPhase("error");
        }
      }
    })();

    return () => {
      cancelled = true;
      flush(); // leaving for the dashboard: save now instead of waiting
      window.removeEventListener("pagehide", onPageHide);
      if (window.originBridge === bridge) delete window.originBridge;
    };
  }, []);

  return (
    <div className="village-page">
      <header className="village-bar">
        <Link to="/dashboard" className="btn-ghost" onClick={() => flushRef.current()}>
          ← Dashboard
        </Link>
        <span className="logo">ORIGIN</span>
        <span className={"save-state save-" + saveState} title={saveError}>
          {saveState === "saving" && "Saving…"}
          {saveState === "saved" && "Saved to your account"}
          {saveState === "error" && "Not saved: " + saveError}
        </span>
      </header>

      <main className="village-stage">
        {phase === "loading" && <p className="village-msg">Walking to the village…</p>}
        {phase === "error" && (
          <p className="village-msg">Couldn't load your journey: {loadError}</p>
        )}
        {phase === "missing" && (
          <div className="village-msg">
            <p>The game hasn't been built yet.</p>
            <p>
              Open <code>Origin/project.godot</code> in Godot 4.7, then{" "}
              <em>Project → Export → Web → Export Project</em>. It writes to{" "}
              <code>frontend/public/game/</code>. Reload this page afterwards.
            </p>
          </div>
        )}
        {phase === "ready" && (
          <iframe className="village-frame" src={GAME_URL} title="Origin village" allow="autoplay; fullscreen" />
        )}
      </main>
    </div>
  );
}
