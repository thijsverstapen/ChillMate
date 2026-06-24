import { AbsoluteFill, Easing, interpolate, useCurrentFrame, useVideoConfig } from "remotion";

// Brand palette (mirrors Color.chill* in LiquidGlass.swift)
const INDIGO = "#6366F1";
const SKY = "#60A5FA";
const TEAL = "#2DD4BF";
const MINT = "#7EE7C7";
const NAVY_TOP = "#10131C";
const NAVY_BOTTOM = "#070A11";

const EASE_OUT = Easing.bezier(0.16, 1, 0.3, 1);

// Seamless variant: the logomark + wordmark are FULLY present from frame 0,
// matching the static launch screen (Splash.png). Nothing pops in or redraws —
// the only motion is a calm glow bloom, a subtle breath, and a graceful
// dissolve into the (navy) onboarding screen at the end.
export const ChillMateSplash: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();

  // Soft glow blooms gently to life, then settles.
  const glow = interpolate(frame, [0, 26, durationInFrames], [0.3, 0.6, 0.46], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Very subtle breathing on the whole mark (calm, on-brand).
  const breath = Math.sin((frame / durationInFrames) * Math.PI);
  const breatheScale = 1 + breath * 0.02;

  // Graceful exit: ease up + fade the mark so it dissolves into onboarding,
  // leaving the matching navy background behind.
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
          gap: 60,
          translate: "0px -150px",
          scale: breatheScale * exitScale,
          opacity: exitOpacity,
        }}
      >
        {/* Logomark + soft glow */}
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
              background: `radial-gradient(circle, ${SKY} 0%, rgba(96,165,250,0) 62%)`,
              opacity: glow,
              filter: "blur(28px)",
            }}
          />
          <svg width={420} height={420} viewBox="0 0 240 240">
            <defs>
              <linearGradient id="cGrad" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor={INDIGO} />
                <stop offset="100%" stopColor={SKY} />
              </linearGradient>
              <linearGradient id="checkGrad" x1="0" y1="1" x2="1" y2="0">
                <stop offset="0%" stopColor={TEAL} />
                <stop offset="100%" stopColor={MINT} />
              </linearGradient>
            </defs>

            {/* "C" arc, gap centred on the right (toward the checkmark) */}
            <path
              d="M 169.5 169.5 A 70 70 0 1 1 169.5 70.5"
              fill="none"
              stroke="url(#cGrad)"
              strokeWidth={30}
              strokeLinecap="round"
            />

            {/* checkmark */}
            <path
              d="M 96 124 L 114 142 L 156 92"
              fill="none"
              stroke="url(#checkGrad)"
              strokeWidth={26}
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </div>

        {/* Wordmark (static gradient, matches the launch screen) */}
        <div
          style={{
            fontSize: 112,
            fontWeight: 700,
            letterSpacing: -1,
            fontFamily:
              '"Arial Rounded MT Bold", "SF Pro Rounded", "Avenir Next", system-ui, sans-serif',
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
