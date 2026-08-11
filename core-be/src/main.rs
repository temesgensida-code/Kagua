mod models;
mod pdf;
mod secure_buffer;
mod service;
mod ws;

use std::net::SocketAddr;
use std::sync::Arc;
use axum::{
    extract::{Multipart, State},
    http::{header, HeaderMap, StatusCode},
    response::{IntoResponse, Json},
    routing::{get, post},
    Router,
};
use tower_http::cors::{Any, CorsLayer};
use tracing::info;

use crate::models::AnalysisReport;
use crate::pdf::generate_audit_pdf;
use crate::service::process_analysis_pipeline;
use crate::ws::{ws_handler, WsState};

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let ws_state = Arc::new(WsState::new());

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/health", get(health_check))
        .route("/ws", get(ws_handler))
        .route("/analyze", post(analyze_handler))
        .route("/report/pdf", post(generate_pdf_handler))
        .layer(cors)
        .with_state(ws_state);

    let port: u16 = std::env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8080);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    info!("Kagua Rust Core Backend listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("Failed to bind TCP listener");

    axum::serve(listener, app)
        .await
        .expect("Axum server error");
}

async fn health_check() -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "service": "kagua-core-be",
        "status": "online",
        "timestamp": std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs()
    }))
}

async fn analyze_handler(
    State(ws_state): State<Arc<WsState>>,
    mut multipart: Multipart,
) -> Result<Json<AnalysisReport>, (StatusCode, String)> {
    let mut filename = String::from("document.pdf");
    let mut content_type = None;
    let mut file_bytes: Option<Vec<u8>> = None;
    let mut domain_spec = serde_json::json!("all");

    while let Ok(Some(field)) = multipart.next_field().await {
        let name = field.name().unwrap_or_default().to_string();
        if name == "file" {
            if let Some(name_attr) = field.file_name() {
                filename = name_attr.to_string();
            }
            content_type = field.content_type().map(|c| c.to_string());
            let bytes = field
                .bytes()
                .await
                .map_err(|e| (StatusCode::BAD_REQUEST, format!("Failed to read field bytes: {}", e)))?;
            file_bytes = Some(bytes.to_vec());
        } else if name == "domain" {
            let text = field
                .text()
                .await
                .map_err(|e| (StatusCode::BAD_REQUEST, format!("Failed to read domain text: {}", e)))?;
            if let Ok(parsed_json) = serde_json::from_str::<serde_json::Value>(&text) {
                domain_spec = parsed_json;
            } else {
                domain_spec = serde_json::json!(text);
            }
        }
    }

    let bytes = file_bytes.ok_or_else(|| {
        (StatusCode::BAD_REQUEST, "Missing 'file' field in multipart form upload".to_string())
    })?;

    if bytes.is_empty() {
        return Err((StatusCode::BAD_REQUEST, "Uploaded file stream is empty".to_string()));
    }

    let report = process_analysis_pipeline(filename, content_type, bytes, domain_spec, &ws_state).await?;

    Ok(Json(report))
}

async fn generate_pdf_handler(
    Json(report): Json<AnalysisReport>,
) -> Result<impl IntoResponse, (StatusCode, String)> {
    let pdf_bytes = generate_audit_pdf(&report).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("PDF generation error: {}", e),
        )
    })?;

    let mut headers = HeaderMap::new();
    headers.insert(
        header::CONTENT_TYPE,
        "application/pdf".parse().unwrap(),
    );
    headers.insert(
        header::CONTENT_DISPOSITION,
        format!("attachment; filename=\"kagua_audit_{}\"", report.filename.replace(".txt", ".pdf").replace(".docx", ".pdf"))
            .parse()
            .unwrap(),
    );

    Ok((headers, pdf_bytes))
}
