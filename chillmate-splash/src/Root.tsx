import "./index.css";
import { Composition } from "remotion";
import { ChillMateSplash } from "./Splash";
import { PreviewHero, PreviewShot } from "./AppStorePreview";
import { IGText, IGFeature } from "./Instagram";

// First-launch splash for the ChillMate iOS app.
// Rendered to a video and played once, before onboarding.
// Portrait, sized to comfortably cover modern iPhone screens (~19.5:9).
export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="ChillMateSplash"
        component={ChillMateSplash}
        durationInFrames={72}
        fps={30}
        width={1170}
        height={2532}
      />

      {/* App Store screenshots — 6.9" iPhone (1290 x 2796), rendered as stills. */}
      <Composition
        id="PreviewHero"
        component={PreviewHero}
        durationInFrames={1}
        fps={30}
        width={1290}
        height={2796}
      />
      <Composition
        id="PreviewShot"
        component={PreviewShot}
        durationInFrames={1}
        fps={30}
        width={1290}
        height={2796}
        defaultProps={{
          screenshot: "shot-summary.png",
          serif: "Your private",
          bold: "Overview",
          glow: "#6366F1",
          layout: "full" as const,
          callout: "summary",
        }}
      />
      {/* Instagram posts — 1080 x 1350 (4:5), rendered as stills. */}
      <Composition
        id="IGText"
        component={IGText}
        durationInFrames={1}
        fps={30}
        width={1080}
        height={1350}
        defaultProps={{ dark: true, a: "#6366F1", b: "#2DD4BF", eyebrow: "", serif: "Free. Private.", bold: "No ads", body: "No paywall. No account.", footer: "", align: "center" as const }}
      />
      <Composition
        id="IGFeature"
        component={IGFeature}
        durationInFrames={1}
        fps={30}
        width={1080}
        height={1350}
        defaultProps={{ screenshot: "shot-summary.png", a: "#6366F1", b: "#22D3EE", serif: "Your daily", bold: "Score" }}
      />
    </>
  );
};
