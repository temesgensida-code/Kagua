use std::sync::Arc;
use axum::{
    extract::ws::{Message, WebSocket, WebSocketUpgrade},
    response::IntoResponse,
};
use tokio::sync::broadcast;
use tracing::{info, warn};
use crate::models::ProgressEvent;

#[derive(Clone)]
pub struct WsState {
    tx: broadcast::Sender<ProgressEvent>,
}

impl WsState {
    pub fn new() -> Self {
        let (tx, _) = broadcast::channel(100);
        Self { tx }
    }

    pub fn broadcast_progress(&self, stage: &str, message: &str, details: Option<serde_json::Value>) {
        let now_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as u64)
            .unwrap_or(0);

        let event = ProgressEvent {
            stage: stage.to_string(),
            message: message.to_string(),
            details,
            timestamp_ms: now_ms,
        };

        let _ = self.tx.send(event);
    }
}

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    axum::extract::State(state): axum::extract::State<Arc<WsState>>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, state))
}

async fn handle_socket(mut socket: WebSocket, state: Arc<WsState>) {
    info!("WebSocket client connected for progress streaming");
    let mut rx = state.tx.subscribe();

    // Send initial welcome message
    let welcome = serde_json::json!({
        "stage": "CONNECTED",
        "message": "Connected to Kagua WebSocket progress stream"
    });
    if socket.send(Message::Text(welcome.to_string())).await.is_err() {
        return;
    }

    loop {
        tokio::select! {
            result = rx.recv() => {
                match result {
                    Ok(event) => {
                        if let Ok(json_str) = serde_json::to_string(&event) {
                            if socket.send(Message::Text(json_str)).await.is_err() {
                                break;
                            }
                        }
                    }
                    Err(broadcast::error::RecvError::Lagged(n)) => {
                        warn!("WebSocket client lagged by {} messages", n);
                    }
                    Err(broadcast::error::RecvError::Closed) => {
                        break;
                    }
                }
            }
            msg = socket.recv() => {
                match msg {
                    Some(Ok(Message::Close(_))) | None => break,
                    _ => {}
                }
            }
        }
    }
    info!("WebSocket client disconnected");
}
