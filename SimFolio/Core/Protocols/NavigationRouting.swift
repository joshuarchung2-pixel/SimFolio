import Foundation

protocol NavigationRouting: AnyObject {
    var selectedTab: MainTab { get set }
    var isTabBarVisible: Bool { get }
    var activeSheet: NavigationRouter.SheetType? { get }
    var captureFlowActive: Bool { get }
    var libraryFilter: LibraryFilter { get set }

    func navigateToHome()
    func navigateToCapture(procedure: String?, stage: String?, angle: String?, toothNumber: Int?, forPortfolioId: String?)
    func navigateToLibrary(filter: LibraryFilter?)
    func navigateToPortfolio(id: String)
    func presentSheet(_ sheet: NavigationRouter.SheetType)
    func dismissSheet()
    func showTabBar()
    func hideTabBar()
    func resetCaptureState()
    func resetAll()
}
