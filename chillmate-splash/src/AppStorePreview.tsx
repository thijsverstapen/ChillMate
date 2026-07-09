import { AbsoluteFill, Img, staticFile } from "remotion";
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadSerif } from "@remotion/google-fonts/InstrumentSerif";

const { fontFamily: INTER } = loadInter("normal", { weights: ["500", "600", "700", "800"], subsets: ["latin"] });
const { fontFamily: SERIF } = loadSerif();

const W = 1290;
const INDIGO = "#6366F1";
const SKY = "#60A5FA";
const TEAL = "#2DD4BF";

// Clean, front-facing device with a thin minimal frame (no 3D perspective).
const Device: React.FC<{ src: string; w: number; left: number; top: number; glow: string }> = ({ src, w, left, top, glow }) => (
  <div
    style={{
      position: "absolute",
      left,
      top,
      width: w,
      padding: 13,
      borderRadius: 76,
      background: "#0C0D11",
      border: "1.6px solid rgba(255,255,255,0.16)",
      boxShadow: `0 50px 110px rgba(0,0,0,0.6), 0 0 80px ${glow}22`,
    }}
  >
    <div style={{ borderRadius: 63, overflow: "hidden", border: "1px solid rgba(0,0,0,0.6)" }}>
      <Img src={staticFile(src)} style={{ width: "100%", display: "block" }} />
    </div>
  </div>
);

// Editorial headline: small elegant serif lead-in + bold uppercase punch.
const Headline: React.FC<{ serif: string; bold: string; boldSize?: number; color?: string }> = ({ serif, bold, boldSize = 80, color = "white" }) => (
  <div style={{ textAlign: "center" }}>
    <div style={{ fontFamily: SERIF, fontSize: boldSize * 0.74, lineHeight: 1.0, color, opacity: 0.96 }}>{serif}</div>
    <div style={{ fontFamily: INTER, fontWeight: 800, fontSize: boldSize, textTransform: "uppercase", letterSpacing: -2, lineHeight: 0.98, color, marginTop: 4 }}>{bold}</div>
  </div>
);

const BrandLabel = () => (
  <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
    <Img src={staticFile("glyph.png")} style={{ width: 46, height: 46 }} />
    <span style={{ fontFamily: INTER, fontSize: 36, fontWeight: 700, color: "rgba(255,255,255,0.96)" }}>ChillMate</span>
  </div>
);

const Pills: React.FC<{ items: string[] }> = ({ items }) => (
  <div style={{ display: "flex", gap: 16 }}>
    {items.map((t) => (
      <div key={t} style={{ fontFamily: INTER, fontSize: 32, fontWeight: 700, color: "white", padding: "12px 30px", borderRadius: 999, background: "rgba(255,255,255,0.14)", border: "1.5px solid rgba(255,255,255,0.26)" }}>{t}</div>
    ))}
  </div>
);

export const PreviewHero: React.FC = () => (
  <AbsoluteFill style={{ fontFamily: INTER }}>
    <AbsoluteFill style={{ background: "linear-gradient(155deg, #4F46E5 0%, #7C3AED 46%, #14B8A6 100%)" }} />
    <AbsoluteFill style={{ background: "radial-gradient(70% 45% at 50% 104%, rgba(0,0,0,0.5) 0%, rgba(0,0,0,0) 60%)" }} />
    <Device src="shot-summary.png" w={1140} left={(W - 1140) / 2} top={880} glow="#1E1B4B" />
    <AbsoluteFill style={{ flexDirection: "column", alignItems: "center", paddingTop: 150 }}>
      <BrandLabel />
      <div style={{ marginTop: 64 }}>
        <Headline serif="Look after" bold="Yourself" boldSize={132} />
      </div>
    </AbsoluteFill>
    <div style={{ position: "absolute", left: 0, right: 0, bottom: 88, display: "flex", justifyContent: "center" }}>
      <Pills items={["Free", "Private", "No ads"]} />
    </div>
  </AbsoluteFill>
);

type Layout = "full" | "card";
const LAYOUTS: Record<Layout, { top: number; w: number }> = {
  full: { top: 470, w: 1130 }, // full-screen shot, large, bleeds off the bottom
  card: { top: 610, w: 1200 }, // short (cropped) screen, centered
};

// --- Call-outs ---
const IconCheck = (<svg width={44} height={44} viewBox="0 0 24 24" fill="none"><path d="M5 13l4 4L19 7" stroke="white" strokeWidth={2.6} strokeLinecap="round" strokeLinejoin="round" /></svg>);
const IconClock = (<svg width={44} height={44} viewBox="0 0 24 24" fill="none"><circle cx={12} cy={12} r={9} stroke="white" strokeWidth={2.1} /><path d="M12 7.5V12l3 2" stroke="white" strokeWidth={2.1} strokeLinecap="round" strokeLinejoin="round" /></svg>);
const IconLock = (<svg width={44} height={44} viewBox="0 0 24 24" fill="none"><path d="M7 10V8a5 5 0 0 1 10 0v2" stroke="white" strokeWidth={2.2} strokeLinecap="round" /><rect x={5} y={10} width={14} height={10} rx={3} fill="white" /></svg>);
const IconHeart = (<svg width={44} height={44} viewBox="0 0 24 24" fill="none"><path d="M12 20.5S4.5 15.5 4.5 9.8A4.3 4.3 0 0 1 12 7a4.3 4.3 0 0 1 7.5 2.8c0 5.7-7.5 10.7-7.5 10.7z" fill="white" /></svg>);

type CalloutCfg = { icon: React.ReactNode; title: string; subtitle: string; pos: React.CSSProperties; rot: number };
const CALLOUTS: Record<string, CalloutCfg | null> = {
  summary: { icon: IconCheck, title: "5 days clear", subtitle: "all-clear check-ins", pos: { bottom: 250, left: 34 }, rot: -3 },
  plan: { icon: IconClock, title: "Ready in 30s", subtitle: "a quick safer plan", pos: { bottom: 250, left: 30 }, rot: 3 },
  privacy: { icon: IconLock, title: "On your iPhone", subtitle: "nothing leaves it", pos: { bottom: 520, right: 34 }, rot: 3 },
  journal: { icon: IconHeart, title: "Worth remembering", subtitle: "saved privately", pos: { bottom: 560, right: 30 }, rot: 3 },
  none: null,
};
const GlassCallout: React.FC<{ accent: string; cfg: CalloutCfg }> = ({ accent, cfg }) => (
  <div style={{ position: "absolute", ...cfg.pos, transform: `rotate(${cfg.rot}deg)`, fontFamily: INTER, display: "flex", alignItems: "center", gap: 18, padding: "22px 32px 22px 22px", borderRadius: 28, background: "rgba(18,20,30,0.94)", border: `1.5px solid ${accent}88`, boxShadow: `0 26px 60px rgba(0,0,0,0.6), 0 0 46px ${accent}33` }}>
    <div style={{ width: 76, height: 76, borderRadius: 21, flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center", background: `linear-gradient(135deg, ${accent}, ${accent}AA)`, boxShadow: `0 0 26px ${accent}66` }}>{cfg.icon}</div>
    <div style={{ display: "flex", flexDirection: "column" }}>
      <div style={{ fontSize: 38, fontWeight: 800, color: "white", lineHeight: 1.04 }}>{cfg.title}</div>
      <div style={{ fontSize: 28, fontWeight: 500, color: "rgba(255,255,255,0.64)", marginTop: 4 }}>{cfg.subtitle}</div>
    </div>
  </div>
);

export type PreviewShotProps = { screenshot: string; serif: string; bold: string; glow: string; layout: Layout; callout: string };

export const PreviewShot: React.FC<PreviewShotProps> = ({ screenshot, serif, bold, glow, layout, callout }) => {
  const L = LAYOUTS[layout] ?? LAYOUTS.full;
  const co = CALLOUTS[callout] ?? null;
  const left = (W - L.w) / 2;
  return (
    <AbsoluteFill style={{ fontFamily: INTER }}>
      <AbsoluteFill style={{ background: "#050609" }} />
      <AbsoluteFill style={{ background: `radial-gradient(50% 32% at 50% 56%, ${glow}26 0%, ${glow}00 72%)` }} />
      <Device src={screenshot} w={L.w} left={left} top={L.top} glow={glow} />
      {co ? <GlassCallout accent={glow} cfg={co} /> : null}
      <div style={{ position: "absolute", left: 0, right: 0, top: 150, padding: "0 70px" }}>
        <Headline serif={serif} bold={bold} boldSize={84} />
      </div>
    </AbsoluteFill>
  );
};
