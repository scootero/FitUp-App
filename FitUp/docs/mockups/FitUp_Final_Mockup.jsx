// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  FITUP — FINAL UNIFIED DESIGN SYSTEM MOCKUP                                ║
// ║  Source: Merged from File 1 (theme/screens) + File 2 (Health, BottomNav)   ║
// ║                                                                             ║
// ║  SCREENS INCLUDED:                                                          ║
// ║    Home · Match Details · Challenge Flow · Leaderboard/Ranks                ║
// ║    Activity · Health · Profile                                               ║
// ║                                                                             ║
// ║  NOTES:                                                                     ║
// ║    Live Match — accessible from Match Details card (not in nav)            ║
// ║                                                                             ║
// ║  FOR CURSOR / SWIFT IMPLEMENTATION:                                         ║
// ║    • All design tokens are in the T object at the top — treat these as      ║
// ║      SwiftUI Color / Font constants                                          ║
// ║    • Every section marked [MOCK DATA] must be replaced with real API data   ║
// ║    • Navigation is bottom tab bar — see BottomNav component for structure   ║
// ║    • HealthKit integration points are clearly marked                        ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import { useState, useEffect, useCallback } from "react";
import { BarChart, Bar, XAxis, YAxis, ResponsiveContainer, Tooltip } from "recharts";
import {
  Zap, Home, Activity, Heart, User, ChevronRight, Check, X,
  RotateCcw, Flame, Trophy, Target, TrendingUp, Settings,
  Bell, Shield, Code, ToggleLeft, ToggleRight, LogOut,
  Crown, Star, Plus, Clock, Search, ChevronUp, ChevronDown,
  Footprints, Swords, Medal, ArrowLeft,
  ChevronLeft, Sparkles, Moon, Award, Play, Pause
} from "lucide-react";


// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// All colors, fonts, glass effects, and radius values live here.
// In Swift: map these to Color, Font, and style extensions.
// ─────────────────────────────────────────────────────────────────────────────
const T = {
  // ── Background ──────────────────────────────────────────────────────────
  bg: { base: "#04040A" },

  // ── Neon accent colors ───────────────────────────────────────────────────
  // win (teal/cyan) = user is winning, positive state
  // orange = user is losing, negative state / opponent accent
  // blue = pending/searching/neutral actions
  // yellow = premium / gold / rank 1
  // pink = decline / danger
  // purple = matchmaking / random
  // green = live/synced badge
  // red = generic error
  neon: {
    cyan:   "#00FFE0", cyanDim:   "rgba(0,255,224,0.14)",
    blue:   "#00AAFF", blueDim:   "rgba(0,170,255,0.14)",
    orange: "#FF6200", orangeDim: "rgba(255,98,0,0.14)",
    yellow: "#FFE000",
    pink:   "#FF2D9B",
    purple: "#BF5FFF",
    green:  "#39FF14", greenDim:  "rgba(57,255,20,0.12)",
    red:    "#FF3B3B",
  },

  // ── Text hierarchy ───────────────────────────────────────────────────────
  text: {
    primary:   "#FFFFFF",
    secondary: "rgba(255,255,255,0.52)",
    tertiary:  "rgba(255,255,255,0.27)",
  },

  // ── Glass card variants ──────────────────────────────────────────────────
  // win   = winning state card (cyan tint)
  // lose  = losing state card (orange tint)
  // base  = neutral card
  // pending = incoming challenge card (blue tint)
  // gold  = premium / rank 1 card
  glass: {
    win: {
      background: "linear-gradient(135deg, rgba(0,255,224,0.07) 0%, rgba(0,255,224,0.02) 100%)",
      border: "1px solid rgba(0,255,224,0.22)",
      boxShadow: "0 8px 32px rgba(0,255,224,0.07), inset 0 1px 0 rgba(0,255,224,0.13)",
    },
    lose: {
      background: "linear-gradient(135deg, rgba(255,98,0,0.07) 0%, rgba(255,98,0,0.02) 100%)",
      border: "1px solid rgba(255,98,0,0.22)",
      boxShadow: "0 8px 32px rgba(255,98,0,0.07), inset 0 1px 0 rgba(255,98,0,0.13)",
    },
    base: {
      background: "linear-gradient(135deg, rgba(255,255,255,0.055) 0%, rgba(255,255,255,0.018) 100%)",
      border: "1px solid rgba(255,255,255,0.09)",
      boxShadow: "0 8px 32px rgba(0,0,0,0.45), inset 0 1px 0 rgba(255,255,255,0.07)",
    },
    pending: {
      background: "linear-gradient(135deg, rgba(0,170,255,0.07) 0%, rgba(0,170,255,0.02) 100%)",
      border: "1px solid rgba(0,170,255,0.22)",
      boxShadow: "0 8px 32px rgba(0,170,255,0.07), inset 0 1px 0 rgba(0,170,255,0.13)",
    },
    gold: {
      background: "linear-gradient(135deg, rgba(255,224,0,0.1) 0%, rgba(255,224,0,0.03) 100%)",
      border: "1px solid rgba(255,224,0,0.28)",
      boxShadow: "0 8px 32px rgba(255,224,0,0.1), inset 0 1px 0 rgba(255,224,0,0.18)",
    },
  },

  // ── Border radius scale ──────────────────────────────────────────────────
  radius: { sm: 10, md: 16, lg: 22, xl: 28, pill: 999 },

  // ── Font families ────────────────────────────────────────────────────────
  // In Swift: SF Pro Display = .systemFont(size:, design: .default)
  //           SF Mono        = .monospacedSystemFont(size:, weight:)
  font: {
    display: "'SF Pro Display', -apple-system, BlinkMacSystemFont, sans-serif",
    body:    "'SF Pro Text', -apple-system, BlinkMacSystemFont, sans-serif",
    mono:    "'SF Mono', 'Fira Code', monospace",
  },
};

// ── Full-screen background gradient ─────────────────────────────────────────
const BG_STYLE = {
  background: `
    radial-gradient(ellipse 90% 55% at 15% 8%, rgba(0,255,224,0.038) 0%, transparent 58%),
    radial-gradient(ellipse 65% 45% at 85% 88%, rgba(0,170,255,0.038) 0%, transparent 58%),
    radial-gradient(ellipse 55% 35% at 50% 50%, rgba(255,98,0,0.018) 0%, transparent 65%),
    #04040A
  `,
};

// ── Style helper functions ───────────────────────────────────────────────────
const glassCard  = (v="base") => ({ ...T.glass[v], borderRadius: T.radius.lg, backdropFilter:"blur(22px)", WebkitBackdropFilter:"blur(22px)", overflow:"hidden", position:"relative" });
const neonPill   = (c=T.neon.cyan) => ({ background:`${c}18`, border:`1px solid ${c}40`, borderRadius:T.radius.pill, padding:"3px 10px", fontSize:11, fontWeight:700, color:c, letterSpacing:"0.05em" });
const secLabel   = { fontSize:11, fontWeight:700, letterSpacing:"0.13em", textTransform:"uppercase", color:T.text.tertiary, marginBottom:10, paddingLeft:2 };
const ghostBtn   = (c=T.neon.cyan) => ({ background:`${c}1a`, border:`1px solid ${c}50`, color:c, fontWeight:800, cursor:"pointer", fontFamily:T.font.body, borderRadius:T.radius.pill });
const solidBtn   = (c=T.neon.cyan) => ({ background:`linear-gradient(135deg,${c}cc,${c}88)`, border:`1px solid ${c}50`, color:"#000", fontWeight:800, cursor:"pointer", fontFamily:T.font.body, borderRadius:T.radius.md, boxShadow:`0 0 24px ${c}44` });


// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA
// [MOCK DATA] — All data below must be replaced with real API / HealthKit data
// in the Swift implementation. Comments indicate what each value represents.
// ─────────────────────────────────────────────────────────────────────────────

// [MOCK DATA] Current logged-in user — replace with authenticated user profile
const ME = { name:"Marcus R.", initials:"MR", color:T.neon.cyan };

// [MOCK DATA] Active, pending, searching, and completed matches
// In Swift: fetched from your backend (Firebase/Supabase) in real time
// match.winning       = Boolean: user's score > opponent's score
// match.myToday       = Integer: user's step count today (from HealthKit)
// match.theirToday    = Integer: opponent's step count today (from backend)
// match.myScore       = Integer: number of days user has won so far
// match.theirScore    = Integer: number of days opponent has won so far
// match.daysLeft      = Integer: days remaining in challenge
// match.days[]        = Array of day objects: { day, me, them, winner }
//   - me/them         = step count for that day (null if not yet played)
//   - winner          = "me" | "them" | null (null = day in progress or future)
const MATCHES = [
  { id:1, status:"active", winning:true, sport:"Steps", myScore:4, theirScore:2,
    myToday:11240, theirToday:8980, daysLeft:3, totalDays:7, series:"Best of 7",
    opponent:{name:"Jake T.",initials:"JT",color:T.neon.orange},
    days:[
      {day:"M",me:12400,them:9800,winner:"me"},
      {day:"T",me:8900,them:11200,winner:"them"},
      {day:"W",me:13100,them:8400,winner:"me"},
      {day:"T",me:10200,them:9100,winner:"me"},
      {day:"F",me:9400,them:11800,winner:"them"},
      {day:"S",me:11240,them:8980,winner:null},  // null = today, in progress
      {day:"S",me:null,them:null,winner:null},    // null = future day
    ]
  },
  { id:2, status:"active", winning:false, sport:"Steps", myScore:1, theirScore:3,
    myToday:5102, theirToday:8774, daysLeft:2, totalDays:5, series:"First to 3",
    opponent:{name:"Sofia M.",initials:"SM",color:T.neon.pink},
    days:[
      {day:"M",me:510,them:620,winner:"them"},
      {day:"T",me:480,them:390,winner:"me"},
      {day:"W",me:350,them:580,winner:"them"},
      {day:"T",me:410,them:640,winner:"them"},
      {day:"F",me:5102,them:8774,winner:null},
    ]
  },
  // [MOCK DATA] Incoming challenge request — waiting for user to accept/decline
  { id:3, status:"pending_incoming", opponent:{name:"Drew K.",initials:"DK",color:T.neon.purple}, sport:"Steps", series:"Best of 5" },
  { id:4, status:"pending_incoming", opponent:{name:"Priya L.",initials:"PL",color:T.neon.yellow}, sport:"Steps", series:"First to 3" },
  // [MOCK DATA] Matchmaking in progress — searching for a random opponent
  // waitTime = time elapsed since search started
  { id:5, status:"searching", sport:"Steps", series:"Best of 7", waitTime:"2m 34s" },
  // [MOCK DATA] Completed matches for history
  { id:6, status:"completed", winning:true, sport:"Steps", myScore:3, theirScore:1,
    opponent:{name:"Lena W.",initials:"LW",color:T.neon.green},
    days:[{day:"M",me:12400,them:9800,winner:"me"},{day:"T",me:8900,them:11200,winner:"them"},{day:"W",me:13100,them:8400,winner:"me"},{day:"T",me:10200,them:9100,winner:"me"}]
  },
  { id:7, status:"completed", winning:false, sport:"Steps", myScore:0, theirScore:3,
    opponent:{name:"Omar S.",initials:"OS",color:T.neon.blue},
    days:[{day:"M",me:310,them:620,winner:"them"},{day:"T",me:280,them:590,winner:"them"},{day:"W",me:350,them:480,winner:"them"}]
  },
];

// [MOCK DATA] Global leaderboard — fetched from backend, ordered by points
// points = calculated server-side: based on wins, streaks, and activity level
// isMe   = Boolean flag to highlight the current user's row
const LEADERBOARD = [
  { rank:1, name:"Tariq H.",  initials:"TH", color:T.neon.yellow, wins:34, losses:6,  streak:8, points:4820 },
  { rank:2, name:"Anya B.",   initials:"AB", color:T.neon.cyan,   wins:28, losses:9,  streak:5, points:3970 },
  { rank:3, name:"Chris V.",  initials:"CV", color:T.neon.green,  wins:26, losses:8,  streak:3, points:3610 },
  { rank:4, name:"Marcus R.", initials:"MR", color:T.neon.cyan,   wins:18, losses:8,  streak:4, points:2550, isMe:true },
  { rank:5, name:"Nadia F.",  initials:"NF", color:T.neon.orange, wins:16, losses:12, streak:2, points:2210 },
  { rank:6, name:"Priya L.",  initials:"PL", color:T.neon.yellow, wins:14, losses:11, streak:0, points:1940 },
  { rank:7, name:"Drew K.",   initials:"DK", color:T.neon.purple, wins:12, losses:14, streak:1, points:1650 },
  { rank:8, name:"Sofia M.",  initials:"SM", color:T.neon.pink,   wins:9,  losses:14, streak:0, points:1240 },
];

// [MOCK DATA] Suggested opponents for "Discover Players" section
// In Swift: fetched from backend, filtered by similar activity level (skill matching)
// steps/cals = today's values pulled from backend (opponent's HealthKit sync)
const DISCOVER = [
  { name:"Tariq H.",initials:"TH",color:T.neon.blue,  steps:14200, cals:720, wins:18, losses:4 },
  { name:"Anya B.", initials:"AB",color:T.neon.pink,  steps:9800,  cals:510, wins:12, losses:9 },
  { name:"Chris V.",initials:"CV",color:T.neon.green, steps:11400, cals:630, wins:22, losses:6 },
  { name:"Nadia F.",initials:"NF",color:T.neon.yellow,steps:7300,  cals:380, wins:8,  losses:14},
];

// [MOCK DATA] Health data — ALL values must come from HealthKit in Swift
// HKQuantityTypeIdentifier.stepCount        → steps
// HKQuantityTypeIdentifier.activeEnergyBurned → cals
// HKCategoryTypeIdentifier.sleepAnalysis    → sleep stages
// HKQuantityTypeIdentifier.heartRate        → HR zones
const HEALTH_MOCK = {
  // battleReadiness: 0–100 score — computed from sleep + resting HR + steps trend
  // In Swift: calculate server-side or on-device from HealthKit samples
  battleReadiness: 73,
  steps:    { today:11240, goal:12000, week:[8200,12400,9100,13200,10800,7600,11240] },
  calories: { today:520,   goal:650,   week:[410,680,490,720,580,340,520] },
  sleep: {
    avgHours: 7.6,  // 7-night rolling average from HKCategoryTypeIdentifier.sleepAnalysis
    variance: 2.3,
    // Percentages of each sleep stage (from HealthKit sleep analysis samples)
    stages: [
      { label:"Deep",  pct:29, color:"#1E90FF" },
      { label:"Core",  pct:53, color:"#00A8FF" },
      { label:"REM",   pct:12, color:T.neon.cyan },
      { label:"Awake", pct:6,  color:"rgba(255,255,255,0.27)" },
    ],
  },
  restingHR: 58, // bpm from HKQuantityTypeIdentifier.restingHeartRate
  // HR zones: percentages of time spent in each zone during most recent workout
  hrZones: [
    { label:"Zone 1 · Rest",     pct:0,  color:"rgba(255,255,255,0.25)", val:"0%" },
    { label:"Zone 2 · Fat burn", pct:3,  color:T.neon.blue,             val:"3%" },
    { label:"Zone 3 · Cardio",   pct:15, color:T.neon.cyan,             val:"15%" },
    { label:"Zone 4 · Peak",     pct:44, color:T.neon.orange,           val:"44%" },
    { label:"Zone 5 · Max",      pct:38, color:T.neon.red,              val:"38%" },
  ],
  allTimeBests: {
    // [MOCK DATA] All-time personal records — stored in your backend, seeded from HealthKit
    stepsBestDay:   { val:"15.7k", sub:"steps · Jun 1" },
    stepsBestWeek:  { val:"80.6k", sub:"steps · Oct wk 3" },
    calsBestDay:    { val:"1,240",  sub:"cal · Aug 14" },
    calsBestWeek:   { val:"7.8k",   sub:"cal · Oct wk 3" },
    bestWinStreak:  { val:"4",      sub:"days · Feb 20–23" },
    battleWinRate:  { val:"71%",    sub:"7 wins · 2 losses" },
  },
};

// Days label array for week charts — reusable
const WEEK_DAYS = ["S","M","T","W","T","F","S"];


// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

// iOS-style status bar — static display only
function StatusBar() {
  return (
    <div style={{ height:44, display:"flex", alignItems:"center", justifyContent:"space-between", padding:"0 22px", flexShrink:0 }}>
      <span style={{ fontSize:15, fontWeight:600, color:T.text.primary, fontFamily:T.font.body }}>9:41</span>
      <div style={{ width:120, height:34, background:"#000", borderRadius:20, position:"absolute", left:"50%", transform:"translateX(-50%)", top:8 }}/>
      <div style={{ display:"flex", gap:6, alignItems:"center" }}>
        <div style={{ display:"flex", gap:1.5, alignItems:"flex-end" }}>
          {[3,4,5,6].map(h=><div key={h} style={{ width:3, height:h, background:T.text.primary, borderRadius:1 }}/>)}
        </div>
        <svg width="16" height="12" viewBox="0 0 16 12"><path d="M8 2.5C9.8 2.5 11.4 3.3 12.5 4.5L14 3C12.5 1.4 10.4 0.5 8 0.5C5.6 0.5 3.5 1.4 2 3L3.5 4.5C4.6 3.3 6.2 2.5 8 2.5Z" fill="white"/><path d="M8 5.5C9.1 5.5 10.1 6 10.8 6.8L12.3 5.3C11.2 4.2 9.7 3.5 8 3.5C6.3 3.5 4.8 4.2 3.7 5.3L5.2 6.8C5.9 6 6.9 5.5 8 5.5Z" fill="white"/><circle cx="8" cy="10" r="1.5" fill="white"/></svg>
        <div style={{ width:26, height:13, border:"1.5px solid rgba(255,255,255,0.6)", borderRadius:3, display:"flex", alignItems:"center", padding:"1px 2px" }}>
          <div style={{ flex:1, background:T.text.primary, borderRadius:2, height:"100%" }}/><div style={{ width:2, height:6, background:"rgba(255,255,255,0.4)", borderRadius:1, marginLeft:1 }}/>
        </div>
      </div>
    </div>
  );
}

// ── Avatar chip ──────────────────────────────────────────────────────────────
// initials: 2-char string | color: accent hex | size: px | glow: add glow ring
// rank: optional rank number badge overlay (1=gold, 2=silver, 3=bronze)
function Av({ initials, color, size=36, glow=false, rank }) {
  return (
    <div style={{ position:"relative", flexShrink:0 }}>
      <div style={{ width:size, height:size, borderRadius:T.radius.pill, background:`linear-gradient(135deg,${color}2e,${color}16)`, border:`2px solid ${color}58`, boxShadow:glow?`0 0 18px ${color}55`:"none", display:"flex", alignItems:"center", justifyContent:"center", fontSize:size*0.33, fontWeight:700, color, fontFamily:T.font.display }}>
        {initials}
      </div>
      {rank && <div style={{ position:"absolute", bottom:-4, right:-4, width:18, height:18, borderRadius:T.radius.pill, background:rank===1?T.neon.yellow:rank===2?"rgba(192,210,255,0.9)":T.neon.orange, color:"#000", fontSize:9, fontWeight:900, display:"flex", alignItems:"center", justifyContent:"center" }}>{rank}</div>}
    </div>
  );
}

// ── Neon pill badge ──────────────────────────────────────────────────────────
function Badge({ label, color }) {
  return <span style={neonPill(color)}>{label}</span>;
}

// ── Section heading row with optional action link ────────────────────────────
function SecHead({ title, action, onAction }) {
  return (
    <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", marginBottom:10 }}>
      <span style={{ fontSize:16, fontWeight:700, color:T.text.primary, fontFamily:T.font.display }}>{title}</span>
      {action && <button onClick={onAction} style={{ background:"none", border:"none", padding:0, cursor:"pointer", fontSize:12, color:T.neon.cyan }}>{action}</button>}
    </div>
  );
}

// ── Section label (all-caps, small, dimmed) ──────────────────────────────────
function SLabel({ text, count, action }) {
  return (
    <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", padding:"4px 0 10px" }}>
      <div style={{ display:"flex", alignItems:"center", gap:8 }}>
        <span style={{ fontFamily:T.font.body, fontSize:11, fontWeight:700, letterSpacing:"2px", color:T.text.tertiary }}>{text.toUpperCase()}</span>
        {count !== undefined && (
          <span style={{ ...glassCard("base"), padding:"2px 8px", fontSize:10, fontFamily:T.font.mono, color:T.text.secondary, borderRadius:T.radius.pill }}>{count}</span>
        )}
      </div>
      {action && <span style={{ fontSize:12, fontWeight:600, color:T.neon.cyan, cursor:"pointer" }}>{action}</span>}
    </div>
  );
}

// ── Subtle ambient background blobs (decorative) ─────────────────────────────
function BgBlobs() {
  return (
    <div style={{ position:"absolute", inset:0, overflow:"hidden", pointerEvents:"none", zIndex:0 }}>
      <div style={{ position:"absolute", top:"-15%", left:"-15%", width:"70%", height:"70%", borderRadius:"50%", background:"radial-gradient(circle, rgba(0,255,200,0.055) 0%, transparent 65%)" }}/>
      <div style={{ position:"absolute", bottom:"5%", right:"-20%", width:"75%", height:"60%", borderRadius:"50%", background:"radial-gradient(circle, rgba(0,180,255,0.04) 0%, transparent 65%)" }}/>
      <div style={{ position:"absolute", top:"45%", left:"30%", width:"50%", height:"40%", borderRadius:"50%", background:"radial-gradient(circle, rgba(180,77,255,0.03) 0%, transparent 70%)" }}/>
    </div>
  );
}

// ── Screen slide-in animation wrapper ────────────────────────────────────────
function ScreenIn({ children, id }) {
  const [vis, setVis] = useState(false);
  useEffect(() => { const t=setTimeout(()=>setVis(true),30); return()=>clearTimeout(t); }, [id]);
  return (
    <div style={{ flex:1, overflow:"hidden", display:"flex", flexDirection:"column", opacity:vis?1:0, transform:vis?"translateY(0)":"translateY(12px)", transition:"opacity 0.26s ease, transform 0.26s ease" }}>
      {children}
    </div>
  );
}

// ── Progress bar (used in Health screen HR zones, etc.) ──────────────────────
function ProgressBar({ pct, color=T.neon.cyan, label, value }) {
  return (
    <div style={{ marginBottom:12 }}>
      <div style={{ display:"flex", justifyContent:"space-between", marginBottom:6 }}>
        <span style={{ fontSize:13, color:T.text.secondary, fontFamily:T.font.body }}>{label}</span>
        <span style={{ fontSize:13, color, fontFamily:T.font.mono, fontWeight:700 }}>{value}</span>
      </div>
      <div style={{ height:6, background:"rgba(255,255,255,0.08)", borderRadius:T.radius.pill, overflow:"hidden" }}>
        <div style={{ height:"100%", width:`${pct}%`, background:color, borderRadius:T.radius.pill }}/>
      </div>
    </div>
  );
}

// ── Circular progress ring (Battle Readiness score) ──────────────────────────
// score: 0–100 integer
// color adapts: green ≥75 | yellow 50–74 | red <50
function CircleProgress({ score, size=90 }) {
  const r=(size-12)/2, circ=2*Math.PI*r, offset=circ-(score/100)*circ;
  const color=score>=75?T.neon.cyan:score>=50?T.neon.yellow:T.neon.red;
  return (
    <div style={{ position:"relative", width:size, height:size, flexShrink:0 }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ transform:"rotate(-90deg)" }}>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="8"/>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={color} strokeWidth="8" strokeDasharray={circ} strokeDashoffset={offset} strokeLinecap="round"/>
      </svg>
      <div style={{ position:"absolute", inset:0, display:"flex", flexDirection:"column", alignItems:"center", justifyContent:"center" }}>
        <span style={{ fontFamily:T.font.display, fontSize:28, color, lineHeight:1 }}>{score}</span>
        <span style={{ fontFamily:T.font.mono, fontSize:9, color:T.text.tertiary, marginTop:1 }}>/100</span>
      </div>
    </div>
  );
}

// ── Day bar chart column (used in Match Details day-by-day view) ─────────────
// myVal/theirVal: step/cal counts | myWon: did user win this day
// finalized: day is complete | isToday: currently in-progress day
function DayBar({ day, myVal, theirVal, myWon, finalized, isToday }) {
  const maxVal=Math.max(myVal,theirVal,1), myH=(myVal/maxVal)*80, thH=(theirVal/maxVal)*80;
  return (
    <div style={{ display:"flex", flexDirection:"column", alignItems:"center", gap:4, flex:1 }}>
      <div style={{ display:"flex", gap:3, alignItems:"flex-end", height:80 }}>
        <div style={{ width:12, borderRadius:"4px 4px 0 0", height:`${myH}px`,
          background:finalized?(myWon?T.neon.cyan:"rgba(255,255,255,0.15)"):"rgba(0,255,224,0.5)", position:"relative", overflow:"hidden" }}/>
        <div style={{ width:12, borderRadius:"4px 4px 0 0", height:`${thH}px`,
          background:finalized?(!myWon?T.neon.orange:"rgba(255,255,255,0.12)"):"rgba(255,98,0,0.45)" }}/>
      </div>
      <span style={{ fontSize:10, fontFamily:T.font.mono, color:isToday?T.neon.cyan:T.text.tertiary }}>{day}</span>
      {finalized && <div style={{ width:6, height:6, borderRadius:"50%", background:myWon?T.neon.cyan:T.neon.orange }}/>}
      {isToday && !finalized && <div style={{ width:6, height:6, borderRadius:"50%", background:T.neon.blue }}/>}
    </div>
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAVIGATION
// ── 6 tabs: Home · Activity · ⚔️ BATTLE (center) · Health · Profile · Ranks ─
//
// SOURCE: File 2 (Claude- Use- Health page, and Navigation bar.JSX) layout
//         with Ranks added as a 6th item to the right of Profile.
//
// DESIGN NOTES FOR SWIFT:
//   • The nav bar is a FLOATING CARD — does NOT stretch edge-to-edge
//   • Horizontal padding: 12pt each side | Bottom padding: 10pt (+ safe area inset)
//   • ALL 4 corners are rounded (T.radius.xl = 28pt)
//   • Position: sticky/fixed to bottom, always visible when scrolling
//   • The center ⚔️ button rises ABOVE the bar via negative top offset (-14pt)
//   • Active tab icon: full opacity + neon glow filter
//   • Inactive tab icon: 35% opacity, dim label
//   • Active tab label: T.neon.cyan color
//   • In Swift: use TabView with a custom TabBar overlay, or a sticky ZStack footer
// ─────────────────────────────────────────────────────────────────────────────
function BottomNav({ active, onChange }) {
  // Tab order: Home | Activity | null (center BATTLE btn) | Health | Profile | Ranks
  const tabs = [
    { id:"home",        icon:Home,    label:"HOME"     },
    { id:"activity",    icon:Activity,label:"BATTLES"  },
    null, // ← center ⚔️ BATTLE button placeholder
    { id:"health",      icon:Heart,   label:"HEALTH"   },
    { id:"profile",     icon:User,    label:"PROFILE"  },
    { id:"leaderboard", icon:Trophy,  label:"RANKS"    },
  ];

  return (
    // Outer wrapper: adds horizontal + bottom padding so the card floats off all edges
    <div style={{ padding:"0 12px 10px", flexShrink:0, background:"transparent" }}>
      {/* Floating card */}
      <div style={{
        background:"rgba(5,5,10,0.92)",
        backdropFilter:"blur(28px)",
        WebkitBackdropFilter:"blur(28px)",
        border:"1px solid rgba(255,255,255,0.09)",
        borderRadius:T.radius.xl,                       // all 4 corners rounded — key to "floating" look
        boxShadow:"0 -4px 40px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.04), 0 8px 32px rgba(0,0,0,0.4)",
        height:68,
        display:"flex",
        alignItems:"flex-start",
        paddingTop:10,
        position:"relative",
        overflow:"visible",                             // allows center btn to pop above bar boundary
      }}>
        {tabs.map((tab, i) => {
          if (tab === null) {
            // ── Center ⚔️ BATTLE button ───────────────────────────────────
            // Floats above the nav bar via absolute positioning + negative top
            // In Swift: place as a ZStack overlay with a yOffset of -14
            return (
              <div key="battle" style={{ flex:1, display:"flex", flexDirection:"column", alignItems:"center", gap:3, position:"relative" }}>
                <div
                  onClick={()=>onChange("challenge")}
                  style={{
                    width:54, height:54,
                    borderRadius:18,
                    background:`linear-gradient(135deg, ${T.neon.cyan}, ${T.neon.blue})`,
                    display:"flex", alignItems:"center", justifyContent:"center",
                    fontSize:22,
                    boxShadow:`0 4px 24px rgba(0,255,200,0.4), 0 0 0 3px rgba(5,5,10,0.92)`,
                    cursor:"pointer",
                    position:"absolute",
                    top:-14,                            // rises above bar
                    left:"50%",
                    transform:"translateX(-50%)",
                  }}>
                  ⚔️
                </div>
                {/* Spacer so label sits in the right vertical position */}
                <div style={{ height:30 }}/>
                <span style={{ fontSize:9, fontWeight:700, color:T.text.tertiary, fontFamily:T.font.body, letterSpacing:"0.5px" }}>BATTLE</span>
              </div>
            );
          }
          const ia=active===tab.id, Icon=tab.icon;
          return (
            <button key={tab.id} onClick={()=>onChange(tab.id)} style={{ flex:1, display:"flex", flexDirection:"column", alignItems:"center", gap:4, background:"none", border:"none", cursor:"pointer", padding:"2px 0" }}>
              <span style={{ fontSize:18, opacity:ia?1:0.35, filter:ia?`drop-shadow(0 0 6px ${T.neon.cyan})`:"none", transition:"all 0.2s" }}>
                <Icon size={20} color={ia?T.neon.cyan:"rgba(255,255,255,0.55)"} strokeWidth={ia?2.2:1.8}/>
              </span>
              <span style={{ fontSize:9, fontWeight:700, letterSpacing:"0.5px", color:ia?T.neon.cyan:T.text.tertiary, fontFamily:T.font.body }}>{tab.label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// MATCH CARD  (used on Home screen for each active match)
// ─────────────────────────────────────────────────────────────────────────────
// Props: match (from MATCHES array), onTap (navigate to match details), delay (stagger)
function MatchCard({ match, onTap, delay=0 }) {
  const [in_, setIn]=useState(false);
  useEffect(()=>{ const t=setTimeout(()=>setIn(true),delay+60); return()=>clearTimeout(t); },[]);
  const win=match.winning, accent=win?T.neon.cyan:T.neon.orange;

  return (
    <div onClick={()=>onTap&&onTap(match)} style={{ ...glassCard(win?"win":"lose"), marginBottom:12, cursor:"pointer", opacity:in_?1:0, transform:in_?"translateY(0)":"translateY(14px)", transition:`opacity 0.32s ease ${delay}ms, transform 0.32s ease ${delay}ms` }}>
      {/* Color accent top bar */}
      <div style={{ height:2, background:`linear-gradient(90deg,${accent}88,transparent)` }}/>
      <div style={{ padding:"14px 16px" }}>
        {/* Sport + series + days left */}
        <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", marginBottom:12 }}>
          <div style={{ display:"flex", alignItems:"center", gap:8 }}>
            <Footprints size={13} color={accent}/>
            <span style={{ fontSize:11, fontWeight:700, color:accent, letterSpacing:"0.08em" }}>{match.sport.toUpperCase()}</span>
            <Badge label={match.series} color={accent}/>
          </div>
          <div style={{ display:"flex", alignItems:"center", gap:5 }}>
            <Clock size={10} color={T.text.tertiary}/>
            <span style={{ fontSize:10, color:T.text.tertiary }}>{match.daysLeft}d left</span>
          </div>
        </div>
        {/* You vs opponent row */}
        <div style={{ display:"flex", alignItems:"center", gap:10 }}>
          {/* Your side */}
          <div style={{ flex:1, display:"flex", alignItems:"center", gap:8 }}>
            <Av initials={ME.initials} color={T.neon.cyan} size={38} glow={win}/>
            <div>
              {/* [MOCK DATA] Your name — replace with authenticated user's name */}
              <div style={{ fontSize:13, fontWeight:700, color:T.text.primary, fontFamily:T.font.display }}>You</div>
              {/* [MOCK DATA] myToday — today's step count from HealthKit */}
              <div style={{ fontSize:10, color:T.text.secondary }}>{match.myToday?.toLocaleString()}</div>
            </div>
          </div>
          {/* Score center */}
          <div style={{ display:"flex", flexDirection:"column", alignItems:"center", gap:3 }}>
            <div style={{ display:"flex", alignItems:"center", gap:6, background:"rgba(0,0,0,0.4)", border:"1px solid rgba(255,255,255,0.1)", borderRadius:T.radius.pill, padding:"4px 12px" }}>
              {/* [MOCK DATA] myScore / theirScore — days won so far */}
              <span style={{ fontSize:18, fontWeight:900, color:win?T.neon.cyan:T.neon.orange, fontFamily:T.font.display }}>{match.myScore}</span>
              <span style={{ fontSize:11, color:T.text.tertiary }}>–</span>
              <span style={{ fontSize:18, fontWeight:900, color:T.text.secondary, fontFamily:T.font.display }}>{match.theirScore}</span>
            </div>
            <span style={{ fontSize:9.5, fontWeight:800, color:accent, letterSpacing:"0.1em" }}>{win?"WINNING":"LOSING"}</span>
          </div>
          {/* Opponent side */}
          <div style={{ flex:1, display:"flex", alignItems:"center", gap:8, justifyContent:"flex-end" }}>
            <div style={{ textAlign:"right" }}>
              {/* [MOCK DATA] Opponent name + their today steps — from backend */}
              <div style={{ fontSize:13, fontWeight:700, color:T.text.primary, fontFamily:T.font.display }}>{match.opponent.name}</div>
              <div style={{ fontSize:10, color:T.text.secondary }}>{match.theirToday?.toLocaleString()}</div>
            </div>
            <Av initials={match.opponent.initials} color={match.opponent.color} size={38}/>
          </div>
        </div>
        {/* Day pip indicators — one pip per day */}
        {/* cyan = user won that day | orange = opponent won | dim = future */}
        <div style={{ display:"flex", gap:5, marginTop:12, justifyContent:"center" }}>
          {match.days.map((d,i)=>{
            const isToday=d.winner===null&&d.me!==null, isFuture=d.me===null, meWon=d.winner==="me";
            return <div key={i} style={{ width:isToday?22:16, height:5, borderRadius:3, background:isFuture?"rgba(255,255,255,0.09)":isToday?`${T.neon.cyan}55`:meWon?T.neon.cyan:T.neon.orange, boxShadow:isToday?`0 0 7px ${T.neon.cyan}90`:"none" }}/>;
          })}
        </div>
      </div>
    </div>
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// LIVE MATCH SCREEN  (real-time step race — accessible from active match card)
// ─────────────────────────────────────────────────────────────────────────────
// SOURCE: File 1 (claude - Use Theme...) — preserved exactly.
//
// ACCESS FLOW: Home → tap active MatchCard → Match Details → tap "Watch Live" button
// NOT accessible from the bottom nav tab bar.
//
// In Swift: push this as a sheet or full-screen cover from MatchDetailView.
// The step counters animate via a timer — in production, replace the interval
// with a real-time listener (Firestore/Supabase subscription) to the match document.
//
// [MOCK DATA] myS, thS — initial values are hardcoded starting step counts.
//   Replace with: match.myToday (HealthKit) and match.theirToday (backend).
// [MOCK DATA] Jake T. / JT — replace with actual opponent name/initials from match object.
// [MOCK DATA] Series "Best of 7", score 4–2 — replace with match.series / myScore / theirScore.
// [MOCK DATA] The increment simulation (random +3–18 steps) — replace with
//   real-time polling/subscription to backend step count updates.
function LiveMatchScreen({ onBack }) {
  const GOAL=12000;
  // [MOCK DATA] Starting step counts — replace with match.myToday / match.theirToday
  const [myS, setMyS]=useState(9840);
  const [thS, setThS]=useState(8420);
  const [run, setRun]=useState(true);
  const [flashes, setFlashes]=useState([]);

  const addFlash=useCallback((msg,color)=>{
    const id=Date.now();
    setFlashes(f=>[...f.slice(-2),{id,msg,color}]);
    setTimeout(()=>setFlashes(f=>f.filter(x=>x.id!==id)),2200);
  },[]);

  // [MOCK DATA] This interval simulates live step updates.
  // In Swift: replace with a Firestore/Supabase real-time listener that fires
  // whenever either user's step count updates (backend polling HealthKit).
  useEffect(()=>{
    if(!run)return;
    const t=setInterval(()=>{
      const md=Math.floor(Math.random()*18+3), td=Math.floor(Math.random()*15+1);
      setMyS(s=>{const n=Math.min(s+md,GOAL+1200); if(Math.random()<0.12) addFlash(`+${md} steps! 🔥`,T.neon.cyan); return n;});
      setThS(s=>{const n=Math.min(s+td,GOAL+800);  if(Math.random()<0.06) addFlash(`Jake closing in! ⚡`,T.neon.orange); return n;});
    },500);
    return()=>clearInterval(t);
  },[run,addFlash]);

  const myPct=Math.min(myS/GOAL,1), thPct=Math.min(thS/GOAL,1), lead=myS-thS, winning=lead>=0;

  return (
    <div style={{ flex:1, overflowY:"auto", padding:"0 16px 20px" }}>
      {/* Floating toast notifications for live events */}
      <div style={{ position:"fixed", top:70, left:"50%", transform:"translateX(-50%)", zIndex:100, display:"flex", flexDirection:"column", gap:5, alignItems:"center", pointerEvents:"none", width:280 }}>
        {flashes.map(f=>(
          <div key={f.id} style={{ background:`${f.color}22`, border:`1px solid ${f.color}50`, borderRadius:T.radius.pill, padding:"5px 16px", fontSize:12, fontWeight:700, color:f.color, backdropFilter:"blur(12px)", animation:"flashIn 0.2s ease" }}>{f.msg}</div>
        ))}
      </div>

      {/* Header */}
      <div style={{ paddingTop:8, marginBottom:16, display:"flex", alignItems:"center", gap:10 }}>
        <button onClick={onBack} style={{ background:"none", border:"none", color:T.neon.cyan, cursor:"pointer", padding:0 }}>
          <ChevronLeft size={20}/>
        </button>
        <span style={{ fontSize:18, fontWeight:800, color:T.text.primary, fontFamily:T.font.display, flex:1 }}>Live Match</span>
        {/* LIVE / PAUSED badge */}
        <Badge label={run?"● LIVE":"PAUSED"} color={run?T.neon.green:T.neon.orange}/>
      </div>

      {/* VS Hero card — real-time step counters */}
      <div style={{ ...glassCard(winning?"win":"lose"), marginBottom:16 }}>
        <div style={{ height:2, background:`linear-gradient(90deg,${winning?T.neon.cyan:T.neon.orange}90,transparent)` }}/>
        <div style={{ padding:"20px 16px 18px" }}>
          <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", marginBottom:20 }}>
            {/* Your side */}
            <div style={{ display:"flex", flexDirection:"column", alignItems:"center", gap:5 }}>
              <Av initials={ME.initials} color={T.neon.cyan} size={54} glow={winning}/>
              {/* [MOCK DATA] "You" — authenticated user */}
              <span style={{ fontSize:12, fontWeight:700, color:T.text.primary }}>You</span>
              {/* [MOCK DATA] myS — live step count, updating in real time */}
              <span style={{ fontSize:22, fontWeight:900, color:T.neon.cyan, fontFamily:T.font.display, lineHeight:1 }}>{myS.toLocaleString()}</span>
              <span style={{ fontSize:10, color:T.text.secondary }}>steps</span>
            </div>
            {/* Center VS + lead/behind indicator */}
            <div style={{ display:"flex", flexDirection:"column", alignItems:"center", gap:4 }}>
              <div style={{ fontSize:20, fontWeight:900, background:`linear-gradient(180deg,${winning?T.neon.cyan:T.neon.orange},${winning?T.neon.cyan+"60":T.neon.orange+"60"})`, WebkitBackgroundClip:"text", WebkitTextFillColor:"transparent", fontFamily:T.font.display }}>VS</div>
              {/* [MOCK DATA] lead = myS - thS */}
              <div style={{ fontSize:11, fontWeight:800, color:winning?T.neon.cyan:T.neon.orange }}>{Math.abs(lead).toLocaleString()} {winning?"ahead":"behind"}</div>
            </div>
            {/* Opponent side */}
            {/* [MOCK DATA] "JT" / "Jake T." — replace with match.opponent.initials / name */}
            <div style={{ display:"flex", flexDirection:"column", alignItems:"center", gap:5 }}>
              <Av initials="JT" color={T.neon.orange} size={54} glow={!winning}/>
              <span style={{ fontSize:12, fontWeight:700, color:T.text.primary }}>Jake T.</span>
              {/* [MOCK DATA] thS — opponent's live step count from backend */}
              <span style={{ fontSize:22, fontWeight:900, color:T.neon.orange, fontFamily:T.font.display, lineHeight:1 }}>{thS.toLocaleString()}</span>
              <span style={{ fontSize:10, color:T.text.secondary }}>steps</span>
            </div>
          </div>

          {/* Progress race bars — shows % toward daily goal */}
          {/* [MOCK DATA] GOAL = 12000 — in production use user's personal step goal */}
          <div>
            <div style={{ display:"flex", justifyContent:"space-between", marginBottom:5 }}>
              <span style={{ fontSize:9, color:T.text.tertiary }}>0</span>
              <span style={{ fontSize:9, color:T.text.tertiary }}>Goal: {GOAL.toLocaleString()}</span>
            </div>
            {[[myPct,"You",T.neon.cyan],[thPct,"Jake",T.neon.orange]].map(([pct,label,col],i)=>(
              <div key={i} style={{ position:"relative", height:22, marginBottom:i===0?6:0 }}>
                <div style={{ position:"absolute", inset:0, background:"rgba(255,255,255,0.06)", borderRadius:11 }}/>
                <div style={{ position:"absolute", left:0, top:0, height:"100%", width:`${pct*100}%`, background:`linear-gradient(90deg,${col}cc,${col}80)`, borderRadius:11, boxShadow:`0 0 14px ${col}70`, transition:"width 0.4s ease" }}/>
                <div style={{ position:"absolute", inset:0, display:"flex", alignItems:"center", paddingLeft:10 }}>
                  <span style={{ fontSize:10, fontWeight:800, color:"#000" }}>{label} · {Math.round(pct*100)}%</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Pause / Resume simulation toggle */}
      {/* In Swift: this is not needed — replace with a "Refresh" or auto-live indicator */}
      <button onClick={()=>setRun(r=>!r)} style={{ width:"100%", padding:"13px", borderRadius:T.radius.md, marginBottom:14, background:run?`${T.neon.orange}18`:`${T.neon.cyan}18`, border:`1px solid ${run?T.neon.orange:T.neon.cyan}45`, color:run?T.neon.orange:T.neon.cyan, fontWeight:800, fontSize:15, cursor:"pointer", display:"flex", alignItems:"center", justifyContent:"center", gap:8 }}>
        {run?<><Pause size={16}/>Pause Simulation</>:<><Play size={16}/>Resume Simulation</>}
      </button>

      {/* Series score indicator */}
      {/* [MOCK DATA] 4–2 Best of 7 — replace with match.myScore / theirScore / series */}
      <div style={{ ...glassCard("base"), padding:"14px 16px" }}>
        <div style={{ fontSize:11, fontWeight:700, color:T.text.secondary, marginBottom:8, letterSpacing:"0.08em" }}>SERIES · BEST OF 7</div>
        <div style={{ display:"flex", alignItems:"center", gap:12 }}>
          <span style={{ fontSize:32, fontWeight:900, color:T.neon.cyan, fontFamily:T.font.display }}>4</span>
          <div style={{ flex:1, display:"flex", gap:4, justifyContent:"center" }}>
            {/* [MOCK DATA] [1,1,1,1,0,0,0] = 4 wins, 2 losses, 1 remaining */}
            {[1,1,1,1,0,0,0].map((r,i)=>(
              <div key={i} style={{ width:14, height:14, borderRadius:T.radius.pill, background:r===1?T.neon.cyan:"rgba(255,255,255,0.1)", boxShadow:r===1?`0 0 6px ${T.neon.cyan}`:"none" }}/>
            ))}
          </div>
          <span style={{ fontSize:32, fontWeight:900, color:T.neon.orange, fontFamily:T.font.display }}>2</span>
        </div>
        <div style={{ display:"flex", justifyContent:"space-between", marginTop:4 }}>
          <span style={{ fontSize:10, color:T.text.secondary }}>You</span>
          {/* [MOCK DATA] opponent name */}
          <span style={{ fontSize:10, color:T.text.secondary }}>Jake T.</span>
        </div>
      </div>
    </div>
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────────────────────────
function HomeScreen({ onMatchTap, onChallenge }) {
  const active  = MATCHES.filter(m=>m.status==="active");
  const pending = MATCHES.filter(m=>m.status==="pending_incoming");
  const searching=MATCHES.filter(m=>m.status==="searching");
  const [dots,setDots]=useState(0);
  useEffect(()=>{ const t=setInterval(()=>setDots(d=>(d+1)%4),600); return()=>clearInterval(t); },[]);

  return (
    <div style={{ flex:1, overflowY:"auto", padding:"0 16px 20px" }}>
      {/* Header row */}
      <div style={{ padding:"8px 0 16px", display:"flex", justifyContent:"space-between", alignItems:"center" }}>
        <div>
          {/* App wordmark */}
          <div style={{ fontSize:27, fontWeight:900, fontFamily:T.font.display, letterSpacing:"-0.5px" }}>
            <span style={{ background:`linear-gradient(90deg,${T.neon.cyan},${T.neon.blue})`, WebkitBackgroundClip:"text", WebkitTextFillColor:"transparent" }}>FIT</span>
            <span style={{ background:`linear-gradient(90deg,${T.neon.orange},${T.neon.yellow})`, WebkitBackgroundClip:"text", WebkitTextFillColor:"transparent" }}>UP</span>
          </div>
          {/* [MOCK DATA] User's first name — from authenticated user profile */}
          <div style={{ fontSize:12, color:T.text.secondary }}>Let's go, Marcus 👊</div>
        </div>
        <div style={{ display:"flex", gap:10 }}>
          {/* Notifications bell */}
          <button style={{ width:36, height:36, borderRadius:T.radius.pill, ...glassCard("base"), display:"flex", alignItems:"center", justifyContent:"center", cursor:"pointer", border:"1px solid rgba(255,255,255,0.09)" }}>
            <Bell size={16} color={T.text.secondary}/>
          </button>
          {/* Quick challenge button → opens challenge flow */}
          <button onClick={onChallenge} style={{ width:36, height:36, borderRadius:T.radius.pill, background:`${T.neon.cyan}22`, border:`1px solid ${T.neon.cyan}45`, display:"flex", alignItems:"center", justifyContent:"center", cursor:"pointer" }}>
            <Plus size={18} color={T.neon.cyan}/>
          </button>
        </div>
      </div>

      {/* Active matches */}
      {/* [MOCK DATA] active[] — real-time match list from backend */}
      <div style={{ marginBottom:20 }}>
        <SecHead title="Active Matches" action={`${active.length} live`}/>
        {active.map((m,i)=><MatchCard key={m.id} match={m} onTap={onMatchTap} delay={i*80}/>)}
      </div>

      {/* Incoming challenge requests */}
      {/* [MOCK DATA] pending[] — challenge requests sent to this user */}
      {pending.length>0&&(
        <div style={{ marginBottom:20 }}>
          <SecHead title="Incoming Challenges" action={`${pending.length} new`}/>
          {pending.map(m=>(
            <div key={m.id} style={{ ...glassCard("pending"), marginBottom:10 }}>
              <div style={{ padding:"12px 14px", display:"flex", alignItems:"center", gap:12 }}>
                <Av initials={m.opponent.initials} color={m.opponent.color} size={40}/>
                <div style={{ flex:1 }}>
                  <div style={{ fontSize:14, fontWeight:700, color:T.text.primary, fontFamily:T.font.display }}>{m.opponent.name}</div>
                  <div style={{ fontSize:11, color:T.text.secondary }}>{m.sport} · {m.series}</div>
                </div>
                <div style={{ display:"flex", gap:8 }}>
                  {/* Decline */}
                  <button style={{ width:34, height:34, borderRadius:T.radius.pill, background:`${T.neon.pink}18`, border:`1px solid ${T.neon.pink}40`, color:T.neon.pink, display:"flex", alignItems:"center", justifyContent:"center", cursor:"pointer" }}><X size={15}/></button>
                  {/* Accept */}
                  <button style={{ width:34, height:34, borderRadius:T.radius.pill, background:`${T.neon.cyan}18`, border:`1px solid ${T.neon.cyan}40`, color:T.neon.cyan, display:"flex", alignItems:"center", justifyContent:"center", cursor:"pointer" }}><Check size={15}/></button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Matchmaking in progress */}
      {/* [MOCK DATA] searching[] — random matchmaking queue entry */}
      {searching.length>0&&(
        <div style={{ marginBottom:20 }}>
          <SecHead title="Matchmaking"/>
          {searching.map(m=>(
            <div key={m.id} style={{ ...glassCard("base"), marginBottom:10 }}>
              <div style={{ padding:"12px 14px", display:"flex", alignItems:"center", gap:12 }}>
                <div style={{ width:40, height:40, borderRadius:T.radius.pill, background:`${T.neon.purple}18`, border:`1px solid ${T.neon.purple}35`, display:"flex", alignItems:"center", justifyContent:"center" }}>
                  <Search size={17} color={T.neon.purple}/>
                </div>
                {/* [MOCK DATA] waitTime — time elapsed, from local timer */}
                <div style={{ flex:1 }}>
                  <div style={{ fontSize:13, fontWeight:700, color:T.text.primary, fontFamily:T.font.display }}>Finding opponent{"." .repeat(dots)}</div>
                  <div style={{ fontSize:11, color:T.text.secondary }}>{m.sport} · {m.series} · {m.waitTime}</div>
                </div>
                <button style={{ padding:"6px 12px", borderRadius:T.radius.pill, background:"rgba(255,255,255,0.05)", border:"1px solid rgba(255,255,255,0.1)", color:T.text.secondary, fontSize:12, cursor:"pointer" }}>Cancel</button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Discover players to challenge */}
      {/* [MOCK DATA] DISCOVER — suggested opponents from backend (skill-matched) */}
      <div style={{ marginBottom:20 }}>
        <SecHead title="Discover Players" action="See All"/>
        {DISCOVER.map((u,i)=>(
          <div key={i} style={{ ...glassCard("base"), padding:"12px 14px", marginBottom:8, display:"flex", alignItems:"center", gap:12 }}>
            <Av initials={u.initials} color={u.color} size={38}/>
            <div style={{ flex:1 }}>
              <div style={{ fontSize:13, fontWeight:700, color:T.text.primary, fontFamily:T.font.display }}>{u.name}</div>
              {/* [MOCK DATA] steps = their today's step count | wins/losses = their record */}
              <div style={{ fontSize:11, color:T.text.secondary }}>{u.steps.toLocaleString()} steps · {u.wins}W {u.losses}L</div>
            </div>
            <button onClick={onChallenge} style={{ padding:"7px 14px", fontSize:12, ...ghostBtn(T.neon.cyan) }}>
              <Zap size={11} style={{ display:"inline", marginRight:4 }}/>Challenge
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// MATCH DETAILS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
// Shows 3 states via toggle: active | pending | completed
// In Swift: this is a single MatchDetailView with a match object passed in
// onLive: navigate to LiveMatchScreen (only shown for active matches)
function MatchDetailsScreen({ onBack, onLive }) {
  const [variant, setVariant]=useState("active");
  const match=variant==="completed"?MATCHES[5]:variant==="pending"?MATCHES[2]:MATCHES[0];
  const isP=variant==="pending", isC=variant==="completed", isA=variant==="active";
  const win=isC?true:isA?MATCHES[0].winning:false;
  const accent=win?T.neon.cyan:T.neon.orange;
  // Days with data (filter out future null days)
  const cd=(isA||isC)?(match.days||[]).filter(d=>d.me!==null):[{day:"M",me:9200,them:11400},{day:"T",me:8700,them:10200}];

  return (
    <div style={{ flex:1, overflowY:"auto", padding:"0 16px 20px" }}>
      {/* Back + state toggle (demo only — in Swift, pass variant as route param) */}
      <div style={{ paddingTop:8, marginBottom:14, display:"flex", flexDirection:"column", gap:10 }}>
        <button onClick={onBack} style={{ background:"none", border:"none", display:"flex", alignItems:"center", gap:6, color:T.neon.cyan, cursor:"pointer", padding:0, fontSize:13 }}>
          <ChevronLeft size={16}/> Back
        </button>
        {/* State switcher — demo only */}
        <div style={{ display:"flex", gap:6 }}>
          {["active","pending","completed"].map(v=>(
            <button key={v} onClick={()=>setVariant(v)} style={{ flex:1, padding:"7px 0", borderRadius:T.radius.pill, background:variant===v?`${T.neon.cyan}1e`:"rgba(255,255,255,0.05)", border:variant===v?`1px solid ${T.neon.cyan}50`:"1px solid rgba(255,255,255,0.08)", color:variant===v?T.neon.cyan:T.text.secondary, fontSize:11, fontWeight:700, cursor:"pointer", letterSpacing:"0.06em", textTransform:"capitalize" }}>{v}</button>
          ))}
        </div>
      </div>

      {/* Score hero card */}
      <div style={{ ...glassCard(win?"win":"base"), marginBottom:14 }}>
        <div style={{ height:2, background:`linear-gradient(90deg,${accent}80,transparent)` }}/>
        <div style={{ padding:"16px" }}>
          <div style={{ display:"flex", justifyContent:"center", marginBottom:12 }}>
            <Badge label={`${isP?"INCOMING · ":""}${(match.sport||"STEPS").toUpperCase()} · ${(match.series||"Best of 5").toUpperCase()}`} color={isP?T.neon.blue:accent}/>
          </div>
          <div style={{ display:"flex", alignItems:"center" }}>
            {/* Your side */}
            <div style={{ flex:1, display:"flex", flexDirection:"column", alignItems:"center", gap:6 }}>
              <Av initials={ME.initials} color={T.neon.cyan} size={52} glow={win&&!isP}/>
              <span style={{ fontSize:14, fontWeight:700, color:T.text.primary, fontFamily:T.font.display }}>You</span>
              {/* [MOCK DATA] myScore — days won by user */}
              {!isP&&<div style={{ fontSize:24, fontWeight:900, color:win?T.neon.cyan:T.text.secondary, fontFamily:T.font.display }}>{match.myScore}</div>}
              {/* [MOCK DATA] myToday — today's steps from HealthKit */}
              {isA&&<div style={{ fontSize:10, color:T.text.secondary }}>{match.myToday?.toLocaleString()} today</div>}
            </div>
            {/* VS center */}
            <div style={{ display:"flex", flexDirection:"column", alignItems:"center", gap:5 }}>
              <div style={{ fontSize:20, fontWeight:900, letterSpacing:"0.15em", background:`linear-gradient(180deg,${accent},${accent}60)`, WebkitBackgroundClip:"text", WebkitTextFillColor:"transparent", fontFamily:T.font.display }}>VS</div>
              {isC&&<Badge label="🏆 WINNER" color={T.neon.cyan}/>}
            </div>
            {/* Opponent side */}
            <div style={{ flex:1, display:"flex", flexDirection:"column", alignItems:"center", gap:6 }}>
              <Av initials={match.opponent?.initials||"??"} color={match.opponent?.color||T.neon.orange} size={52} glow={!win&&isC}/>
              <span style={{ fontSize:14, fontWeight:700, color:T.text.primary, fontFamily:T.font.display }}>{match.opponent?.name||"???"}</span>
              {/* [MOCK DATA] theirScore — days won by opponent (from backend) */}
              {!isP&&<div style={{ fontSize:24, fontWeight:900, color:!win?T.neon.orange:T.text.secondary, fontFamily:T.font.display }}>{match.theirScore}</div>}
              {/* [MOCK DATA] theirToday — opponent's today steps (from backend sync) */}
              {isA&&<div style={{ fontSize:10, color:T.text.secondary }}>{match.theirToday?.toLocaleString()} today</div>}
            </div>
          </div>

          {/* Pending accept/decline */}
          {isP&&<div style={{ display:"flex", gap:10, marginTop:16 }}>
            <button style={{ flex:1, padding:"12px", borderRadius:T.radius.md, background:`${T.neon.pink}12`, border:`1px solid ${T.neon.pink}35`, color:T.neon.pink, fontWeight:700, fontSize:14, cursor:"pointer" }}>Decline</button>
            <button style={{ flex:2, padding:"12px", ...solidBtn(T.neon.cyan), fontSize:14 }}><Zap size={13} style={{ display:"inline", marginRight:6 }}/>Accept Challenge</button>
          </div>}

          {/* Completed rematch */}
          {isC&&<button style={{ width:"100%", padding:"12px", marginTop:16, ...solidBtn(T.neon.orange), fontSize:14 }}><RotateCcw size={13} style={{ display:"inline", marginRight:6 }}/>Rematch</button>}

          {/* ── Watch Live button — only shown for ACTIVE matches ── */}
          {/* Tapping this navigates to LiveMatchScreen (not in nav tab bar) */}
          {/* In Swift: present LiveMatchView as a sheet or navigationLink push */}
          {isA&&(
            <button
              onClick={onLive}
              style={{ width:"100%", padding:"12px", marginTop:12, display:"flex", alignItems:"center", justifyContent:"center", gap:8, borderRadius:T.radius.md, background:`${T.neon.green}18`, border:`1px solid ${T.neon.green}45`, color:T.neon.green, fontWeight:800, fontSize:14, cursor:"pointer" }}>
              <span style={{ width:8, height:8, borderRadius:"50%", background:T.neon.green, boxShadow:`0 0 6px ${T.neon.green}`, display:"inline-block" }}/>
              Watch Live ⚡
            </button>
          )}
        </div>
      </div>

      {/* Day-by-day chart (recharts BarChart) */}
      {/* [MOCK DATA] cd — array of {day, me, them, winner} per completed day */}
      {!isP&&cd.length>0&&(
        <div style={{ ...glassCard("base"), marginBottom:14, padding:"16px 14px" }}>
          <div style={{ fontSize:11, fontWeight:700, color:T.text.secondary, marginBottom:12, letterSpacing:"0.08em" }}>DAY-BY-DAY BREAKDOWN</div>
          <ResponsiveContainer width="100%" height={110}>
            <BarChart data={cd} barSize={9} barGap={2}>
              <XAxis dataKey="day" tick={{ fill:T.text.tertiary, fontSize:10 }} axisLine={false} tickLine={false}/>
              <YAxis hide/>
              <Tooltip contentStyle={{ background:"rgba(4,4,10,0.97)", border:`1px solid ${T.neon.cyan}30`, borderRadius:8, fontSize:11, color:T.text.primary }}/>
              {/* [MOCK DATA] "me" key = user's step count per day */}
              <Bar dataKey="me" name="You" fill={T.neon.cyan} radius={[3,3,0,0]} opacity={0.85}/>
              {/* [MOCK DATA] "them" key = opponent's step count per day */}
              <Bar dataKey="them" name="Them" fill={match.opponent?.color||T.neon.orange} radius={[3,3,0,0]} opacity={0.85}/>
            </BarChart>
          </ResponsiveContainer>
          <div style={{ display:"flex", gap:16, justifyContent:"center", marginTop:6 }}>
            {[["You",T.neon.cyan],[match.opponent?.name||"Opp",match.opponent?.color||T.neon.orange]].map(([l,c])=>(
              <div key={l} style={{ display:"flex", gap:5, alignItems:"center" }}>
                <div style={{ width:8, height:8, borderRadius:2, background:c }}/>
                <span style={{ fontSize:10, color:T.text.secondary }}>{l}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Day-by-day results list */}
      {!isP&&cd.length>0&&(
        <div style={{ ...glassCard("base"), marginBottom:14 }}>
          <div style={{ padding:"12px 14px" }}>
            <div style={{ fontSize:11, fontWeight:700, color:T.text.secondary, marginBottom:8, letterSpacing:"0.08em" }}>RESULTS</div>
            {cd.map((d,i)=>{
              const mw=d.winner==="me", tied=d.winner===null&&d.me!==null;
              return (
                <div key={i} style={{ display:"flex", alignItems:"center", gap:10, padding:i>0?"10px 0 10px":"0 0 10px", borderBottom:i<cd.length-1?"1px solid rgba(255,255,255,0.05)":"none" }}>
                  <span style={{ fontSize:12, color:T.text.tertiary, width:28 }}>{d.day}</span>
                  <div style={{ flex:1, display:"flex", alignItems:"center", gap:4 }}>
                    <div style={{ width:`${mw||tied?60:35}%`, height:4, background:mw||tied?T.neon.cyan:"rgba(255,255,255,0.1)", borderRadius:2 }}/>
                    <div style={{ flex:1, height:4, background:!mw?match.opponent?.color||T.neon.orange:"rgba(255,255,255,0.1)", borderRadius:2 }}/>
                  </div>
                  <span style={{ fontSize:10, color:mw?T.neon.cyan:match.opponent?.color||T.neon.orange, fontWeight:700, width:55, textAlign:"right" }}>{d.me?.toLocaleString()}</span>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// CHALLENGE CREATION FLOW  (multi-step)
// ─────────────────────────────────────────────────────────────────────────────
// Step 0: Choose sport (Steps / Calories)
// Step 1: Choose format (Best of 5/7, First to 3, Daily)
// Step 2: Choose opponent (search or quick match)
// Step 3: Review + send
// Sent state: confirmation screen
function ChallengeScreen({ onBack, onDone }) {
  const [step,setStep]=useState(0);
  const [sport,setSport]=useState(null);
  const [format,setFormat]=useState(null);
  const [opponent,setOpponent]=useState(null);
  const [query,setQuery]=useState("");
  const [sending,setSending]=useState(false);
  const [sent,setSent]=useState(false);

  const sports=[
    { id:"steps",    label:"Steps",    icon:Footprints, color:T.neon.cyan,   desc:"Daily step count battle" },
    { id:"calories", label:"Calories", icon:Flame,      color:T.neon.orange, desc:"Active calorie burn-off" },
  ];
  const formats=[
    { id:"best5",  label:"Best of 5",  sub:"First to 3 wins",     color:T.neon.cyan   },
    { id:"best7",  label:"Best of 7",  sub:"First to 4 wins",     color:T.neon.blue   },
    { id:"first3", label:"First to 3", sub:"Race to 3 victories",  color:T.neon.purple },
    { id:"daily",  label:"Daily",      sub:"Single day showdown",  color:T.neon.yellow },
  ];
  // [MOCK DATA] results — filter of DISCOVER players by search query
  const results=DISCOVER.filter(u=>u.name.toLowerCase().includes(query.toLowerCase())||!query);
  const handleSend=()=>{ setSending(true); setTimeout(()=>{ setSending(false); setSent(true); },1400); };

  return (
    <div style={{ flex:1, overflowY:"auto", padding:"0 16px 20px" }}>
      {/* Header */}
      <div style={{ paddingTop:8, marginBottom:16, display:"flex", alignItems:"center", gap:10 }}>
        <button onClick={step===0?onBack:()=>setStep(s=>s-1)} style={{ background:"none", border:"none", color:T.neon.cyan, cursor:"pointer", padding:0 }}>
          <ChevronLeft size={20}/>
        </button>
        <span style={{ fontSize:18, fontWeight:800, color:T.text.primary, fontFamily:T.font.display, flex:1 }}>New Challenge</span>
        <Swords size={18} color={T.neon.cyan}/>
      </div>

      {/* Progress stepper */}
      {!sent&&(
        <div style={{ display:"flex", gap:6, marginBottom:20 }}>
          {["Sport","Format","Opponent","Send"].map((l,i)=>(
            <div key={i} style={{ flex:1, display:"flex", flexDirection:"column", alignItems:"center", gap:3 }}>
              <div style={{ height:3, width:"100%", borderRadius:2, background:i<=step?T.neon.cyan:"rgba(255,255,255,0.1)", boxShadow:i===step?`0 0 8px ${T.neon.cyan}`:"none", transition:"all 0.3s" }}/>
              <span style={{ fontSize:9, color:i===step?T.neon.cyan:T.text.tertiary, fontWeight:700, letterSpacing:"0.06em" }}>{l.toUpperCase()}</span>
            </div>
          ))}
        </div>
      )}

      {/* Step 0: Choose sport */}
      {step===0&&!sent&&(
        <div>
          <div style={{ fontSize:14, color:T.text.secondary, marginBottom:16 }}>What are you competing in?</div>
          <div style={{ display:"flex", flexDirection:"column", gap:10 }}>
            {sports.map(s=>(
              <button key={s.id} onClick={()=>{ setSport(s.id); setStep(1); }} style={{ ...glassCard("base"), padding:"18px 16px", display:"flex", alignItems:"center", gap:14, cursor:"pointer", border:`1px solid ${s.color}28`, textAlign:"left", transition:"all 0.2s" }}>
                <div style={{ width:46, height:46, borderRadius:T.radius.md, background:`${s.color}18`, border:`1px solid ${s.color}35`, display:"flex", alignItems:"center", justifyContent:"center" }}>
                  <s.icon size={22} color={s.color}/>
                </div>
                <div>
                  <div style={{ fontSize:16, fontWeight:700, color:T.text.primary, fontFamily:T.font.display }}>{s.label}</div>
                  <div style={{ fontSize:12, color:T.text.secondary }}>{s.desc}</div>
                </div>
                <ChevronRight size={16} color={T.text.tertiary} style={{ marginLeft:"auto" }}/>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Step 1: Choose format */}
      {step===1&&!sent&&(
        <div>
          <div style={{ fontSize:14, color:T.text.secondary, marginBottom:16 }}>Choose match format</div>
          <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:10 }}>
            {formats.map(f=>(
              <button key={f.id} onClick={()=>{ setFormat(f.id); setStep(2); }} style={{ ...glassCard("base"), padding:"16px 12px", border:`1px solid ${f.color}28`, cursor:"pointer", textAlign:"center", transition:"all 0.2s" }}>
                <div style={{ fontSize:15, fontWeight:800, color:f.color, fontFamily:T.font.display, marginBottom:4 }}>{f.label}</div>
                <div style={{ fontSize:11, color:T.text.secondary }}>{f.sub}</div>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Step 2: Choose opponent */}
      {step===2&&!sent&&(
        <div>
          <div style={{ fontSize:14, color:T.text.secondary, marginBottom:12 }}>Who do you want to challenge?</div>
          {/* Search input */}
          <div style={{ display:"flex", alignItems:"center", gap:8, marginBottom:14, ...glassCard("base"), padding:"10px 12px" }}>
            <Search size={15} color={T.text.tertiary}/>
            {/* [MOCK DATA] search filters DISCOVER list — replace with backend search */}
            <input value={query} onChange={e=>setQuery(e.target.value)} placeholder="Search players..." style={{ flex:1, background:"none", border:"none", outline:"none", color:T.text.primary, fontSize:14, fontFamily:T.font.body }}/>
          </div>
          <div style={{ display:"flex", flexDirection:"column", gap:8 }}>
            {/* Quick random match */}
            <button onClick={()=>{ setOpponent({name:"Random Opponent",initials:"??",color:T.neon.purple}); setStep(3); }} style={{ ...glassCard("pending"), padding:"12px 14px", display:"flex", alignItems:"center", gap:12, cursor:"pointer", textAlign:"left" }}>
              <div style={{ width:40, height:40, borderRadius:T.radius.pill, background:`${T.neon.purple}18`, border:`1px solid ${T.neon.purple}35`, display:"flex", alignItems:"center", justifyContent:"center" }}>
                <Search size={18} color={T.neon.purple}/>
              </div>
              <div>
                <div style={{ fontSize:13, fontWeight:700, color:T.text.primary }}>Quick Match</div>
                <div style={{ fontSize:11, color:T.text.secondary }}>Find best available opponent</div>
              </div>
              <Zap size={14} color={T.neon.purple} style={{ marginLeft:"auto" }}/>
            </button>
            {/* [MOCK DATA] results — skill-matched player list from backend */}
            {results.map((u,i)=>(
              <button key={i} onClick={()=>{ setOpponent(u); setStep(3); }} style={{ ...glassCard("base"), padding:"12px 14px", display:"flex", alignItems:"center", gap:12, cursor:"pointer", textAlign:"left" }}>
                <Av initials={u.initials} color={u.color} size={38}/>
                <div style={{ flex:1 }}>
                  <div style={{ fontSize:13, fontWeight:700, color:T.text.primary }}>{u.name}</div>
                  <div style={{ fontSize:11, color:T.text.secondary }}>{u.wins}W · {u.losses}L · {u.steps.toLocaleString()} today</div>
                </div>
                <ChevronRight size={14} color={T.text.tertiary}/>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Step 3: Review + send */}
      {step===3&&opponent&&!sent&&(
        <div>
          <div style={{ ...glassCard("win"), marginBottom:16, padding:"20px 16px", textAlign:"center" }}>
            <div style={{ display:"flex", justifyContent:"center", alignItems:"center", gap:16, marginBottom:16 }}>
              <div style={{ display:"flex", flexDirection:"column", alignItems:"center", gap:6 }}>
                <Av initials={ME.initials} color={T.neon.cyan} size={50} glow/>
                <span style={{ fontSize:12, fontWeight:700, color:T.text.primary }}>You</span>
              </div>
              <div style={{ fontSize:20, fontWeight:900, color:T.neon.cyan, fontFamily:T.font.display }}>VS</div>
              <div style={{ display:"flex", flexDirection:"column", alignItems:"center", gap:6 }}>
                <Av initials={opponent.initials} color={opponent.color||T.neon.purple} size={50}/>
                {/* [MOCK DATA] opponent.name — selected opponent from Step 2 */}
                <span style={{ fontSize:12, fontWeight:700, color:T.text.primary }}>{opponent.name}</span>
              </div>
            </div>
            <div style={{ display:"flex", gap:8, justifyContent:"center", flexWrap:"wrap" }}>
              <Badge label={(sports.find(s=>s.id===sport)||sports[0]).label} color={T.neon.cyan}/>
              <Badge label={(formats.find(f=>f.id===format)||formats[0]).label} color={T.neon.blue}/>
            </div>
          </div>
          <button onClick={handleSend} style={{ width:"100%", padding:"15px", ...solidBtn(T.neon.cyan), fontSize:16, display:"flex", alignItems:"center", justifyContent:"center", gap:8, opacity:sending?0.7:1, transition:"opacity 0.2s" }}>
            {sending
              ? <><div style={{ width:16, height:16, borderRadius:"50%", border:"2px solid #000", borderTop:"2px solid transparent", animation:"spin 0.7s linear infinite" }}/>Sending...</>
              : <><Zap size={16}/>Send Challenge!</>
            }
          </button>
        </div>
      )}

      {/* Sent confirmation */}
      {sent&&(
        <div style={{ textAlign:"center", padding:"30px 0" }}>
          <div style={{ fontSize:60, marginBottom:16 }}>⚡</div>
          <div style={{ fontSize:22, fontWeight:900, color:T.neon.cyan, fontFamily:T.font.display, marginBottom:6 }}>Challenge Sent!</div>
          {/* [MOCK DATA] opponent.name — name of challenged player */}
          <div style={{ fontSize:14, color:T.text.secondary, marginBottom:24 }}>Waiting for {opponent?.name} to accept...</div>
          <Badge label={`${(sports.find(s=>s.id===sport)||sports[0]).label} · ${(formats.find(f=>f.id===format)||formats[0]).label}`} color={T.neon.cyan}/>
          <div style={{ marginTop:28 }}>
            <button onClick={onDone} style={{ padding:"13px 32px", ...ghostBtn(T.neon.cyan), fontSize:14 }}>Back to Home</button>
          </div>
        </div>
      )}
    </div>
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// LEADERBOARD / RANKS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
function LeaderboardScreen() {
  const [tab,setTab]=useState("global");
  const podium=LEADERBOARD.slice(0,3), rest=LEADERBOARD.slice(3);
  // [MOCK DATA] me — current user's leaderboard entry
  const me=LEADERBOARD.find(u=>u.isMe);

  return (
    <div style={{ flex:1, overflowY:"auto", padding:"0 16px 20px" }}>
      {/* Header */}
      <div style={{ paddingTop:10, paddingBottom:14, display:"flex", justifyContent:"space-between", alignItems:"center" }}>
        <div>
          <span style={{ fontSize:22, fontWeight:800, color:T.text.primary, fontFamily:T.font.display }}>Leaderboard</span>
          {/* [MOCK DATA] date range — current week, computed dynamically */}
          <div style={{ fontSize:11, color:T.text.secondary }}>Week of Mar 16 – 22</div>
        </div>
        <Badge label="LIVE" color={T.neon.green}/>
      </div>

      {/* Global / Friends toggle */}
      <div style={{ display:"flex", gap:6, marginBottom:18 }}>
        {["global","friends"].map(t=>(
          <button key={t} onClick={()=>setTab(t)} style={{ flex:1, padding:"7px 0", borderRadius:T.radius.pill, background:tab===t?`${T.neon.cyan}1e`:"rgba(255,255,255,0.05)", border:tab===t?`1px solid ${T.neon.cyan}50`:"1px solid rgba(255,255,255,0.08)", color:tab===t?T.neon.cyan:T.text.secondary, fontSize:12, fontWeight:700, cursor:"pointer", textTransform:"capitalize" }}>{t}</button>
        ))}
      </div>

      {/* Podium — top 3 */}
      {/* [MOCK DATA] podium — top 3 entries from LEADERBOARD */}
      <div style={{ display:"flex", alignItems:"flex-end", justifyContent:"center", gap:8, marginBottom:20, paddingTop:16 }}>
        {/* 2nd place */}
        <div style={{ display:"flex", flexDirection:"column", alignItems:"center", gap:6 }}>
          <Av initials={podium[1].initials} color={podium[1].color} size={44}/>
          <div style={{ width:82, height:60, ...glassCard("base"), display:"flex", flexDirection:"column", alignItems:"center", justifyContent:"center", border:"1px solid rgba(192,210,255,0.18)" }}>
            <span style={{ fontSize:20, marginBottom:2 }}>🥈</span>
            <span style={{ fontSize:11, fontWeight:700, color:T.text.primary }}>{podium[1].name.split(" ")[0]}</span>
            <span style={{ fontSize:10, color:T.text.secondary }}>{podium[1].points.toLocaleString()}</span>
          </div>
        </div>
        {/* 1st place */}
        <div style={{ display:"flex", flexDirection:"column", alignItems:"center", gap:6 }}>
          <div style={{ position:"relative" }}>
            <div style={{ position:"absolute", top:-18, left:"50%", transform:"translateX(-50%)", fontSize:22 }}>👑</div>
            <Av initials={podium[0].initials} color={podium[0].color} size={54} glow/>
          </div>
          <div style={{ width:82, height:75, ...glassCard("gold"), display:"flex", flexDirection:"column", alignItems:"center", justifyContent:"center" }}>
            <span style={{ fontSize:22, marginBottom:2 }}>🥇</span>
            <span style={{ fontSize:11, fontWeight:700, color:T.text.primary }}>{podium[0].name.split(" ")[0]}</span>
            <span style={{ fontSize:10, color:T.neon.yellow }}>{podium[0].points.toLocaleString()}</span>
          </div>
        </div>
        {/* 3rd place */}
        <div style={{ display:"flex", flexDirection:"column", alignItems:"center", gap:6 }}>
          <Av initials={podium[2].initials} color={podium[2].color} size={44}/>
          <div style={{ width:82, height:50, ...glassCard("base"), display:"flex", flexDirection:"column", alignItems:"center", justifyContent:"center", border:"1px solid rgba(255,150,60,0.18)" }}>
            <span style={{ fontSize:20, marginBottom:2 }}>🥉</span>
            <span style={{ fontSize:11, fontWeight:700, color:T.text.primary }}>{podium[2].name.split(" ")[0]}</span>
            <span style={{ fontSize:10, color:T.text.secondary }}>{podium[2].points.toLocaleString()}</span>
          </div>
        </div>
      </div>

      {/* Rest of the list (rank 4+) */}
      {/* [MOCK DATA] rest — ranks 4+ from LEADERBOARD */}
      {rest.map((u,i)=>(
        <div key={i} style={{ ...glassCard(u.isMe?"win":"base"), marginBottom:8, padding:"12px 14px", display:"flex", alignItems:"center", gap:12 }}>
          <span style={{ width:20, fontSize:13, fontWeight:700, color:T.text.tertiary, textAlign:"center" }}>{u.rank}</span>
          <Av initials={u.initials} color={u.color} size={38}/>
          <div style={{ flex:1 }}>
            <div style={{ fontSize:13, fontWeight:700, color:u.isMe?T.neon.cyan:T.text.primary, fontFamily:T.font.display }}>{u.name}{u.isMe?" (You)":""}</div>
            <div style={{ fontSize:11, color:T.text.secondary }}>{u.wins}W · {u.losses}L{u.streak>0?` · 🔥${u.streak}`:""}</div>
          </div>
          {/* [MOCK DATA] u.points — server-calculated points total */}
          <span style={{ fontSize:14, fontWeight:700, color:u.isMe?T.neon.cyan:T.text.primary, fontFamily:T.font.display }}>{u.points.toLocaleString()}</span>
        </div>
      ))}

      {/* Current user's position (pinned if not in visible range) */}
      {me&&(
        <div style={{ ...glassCard("win"), marginTop:8, padding:"12px 14px", display:"flex", alignItems:"center", gap:12, border:`1px solid ${T.neon.cyan}40` }}>
          <span style={{ width:20, fontSize:13, fontWeight:700, color:T.neon.cyan, textAlign:"center" }}>{me.rank}</span>
          <Av initials={me.initials} color={T.neon.cyan} size={38} glow/>
          <div style={{ flex:1 }}>
            <div style={{ fontSize:13, fontWeight:700, color:T.neon.cyan, fontFamily:T.font.display }}>You</div>
            <div style={{ fontSize:11, color:T.text.secondary }}>{me.wins}W · {me.losses}L · 🔥{me.streak}</div>
          </div>
          <span style={{ fontSize:14, fontWeight:700, color:T.neon.cyan, fontFamily:T.font.display }}>{me.points.toLocaleString()}</span>
        </div>
      )}
    </div>
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY SCREEN
// ─────────────────────────────────────────────────────────────────────────────
function ActivityScreen({ onMatchTap }) {
  const active    = MATCHES.filter(m=>m.status==="active");
  const completed = MATCHES.filter(m=>m.status==="completed");

  return (
    <div style={{ flex:1, overflowY:"auto", padding:"0 16px 20px" }}>
      {/* Header */}
      <div style={{ paddingTop:10, paddingBottom:14, display:"flex", justifyContent:"space-between", alignItems:"center" }}>
        <span style={{ fontSize:22, fontWeight:800, color:T.text.primary, fontFamily:T.font.display }}>Activity</span>
        <div style={{ ...glassCard("base"), width:36, height:36, display:"flex", alignItems:"center", justifyContent:"center", cursor:"pointer" }}>
          <Search size={16} color={T.text.secondary}/>
        </div>
      </div>

      {/* Summary stats row */}
      {/* [MOCK DATA] stats — calculated from user's match history */}
      <div style={{ display:"flex", gap:10, marginBottom:20 }}>
        {[
          { v:"7", l:"Matches" },
          { v:"5", l:"Wins" },
          { v:"71%", l:"Win Rate", accent:true },
        ].map((s,i)=>(
          <div key={i} style={{ ...glassCard("base"), flex:1, padding:"14px 10px", textAlign:"center" }}>
            <div style={{ fontSize:28, fontWeight:900, color:s.accent?T.neon.cyan:T.text.primary, fontFamily:T.font.display, letterSpacing:"-1px", lineHeight:1 }}>{s.v}</div>
            <div style={{ fontSize:10, color:T.text.tertiary, marginTop:5, letterSpacing:"0.5px" }}>{s.l.toUpperCase()}</div>
          </div>
        ))}
      </div>

      {/* Active matches */}
      {/* [MOCK DATA] active — live matches from backend */}
      <SLabel text="Active Battles" count={active.length}/>
      {active.map((m,i)=>(
        <div key={i} onClick={()=>onMatchTap&&onMatchTap(m)} style={{ ...glassCard(m.winning?"win":"lose"), marginBottom:8, padding:"12px 16px", display:"flex", alignItems:"center", gap:12, cursor:"pointer" }}>
          <Av initials={m.opponent.initials} color={m.opponent.color} size={40}/>
          <div style={{ flex:1 }}>
            <div style={{ fontSize:13, fontWeight:700, color:T.text.primary, fontFamily:T.font.display }}>{m.opponent.name}</div>
            <div style={{ fontSize:11, color:T.text.secondary }}>{m.sport} · Day {m.totalDays-m.daysLeft}/{m.totalDays}</div>
          </div>
          <div style={{ textAlign:"right" }}>
            {/* [MOCK DATA] myScore/theirScore — days won */}
            <div style={{ fontSize:16, fontWeight:800, color:m.winning?T.neon.cyan:T.neon.orange, fontFamily:T.font.display }}>{m.myScore} – {m.theirScore}</div>
            <Badge label={m.winning?"WINNING":"LOSING"} color={m.winning?T.neon.cyan:T.neon.orange}/>
          </div>
        </div>
      ))}

      {/* Past matches */}
      {/* [MOCK DATA] completed — match history from backend */}
      <SLabel text="Past Matches" action="Filter →" style={{ marginTop:12 }}/>
      {completed.map((m,i)=>(
        <div key={i} style={{ ...glassCard(m.winning?"win":"lose"), marginBottom:10, opacity:0.8 }}>
          <div style={{ padding:"12px 14px", display:"flex", alignItems:"center", gap:12 }}>
            <Av initials={m.opponent.initials} color={m.opponent.color} size={38}/>
            <div style={{ flex:1 }}>
              <div style={{ fontSize:13, fontWeight:700, color:T.text.primary, fontFamily:T.font.display }}>{m.opponent.name}</div>
              <div style={{ fontSize:11, color:T.text.secondary }}>{m.sport} · {m.series}</div>
            </div>
            <div style={{ display:"flex", flexDirection:"column", alignItems:"flex-end", gap:3 }}>
              <div style={{ fontSize:16, fontWeight:800, color:m.winning?T.neon.cyan:T.neon.orange, fontFamily:T.font.display }}>{m.myScore} – {m.theirScore}</div>
              <Badge label={m.winning?"WIN":"LOSS"} color={m.winning?T.neon.cyan:T.neon.orange}/>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// HEALTH SCREEN  (from File 2 — richest implementation)
// ─────────────────────────────────────────────────────────────────────────────
// ALL data in this screen comes from Apple HealthKit
// HKQuantityTypeIdentifier references are noted per field
function HealthScreen() {
  const [statsTab, setStatsTab] = useState("steps");
  const [anim, setAnim] = useState(false);
  useEffect(()=>{ const t=setTimeout(()=>setAnim(true),120); return()=>clearTimeout(t); },[]);

  const h = HEALTH_MOCK; // all values are [MOCK DATA] — replace with HealthKit

  // Derived values
  const stepsGoalPct = h.steps.today / h.steps.goal;
  const calsGoalPct  = h.calories.today / h.calories.goal;
  const battleReadinessLabel = h.battleReadiness>=75?"Strong Readiness":h.battleReadiness>=50?"Moderate Readiness":"Low Readiness";
  const battleReadinessSub   = h.battleReadiness>=75?"You're well-primed for battle today.":"Some factors could be improved.";
  const scoreColor = h.battleReadiness>=75?T.neon.cyan:h.battleReadiness>=50?T.neon.yellow:T.neon.red;

  // Mini bar chart component (used for 7-day step/cal charts)
  const MiniBars = ({ data, color, goal }) => {
    const peak = Math.max(...data);
    return (
      <div style={{ display:"flex", alignItems:"flex-end", gap:3, height:56 }}>
        {data.map((v,i)=>{
          const pct=v/peak, isToday=i===data.length-1;
          return (
            <div key={i} style={{ flex:1, display:"flex", flexDirection:"column", alignItems:"center", gap:3, height:"100%" }}>
              <div style={{ flex:1, display:"flex", alignItems:"flex-end", width:"100%" }}>
                <div style={{ width:"100%", borderRadius:"3px 3px 0 0", height:anim?`${pct*100}%`:"0%", background:isToday?`linear-gradient(180deg,${color},${color}80)`:v>=goal?`${color}48`:`${color}22`, boxShadow:isToday?`0 0 12px ${color}60`:"none", transition:`height 0.6s ease ${i*40}ms` }}/>
              </div>
              <span style={{ fontSize:9, color:T.text.tertiary }}>{WEEK_DAYS[i]}</span>
            </div>
          );
        })}
      </div>
    );
  };

  return (
    <div style={{ flex:1, overflowY:"auto", padding:"0 16px 20px" }}>
      {/* Header */}
      <div style={{ paddingTop:10, paddingBottom:14, display:"flex", justifyContent:"space-between", alignItems:"center" }}>
        <span style={{ fontSize:22, fontWeight:800, color:T.text.primary, fontFamily:T.font.display }}>Health</span>
        <Badge label="SYNCED" color={T.neon.green}/>
        {/* [MOCK DATA] SYNCED badge = HealthKit authorization granted + last sync < 5 min ago */}
      </div>

      {/* ── BATTLE READINESS HERO ─────────────────────────────────────────── */}
      {/* [MOCK DATA] battleReadiness (0–100) — computed from: sleep quality,
           resting HR, steps trend, HRV (if available). Calculated on-device
           or server-side from HealthKit samples */}
      <div style={{ ...glassCard("win"), marginBottom:14, padding:"20px" }}>
        <div style={{ fontSize:10, fontWeight:700, letterSpacing:"2px", color:T.text.tertiary, fontFamily:T.font.body, marginBottom:14 }}>TODAY'S BATTLE READINESS</div>
        <div style={{ display:"flex", alignItems:"center", gap:16, marginBottom:16 }}>
          <CircleProgress score={h.battleReadiness}/>
          <div>
            <div style={{ fontFamily:T.font.display, fontWeight:700, fontSize:22, color:T.text.primary, lineHeight:1.2 }}>{battleReadinessLabel}</div>
            <div style={{ fontSize:13, color:T.text.secondary, marginTop:6, lineHeight:1.5 }}>{battleReadinessSub}</div>
          </div>
        </div>
        {/* Quick stats row */}
        <div style={{ display:"flex", gap:8 }}>
          {[
            // [MOCK DATA] Each value below from HealthKit:
            { icon:"🌙", val:`${h.sleep.avgHours}h`,  label:"Sleep"      }, // HKCategoryTypeIdentifier.sleepAnalysis
            { icon:"❤️", val:`${h.restingHR}`,         label:"Resting HR" }, // HKQuantityTypeIdentifier.restingHeartRate (bpm)
            { icon:"👟", val:`${(h.steps.today/1000).toFixed(1)}k`, label:"Steps" }, // HKQuantityTypeIdentifier.stepCount
            { icon:"🔥", val:`${h.calories.today}`,    label:"Active Cal" }, // HKQuantityTypeIdentifier.activeEnergyBurned
          ].map((s,i)=>(
            <div key={i} style={{ ...glassCard("base"), flex:1, padding:"10px 6px", textAlign:"center" }}>
              <div style={{ fontSize:16, marginBottom:4 }}>{s.icon}</div>
              <div style={{ fontFamily:T.font.mono, fontSize:13, fontWeight:700, color:T.text.primary }}>{s.val}</div>
              <div style={{ fontSize:9, color:T.text.tertiary, marginTop:2, fontFamily:T.font.body }}>{s.label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* ── COMPONENT BREAKDOWN ─────────────────────────────────────────────── */}
      {/* [MOCK DATA] All values below from HealthKit — replace with real data:
           Sleep: HKCategoryTypeIdentifier.sleepAnalysis (hours)
           Resting HR: HKQuantityTypeIdentifier.restingHeartRate (bpm)
           Steps: HKQuantityTypeIdentifier.stepCount
           Calories: HKQuantityTypeIdentifier.activeEnergyBurned
           Goals: configure these targets based on user profile / fitness level */}
      <div style={{ ...glassCard("base"), marginBottom:14, padding:"18px" }}>
        <div style={{ fontSize:10, fontWeight:700, letterSpacing:"2px", color:T.text.tertiary, fontFamily:T.font.body, marginBottom:16 }}>COMPONENT BREAKDOWN</div>
        <div style={{ fontSize:12, color:T.text.secondary, marginBottom:16, lineHeight:1.5 }}>How the readiness score is built for competition context.</div>
        
        {/* Breakdown items */}
        <div style={{ display:"flex", flexDirection:"column", gap:14 }}>
          {[
            // [MOCK DATA] — Replace with real HealthKit data:
            // Sleep: h.sleep.hoursLastNight (actual hours slept), h.sleep.goal (e.g., 8 hours)
            {
              label: "Sleep",
              actual: 7.8,           // [MOCK DATA] HKCategoryTypeIdentifier.sleepAnalysis
              goal: 8,               // [MOCK DATA] user's target sleep hours
              unit: "hrs",
              color: T.neon.blue,
            },
            // Resting HR: h.restingHR (bpm), goal typically 60
            {
              label: "Resting HR",
              actual: 58,            // [MOCK DATA] HKQuantityTypeIdentifier.restingHeartRate
              goal: 60,              // [MOCK DATA] target bpm (lower is better for athletes)
              unit: "bpm",
              color: T.neon.cyan,
            },
            // Steps: h.steps.today (count), h.steps.goal (e.g., 10000)
            {
              label: "Steps",
              actual: 5000,          // [MOCK DATA] HKQuantityTypeIdentifier.stepCount
              goal: 10000,           // [MOCK DATA] user's daily step target
              unit: "steps",
              color: T.neon.orange,
            },
            // Calories: h.calories.today, h.calories.goal (e.g., 500 kcal)
            {
              label: "Calories",
              actual: 320,           // [MOCK DATA] HKQuantityTypeIdentifier.activeEnergyBurned
              goal: 500,             // [MOCK DATA] user's daily active calories target
              unit: "kcal",
              color: T.neon.pink,
            },
          ].map((metric, i) => {
            // Auto-calculate percentage
            const pct = Math.min((metric.actual / metric.goal) * 100, 100);
            
            // Format the metric display based on unit
            let metricDisplay = "";
            if (metric.unit === "steps") {
              metricDisplay = `${metric.actual.toLocaleString()} / ${metric.goal.toLocaleString()} ${metric.unit}`;
            } else if (metric.unit === "bpm") {
              metricDisplay = `${metric.actual} / ${metric.goal} ${metric.unit}`;
            } else {
              // hrs, kcal
              metricDisplay = `${metric.actual} / ${metric.goal} ${metric.unit}`;
            }

            return (
              <div key={i}>
                {/* Label + metric value + percentage */}
                <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", marginBottom:6 }}>
                  <span style={{ fontSize:13, fontWeight:700, color:T.text.primary, fontFamily:T.font.body }}>{metric.label}</span>
                  <div style={{ display:"flex", alignItems:"center", gap:12 }}>
                    <span style={{ fontSize:11, color:T.text.secondary, fontFamily:T.font.mono }}>{metricDisplay}</span>
                    <span style={{ fontSize:11, fontWeight:700, color:metric.color, minWidth:35, textAlign:"right" }}>{Math.round(pct)}%</span>
                  </div>
                </div>
                
                {/* Progress bar */}
                <div style={{ height:5, background:"rgba(255,255,255,0.06)", borderRadius:3, overflow:"hidden" }}>
                  <div
                    style={{
                      height:"100%",
                      width:`${pct}%`,
                      background:`linear-gradient(90deg, ${metric.color}, ${metric.color}80)`,
                      borderRadius:3,
                      transition:"width 0.6s ease",
                    }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* ── YOUR STATS (steps / calories toggle) ────────────────────────────── */}
      {/* [MOCK DATA] all stats below from HealthKit + backend match history */}
      <SLabel text="Your Stats"/>
      <div style={{ ...glassCard("base"), marginBottom:14, padding:"18px" }}>
        {/* Steps / Calories tab toggle */}
        <div style={{ display:"flex", background:"rgba(255,255,255,0.06)", borderRadius:T.radius.pill, padding:"3px", marginBottom:16 }}>
          {["steps","calories"].map(tab=>(
            <button key={tab} onClick={()=>setStatsTab(tab)} style={{ flex:1, padding:"8px", borderRadius:T.radius.pill, border:"none", cursor:"pointer", fontFamily:T.font.body, fontSize:13, fontWeight:700, transition:"all 0.2s", background:statsTab===tab?T.neon.cyan:"transparent", color:statsTab===tab?"#000":T.text.secondary }}>
              {tab.charAt(0).toUpperCase()+tab.slice(1)}
            </button>
          ))}
        </div>

        {/* 7-day bar chart */}
        {/* [MOCK DATA] week arrays = 7 daily values from HealthKit */}
        <div style={{ fontSize:10, fontWeight:700, letterSpacing:"2px", color:T.text.tertiary, fontFamily:T.font.body, marginBottom:8 }}>7-DAY TREND</div>
        <MiniBars
          data={statsTab==="steps"?h.steps.week:h.calories.week}
          color={statsTab==="steps"?T.neon.cyan:T.neon.orange}
          goal={statsTab==="steps"?h.steps.goal:h.calories.goal}
        />
        {/* Today vs goal */}
        <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", marginTop:12, marginBottom:6 }}>
          <span style={{ fontSize:11, color:T.text.secondary }}>
            Today: <strong style={{ color:T.text.primary }}>{(statsTab==="steps"?h.steps.today:h.calories.today).toLocaleString()}</strong>
          </span>
          <span style={{ fontSize:11, color:T.text.secondary }}>
            Goal: <strong style={{ color:statsTab==="steps"?T.neon.cyan:T.neon.orange }}>{(statsTab==="steps"?h.steps.goal:h.calories.goal).toLocaleString()}</strong>
          </span>
        </div>
        {/* Progress bar toward goal */}
        <div style={{ height:5, background:"rgba(255,255,255,0.07)", borderRadius:3, marginBottom:16, overflow:"hidden" }}>
          <div style={{ height:"100%", width:anim?`${Math.min((statsTab==="steps"?stepsGoalPct:calsGoalPct)*100,100)}%`:"0%", background:`linear-gradient(90deg,${statsTab==="steps"?T.neon.cyan:T.neon.orange},${statsTab==="steps"?T.neon.cyan:T.neon.orange}80)`, borderRadius:3, transition:"width 0.8s ease" }}/>
        </div>

        {/* All-time bests grid */}
        <div style={{ fontSize:10, fontWeight:700, letterSpacing:"2px", color:T.text.tertiary, fontFamily:T.font.body, marginBottom:12 }}>ALL-TIME BESTS</div>
        <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:10 }}>
          {[
            // [MOCK DATA] all-time bests — from backend (aggregated from historical HealthKit data)
            { label:"BEST SINGLE DAY", val:statsTab==="steps"?h.allTimeBests.stepsBestDay.val:h.allTimeBests.calsBestDay.val,   sub:statsTab==="steps"?h.allTimeBests.stepsBestDay.sub:h.allTimeBests.calsBestDay.sub },
            { label:"BEST WEEK TOTAL", val:statsTab==="steps"?h.allTimeBests.stepsBestWeek.val:h.allTimeBests.calsBestWeek.val, sub:statsTab==="steps"?h.allTimeBests.stepsBestWeek.sub:h.allTimeBests.calsBestWeek.sub },
            { label:"BEST WIN STREAK", val:h.allTimeBests.bestWinStreak.val, sub:h.allTimeBests.bestWinStreak.sub },
            { label:"BATTLE WIN RATE", val:h.allTimeBests.battleWinRate.val, sub:h.allTimeBests.battleWinRate.sub, accent:true },
          ].map((s,i)=>(
            <div key={i} style={{ ...glassCard("base"), padding:"12px 14px" }}>
              <div style={{ fontSize:9, fontWeight:700, color:T.text.tertiary, letterSpacing:"1.5px", fontFamily:T.font.body, marginBottom:6 }}>{s.label}</div>
              <div style={{ fontFamily:T.font.display, fontSize:28, color:s.accent?T.neon.green:T.neon.cyan, letterSpacing:"-0.5px", lineHeight:1 }}>{s.val}</div>
              <div style={{ fontSize:11, color:T.text.tertiary, marginTop:4, fontFamily:T.font.body }}>{s.sub}</div>
            </div>
          ))}
        </div>
      </div>

      {/* ── SLEEP QUALITY ──────────────────────────────────────────────────── */}
      {/* [MOCK DATA] all sleep values from HKCategoryTypeIdentifier.sleepAnalysis */}
      <SLabel text="Sleep Quality"/>
      <div style={{ ...glassCard("base"), marginBottom:14, padding:"18px" }}>
        <div style={{ fontSize:10, fontFamily:T.font.mono, color:T.text.tertiary, letterSpacing:"1px", marginBottom:8 }}>7-NIGHT AVERAGE</div>
        {/* [MOCK DATA] avgHours = mean of last 7 nights */}
        <div style={{ fontFamily:T.font.display, fontSize:52, color:T.text.primary, letterSpacing:"-1px", lineHeight:1 }}>{h.sleep.avgHours} hrs</div>
        {/* [MOCK DATA] variance = std deviation of last 7 nights */}
        <div style={{ fontSize:13, color:T.text.tertiary, margin:"6px 0 14px", fontFamily:T.font.body }}>±{h.sleep.variance}h variance</div>
        {/* Sleep stage segmented bar */}
        <div style={{ display:"flex", height:8, borderRadius:T.radius.pill, overflow:"hidden", marginBottom:10 }}>
          {h.sleep.stages.map((s,i)=>(
            <div key={i} style={{ width:`${s.pct}%`, background:s.color }}/>
          ))}
        </div>
        {/* Legend */}
        <div style={{ display:"flex", flexWrap:"wrap", gap:12 }}>
          {h.sleep.stages.map((s,i)=>(
            <div key={i} style={{ display:"flex", alignItems:"center", gap:5 }}>
              <div style={{ width:8, height:8, borderRadius:"50%", background:s.color }}/>
              {/* [MOCK DATA] label + pct — from HK sleep stage samples */}
              <span style={{ fontSize:11, color:T.text.secondary, fontFamily:T.font.body }}>{s.label} {s.pct}%</span>
            </div>
          ))}
        </div>
      </div>

      {/* ── HR ZONES ──────────────────────────────────────────────────────── */}
      {/* [MOCK DATA] from HKQuantityTypeIdentifier.heartRate samples + workout zone calculation */}
      <SLabel text="HR Zones"/>
      <div style={{ ...glassCard("base"), marginBottom:14, padding:"18px" }}>
        {/* [MOCK DATA] restingHR = HKQuantityTypeIdentifier.restingHeartRate */}
        <div style={{ display:"flex", alignItems:"center", gap:10, marginBottom:14 }}>
          <div style={{ height:6, width:40, background:"rgba(255,255,255,0.15)", borderRadius:T.radius.pill }}/>
          <span style={{ fontFamily:T.font.body, fontSize:14, color:T.text.secondary }}>{h.restingHR} bpm resting</span>
        </div>
        <div style={{ fontSize:11, color:T.text.tertiary, marginBottom:14, fontFamily:T.font.body }}>From most recent workout</div>
        {/* [MOCK DATA] hrZones — pct time in each zone during last HK workout */}
        {h.hrZones.map((z,i)=>(
          <ProgressBar key={i} label={z.label} value={z.val} pct={z.pct} color={z.color}/>
        ))}
      </div>

      {/* ── COMPETITION EDGE TODAY ──────────────────────────────────────────── */}
      {/* [MOCK DATA] delta values — calculated from: your HealthKit steps vs
           opponent's steps (fetched from backend). One row per active match. */}
      <SLabel text="Competition Edge Today"/>
      <div style={{ ...glassCard("base"), marginBottom:14, padding:"14px" }}>
        {MATCHES.filter(m=>m.status==="active").map((m,i)=>{
          const delta=m.myToday-m.theirToday, up=delta>=0;
          const label=m.sport==="Steps"?`${Math.abs(delta).toLocaleString()} steps`:`${Math.abs(delta)} cal`;
          return (
            <div key={i} style={{ display:"flex", justifyContent:"space-between", alignItems:"center", padding:"8px 0", borderBottom:i<MATCHES.filter(x=>x.status==="active").length-1?"1px solid rgba(255,255,255,0.06)":"none" }}>
              {/* [MOCK DATA] opponent name + today comparison */}
              <span style={{ fontSize:12, color:T.text.secondary }}>vs {m.opponent.name}</span>
              <div style={{ display:"flex", alignItems:"center", gap:4 }}>
                {up?<ChevronUp size={12} color={T.neon.cyan}/>:<ChevronDown size={12} color={T.neon.orange}/>}
                <span style={{ fontSize:13, fontWeight:700, color:up?T.neon.cyan:T.neon.orange, fontFamily:T.font.display }}>{up?"+":"-"}{label}</span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
function ProfileScreen() {
  const [dev,setDev]=useState(false), [notifs,setNotifs]=useState(true);

  // [MOCK DATA] logs — replace with real app log stream in dev mode
  const logs=[
    "[12:04:01] HealthKit sync: 11240 steps",
    "[12:04:00] Match 1 updated: score 4-2",
    "[11:58:22] Opponent data fetched",
    "[11:55:11] Push notification sent",
    "[11:50:03] Background refresh completed",
  ];

  const groups=[
    {
      title:"ACCOUNT",
      items:[
        { icon:Bell,    label:"Notifications",   action:"toggle", value:notifs, onToggle:()=>setNotifs(n=>!n) },
        { icon:Shield,  label:"Privacy",          action:"chevron" },
        { icon:Settings,label:"Connected Apps",   action:"chevron" },
      ]
    },
    {
      title:"SUBSCRIPTION",
      items:[
        // [MOCK DATA] subscription tier — from RevenueCat entitlement check
        { icon:Crown, label:"FitUp Pro · Active", action:"badge", badge:"PRO", bc:T.neon.yellow },
        { icon:Star,  label:"Manage Plan",         action:"chevron" },
      ]
    },
    {
      title:"DEVELOPER",
      items:[
        { icon:Code,   label:"Dev Mode",  action:"toggle", value:dev, onToggle:()=>setDev(d=>!d) },
        { icon:LogOut, label:"Sign Out",  action:"chevron", danger:true },
      ]
    },
  ];

  return (
    <div style={{ flex:1, overflowY:"auto", padding:"0 16px 20px" }}>
      <div style={{ paddingTop:10, paddingBottom:14 }}>
        <span style={{ fontSize:22, fontWeight:800, color:T.text.primary, fontFamily:T.font.display }}>Profile</span>
      </div>

      {/* User hero card */}
      <div style={{ ...glassCard("win"), marginBottom:20, padding:"20px" }}>
        <div style={{ display:"flex", alignItems:"center", gap:16, marginBottom:16 }}>
          {/* [MOCK DATA] initials, name — from authenticated user profile */}
          <Av initials={ME.initials} color={T.neon.cyan} size={62} glow/>
          <div style={{ flex:1 }}>
            <div style={{ fontSize:20, fontWeight:800, color:T.text.primary, fontFamily:T.font.display }}>{ME.name}</div>
            {/* [MOCK DATA] username, level — from user profile in backend */}
            <div style={{ fontSize:12, color:T.text.secondary, marginBottom:6 }}>@marcusr · Level 12</div>
            <div style={{ display:"flex", gap:6 }}>
              {/* [MOCK DATA] PRO badge = RevenueCat subscription active | 18 WINS = match history count */}
              <Badge label="PRO" color={T.neon.yellow}/>
              <Badge label="18 WINS" color={T.neon.cyan}/>
            </div>
          </div>
        </div>
        {/* Stats grid */}
        <div style={{ display:"grid", gridTemplateColumns:"repeat(3, 1fr)", gap:8 }}>
          {[
            // [MOCK DATA] all stats from backend match history
            { l:"Matches", v:26 },
            { l:"Wins",    v:18 },
            { l:"Streak",  v:"4🔥" },
          ].map((s,i)=>(
            <div key={i} style={{ textAlign:"center", padding:"8px 0", borderRadius:T.radius.sm, background:"rgba(0,0,0,0.2)" }}>
              <div style={{ fontSize:18, fontWeight:800, color:T.text.primary, fontFamily:T.font.display }}>{s.v}</div>
              <div style={{ fontSize:10, color:T.text.secondary }}>{s.l}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Settings groups */}
      {groups.map((g,gi)=>(
        <div key={gi} style={{ marginBottom:16 }}>
          <div style={secLabel}>{g.title}</div>
          <div style={{ ...glassCard("base"), overflow:"hidden" }}>
            {g.items.map((item,ii)=>{
              const Icon=item.icon;
              return (
                <div key={ii} style={{ display:"flex", alignItems:"center", gap:12, padding:"13px 14px", borderBottom:ii<g.items.length-1?"1px solid rgba(255,255,255,0.05)":"none", cursor:"pointer" }}>
                  <div style={{ width:28, height:28, borderRadius:8, background:item.danger?`${T.neon.pink}14`:"rgba(255,255,255,0.07)", display:"flex", alignItems:"center", justifyContent:"center" }}>
                    <Icon size={13} color={item.danger?T.neon.pink:T.text.secondary}/>
                  </div>
                  <span style={{ flex:1, fontSize:14, color:item.danger?T.neon.pink:T.text.primary, fontFamily:T.font.body }}>{item.label}</span>
                  {item.action==="chevron"&&<ChevronRight size={14} color={T.text.tertiary}/>}
                  {item.action==="badge"&&<Badge label={item.badge} color={item.bc}/>}
                  {item.action==="toggle"&&(
                    <button onClick={item.onToggle} style={{ background:"none", border:"none", cursor:"pointer", padding:0 }}>
                      {item.value?<ToggleRight size={22} color={T.neon.cyan}/>:<ToggleLeft size={22} color={T.text.tertiary}/>}
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      ))}

      {/* Dev log viewer (only shown when dev mode is on) */}
      {dev&&(
        <div style={{ marginBottom:16 }}>
          <div style={secLabel}>LOG VIEWER</div>
          {/* [MOCK DATA] logs — replace with real-time log stream */}
          <div style={{ ...glassCard("base"), padding:"12px 14px", fontFamily:T.font.mono, fontSize:10, color:T.neon.green }}>
            {logs.map((log,i)=><div key={i} style={{ paddingBottom:5, borderBottom:i<logs.length-1?"1px solid rgba(57,255,20,0.08)":"none", paddingTop:i>0?5:0 }}>{log}</div>)}
          </div>
        </div>
      )}
    </div>
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// ROOT  — App shell, navigation state, phone frame wrapper
// ─────────────────────────────────────────────────────────────────────────────
// Screen IDs that live in the bottom nav (set navActive when navigating to them)
const NAV_SCREENS = ["home","leaderboard","activity","health","profile"];

// All available screens — for the demo switcher buttons above the phone
// NOTE: "live" is not in the nav but is accessible via Match Details → Watch Live
const ALL_SCREENS = [
  { id:"home",        label:"🏠 Home"       },
  { id:"match",       label:"⚔️ Match"      },
  { id:"live",        label:"⚡ Live"        },  // accessible from Match Details only
  { id:"challenge",   label:"🎯 Challenge"  },
  { id:"leaderboard", label:"🏆 Ranks"      },
  { id:"activity",    label:"📊 Activity"   },
  { id:"health",      label:"❤️ Health"     },
  { id:"profile",     label:"👤 Profile"    },
];

export default function FitUpFinalMockup() {
  const [screen,   setScreen  ] = useState("home");
  const [navActive,setNavActive] = useState("home");
  const [key,      setKey     ] = useState(0);

  // Navigate to a screen and update nav state if it's a tab-level screen
  const go = (id) => {
    setScreen(id);
    setKey(k=>k+1);
    if(NAV_SCREENS.includes(id)) setNavActive(id);
  };

  const getScreen = () => {
    switch(screen) {
      case "home":        return <HomeScreen        onMatchTap={()=>go("match")} onChallenge={()=>go("challenge")}/>;
      // Match Details → onLive navigates to Live screen (NOT via nav bar)
      case "match":       return <MatchDetailsScreen onBack={()=>go("home")} onLive={()=>go("live")}/>;
      // Live screen: back arrow returns to Match Details
      case "live":        return <LiveMatchScreen    onBack={()=>go("match")}/>;
      case "challenge":   return <ChallengeScreen    onBack={()=>go("home")}  onDone={()=>go("home")}/>;
      case "leaderboard": return <LeaderboardScreen/>;
      case "activity":    return <ActivityScreen     onMatchTap={()=>go("match")}/>;
      case "health":      return <HealthScreen/>;
      case "profile":     return <ProfileScreen/>;
      default:            return <HomeScreen        onMatchTap={()=>go("match")} onChallenge={()=>go("challenge")}/>;
    }
  };

  return (
    <div style={{ minHeight:"100vh", background:"#000", display:"flex", flexDirection:"column", alignItems:"center", padding:"24px 16px 40px", fontFamily:T.font.body }}>
      {/* Demo header */}
      <div style={{ marginBottom:18, textAlign:"center" }}>
        <div style={{ fontSize:30, fontWeight:900, fontFamily:T.font.display, letterSpacing:"-1px" }}>
          <span style={{ background:`linear-gradient(90deg,${T.neon.cyan},${T.neon.blue})`, WebkitBackgroundClip:"text", WebkitTextFillColor:"transparent" }}>FIT</span>
          <span style={{ background:`linear-gradient(90deg,${T.neon.orange},${T.neon.yellow})`, WebkitBackgroundClip:"text", WebkitTextFillColor:"transparent" }}>UP</span>
          <span style={{ fontSize:13, fontWeight:500, color:"rgba(255,255,255,0.28)", marginLeft:10 }}>Final Design System</span>
        </div>
        <div style={{ fontSize:11, color:"rgba(255,255,255,0.28)", marginTop:3 }}>8 screens · all interactive · tap cards or use switcher to navigate</div>
      </div>

      {/* Screen switcher buttons (demo only — not part of app UI) */}
      <div style={{ display:"flex", gap:5, marginBottom:20, flexWrap:"wrap", justifyContent:"center", maxWidth:520 }}>
        {ALL_SCREENS.map(s=>(
          <button key={s.id} onClick={()=>go(s.id)} style={{ padding:"7px 12px", borderRadius:T.radius.pill, background:screen===s.id?`linear-gradient(135deg,${T.neon.cyan}22,${T.neon.blue}14)`:"rgba(255,255,255,0.05)", border:screen===s.id?`1px solid ${T.neon.cyan}50`:"1px solid rgba(255,255,255,0.08)", color:screen===s.id?T.neon.cyan:"rgba(255,255,255,0.42)", fontSize:11, fontWeight:700, cursor:"pointer", fontFamily:T.font.body, transition:"all 0.18s" }}>
            {s.label}
          </button>
        ))}
      </div>

      {/* Phone frame */}
      <div style={{ width:390, height:844, borderRadius:50, overflow:"hidden", position:"relative", border:"1.5px solid rgba(255,255,255,0.11)", boxShadow:`0 0 0 1px rgba(0,0,0,0.8), 0 50px 120px rgba(0,0,0,0.85), 0 0 80px ${T.neon.cyan}0c, inset 0 0 0 1px rgba(255,255,255,0.04)`, display:"flex", flexDirection:"column", ...BG_STYLE }}>
        {/* Scanline overlay (subtle CRT texture) */}
        <div style={{ position:"absolute", inset:0, pointerEvents:"none", zIndex:0, background:"repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(255,255,255,0.005) 2px,rgba(255,255,255,0.005) 4px)" }}/>
        <div style={{ position:"relative", zIndex:1, display:"flex", flexDirection:"column", height:"100%" }}>
          <StatusBar/>
          <ScreenIn key={key} id={screen}>{getScreen()}</ScreenIn>
          {/* Hide bottom nav on sub-screens (match detail, live, challenge) */}
          {NAV_SCREENS.includes(screen) && <BottomNav active={navActive} onChange={go}/>}
        </div>
      </div>

      <style>{`
        @keyframes spin    { to { transform:rotate(360deg); } }
        @keyframes flashIn { from { opacity:0; transform:translateY(-6px) scale(0.94); } to { opacity:1; transform:translateY(0) scale(1); } }
        * { box-sizing:border-box; }
        ::-webkit-scrollbar { width:0; }
        input::placeholder { color:rgba(255,255,255,0.28); }
      `}</style>
    </div>
  );
}
