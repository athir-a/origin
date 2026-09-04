// A tiny pixel-art placeholder of the village at night.
// Phase 2 will replace this with a real, data-driven village.
// For now it just establishes Origin's mood: warm lights, a dirt path,
// a house, a tree, and a street lamp — the starting point of the journey.
export default function VillageScene() {
  return (
    <svg viewBox="0 0 400 200" role="img" aria-label="The village at night" shapeRendering="crispEdges">
      {/* night sky */}
      <rect width="400" height="105" fill="#1d2137" />
      {/* stars */}
      <rect x="30" y="18" width="3" height="3" fill="#f5e9d3" />
      <rect x="70" y="40" width="2" height="2" fill="#f5e9d3" />
      <rect x="120" y="14" width="3" height="3" fill="#f2a33c" />
      <rect x="160" y="48" width="2" height="2" fill="#f5e9d3" />
      <rect x="210" y="20" width="3" height="3" fill="#f5e9d3" />
      <rect x="260" y="52" width="2" height="2" fill="#f2a33c" />
      <rect x="300" y="16" width="3" height="3" fill="#f5e9d3" />
      <rect x="360" y="44" width="2" height="2" fill="#f5e9d3" />
      {/* moon */}
      <rect x="330" y="14" width="18" height="18" fill="#f2d98b" transform="rotate(45 339 23)" />
      {/* distant hills */}
      <rect x="0" y="95" width="400" height="10" fill="#2f4a2f" />
      {/* ground */}
      <rect x="0" y="105" width="400" height="95" fill="#2e2418" />
      {/* dirt path */}
      <rect x="182" y="105" width="36" height="95" fill="#6b4f35" />
      <rect x="194" y="105" width="12" height="95" fill="#8a6a4a" />
      {/* grass tufts */}
      <rect x="20" y="120" width="8" height="3" fill="#3f5a34" />
      <rect x="330" y="128" width="8" height="3" fill="#3f5a34" />
      <rect x="60" y="150" width="8" height="3" fill="#3f5a34" />
      <rect x="290" y="160" width="8" height="3" fill="#3f5a34" />
      {/* house */}
      <polygon points="55,92 95,66 135,92" fill="#8b3a2f" />
      <rect x="60" y="92" width="70" height="48" fill="#7a4a2b" />
      <rect x="70" y="104" width="16" height="16" fill="#ffd97a" />
      <rect x="70" y="104" width="16" height="3" fill="#5c361d" />
      <rect x="70" y="117" width="16" height="3" fill="#5c361d" />
      <rect x="77" y="104" width="3" height="16" fill="#5c361d" />
      <rect x="90" y="118" width="13" height="22" fill="#4a2c17" />
      {/* tree */}
      <rect x="332" y="62" width="10" height="18" fill="#2f6b3f" />
      <rect x="338" y="48" width="18" height="16" fill="#3f8a52" />
      <rect x="326" y="52" width="16" height="14" fill="#2f6b3f" />
      <rect x="330" y="100" width="8" height="40" fill="#4a2c17" />
      {/* street lamp */}
      <rect x="246" y="88" width="5" height="52" fill="#3a3a3a" />
      <rect x="240" y="80" width="17" height="9" fill="#2a2a2a" />
      <rect x="238" y="87" width="21" height="30" fill="#ffd97a" opacity="0.28" />
      <rect x="244" y="96" width="10" height="12" fill="#ffd97a" opacity="0.55" />
    </svg>
  );
}
