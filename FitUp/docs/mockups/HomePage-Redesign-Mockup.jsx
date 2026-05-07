import { useState } from "react";

const MOCK = {
  user: { name: "Scotty", initials: "SO" },
  period: "D",
  margin: "+1,782",
  marginSign: "positive",
  status: "WINNING TODAY",
  opponent: { initials: "BA", name: "BadB" },
  leading: "2 / 3 matches",
  closest: "+220",
  stats: [
    { label: "Winning", value: "2", color: "win" },
    { label: "Losing", value: "1", color: "lose" },
    { label: "Closest Lead", value: "+220", color: "lead" },
    { label: "Closest Deficit", value: "−150", color: "deficit" },
  ],
  activeBattles: [
    {
      initials: "BA",
      name: "BadB",
      avatarColor: "#e8732a",
      dayStatus: "Ahead today",
      margin: "+1,782",
      marginSign: "positive",
      metric: "steps",
      updated: "Updated 3h ago",
      cta: "Push lead",
    },
    {
      initials: "MR",
      name: "MikeR",
      avatarColor: "#c94cdb",
      dayStatus: "Behind today",
      margin: "−150",
      marginSign: "negative",
      metric: "steps",
      updated: "Updated 12m ago",
      cta: "Catch up",
    },
  ],
  pendingBattles: [
    { type: "searching", label: "Searching for opponent…", sub: "Matchmaking active" },
    { type: "pending", label: "Invite sent to JakeT", sub: "Waiting on response" },
    { type: "upcoming", label: "Match vs RoboRun starts tomorrow", sub: "6:00 AM" },
  ],
};

const TEAL = "#00e5c8";
const GREEN = "#39ff5a";
const DARK_BG = "#08090f";
const CARD_BG = "rgba(255,255,255,0.05)";
const CARD_BORDER = "rgba(255,255,255,0.09)";

const avatarRing = (color) => ({
  width: 38,
  height: 38,
  borderRadius: "50%",
  background: color,
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  fontSize: 13,
  fontWeight: 700,
  color: "#fff",
  letterSpacing: "0.03em",
  flexShrink: 0,
  border: `2px solid rgba(255,255,255,0.15)`,
});

function PeriodPill({ period, setPeriod }) {
  const opts = ["D", "W", "M"];
  return (
    <div style={{
      display: "flex",
      background: "rgba(255,255,255,0.08)",
      borderRadius: 20,
      padding: 3,
      gap: 2,
    }}>
      {opts.map((o) => (
        <button
          key={o}
          onClick={() => setPeriod(o)}
          style={{
            background: period === o ? TEAL : "transparent",
            color: period === o ? "#08090f" : "rgba(255,255,255,0.55)",
            border: "none",
            borderRadius: 16,
            padding: "4px 12px",
            fontSize: 12,
            fontWeight: 700,
            cursor: "pointer",
            transition: "all 0.18s",
            letterSpacing: "0.04em",
          }}
        >
          {o}
        </button>
      ))}
    </div>
  );
}

function BattleRing({ margin, status, opponent }) {
  const ringSize = 220;
  const stroke = 12;
  const r = (ringSize - stroke) / 2;
  const circ = 2 * Math.PI * r;
  const fillPct = 0.72;

  return (
    <div style={{
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      position: "relative",
      marginTop: 10,
      marginBottom: 8,
    }}>
      <div style={{ position: "relative", width: ringSize, height: ringSize }}>
        <svg
          width={ringSize}
          height={ringSize}
          viewBox={`0 0 ${ringSize} ${ringSize}`}
          style={{ display: "block" }}
        >
          <defs>
            <filter id="glow">
              <feGaussianBlur stdDeviation="4" result="blur" />
              <feMerge>
                <feMergeNode in="blur" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
          </defs>
          {/* Track */}
          <circle
            cx={ringSize / 2}
            cy={ringSize / 2}
            r={r}
            fill="none"
            stroke="rgba(255,255,255,0.07)"
            strokeWidth={stroke}
          />
          {/* Progress arc */}
          <circle
            cx={ringSize / 2}
            cy={ringSize / 2}
            r={r}
            fill="none"
            stroke={TEAL}
            strokeWidth={stroke}
            strokeLinecap="round"
            strokeDasharray={`${circ * fillPct} ${circ * (1 - fillPct)}`}
            strokeDashoffset={circ * 0.25}
            filter="url(#glow)"
            style={{ transition: "stroke-dasharray 0.6s ease" }}
          />
          {/* Opponent tick */}
          <circle
            cx={ringSize / 2}
            cy={ringSize / 2}
            r={r}
            fill="none"
            stroke={GREEN}
            strokeWidth={stroke}
            strokeLinecap="round"
            strokeDasharray={`3 ${circ - 3}`}
            strokeDashoffset={circ * 0.25 - circ * (fillPct - 0.008)}
            opacity={0.9}
          />
        </svg>

        {/* Center content */}
        <div style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: 0,
        }}>
          <div style={{
            fontSize: 38,
            fontWeight: 800,
            color: "#fff",
            letterSpacing: "-0.02em",
            lineHeight: 1.1,
          }}>
            {margin}
          </div>
          <div style={{
            fontSize: 11,
            fontWeight: 700,
            color: "rgba(255,255,255,0.45)",
            letterSpacing: "0.12em",
            marginTop: 3,
          }}>
            STEPS
          </div>
          <div style={{
            fontSize: 10,
            fontWeight: 700,
            color: TEAL,
            letterSpacing: "0.1em",
            marginTop: 2,
          }}>
            {status}
          </div>
        </div>

        {/* Opponent badge */}
        <div style={{
          position: "absolute",
          bottom: -12,
          left: "50%",
          transform: "translateX(-50%)",
          display: "flex",
          alignItems: "center",
          gap: 6,
          background: "rgba(18,20,30,0.95)",
          border: `1px solid rgba(255,255,255,0.12)`,
          borderRadius: 20,
          padding: "4px 10px 4px 5px",
        }}>
          <div style={{
            ...avatarRing(opponent.avatarColor || "#e8732a"),
            width: 22,
            height: 22,
            fontSize: 9,
          }}>
            {opponent.initials}
          </div>
          <span style={{ fontSize: 12, fontWeight: 600, color: "#fff" }}>
            {opponent.name}
          </span>
        </div>
      </div>

      {/* Sub-ring label */}
      <div style={{ marginTop: 28, textAlign: "center" }}>
        <span style={{ fontSize: 13, color: "rgba(255,255,255,0.65)", fontWeight: 500 }}>
          Leading <span style={{ color: "#fff", fontWeight: 700 }}>{MOCK.leading}</span>
          {"  ·  "}
          <span style={{ color: GREEN }}>Closest: {MOCK.closest}</span>
        </span>
      </div>
    </div>
  );
}

function BattleStatusStrip() {
  return (
    <div style={{
      margin: "14px 0 0",
      background: "rgba(0,229,200,0.07)",
      border: "1px solid rgba(0,229,200,0.2)",
      borderRadius: 14,
      padding: "10px 14px",
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      gap: 10,
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        <span style={{
          width: 8,
          height: 8,
          borderRadius: "50%",
          background: TEAL,
          display: "inline-block",
          animation: "pulse 1.6s infinite",
          flexShrink: 0,
        }} />
        <span style={{ fontSize: 13, color: "rgba(255,255,255,0.85)", fontWeight: 500 }}>
          Searching for opponent…
        </span>
      </div>
      <div style={{
        background: "rgba(0,229,200,0.15)",
        borderRadius: 10,
        padding: "3px 9px",
        fontSize: 11,
        fontWeight: 700,
        color: TEAL,
        letterSpacing: "0.02em",
        whiteSpace: "nowrap",
      }}>
        2 pending invites
      </div>
    </div>
  );
}

function StatCards({ stats }) {
  const colors = {
    win: { bg: "rgba(57,255,90,0.10)", border: "rgba(57,255,90,0.22)", text: GREEN },
    lose: { bg: "rgba(255,70,70,0.10)", border: "rgba(255,70,70,0.22)", text: "#ff5555" },
    lead: { bg: "rgba(0,229,200,0.10)", border: "rgba(0,229,200,0.22)", text: TEAL },
    deficit: { bg: "rgba(255,150,50,0.10)", border: "rgba(255,150,50,0.22)", text: "#ff9c38" },
  };
  return (
    <div style={{
      display: "grid",
      gridTemplateColumns: "repeat(4,1fr)",
      gap: 8,
      marginTop: 14,
    }}>
      {stats.map((s) => {
        const c = colors[s.color];
        return (
          <div key={s.label} style={{
            background: c.bg,
            border: `1px solid ${c.border}`,
            borderRadius: 12,
            padding: "10px 8px 8px",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 2,
          }}>
            <div style={{ fontSize: 16, fontWeight: 800, color: c.text, letterSpacing: "-0.01em" }}>
              {s.value}
            </div>
            <div style={{
              fontSize: 9,
              fontWeight: 600,
              color: "rgba(255,255,255,0.45)",
              letterSpacing: "0.06em",
              textAlign: "center",
              lineHeight: 1.3,
            }}>
              {s.label.toUpperCase()}
            </div>
          </div>
        );
      })}
    </div>
  );
}

function ActiveBattleRow({ battle }) {
  const isPos = battle.marginSign === "positive";
  return (
    <div style={{
      background: CARD_BG,
      border: `1px solid ${CARD_BORDER}`,
      borderRadius: 14,
      padding: "12px 14px",
      display: "flex",
      alignItems: "center",
      gap: 12,
    }}>
      <div style={avatarRing(battle.avatarColor)}>
        {battle.initials}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 2 }}>
          <span style={{ fontSize: 14, fontWeight: 700, color: "#fff" }}>{battle.name}</span>
          <span style={{
            fontSize: 10,
            fontWeight: 600,
            color: isPos ? GREEN : "#ff5555",
            background: isPos ? "rgba(57,255,90,0.12)" : "rgba(255,70,70,0.12)",
            borderRadius: 6,
            padding: "2px 6px",
            letterSpacing: "0.03em",
          }}>
            {battle.dayStatus}
          </span>
        </div>
        <div style={{ fontSize: 11, color: "rgba(255,255,255,0.38)", fontWeight: 500 }}>
          {battle.updated}
        </div>
      </div>
      <div style={{ textAlign: "right", flexShrink: 0 }}>
        <div style={{
          fontSize: 20,
          fontWeight: 800,
          color: isPos ? GREEN : "#ff5555",
          letterSpacing: "-0.02em",
          lineHeight: 1.1,
        }}>
          {battle.margin}
        </div>
        <div style={{ fontSize: 10, color: "rgba(255,255,255,0.35)", fontWeight: 600, letterSpacing: "0.06em" }}>
          {battle.metric.toUpperCase()}
        </div>
        <button style={{
          marginTop: 4,
          background: isPos ? "rgba(0,229,200,0.15)" : "rgba(255,150,50,0.15)",
          border: `1px solid ${isPos ? "rgba(0,229,200,0.3)" : "rgba(255,150,50,0.3)"}`,
          borderRadius: 8,
          padding: "3px 9px",
          fontSize: 10,
          fontWeight: 700,
          color: isPos ? TEAL : "#ff9c38",
          cursor: "pointer",
          letterSpacing: "0.03em",
        }}>
          {battle.cta}
        </button>
      </div>
    </div>
  );
}

function PendingRow({ item }) {
  const icons = {
    searching: { icon: "⌾", color: TEAL, bg: "rgba(0,229,200,0.08)", border: "rgba(0,229,200,0.15)", pulse: true },
    pending: { icon: "◔", color: "#ff9c38", bg: "rgba(255,150,50,0.08)", border: "rgba(255,150,50,0.15)", pulse: false },
    upcoming: { icon: "◈", color: "#9f8bfc", bg: "rgba(130,100,255,0.08)", border: "rgba(130,100,255,0.15)", pulse: false },
  };
  const cfg = icons[item.type];
  return (
    <div style={{
      display: "flex",
      alignItems: "center",
      gap: 12,
      background: cfg.bg,
      border: `1px solid ${cfg.border}`,
      borderRadius: 12,
      padding: "10px 14px",
    }}>
      <div style={{
        width: 32,
        height: 32,
        borderRadius: "50%",
        border: `1.5px solid ${cfg.color}`,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: 15,
        color: cfg.color,
        flexShrink: 0,
        opacity: cfg.pulse ? 1 : 0.9,
      }}>
        {cfg.icon}
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 13, fontWeight: 600, color: "rgba(255,255,255,0.85)" }}>
          {item.label}
        </div>
        <div style={{ fontSize: 11, color: "rgba(255,255,255,0.38)", marginTop: 1 }}>
          {item.sub}
        </div>
      </div>
    </div>
  );
}

function SectionLabel({ children }) {
  return (
    <div style={{
      fontSize: 11,
      fontWeight: 700,
      color: "rgba(255,255,255,0.35)",
      letterSpacing: "0.1em",
      marginBottom: 8,
      marginTop: 18,
    }}>
      {children}
    </div>
  );
}

function TabBar() {
  const [active, setActive] = useState("home");
  const tabs = [
    { id: "home", icon: "⌂", label: "Home" },
    { id: "health", icon: "♡", label: "Health" },
    { id: "battle", icon: "⚔", label: "Battle", highlight: true },
    { id: "ranks", icon: "☆", label: "Ranks" },
    { id: "profile", icon: "◎", label: "Profile" },
  ];
  return (
    <div style={{
      position: "sticky",
      bottom: 0,
      background: "rgba(10,11,18,0.92)",
      backdropFilter: "blur(16px)",
      borderTop: "1px solid rgba(255,255,255,0.08)",
      display: "flex",
      alignItems: "center",
      padding: "10px 6px 22px",
      gap: 0,
      zIndex: 10,
    }}>
      {tabs.map((t) => {
        const isActive = active === t.id;
        return (
          <button
            key={t.id}
            onClick={() => setActive(t.id)}
            style={{
              flex: 1,
              background: isActive && t.highlight
                ? "rgba(0,229,200,0.18)"
                : "transparent",
              border: "none",
              borderRadius: 14,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              gap: 3,
              padding: "6px 4px",
              cursor: "pointer",
              transition: "all 0.15s",
            }}
          >
            <span style={{
              fontSize: 18,
              color: isActive ? (t.highlight ? TEAL : "#fff") : "rgba(255,255,255,0.35)",
            }}>
              {t.icon}
            </span>
            <span style={{
              fontSize: 9,
              fontWeight: 700,
              letterSpacing: "0.05em",
              color: isActive ? (t.highlight ? TEAL : "#fff") : "rgba(255,255,255,0.35)",
            }}>
              {t.label.toUpperCase()}
            </span>
          </button>
        );
      })}
    </div>
  );
}

export default function FitUpHome() {
  const [period, setPeriod] = useState("D");

  return (
    <div style={{
      minHeight: "100vh",
      background: "#111",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      padding: "24px",
      fontFamily: "-apple-system, 'SF Pro Display', BlinkMacSystemFont, sans-serif",
    }}>
      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.4; transform: scale(0.85); }
        }
      `}</style>

      {/* Phone frame */}
      <div style={{
        width: 375,
        maxHeight: 812,
        background: DARK_BG,
        borderRadius: 50,
        overflow: "hidden",
        border: "1px solid rgba(255,255,255,0.12)",
        display: "flex",
        flexDirection: "column",
        position: "relative",
        boxShadow: "0 40px 80px rgba(0,0,0,0.7)",
      }}>
        {/* Status bar */}
        <div style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          padding: "14px 24px 0",
        }}>
          <span style={{ fontSize: 13, fontWeight: 700, color: "#fff" }}>9:41</span>
          <div style={{
            width: 100,
            height: 28,
            background: "#000",
            borderRadius: 14,
          }} />
          <div style={{ display: "flex", gap: 5, alignItems: "center" }}>
            <span style={{ fontSize: 11, color: "rgba(255,255,255,0.7)" }}>●●●</span>
            <span style={{ fontSize: 13, color: "#fff", fontWeight: 600 }}>67</span>
          </div>
        </div>

        {/* Scrollable content */}
        <div style={{ flex: 1, overflowY: "auto", padding: "12px 18px 0" }}>

          {/* Header */}
          <div style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            marginBottom: 2,
          }}>
            <div>
              <div style={{
                display: "flex",
                alignItems: "baseline",
                gap: 1,
              }}>
                <span style={{ fontSize: 22, fontWeight: 900, color: TEAL, letterSpacing: "-0.02em" }}>FIT</span>
                <span style={{ fontSize: 22, fontWeight: 900, color: "#e8732a", letterSpacing: "-0.02em" }}>UP</span>
              </div>
              <div style={{ fontSize: 12, color: "rgba(255,255,255,0.45)", marginTop: -1, fontWeight: 500 }}>
                Let's go, Scotty
              </div>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <PeriodPill period={period} setPeriod={setPeriod} />
              <div style={{
                width: 34,
                height: 34,
                borderRadius: "50%",
                background: "rgba(255,255,255,0.08)",
                border: "1px solid rgba(255,255,255,0.1)",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontSize: 15,
                cursor: "pointer",
              }}>
                🔔
              </div>
            </div>
          </div>

          {/* Battle Ring */}
          <BattleRing
            margin={MOCK.margin}
            status={MOCK.status}
            opponent={{ initials: "BA", name: "BadB", avatarColor: "#e8732a" }}
          />

          {/* Battle status strip */}
          <BattleStatusStrip />

          {/* Mini stat cards */}
          <StatCards stats={MOCK.stats} />

          {/* Active battles */}
          <SectionLabel>ACTIVE BATTLES</SectionLabel>
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            {MOCK.activeBattles.map((b, i) => (
              <ActiveBattleRow key={i} battle={b} />
            ))}
          </div>

          {/* Pending/searching */}
          <SectionLabel>PENDING & SEARCHING</SectionLabel>
          <div style={{ display: "flex", flexDirection: "column", gap: 7, paddingBottom: 16 }}>
            {MOCK.pendingBattles.map((p, i) => (
              <PendingRow key={i} item={p} />
            ))}
          </div>
        </div>

        {/* Tab bar */}
        <TabBar />

        {/* FAB */}
        <div style={{
          position: "absolute",
          bottom: 70,
          right: 18,
          width: 44,
          height: 44,
          borderRadius: "50%",
          background: "linear-gradient(135deg, #00e5c8, #39ff5a)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 22,
          color: "#08090f",
          fontWeight: 700,
          cursor: "pointer",
          boxShadow: "0 4px 20px rgba(0,229,200,0.45)",
        }}>
          +
        </div>
      </div>
    </div>
  );
}