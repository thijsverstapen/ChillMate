import {
  AbsoluteFill,
  Easing,
  Img,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Inter";

// The icon wordmark is set in Inter. Load it so the splash matches exactly.
const { fontFamily: INTER } = loadFont("normal", {
  weights: ["700", "800"],
  subsets: ["latin"],
});

// Brand palette (mirrors Color.chill* in LiquidGlass.swift)
const INDIGO = "#6366F1";
const SKY = "#60A5FA";
const TEAL = "#2DD4BF";
const NAVY_TOP = "#10131C";
const NAVY_BOTTOM = "#070A11";

const EASE_OUT = Easing.bezier(0.16, 1, 0.3, 1);

// First-launch splash. Uses the REAL app logomark (ChillMateGlyph) so it is
// pixel-identical to the app icon / static launch screen, then adds a calm glow
// bloom + breath and dissolves into the (navy) onboarding screen. The logomark
// and wordmark are present from frame 0 so the hand-off from the static launch
// screen is seamless.
export const ChillMateSplash: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();

  // Barely-there settle so the mark feels alive without "popping in".
  const settle = interpolate(frame, [0, 22], [0.97, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: EASE_OUT,
  });

  // Soft glow blooms to life behind the mark, then eases back.
  const glow = interpolate(frame, [0, 26, durationInFrames], [0.3, 0.62, 0.46], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Calm breathing.
  const breath = Math.sin((frame / durationInFrames) * Math.PI);
  const breatheScale = 1 + breath * 0.02;

  // Graceful exit: ease up + fade so it dissolves into onboarding.
  const exitStart = durationInFrames - 16;
  const exitScale = interpolate(frame, [exitStart, durationInFrames], [1, 1.06], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: EASE_OUT,
  });
  const exitOpacity = interpolate(frame, [exitStart, durationInFrames], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: NAVY_BOTTOM,
        backgroundImage: `radial-gradient(120% 80% at 50% 40%, ${NAVY_TOP} 0%, ${NAVY_BOTTOM} 70%)`,
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 54,
          translate: "0px -150px",
          scale: breatheScale * exitScale,
          opacity: exitOpacity,
        }}
      >
        {/* Real logomark + soft glow */}
        <div
          style={{
            position: "relative",
            width: 440,
            height: 440,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <div
            style={{
              position: "absolute",
              width: 440,
              height: 440,
              borderRadius: "50%",
              background: `radial-gradient(circle, ${SKY} 0%, rgba(96,165,250,0) 60%)`,
              opacity: glow,
              filter: "blur(34px)",
            }}
          />
          <Img
            src={staticFile("glyph.png")}
            style={{ width: 360, height: 360, scale: settle }}
          />
        </div>

        {/* Wordmark */}
        <div
          style={{
            fontSize: 112,
            fontWeight: 700,
            letterSpacing: -1.5,
            fontFamily: INTER,
            backgroundImage: `linear-gradient(90deg, ${INDIGO} 0%, ${SKY} 45%, ${TEAL} 100%)`,
            WebkitBackgroundClip: "text",
            backgroundClip: "text",
            color: "transparent",
          }}
        >
          ChillMate
        </div>
      </div>
    </AbsoluteFill>
  );
};
