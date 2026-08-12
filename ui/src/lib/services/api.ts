export interface MappedViolation {
  domain: string;
  rule: string;
  title: string;
  severity: 'critical' | 'warning' | 'info';
  description: string;
  recommendation: string;
  snippet?: string;
  start_char?: number;
  end_char?: number;
}

export interface AnalysisReport {
  filename: string;
  text_length: number;
  domains_checked: any;
  suggested_domain?: string;
  detected_jurisdiction?: string;
  total_violations: number;
  critical_count: number;
  warning_count: number;
  violations: MappedViolation[];
  entities_extracted: number;
  clauses_detected: number;
  pii_redacted_count?: number;
  rag_facts?: any;
  raw_text?: string;
}

export interface ProgressEvent {
  stage: string;
  message: string;
  details?: any;
  timestamp_ms: number;
}

const API_BASE = 'http://127.0.0.1:8080';
const WS_BASE = 'ws://127.0.0.1:8080/ws';

export async function analyzeDocument(
  fileData: Blob | File,
  filename: string,
  domain: string = 'auto'
): Promise<AnalysisReport> {
  const formData = new FormData();
  formData.append('file', fileData, filename);
  formData.append('domain', domain);

  const response = await fetch(`${API_BASE}/analyze`, {
    method: 'POST',
    body: formData,
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Analysis failed (${response.status}): ${errorText}`);
  }

  return response.json();
}

export async function downloadPdfAuditReport(report: AnalysisReport): Promise<void> {
  const response = await fetch(`${API_BASE}/report/pdf`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(report),
  });

  if (!response.ok) {
    throw new Error(`PDF download failed (${response.status})`);
  }

  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `kagua_audit_${report.filename.replace(/\.[^/.]+$/, '')}.pdf`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export function subscribeProgress(onProgress: (event: ProgressEvent) => void): () => void {
  try {
    const socket = new WebSocket(WS_BASE);

    socket.onmessage = (event) => {
      try {
        const parsed: ProgressEvent = JSON.parse(event.data);
        onProgress(parsed);
      } catch (err) {
        console.error('Failed to parse WS message:', err);
      }
    };

    socket.onerror = (err) => {
      console.warn('WebSocket connection error:', err);
    };

    return () => {
      if (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING) {
        socket.close();
      }
    };
  } catch (err) {
    console.warn('WebSocket subscription failed:', err);
    return () => {};
  }
}
