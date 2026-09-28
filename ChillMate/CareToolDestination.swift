import SwiftUI

/// The screen each care tool opens to from Home's navigation stack.
///
/// Routed in two steps. One `switch` over every page inside a single view builder
/// nests a conditional type per case, and at twenty cases that one function took
/// nearly half a second to type-check on every build that touched Home. The top
/// level stays exhaustive, so a new page still has to be routed somewhere; each
/// group below it is only ever handed its own pages.
struct CareToolDestination: View {
    let page: CareToolPage
    let open: (CareToolPage) -> Void

    var body: some View {
        switch page {
        case .safetyAutopilot, .saferPlanning, .stdTests, .drugTimers, .emergency, .panicSupport:
            safetyTool
        case .drugInfo, .aftercare, .combinationRisk, .consentBoundaries, .recoveryMode:
            careTool
        case .privateInsights, .helperBridge, .drugChecking, .safeRoute, .weeklyReflection:
            reflectionTool
        case .groupBefore, .groupDuring, .groupAfter, .groupPatterns:
            if let group = CareToolGroup.homeGroups.first(where: { $0.page == page }) {
                CareToolGroupView(group: group, open: open)
            }
        }
    }

    @ViewBuilder
    private var safetyTool: some View {
        switch page {
        case .safetyAutopilot: SafetyAutopilotView()
        case .saferPlanning: SaferSessionPlanView()
        case .stdTests: STDTestsView()
        case .drugTimers: DrugTimerView()
        case .emergency: EmergencyNetherlandsView()
        case .panicSupport: PanicSupportView()
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var careTool: some View {
        switch page {
        case .drugInfo: DrugInfoView()
        case .aftercare: AftercareView()
        case .combinationRisk: CombinationRiskCheckerView()
        case .consentBoundaries: ConsentBoundariesView()
        case .recoveryMode: RecoveryModeView()
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var reflectionTool: some View {
        switch page {
        case .privateInsights: PrivateInsightsView()
        case .helperBridge: ProfessionalHelperBridgeView()
        case .drugChecking: DrugCheckingEducationView()
        case .safeRoute: SafeRouteHomeView()
        case .weeklyReflection: WeeklyReflectionView()
        default: EmptyView()
        }
    }
}
