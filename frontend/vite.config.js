import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Vite config: the React dev server.
// The proxy block makes the browser think frontend and backend are the SAME
// origin: any fetch("/api/...") is transparently forwarded to Django on :8000.
// That is why we do not need CORS headers during development.
export default defineConfig({
  plugins: [react()],
  server: {
    // Bind to IPv4 loopback so WSL2's localhost forwarding reaches it from
    // the Windows browser (Node would otherwise prefer IPv6 ::1).
    host: "127.0.0.1",
    proxy: {
      "/api": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
    },
  },
});
