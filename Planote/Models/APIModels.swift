import Foundation

// MARK: - Upload

struct CreateUploadRequest: Encodable {
    let content_type: String
    let file_name: String
}

struct CreateUploadResponse: Decodable {
    let upload_id: String
    let object_path: String
    let upload_url: String
    let expires_at: String
}

// MARK: - Note

struct NoteCreateRequest: Encodable {
    let upload_id: String
}

struct NoteCreateResponse: Decodable {
    let note_id: String
    let status: String
}

struct NoteResponse: Decodable {
    let note_id: String
    let status: String
    let ocr_status: String
    let extraction_status: String
    let created_at: String
}

// MARK: - Process

struct ProcessResponseV1: Decodable {
    let note_id: String
    let status: String
    let ocr_status: String
    let extraction_status: String
    let extraction_job_id: String
    let candidates: [ExtractionCandidate]
}

// MARK: - Extraction Candidates

struct ExtractionCandidate: Decodable, Identifiable {
    let candidate_id: String
    let note_id: String
    let type: String
    let title: String
    let date: String?
    let start_time: String?
    let end_time: String?
    let timezone: String?
    let location: String?
    let description: String?
    let confidence: Double
    let needs_confirmation: Bool
    let status: String

    var id: String { candidate_id }
}

struct ExtractionsResponse: Decodable {
    let note_id: String
    let status: String
    let candidates: [ExtractionCandidate]
}

// MARK: - Confirm

struct NoteConfirmRequest: Encodable {
    let candidate_ids: [String]
}

struct NoteConfirmResponse: Decodable {
    let note_id: String
    let confirmed_count: Int
}
