import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    @Bindable private var paywallCoordinator = PaywallCoordinator.shared
    @Bindable private var ratingCoordinator = RatingCoordinator.shared
    @State private var showFolderMonitor = false
    
    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            ControlsBar()
            ContentArea()
            BottomBar()
        }
        .frame(minWidth: 680)
        .background(.thickMaterial)
        .ignoresSafeArea(.all, edges: .top)
        .onAppear {
            WindowConfigurator.configureMainWindow()
            PurchaseManager.shared.configure()
        }
        .focusable()
        .focusEffectDisabled()
        .onCommand(#selector(NSText.paste(_:))) {
            vm.addFromPasteboard()
        }
        .sheet(isPresented: $paywallCoordinator.isPresented) {
            PaywallView()
        }
        .sheet(isPresented: $ratingCoordinator.isPresented) {
            RatingView()
        }
        .processingErrorAlert(errors: $vm.processingErrors)
        .sheet(isPresented: $showFolderMonitor) {
            FolderMonitorSettingsView { showFolderMonitor = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showFolderMonitorSettings)) { _ in
            showFolderMonitor = true
        }
    }
}

#Preview {
    MainView()
        .environmentObject(ImageToolsViewModel())
}
