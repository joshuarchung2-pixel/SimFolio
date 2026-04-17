import Foundation

protocol MetadataManaging: AnyObject {
    var portfolios: [Portfolio] { get }
    var procedureConfigs: [ProcedureConfig] { get }
    var stageConfigs: [StageConfig] { get }
    var assetMetadata: [String: PhotoMetadata] { get }
    var importedAssetIds: Set<String> { get }

    func addPortfolio(_ portfolio: Portfolio)
    func updatePortfolio(_ portfolio: Portfolio)
    func deletePortfolio(_ portfolioId: String)
    func getPortfolio(by id: String) -> Portfolio?

    func assignMetadata(_ metadata: PhotoMetadata, to assetId: String)
    func getMetadata(for assetId: String) -> PhotoMetadata?
    func deleteMetadata(for assetId: String)

    func getPortfolioStats(_ portfolio: Portfolio) -> (fulfilled: Int, total: Int)
    func getPortfolioCompletionPercentage(_ portfolio: Portfolio) -> Double
    func getMatchingPhotoCount(procedure: String, stage: String, angle: String) -> Int

    func getEnabledProcedureNames() -> [String]
    func getEnabledStageNames() -> [String]

    func getRating(for assetId: String) -> Int?
    func setRating(_ rating: Int?, for assetId: String)

    func photoCount(for procedure: String) -> Int

    func hasImported(assetId: String) -> Bool
    func markImported(assetId: String)
}
