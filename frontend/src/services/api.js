// api.js — the ONLY file in the frontend that talks to Django.
// Every page goes through this helper instead of calling fetch directly.
// Keeping all networking in one place means auth headers and error handling
// are written once, not repeated in every component.

const API_BASE = "/api";

// The token lives in localStorage so the browser remembers it across refreshes.
function getToken() {
  return localStorage.getItem("origin_token");
}

function setToken(token) {
  if (token) localStorage.setItem("origin_token", token);
  else localStorage.removeItem("origin_token");
}

// DRF sends errors in two shapes: {detail: "..."} for whole-request errors,
// or {field1: ["msg", ...]} for form validation. Turn both into one readable
// string the UI can show the user.
function errorMessage(data) {
  if (!data) return "Something went wrong. Please try again.";
  if (typeof data === "string") return data;
  if (data.detail) return data.detail;
  const parts = Object.entries(data).map(([field, messages]) => {
    const msgs = Array.isArray(messages) ? messages : [messages];
    return `${field}: ${msgs.join(" ")}`;
  });
  return parts.join(" ") || "Something went wrong. Please try again.";
}

async function request(path, { method = "GET", body, keepalive = false } = {}) {
  const headers = { "Content-Type": "application/json" };
  const token = getToken();
  if (token) headers["Authorization"] = `Token ${token}`;

  const response = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
    // keepalive lets a final save finish even while the page is closing.
    keepalive,
  });

  let data = null;
  try {
    data = await response.json();
  } catch {
    // No JSON body — e.g. the 204 "No Content" we get after logout.
  }

  if (!response.ok) {
    throw new Error(errorMessage(data));
  }
  return data;
}

export const api = {
  get: (path) => request(path),
  post: (path, body) => request(path, { method: "POST", body }),
  put: (path, body, options = {}) => request(path, { method: "PUT", body, ...options }),
  del: (path) => request(path, { method: "DELETE" }),
};

export { getToken, setToken };
