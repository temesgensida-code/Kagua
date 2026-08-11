<script lang="ts">
  import DocumentViewer from './DocumentViewer.svelte';
  import { downloadPdfAuditReport, type AnalysisReport, type MappedViolation } from '$lib/services/api';
  import type { Framework } from '$lib/data/sampleDocs';

  interface Props {
    file: { name: string; size: string; type: string; content?: string };
    report?: AnalysisReport;
    frameworks: Framework[];
    onReset: () => void;
  }

  let { file, report, frameworks, onReset }: Props = $props();

  let activeViolationIndex = $state<number | null>(null);

  // Raw text extracted or passed from file sample
  let rawText = $derived(
    report?.raw_text || file.content || `CONFIDENTIAL SERVICES & EMPLOYMENT AGREEMENT\n\n1. GOVERNING LAW\nThis Agreement shall be governed by and construed in accordance with the laws of the State of California, without giving effect to any choice of law principles.\n\n2. FEES AND PAYMENT TERMS\nClient agrees to pay Service Provider a total fee of $150,000 USD due within 30 days of invoice receipt.\n\n3. NON-COMPETE\nEmployee agrees not to engage in any competing business for a period of 36 months following termination.`
  );

  let activeFrameworks = $derived(frameworks.filter(f => f.active));

  // Compute compliance score based on critical (-25) and warning (-10) violations
  let score = $derived.by(() => {
    if (!report) return 85;
    const penalty = (report.critical_count * 25) + (report.warning_count * 10);
    return Math.max(0, 100 - penalty);
  });

  let scoreColor = $derived(
    score >= 80 ? '#00ff88' : score >= 50 ? '#ffd700' : '#ff2a70'
  );

  let violations = $derived<MappedViolation[]>(
    report?.violations || [
      {
        domain: 'employment',
        rule: 'Non-Compete Enforceability',
        title: 'Non-Compete in Restricted Jurisdiction',
        severity: 'critical',
        description: 'Non-compete clause present but may be unenforceable in California.',
        recommendation: 'Remove or narrow the non-compete clause under California Business & Professions Code § 16600.',
        snippet: 'Employee agrees not to engage in any competing business for a period of 36 months',
        start_char: 290,
        end_char: 380
      },
      {
        domain: 'finance',
        rule: 'SOX Section 302',
        title: 'No Officer Certification Clause',
        severity: 'warning',
        description: 'Document does not reference officer certification requirements for financial disclosures.',
        recommendation: 'Add explicit SOX Section 302 certification language to financial reporting procedures.',
        snippet: 'Client agrees to pay Service Provider a total fee of $150,000 USD',
        start_char: 160,
        end_char: 240
      }
    ]
  );

  let isDownloadingPdf = $state(false);

  async function handleDownloadPdf() {
    if (!report) {
      alert('No active backend audit report available to generate PDF.');
      return;
    }

    try {
      isDownloadingPdf = true;
      await downloadPdfAuditReport({
        ...report,
        raw_text: rawText
      });
    } catch (err: any) {
      alert(`PDF export error: ${err.message}`);
    } finally {
      isDownloadingPdf = false;
    }
  }

  function handleDownloadJson() {
    const dataStr = JSON.stringify(report || { filename: file.name, violations, score }, null, 2);
    const blob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `kagua_audit_${file.name.replace(/[^a-z0-9]/gi, '_')}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }

  function selectViolation(idx: number) {
    activeViolationIndex = activeViolationIndex === idx ? null : idx;
  }
</script>

<div class="result-container">
  <!-- Top Bar Header -->
  <div class="result-header">
    <div class="file-info">
      <div class="file-icon-badge">{file.type}</div>
      <div class="file-details">
        <h3 class="file-title">{file.name}</h3>
        <span class="file-meta">
          {file.size} &bull; 
          {#if report?.detected_jurisdiction}
            Jurisdiction: <strong class="badge-accent">{report.detected_jurisdiction}</strong> &bull;
          {/if}
          {#if report?.suggested_domain}
            Auto-Selected Domain: <strong class="badge-accent">{report.suggested_domain.toUpperCase()}</strong>
          {/if}
        </span>
      </div>
    </div>

    <div class="action-buttons">
      <button type="button" class="btn-rescan" onclick={onReset}>
        &larr; SCAN ANOTHER DOCUMENT
      </button>
    </div>
  </div>

  <!-- Main Split Screen Work Area -->
  <div class="split-screen-grid">
    <!-- Left Panel: Split Document Viewer with Offset Highlights -->
    <div class="viewer-column">
      <DocumentViewer
        filename={file.name}
        {rawText}
        {violations}
        {activeViolationIndex}
        onSelectViolation={selectViolation}
      />
    </div>

    <!-- Right Panel: Compliance Summary & Violations Cards -->
    <div class="summary-column">
      <!-- Score & Status Card -->
      <div class="score-card">
        <div class="score-dial" style="--score-color: {scoreColor}">
          <svg class="score-ring" viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="42" stroke="rgba(255,255,255,0.06)" stroke-width="8" fill="none" />
            <circle
              cx="50"
              cy="50"
              r="42"
              stroke={scoreColor}
              stroke-width="8"
              fill="none"
              stroke-dasharray="263.89"
              stroke-dashoffset={263.89 - (263.89 * score) / 100}
              stroke-linecap="round"
              style="transition: stroke-dashoffset 1s ease;"
            />
          </svg>
          <div class="score-value-box">
            <span class="score-num" style="color: {scoreColor}">{score}%</span>
            <span class="score-label">COMPLIANCE</span>
          </div>
        </div>

        <div class="score-status">
          <span class="status-pill" style="background: {scoreColor}15; color: {scoreColor}; border: 1px solid {scoreColor}40">
            {score >= 80 ? 'HIGH COMPLIANCE' : score >= 50 ? 'MODERATE RISK' : 'CRITICAL RISK'}
          </span>
        </div>

        <div class="counts-row">
          <span class="count-chip critical">CRITICAL: {report ? report.critical_count : violations.filter(v => v.severity === 'critical').length}</span>
          <span class="count-chip warning">WARNING: {report ? report.warning_count : violations.filter(v => v.severity === 'warning').length}</span>
        </div>
      </div>

      <!-- Action Export Panel -->
      <div class="export-card">
        <h4 class="export-title">AUDIT REPORT EXPORT</h4>
        <div class="export-buttons">
          <button type="button" class="btn-pdf-export" disabled={isDownloadingPdf} onclick={handleDownloadPdf}>
            {#if isDownloadingPdf}
              GENERATING PDF...
            {:else}
              📥 DOWNLOAD PDF REPORT
            {/if}
          </button>
          <button type="button" class="btn-json-export" onclick={handleDownloadJson}>
            ⚙ EXPORT JSON
          </button>
        </div>
      </div>

      <!-- Violation Findings Cards List -->
      <div class="findings-card">
        <div class="findings-header">
          <h4 class="findings-title">REASONER FINDINGS ({violations.length})</h4>
          <span class="sub-info">Click card to jump to text offset</span>
        </div>

        <div class="findings-list">
          {#each violations as violation, idx}
            <div
              class="finding-item severity-{violation.severity}"
              class:selected={activeViolationIndex === idx}
              onclick={() => selectViolation(idx)}
              onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && selectViolation(idx)}
              role="button"
              tabindex="0"
            >
              <div class="finding-top">
                <span class="badge-severity severity-{violation.severity}">
                  {violation.severity.toUpperCase()}
                </span>
                <span class="finding-domain">[{violation.domain}]</span>
                <span class="finding-rule-title">{violation.title}</span>
              </div>

              <div class="finding-rule-code">Rule: {violation.rule}</div>
              <p class="finding-desc">{violation.description}</p>

              {#if violation.recommendation}
                <div class="finding-rec">
                  <span class="rec-label">REMEDIATION:</span> {violation.recommendation}
                </div>
              {/if}

              {#if typeof violation.start_char === 'number' && typeof violation.end_char === 'number'}
                <div class="offset-badge">
                  📍 Offset: Chars {violation.start_char} &ndash; {violation.end_char}
                </div>
              {/if}
            </div>
          {/each}
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .result-container {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
    animation: fadeIn 0.4s ease;
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(10px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .result-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: rgba(13, 23, 36, 0.9);
    border: 1px solid rgba(0, 240, 255, 0.2);
    border-radius: 6px;
    padding: 0.85rem 1.25rem;
    flex-wrap: wrap;
    gap: 1rem;
  }

  .file-info {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .file-icon-badge {
    padding: 6px 10px;
    background: rgba(0, 240, 255, 0.15);
    border: 1px solid var(--cyan-primary);
    border-radius: 4px;
    color: var(--cyan-primary);
    font-family: var(--font-mono);
    font-size: 0.75rem;
    font-weight: 700;
  }

  .file-title {
    font-family: var(--font-title);
    font-size: 1.05rem;
    color: #ffffff;
    font-weight: 700;
  }

  .file-meta {
    font-family: var(--font-mono);
    font-size: 0.7rem;
    color: var(--text-muted);
  }

  .badge-accent {
    color: var(--cyan-primary);
  }

  .btn-rescan {
    background: transparent;
    border: 1px solid rgba(0, 240, 255, 0.3);
    color: var(--cyan-primary);
    font-family: var(--font-mono);
    font-size: 0.72rem;
    font-weight: 600;
    letter-spacing: 1px;
    padding: 8px 16px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .btn-rescan:hover {
    background: rgba(0, 240, 255, 0.1);
    border-color: var(--cyan-primary);
    box-shadow: 0 0 10px rgba(0, 240, 255, 0.3);
  }

  /* Split Screen Layout */
  .split-screen-grid {
    display: grid;
    grid-template-columns: 1fr 440px;
    gap: 1.25rem;
    min-height: 600px;
  }

  @media (max-width: 1024px) {
    .split-screen-grid {
      grid-template-columns: 1fr;
    }
  }

  .viewer-column {
    display: flex;
    flex-direction: column;
  }

  .summary-column {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  /* Score Dial Card */
  .score-card {
    background: #0d1724;
    border: 1px solid rgba(0, 240, 255, 0.15);
    border-radius: 6px;
    padding: 1.25rem;
    display: flex;
    align-items: center;
    justify-content: space-around;
    gap: 1rem;
    flex-wrap: wrap;
  }

  .score-dial {
    position: relative;
    width: 90px;
    height: 90px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .score-ring {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    transform: rotate(-90deg);
  }

  .score-value-box {
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  .score-num {
    font-family: var(--font-title);
    font-size: 1.4rem;
    font-weight: 800;
    line-height: 1;
  }

  .score-label {
    font-family: var(--font-mono);
    font-size: 0.55rem;
    letter-spacing: 1px;
    color: var(--text-muted);
  }

  .status-pill {
    font-family: var(--font-mono);
    font-size: 0.65rem;
    font-weight: 700;
    letter-spacing: 1px;
    padding: 4px 10px;
    border-radius: 12px;
  }

  .counts-row {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .count-chip {
    font-family: var(--font-mono);
    font-size: 0.65rem;
    font-weight: 700;
    padding: 3px 8px;
    border-radius: 3px;
  }

  .count-chip.critical {
    color: #ff2a70;
    background: rgba(255, 42, 112, 0.1);
    border: 1px solid rgba(255, 42, 112, 0.3);
  }

  .count-chip.warning {
    color: #ffd700;
    background: rgba(255, 215, 0, 0.1);
    border: 1px solid rgba(255, 215, 0, 0.3);
  }

  /* Export Card */
  .export-card {
    background: #0d1724;
    border: 1px solid rgba(0, 240, 255, 0.15);
    border-radius: 6px;
    padding: 1rem 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .export-title {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    letter-spacing: 1.5px;
    color: var(--cyan-muted);
    font-weight: 700;
  }

  .export-buttons {
    display: flex;
    gap: 10px;
  }

  .btn-pdf-export {
    flex: 1;
    background: var(--cyan-primary);
    color: #050b14;
    border: none;
    font-family: var(--font-mono);
    font-size: 0.72rem;
    font-weight: 700;
    letter-spacing: 1px;
    padding: 10px 14px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s ease;
    box-shadow: 0 0 12px rgba(0, 240, 255, 0.3);
  }

  .btn-pdf-export:hover:not(:disabled) {
    background: #5ce1e6;
    box-shadow: 0 0 20px rgba(0, 240, 255, 0.6);
  }

  .btn-pdf-export:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-json-export {
    background: transparent;
    border: 1px solid rgba(0, 240, 255, 0.3);
    color: var(--cyan-primary);
    font-family: var(--font-mono);
    font-size: 0.72rem;
    font-weight: 600;
    padding: 10px 14px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .btn-json-export:hover {
    background: rgba(0, 240, 255, 0.1);
  }

  /* Findings List */
  .findings-card {
    background: #0d1724;
    border: 1px solid rgba(0, 240, 255, 0.15);
    border-radius: 6px;
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
    flex: 1;
  }

  .findings-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    padding-bottom: 0.5rem;
  }

  .findings-title {
    font-family: var(--font-mono);
    font-size: 0.72rem;
    letter-spacing: 1.5px;
    color: #ffffff;
    font-weight: 700;
  }

  .sub-info {
    font-family: var(--font-mono);
    font-size: 0.62rem;
    color: var(--text-muted);
  }

  .findings-list {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
    max-height: 520px;
    overflow-y: auto;
  }

  .finding-item {
    background: rgba(6, 11, 18, 0.8);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 4px;
    padding: 0.85rem;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .finding-item:hover {
    border-color: rgba(0, 240, 255, 0.4);
    background: rgba(0, 240, 255, 0.04);
  }

  .finding-item.selected {
    border-color: var(--cyan-primary);
    box-shadow: 0 0 14px rgba(0, 240, 255, 0.25);
    background: rgba(0, 240, 255, 0.08);
  }

  .finding-top {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .badge-severity {
    font-family: var(--font-mono);
    font-size: 0.6rem;
    font-weight: 800;
    padding: 2px 6px;
    border-radius: 2px;
  }

  .badge-severity.severity-critical {
    background: rgba(255, 42, 112, 0.2);
    color: #ff2a70;
    border: 1px solid #ff2a70;
  }

  .badge-severity.severity-warning {
    background: rgba(255, 215, 0, 0.2);
    color: #ffd700;
    border: 1px solid #ffd700;
  }

  .finding-domain {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    color: var(--cyan-muted);
    font-weight: 700;
  }

  .finding-rule-title {
    font-family: var(--font-title);
    font-size: 0.82rem;
    color: #ffffff;
    font-weight: 600;
  }

  .finding-rule-code {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    color: #8fa0b5;
  }

  .finding-desc {
    font-family: var(--font-body);
    font-size: 0.78rem;
    color: var(--text-muted);
    line-height: 1.35;
  }

  .finding-rec {
    font-family: var(--font-mono);
    font-size: 0.7rem;
    color: #a0b2c6;
    background: rgba(0, 240, 255, 0.04);
    border-left: 2px solid var(--cyan-primary);
    padding: 4px 8px;
    border-radius: 2px;
  }

  .rec-label {
    color: var(--cyan-primary);
    font-weight: 700;
  }

  .offset-badge {
    font-family: var(--font-mono);
    font-size: 0.62rem;
    color: var(--cyan-primary);
    background: rgba(0, 240, 255, 0.06);
    padding: 2px 6px;
    border-radius: 2px;
    align-self: flex-start;
  }
</style>
