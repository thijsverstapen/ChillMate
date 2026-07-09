import { AbsoluteFill, Img, staticFile } from "remotion";
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadSerif } from "@remotion/google-fonts/InstrumentSerif";

const { fontFamily: INTER } = loadInter("normal", { weights: ["500", "600", "700", "800"], subsets: ["latin"] });
const { fontFamily: SERIF } = loadSerif();

const IW = 1080;

const BrandRow = () => (
  <div style={{ position: "absolute", top: 66, left: 80, right: 80, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
    <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
      <Img src={staticFile("glyph.png")} style={{ width: 52, height: 52 }} />
      <span style={{ fontFamily: INTER, fontSize: 36, fontWeight: 700, color: "white" }}>ChillMate</span>
    </div>
    <span style={{ fontFamily: INTER, fontSize: 27, fontWeight: 600, color: "rgba(255,255,255,0.6)" }}>Free · Private · iPhone</span>
  </div>
);

const BG: React.FC<{ a: string; b: string; dark?: boolean }> = ({ a, b, dark }) =>
  dark ? (
    <>
      <AbsoluteFill style={{ background: "radial-gradient(120% 90% at 50% 0%, #111A38 0%, #0A1024 45%, #05070E 100%)" }} />
      <AbsoluteFill style={{ background: `radial-gradient(50% 32% at 16% 12%, ${a}55 0%, ${a}00 70%)` }} />
      <AbsoluteFill style={{ background: `radial-gradient(54% 36% at 86% 88%, ${b}44 0%, ${b}00 70%)` }} />
    </>
  ) : (
    <>
      <AbsoluteFill style={{ background: `linear-gradient(152deg, ${a} 0%, ${b} 100%)` }} />
      <AbsoluteFill style={{ background: "radial-gradient(85% 60% at 50% 110%, rgba(0,0,0,0.4), rgba(0,0,0,0) 62%)" }} />
    </>
  );

const Eyebrow: React.FC<{ text: string; a: string }> = ({ text, a }) => (
  <div style={{ display: "inline-flex", alignItems: "center", gap: 12, padding: "12px 26px", borderRadius: 999, background: `${a}2E`, border: `1.5px solid ${a}99`, marginBottom: 32 }}>
    <div style={{ width: 13, height: 13, borderRadius: "50%", background: a, boxShadow: `0 0 16px ${a}` }} />
    <span style={{ fontFamily: INTER, fontSize: 27, fontWeight: 700, letterSpacing: 3, color: "rgba(255,255,255,0.94)" }}>{text}</span>
  </div>
);

export type IGTextProps = { dark: boolean; a: string; b: string; eyebrow: string; serif: string; bold: string; body: string; footer: string; align: "center" | "left" };
export const IGText: React.FC<IGTextProps> = ({ dark, a, b, eyebrow, serif, bold, body, footer, align }) => (
  <AbsoluteFill style={{ fontFamily: INTER }}>
    <BG a={a} b={b} dark={dark} />
    <BrandRow />
    <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", padding: "0 92px" }}>
      {eyebrow ? <Eyebrow text={eyebrow} a={a} /> : null}
      <div style={{ textAlign: "center" }}>
        <div style={{ fontFamily: SERIF, fontSize: 84, color: "rgba(255,255,255,0.96)", lineHeight: 1.0 }}>{serif}</div>
        <div style={{ fontFamily: INTER, fontWeight: 800, fontSize: 116, textTransform: "uppercase", letterSpacing: -3, lineHeight: 0.98, color: "white", marginTop: 4 }}>{bold}</div>
      </div>
      {body ? (
        <div style={{ marginTop: 44, fontSize: 43, fontWeight: 500, color: "rgba(255,255,255,0.82)", textAlign: align, lineHeight: 1.4, maxWidth: 860, whiteSpace: "pre-line" }}>{body}</div>
      ) : null}
    </AbsoluteFill>
    {footer ? (
      <div style={{ position: "absolute", bottom: 78, left: 0, right: 0, textAlign: "center", fontFamily: INTER, fontSize: 33, fontWeight: 600, color: "rgba(255,255,255,0.72)" }}>{footer}</div>
    ) : null}
  </AbsoluteFill>
);

export type IGFeatureProps = { screenshot: string; a: string; b: string; serif: string; bold: string };
export const IGFeature: React.FC<IGFeatureProps> = ({ screenshot, a, b, serif, bold }) => (
  <AbsoluteFill style={{ fontFamily: INTER }}>
    <BG a={a} b={b} dark />
    <BrandRow />
    <div style={{ position: "absolute", top: 196, left: 0, right: 0, textAlign: "center", padding: "0 80px" }}>
      <div style={{ fontFamily: SERIF, fontSize: 66, color: "rgba(255,255,255,0.96)", lineHeight: 1.0 }}>{serif}</div>
      <div style={{ fontFamily: INTER, fontWeight: 800, fontSize: 100, textTransform: "uppercase", letterSpacing: -2.5, lineHeight: 0.98, color: "white", marginTop: 4 }}>{bold}</div>
    </div>
    <div style={{ position: "absolute", top: 520, left: (IW - 720) / 2, width: 720, padding: 12, borderRadius: 62, background: "#0C0D11", border: "1.6px solid rgba(255,255,255,0.16)", boxShadow: `0 40px 90px rgba(0,0,0,0.6), 0 0 80px ${a}26` }}>
      <div style={{ borderRadius: 50, overflow: "hidden", border: "1px solid rgba(0,0,0,0.6)" }}>
        <Img src={staticFile(screenshot)} style={{ width: "100%", display: "block" }} />
      </div>
    </div>
  </AbsoluteFill>
);
