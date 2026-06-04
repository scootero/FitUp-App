import { useState } from "react";

const COLORS = {
  bg: "#07090f",
  card: "#0d1117",
  cardBorder: "rgba(255,255,255,0.07)",
  green: "#00e87a",
  red: "#ff4d4d",
  gold: "#f5c842",
  blue: "#4db8ff",
  purple: "#a855f7",
  orange: "#f97316",
  textPrimary: "#ffffff",
  textSecondary: "rgba(255,255,255,0.45)",
  textMuted: "rgba(255,255,255,0.2)",
};

function Label({ children, color }) {
  return (
    <div style={{
      color: color || COLORS.textSecondary,
      fontSize: 10,
      fontFamily: "'DM Mono', monospace",
      letterSpacing: "0.1em",
      fontWeight: 500,
    }}>{children}</div>
  );
}

function Card({ children, style = {}, glowColor }) {
  return (
    <div style={{
      background: COLORS.card,
      border: `1px solid ${COLORS.cardBorder}`,
      borderRadius: 18,
      padding: "16px",
      position: "relative",
      overflow: "hidden",
      ...style,
    }}>
      {glowColor && (
        <div style={{
          position: "absolute", top: -40, right: -40,
          width: 150, height: 150,
          background: glowColor,
          borderRadius: "50%",
          filter: "blur(50px)",
          opacity: 0.15,
          pointerEvents: "none",
        }} />
      )}
      {children}
    </div>
  );
}

function SparkBar({ data, color }) {
  const max = Math.max(...data);
  return (
    <div style={{ display: "flex", alignItems: "flex-end", gap: 3, height: 28 }}>
      {data.map((v, i) => (
        <div key={i} style={{
          flex: 1,
          height: `${(v / max) * 100}%`,
          background: i === data.length - 1 ? color : `${color}55`,
          borderRadius: 2,
          minHeight: 3,
        }} />
      ))}
    </div>
  );
}

// ─── LIVE BATTLE HERO ───────────────────────────────────────────────────────
function LiveBattleCard() {
  const mySteps = 9_241;
  const theirSteps = 7_830;
  const totalSteps = mySteps + theirSteps;
  const myPct = (mySteps / totalSteps) * 100;
  const leading = mySteps > theirSteps;
  const gap = Math.abs(mySteps - theirSteps);
  const hoursLeft = 11;

  return (
    <div style={{
      background: `linear-gradient(135deg, #0a1a12 0%, #0d1420 100%)`,
      border: `1px solid ${leading ? "rgba(0,232,122,0.3)" : "rgba(255,77,77,0.3)"}`,
      borderRadius: 20,
      padding: "18px",
      marginBottom: 10,
      position: "relative",
      overflow: "hidden",
    }}>
      {/* Pulse dot */}
      <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 14 }}>
        <div style={{
          width: 8, height: 8, borderRadius: "50%",
          background: COLORS.green,
          boxShadow: `0 0 8px ${COLORS.green}`,
          animation: "pulse 1.5s infinite",
        }} />
        <style>{`@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.4} }`}</style>
        <Label color={COLORS.green}>LIVE BATTLE</Label>
        <div style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 4 }}>
          <span style={{ fontSize: 12 }}>⏱</span>
          <span style={{ color: COLORS.gold, fontFamily: "'DM Mono', monospace", fontSize: 12, fontWeight: 700 }}>{hoursLeft}h left</span>
        </div>
      </div>

      {/* Competitors */}
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 14 }}>
        {/* You */}
        <div style={{ flex: 1, textAlign: "center" }}>
          <div style={{
            width: 44, height: 44, borderRadius: "50%",
            background: "linear-gradient(135deg, #0099cc, #00e87a)",
            display: "flex", alignItems: "center", justifyContent: "center",
            margin: "0 auto 6px",
            fontFamily: "'DM Mono', monospace", fontWeight: 700, fontSize: 14, color: "#000",
            border: leading ? `2px solid ${COLORS.green}` : "2px solid transparent",
            boxShadow: leading ? `0 0 12px rgba(0,232,122,0.4)` : "none",
          }}>YOU</div>
          <div style={{ color: "#fff", fontFamily: "'DM Mono', monospace", fontWeight: 700, fontSize: 22 }}>
            {mySteps.toLocaleString()}
          </div>
          <Label color={COLORS.green}>YOUR STEPS</Label>
        </div>

        {/* VS */}
        <div style={{ textAlign: "center", flexShrink: 0 }}>
          <div style={{ color: "rgba(255,255,255,0.15)", fontFamily: "'DM Mono', monospace", fontWeight: 700, fontSize: 13 }}>VS</div>
          <div style={{
            background: leading ? "rgba(0,232,122,0.15)" : "rgba(255,77,77,0.15)",
            border: `1px solid ${leading ? "rgba(0,232,122,0.3)" : "rgba(255,77,77,0.3)"}`,
            borderRadius: 8, padding: "3px 8px", marginTop: 4,
          }}>
            <span style={{ color: leading ? COLORS.green : COLORS.red, fontFamily: "'DM Mono', monospace", fontSize: 11, fontWeight: 700 }}>
              {leading ? "+" : "-"}{gap.toLocaleString()}
            </span>
          </div>
        </div>

        {/* Opponent */}
        <div style={{ flex: 1, textAlign: "center" }}>
          <div style={{
            width: 44, height: 44, borderRadius: "50%",
            background: "linear-gradient(135deg, #e8521a, #c43c0a)",
            display: "flex", alignItems: "center", justifyContent: "center",
            margin: "0 auto 6px",
            fontFamily: "'DM Mono', monospace", fontWeight: 700, fontSize: 14, color: "#fff",
          }}>ET</div>
          <div style={{ color: "rgba(255,255,255,0.6)", fontFamily: "'DM Mono', monospace", fontWeight: 700, fontSize: 22 }}>
            {theirSteps.toLocaleString()}
          </div>
          <Label>EMILY THE RED</Label>
        </div>
      </div>

      {/* Progress bar */}
      <div style={{ marginBottom: 12 }}>
        <div style={{ background: "rgba(255,255,255,0.08)", borderRadius: 6, height: 8, overflow: "hidden" }}>
          <div style={{
            width: `${myPct}%`, height: "100%",
            background: `linear-gradient(90deg, #00c97a, #00e87a)`,
            borderRadius: 6,
            transition: "width 0.5s ease",
          }} />
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 4 }}>
          <Label color={COLORS.green}>{myPct.toFixed(0)}%</Label>
          <Label>{(100 - myPct).toFixed(0)}%</Label>
        </div>
      </div>

      <div style={{ color: COLORS.textSecondary, fontSize: 12, fontFamily: "'DM Sans', sans-serif", textAlign: "center" }}>
        {leading ? `🔥 You're leading — keep pushing` : `⚠️ You're behind — time to grind`}
      </div>
    </div>
  );
}

// ─── SUMMARY BAR ─────────────────────────────────────────────────────────────
function SummaryBar() {
  const stats = [
    { label: "RECORD", value: "8-3", color: COLORS.green },
    { label: "WIN RATE", value: "73%", color: COLORS.gold },
    { label: "STREAK", value: "3W 🔥", color: COLORS.orange },
    { label: "RIVALS", value: "4", color: COLORS.blue },
  ];
  return (
    <div style={{ display: "flex", gap: 6, marginBottom: 10 }}>
      {stats.map((s) => (
        <div key={s.label} style={{
          flex: 1,
          background: COLORS.card,
          border: `1px solid ${COLORS.cardBorder}`,
          borderRadius: 14,
          padding: "10px 4px",
          textAlign: "center",
        }}>
          <div style={{ color: s.color, fontFamily: "'DM Mono', monospace", fontWeight: 700, fontSize: 15 }}>{s.value}</div>
          <div style={{ color: COLORS.textMuted, fontSize: 8, fontFamily: "'DM Mono', monospace", marginTop: 2, letterSpacing: "0.06em" }}>{s.label}</div>
        </div>
      ))}
    </div>
  );
}

// ─── RIVAL CARD ───────────────────────────────────────────────────────────────
function RivalCard({ rival }) {
  const [open, setOpen] = useState(false);
  const isNemesis = rival.tag === "nemesis";
  const isPunchingBag = rival.tag === "punchingbag";
  const tagColor = isNemesis ? COLORS.red : isPunchingBag ? COLORS.green : COLORS.blue;
  const tagLabel = isNemesis ? "😤 NEMESIS" : isPunchingBag ? "💪 PUNCHING BAG" : "⚔️ RIVAL";
  const winning = rival.myWins > rival.theirWins;

  return (
    <div style={{
      background: COLORS.card,
      border: `1px solid ${isNemesis ? "rgba(255,77,77,0.2)" : isPunchingBag ? "rgba(0,232,122,0.2)" : COLORS.cardBorder}`,
      borderRadius: 18,
      marginBottom: 8,
      overflow: "hidden",
    }}>
      {/* Tag strip */}
      <div style={{
        background: `${tagColor}18`,
        borderBottom: `1px solid ${tagColor}22`,
        padding: "6px 14px",
        display: "flex", alignItems: "center", justifyContent: "space-between",
      }}>
        <span style={{ color: tagColor, fontSize: 10, fontFamily: "'DM Mono', monospace", fontWeight: 700, letterSpacing: "0.08em" }}>{tagLabel}</span>
        <span style={{ color: COLORS.textMuted, fontSize: 10, fontFamily: "'DM Mono', monospace" }}>{rival.battleDays} battle days</span>
      </div>

      <div style={{ padding: "14px" }}>
        {/* Header */}
        <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 14 }}>
          <div style={{
            width: 42, height: 42, borderRadius: "50%",
            background: rival.avatarGradient,
            display: "flex", alignItems: "center", justifyContent: "center",
            fontFamily: "'DM Mono', monospace", fontWeight: 700, fontSize: 13, color: "#fff",
            flexShrink: 0,
          }}>{rival.initials}</div>
          <div style={{ flex: 1 }}>
            <div style={{ color: "#fff", fontFamily: "'DM Sans', sans-serif", fontWeight: 700, fontSize: 16 }}>{rival.name}</div>
            <div style={{ color: COLORS.textSecondary, fontSize: 12, fontFamily: "'DM Sans', sans-serif" }}>
              Last battle: {rival.lastBattle}
            </div>
          </div>
          <div style={{ textAlign: "right" }}>
            <div style={{
              fontFamily: "'DM Mono', monospace", fontWeight: 700, fontSize: 20,
              color: winning ? COLORS.green : COLORS.red,
            }}>{rival.myWins}-{rival.theirWins}</div>
            <Label>W-L</Label>
          </div>
        </div>

        {/* Stats row */}
        <div style={{ display: "flex", gap: 6, marginBottom: 14 }}>
          {[
            { label: "AVG MARGIN", value: rival.avgMargin, color: COLORS.gold },
            { label: "WIN RATE", value: `${rival.winRate}%`, color: winning ? COLORS.green : COLORS.red },
            { label: "BEST WIN", value: rival.bestWin, color: COLORS.blue },
          ].map((s) => (
            <div key={s.label} style={{
              flex: 1, background: "rgba(255,255,255,0.04)",
              borderRadius: 10, padding: "8px 6px", textAlign: "center",
            }}>
              <div style={{ color: s.color, fontFamily: "'DM Mono', monospace", fontWeight: 700, fontSize: 13 }}>{s.value}</div>
              <div style={{ color: COLORS.textMuted, fontSize: 8, fontFamily: "'DM Mono', monospace", marginTop: 2, letterSpacing: "0.05em" }}>{s.label}</div>
            </div>
          ))}
        </div>

        {/* Spark */}
        <div style={{ marginBottom: 14 }}>
          <Label style={{ marginBottom: 6 }}>THEIR STEPS · LAST 7 DAYS</Label>
          <div style={{ marginTop: 6 }}>
            <SparkBar data={rival.trend} color={isNemesis ? COLORS.red : COLORS.blue} />
          </div>
        </div>

        {/* CTA */}
        <button style={{
          width: "100%",
          background: isNemesis
            ? "linear-gradient(90deg, #b91c1c, #ef4444)"
            : "linear-gradient(90deg, #00a85a, #00e87a)",
          border: "none", borderRadius: 12, padding: "12px",
          color: isNemesis ? "#fff" : "#000",
          fontFamily: "'DM Sans', sans-serif", fontWeight: 800, fontSize: 14,
          cursor: "pointer", letterSpacing: "0.02em",
        }}>
          {isNemesis ? `⚔️ GET REVENGE ON ${rival.name.split(" ")[0].toUpperCase()}` : `⚡ REMATCH ${rival.name.split(" ")[0].toUpperCase()}`}
        </button>
      </div>
    </div>
  );
}

// ─── INSIGHT CARD ─────────────────────────────────────────────────────────────
function InsightCard() {
  const days = ["M","T","W","T","F","S","S"];
  const battleSteps = [11200, 9800, 13400, 0, 10200, 12100, 9241];
  const normalSteps = [6200, 5400, 7100, 4800, 6600, 8200, 5900];
  const maxVal = Math.max(...battleSteps, ...normalSteps);
  const battleAvg = Math.round(battleSteps.filter(Boolean).reduce((a,b)=>a+b,0)/battleSteps.filter(Boolean).length);
  const normalAvg = Math.round(normalSteps.reduce((a,b)=>a+b,0)/normalSteps.length);
  const uplift = Math.round(((battleAvg - normalAvg) / normalAvg) * 100);

  return (
    <Card style={{ marginBottom: 10 }}>
      <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: 14 }}>
        <div>
          <Label>BATTLE DAY EFFECT</Label>
          <div style={{ color: "#fff", fontFamily: "'DM Sans', sans-serif", fontWeight: 700, fontSize: 16, marginTop: 4 }}>
            Competition makes you walk more
          </div>
        </div>
        <div style={{
          background: "rgba(0,232,122,0.15)",
          border: "1px solid rgba(0,232,122,0.3)",
          borderRadius: 10, padding: "6px 10px", textAlign: "center",
        }}>
          <div style={{ color: COLORS.green, fontFamily: "'DM Mono', monospace", fontWeight: 800, fontSize: 18 }}>+{uplift}%</div>
          <div style={{ color: COLORS.textMuted, fontSize: 8, fontFamily: "'DM Mono', monospace" }}>UPLIFT</div>
        </div>
      </div>

      {/* Grouped bars */}
      <div style={{ display: "flex", gap: 4, alignItems: "flex-end", height: 60, marginBottom: 8 }}>
        {days.map((d, i) => (
          <div key={i} style={{ flex: 1, display: "flex", flexDirection: "column", gap: 2, alignItems: "center", height: "100%", justifyContent: "flex-end" }}>
            <div style={{ display: "flex", gap: 1, alignItems: "flex-end", width: "100%" }}>
              <div style={{
                flex: 1,
                height: battleSteps[i] ? `${(battleSteps[i] / maxVal) * 52}px` : "3px",
                background: battleSteps[i] ? COLORS.green : "rgba(255,255,255,0.05)",
                borderRadius: 2,
                minHeight: 3,
              }} />
              <div style={{
                flex: 1,
                height: `${(normalSteps[i] / maxVal) * 52}px`,
                background: "rgba(77,184,255,0.5)",
                borderRadius: 2,
                minHeight: 3,
              }} />
            </div>
          </div>
        ))}
      </div>
      <div style={{ display: "flex", gap: 4 }}>
        {days.map((d, i) => (
          <div key={i} style={{ flex: 1, textAlign: "center" }}>
            <Label>{d}</Label>
          </div>
        ))}
      </div>

      <div style={{ display: "flex", gap: 16, marginTop: 12 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <div style={{ width: 8, height: 8, borderRadius: 2, background: COLORS.green }} />
          <span style={{ color: COLORS.textSecondary, fontSize: 11, fontFamily: "'DM Sans', sans-serif" }}>Battle days · avg {battleAvg.toLocaleString()}</span>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <div style={{ width: 8, height: 8, borderRadius: 2, background: "rgba(77,184,255,0.6)" }} />
          <span style={{ color: COLORS.textSecondary, fontSize: 11, fontFamily: "'DM Sans', sans-serif" }}>Normal days · avg {normalAvg.toLocaleString()}</span>
        </div>
      </div>
    </Card>
  );
}

// ─── PERSONAL RECORDS ─────────────────────────────────────────────────────────
function PersonalRecords() {
  const records = [
    { icon: "👑", label: "Best Battle Day", value: "18,420 steps", sub: "vs Emily · Apr 12" },
    { icon: "💥", label: "Biggest Win Margin", value: "+9,811 steps", sub: "vs Mike Tyson · Mar 3" },
    { icon: "😬", label: "Closest Battle", value: "+12 steps", sub: "vs Emily · May 1" },
    { icon: "🔥", label: "Longest Win Streak", value: "5 wins", sub: "Feb – Mar" },
  ];

  return (
    <Card style={{ marginBottom: 10 }}>
      <Label style={{ marginBottom: 12 }}>PERSONAL RECORDS</Label>
      <div style={{ marginTop: 10, display: "flex", flexDirection: "column", gap: 10 }}>
        {records.map((r) => (
          <div key={r.label} style={{
            display: "flex", alignItems: "center", gap: 12,
            background: "rgba(255,255,255,0.03)",
            borderRadius: 12, padding: "10px 12px",
          }}>
            <span style={{ fontSize: 22 }}>{r.icon}</span>
            <div style={{ flex: 1 }}>
              <div style={{ color: COLORS.textSecondary, fontSize: 11, fontFamily: "'DM Sans', sans-serif" }}>{r.label}</div>
              <div style={{ color: "#fff", fontFamily: "'DM Mono', monospace", fontWeight: 700, fontSize: 15 }}>{r.value}</div>
            </div>
            <div style={{ color: COLORS.textMuted, fontSize: 11, fontFamily: "'DM Sans', sans-serif", textAlign: "right" }}>{r.sub}</div>
          </div>
        ))}
      </div>
    </Card>
  );
}

// ─── ACHIEVEMENTS ────────────────────────────────────────────────────────────
function Achievements() {
  const badges = [
    { icon: "⚡", label: "First Blood", earned: true },
    { icon: "🔥", label: "5-Win Streak", earned: true },
    { icon: "😤", label: "Upset Victory", earned: true },
    { icon: "💀", label: "Dominator", earned: false },
    { icon: "🌙", label: "Night Walker", earned: false },
    { icon: "🏆", label: "Champion", earned: false },
  ];
  return (
    <Card style={{ marginBottom: 10 }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 12 }}>
        <Label>ACHIEVEMENTS</Label>
        <span style={{ color: COLORS.textMuted, fontSize: 11, fontFamily: "'DM Sans', sans-serif" }}>3 / 6</span>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 8 }}>
        {badges.map((b) => (
          <div key={b.label} style={{
            background: b.earned ? "rgba(245,200,66,0.08)" : "rgba(255,255,255,0.03)",
            border: `1px solid ${b.earned ? "rgba(245,200,66,0.25)" : "rgba(255,255,255,0.06)"}`,
            borderRadius: 14, padding: "12px 8px",
            textAlign: "center",
            opacity: b.earned ? 1 : 0.4,
          }}>
            <div style={{ fontSize: 24, marginBottom: 4, filter: b.earned ? "none" : "grayscale(1)" }}>{b.icon}</div>
            <div style={{ color: b.earned ? COLORS.gold : COLORS.textMuted, fontSize: 10, fontFamily: "'DM Mono', monospace", lineHeight: 1.3 }}>{b.label}</div>
          </div>
        ))}
      </div>
    </Card>
  );
}

// ─── LIFETIME STATS ───────────────────────────────────────────────────────────
function LifetimeStats() {
  const stats = [
    { label: "TOTAL BATTLE STEPS", value: "847,230", color: COLORS.blue },
    { label: "BATTLES COMPLETED", value: "11", color: COLORS.purple },
    { label: "DAYS COMPETED", value: "34", color: COLORS.orange },
    { label: "EXTRA MILES WALKED", value: "62 mi", color: COLORS.green },
  ];
  return (
    <Card style={{ marginBottom: 10 }}>
      <Label style={{ marginBottom: 12 }}>LIFETIME</Label>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, marginTop: 10 }}>
        {stats.map((s) => (
          <div key={s.label} style={{
            background: "rgba(255,255,255,0.03)",
            borderRadius: 12, padding: "12px",
          }}>
            <div style={{ color: s.color, fontFamily: "'DM Mono', monospace", fontWeight: 700, fontSize: 20 }}>{s.value}</div>
            <div style={{ color: COLORS.textMuted, fontSize: 9, fontFamily: "'DM Mono', monospace", marginTop: 4, letterSpacing: "0.06em", lineHeight: 1.4 }}>{s.label}</div>
          </div>
        ))}
      </div>
    </Card>
  );
}

// ─── MAIN ─────────────────────────────────────────────────────────────────────
const rivals = [
  {
    id: 1, initials: "ET", name: "Emily the Red",
    avatarGradient: "linear-gradient(135deg, #e8521a, #c43c0a)",
    myWins: 1, theirWins: 3, winRate: 25,
    avgMargin: "+3.1k", bestWin: "+5.1k",
    battleDays: 8, lastBattle: "2d ago",
    tag: "nemesis",
    trend: [8200, 11400, 9600, 13200, 10800, 14100, 7830],
  },
  {
    id: 2, initials: "MJ", name: "Mike J",
    avatarGradient: "linear-gradient(135deg, #7c3aed, #a855f7)",
    myWins: 4, theirWins: 1, winRate: 80,
    avgMargin: "+4.2k", bestWin: "+9.8k",
    battleDays: 12, lastBattle: "5d ago",
    tag: "punchingbag",
    trend: [5100, 6300, 4800, 7200, 5600, 6100, 5400],
  },
  {
    id: 3, initials: "SR", name: "Sara R",
    avatarGradient: "linear-gradient(135deg, #0ea5e9, #38bdf8)",
    myWins: 3, theirWins: 2, winRate: 60,
    avgMargin: "+1.8k", bestWin: "+6.2k",
    battleDays: 9, lastBattle: "1w ago",
    tag: "rival",
    trend: [7600, 8900, 7200, 9400, 8100, 9800, 8400],
  },
];

export default function App() {
  const [tab, setTab] = useState("battle");

  return (
    <div style={{ background: COLORS.bg, minHeight: "100vh", maxWidth: 430, margin: "0 auto", fontFamily: "'DM Sans', sans-serif" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500;700&family=DM+Sans:wght@400;500;700;800&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        ::-webkit-scrollbar { display: none; }
      `}</style>

      {/* Nav */}
      <div style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "16px 18px 10px",
        position: "sticky", top: 0, zIndex: 20,
        background: "rgba(7,9,15,0.96)",
        backdropFilter: "blur(16px)",
        borderBottom: "1px solid rgba(255,255,255,0.05)",
      }}>
        <div style={{ fontFamily: "'DM Sans', sans-serif", fontWeight: 800, fontSize: 22 }}>
          <span style={{ color: "#4db8ff" }}>FIT</span>
          <span style={{ color: COLORS.gold }}>UP</span>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          {["🔔","💬"].map((icon, i) => (
            <div key={i} style={{
              width: 34, height: 34, borderRadius: "50%",
              background: "rgba(255,255,255,0.07)",
              display: "flex", alignItems: "center", justifyContent: "center", fontSize: 15,
            }}>{icon}</div>
          ))}
          <div style={{
            width: 34, height: 34, borderRadius: "50%",
            background: COLORS.green,
            display: "flex", alignItems: "center", justifyContent: "center",
            fontSize: 18, color: "#000", fontWeight: 800,
          }}>+</div>
        </div>
      </div>

      {/* Scroll content */}
      <div style={{ padding: "14px 14px 110px" }}>
        {/* Page header */}
        <div style={{ marginBottom: 14 }}>
          <div style={{ color: "#fff", fontFamily: "'DM Sans', sans-serif", fontWeight: 800, fontSize: 24 }}>Battle Stats</div>
          <div style={{ color: COLORS.textSecondary, fontSize: 13, marginTop: 2 }}>Season 1 · June 2026</div>
        </div>

        {/* T1: Summary */}
        <SummaryBar />

        {/* T1: Live Battle */}
        <LiveBattleCard />

        {/* T2: Rivals */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 8, marginTop: 6 }}>
          <Label>YOUR RIVALS</Label>
          <span style={{ color: COLORS.green, fontSize: 12, fontFamily: "'DM Sans', sans-serif", fontWeight: 600 }}>View all →</span>
        </div>
        {rivals.map((r) => <RivalCard key={r.id} rival={r} />)}

        {/* Add rival */}
        <div style={{
          border: "1.5px dashed rgba(255,255,255,0.1)",
          borderRadius: 18, padding: "18px", textAlign: "center", marginBottom: 10,
        }}>
          <div style={{ fontSize: 26, marginBottom: 6 }}>⚔️</div>
          <div style={{ color: "rgba(255,255,255,0.55)", fontWeight: 600, fontSize: 14 }}>Challenge someone new</div>
          <div style={{ color: COLORS.textMuted, fontSize: 12, marginTop: 4 }}>Keep your streak alive</div>
        </div>

        {/* T3: Insight */}
        <InsightCard />

        {/* T3/T4: Personal Records */}
        <PersonalRecords />

        {/* T4: Achievements */}
        <Achievements />

        {/* T4: Lifetime */}
        <LifetimeStats />
      </div>

      {/* Tab bar */}
      <div style={{
        position: "fixed", bottom: 0, left: "50%", transform: "translateX(-50%)",
        width: "100%", maxWidth: 430,
        background: "rgba(7,9,15,0.97)",
        backdropFilter: "blur(20px)",
        borderTop: "1px solid rgba(255,255,255,0.07)",
        display: "flex", padding: "10px 0 26px",
      }}>
        {[
          { key: "home", icon: "🏠", label: "HOME" },
          { key: "stats", icon: "📊", label: "STATS" },
          { key: "battle", icon: "⚔️", label: "BATTLE" },
          { key: "ranks", icon: "🏆", label: "RANKS" },
          { key: "profile", icon: "👤", label: "PROFILE" },
        ].map((t) => (
          <div key={t.key} onClick={() => setTab(t.key)} style={{
            flex: 1, display: "flex", flexDirection: "column",
            alignItems: "center", gap: 3, cursor: "pointer",
          }}>
            <div style={{
              width: t.key === tab ? 46 : 30,
              height: t.key === tab ? 46 : 30,
              borderRadius: t.key === tab ? 14 : "50%",
              background: t.key === tab ? "linear-gradient(135deg, #0099cc, #00e87a)" : "transparent",
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: t.key === tab ? 20 : 17,
              transition: "all 0.2s ease",
            }}>{t.icon}</div>
            <div style={{
              color: t.key === tab ? "#fff" : COLORS.textMuted,
              fontSize: 8, fontFamily: "'DM Mono', monospace", letterSpacing: "0.08em",
            }}>{t.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
