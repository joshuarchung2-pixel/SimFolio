import Foundation

protocol EditStatePersisting {
    func saveEditState(_ editState: EditState, for assetId: String)
    func getEditState(for assetId: String) -> EditState?
    func hasEditState(for assetId: String) -> Bool
    func deleteEditState(for assetId: String)
    func getEditSummary(for assetId: String) -> String?
}
