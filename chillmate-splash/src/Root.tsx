import "./index.css";
import { Composition } from "remotion";
import { ChillMateSplash } from "./Splash";

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
    </>
  );
};
