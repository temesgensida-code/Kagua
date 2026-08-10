<script lang="ts">
  import type { Framework, SampleDoc } from '$lib/data/sampleDocs';

  interface Props {
    file: { name: string; size: string; type: string; content?: string; sampleId?: string };
    frameworks: Framework[];
    sampleDoc?: SampleDoc;
    onReset: () => void;
  }

  let { file, frameworks, sampleDoc, onReset }: Props = $props();

  let activeFrameworks = $derived(frameworks.filter(f => f.active));
  let score = $derived(sampleDoc ? sampleDoc.complianceScore : 94);

  let scoreColor = $derived(
    score >= 90 ? '#00ff88' : score >= 75 ? '#ffd700' : '#ff2a70'
  );

  let findings = $derived(
    sampleDoc
      ? sampleDoc.findings.filter(f =>
          activeFrameworks.some(fw => fw.name.toLowerCase() === f.framework.toLowerCase())
        )
      : [
          {
            framework: 'GDPR',
            severity: 'PASS' as const,
            title: 'Article 6(1) - Lawfulness of Processing',
            description: 'Explicit consent terms verified in document body.',
            recommendation: 'Ensure consent revocation mechanism remains accessible.'
          },
          {
            framework: 'ISO 27001',
            severity: 'WARNING' as const,
            title: 'Control A.12.6.1 - Management of Technical Vulnerabilities',
            description: 'Patching schedule interval defaults to 90 days instead of 30 days.',
            recommendation: 'Update policy clause to mandate critical security patches within 30 days.'
          },
          {
            framework: 'HIPAA',
            severity: 'PASS' as const,
            title: '§ 164.312(e)(1) - Transmission Security',
            description: 'TLS 1.3 protocol requirement confirmed for all electronic health data in transit.',
            recommendation: 'Quarterly certificate rotation logs required.'
          }
        ]
  );

  function downloadReport() {
    const reportData = {
      timestamp: new Date().toISOString(),
      document: file.name,
      fileSize: file.size,
      complianceScore: `${score}%`,
      activeFrameworks: activeFrameworks.map(f => f.name),
      findings: findings
    };

    const blob = new Blob([JSON.stringify(reportData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `Compliance_Audit_${file.name.replace(/[^a-z0-9]/gi, '_')}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }
</script>

<div class="result-container">
  <!-- Top Bar: File summary and reset button -->
  <div class="result-header">
    <div class="file-info">
      <div class="file-icon-badge">{file.type}</div>
      <div class="file-details">
        <h3 class="file-title">{file.name}</h3>
        <span class="file-meta">{file.size} &bull; {activeFrameworks.length} Frameworks Active</span>
      </div>
    </div>

    <button type="button" class="btn-rescan" onclick={onReset}>
      &larr; SCAN ANOTHER DOCUMENT
    </button>
  </div>

  <!-- Score & Matrix Grid -->
  <div class="summary-grid">
    <!-- Score Gauge Card -->
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
          <span class="score-label">COMPLIANT</span>
        </div>
      </div>

      <div class="score-status">
        <span class="status-pill" style="background: {scoreColor}15; color: {scoreColor}; border: 1px solid {scoreColor}40">
          {score >= 90 ? 'SYSTEM READY' : score >= 75 ? 'ACTION REQUIRED' : 'NON-COMPLIANT'}
        </span>
      </div>
    </div>

    <!-- Active Framework Status Grid -->
    <div class="framework-matrix-card">
      <h4 class="matrix-title">FRAMEWORK STATUS MATRIX</h4>
      <div class="matrix-grid">
        {#each activeFrameworks as fw}
          <div class="matrix-item" style="--fw-color: {fw.color}">
            <div class="matrix-item-header">
              <span class="fw-tag" style="color: {fw.color}">{fw.name}</span>
              <span class="fw-status-badge">PASS</span>
            </div>
            <span class="fw-rules-info">{fw.ruleCount} Rules Evaluated</span>
          </div>
        {/each}
      </div>
    </div>
  </div>

  <!-- Detailed Audit Findings -->
  <div class="findings-card">
    <div class="findings-header">
      <h4 class="findings-title">REGULATORY AUDIT FINDINGS ({findings.length})</h4>
      <button type="button" class="btn-download" onclick={downloadReport}>
        EXPORT REPORT (JSON)
      </button>
    </div>

    <div class="findings-list">
      {#each findings as finding}
        <div class="finding-item severity-{finding.severity.toLowerCase()}">
          <div class="finding-top">
            <span class="badge-severity severity-{finding.severity.toLowerCase()}">
              {finding.severity}
            </span>
            <span class="finding-fw">{finding.framework}</span>
            <span class="finding-rule-title">{finding.title}</span>
          </div>
          <p class="finding-desc">{finding.description}</p>
          <div class="finding-rec">
            <span class="rec-label">RECOMMENDED REMEDIATION:</span> {finding.recommendation}
          </div>
        </div>
      {/each}
    </div>
  </div>
</div>

<style>
  .result-container {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
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
    background: rgba(13, 23, 36, 0.8);
    border: 1px solid rgba(0, 240, 255, 0.2);
    border-radius: 6px;
    padding: 1rem 1.5rem;
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

  .summary-grid {
    display: grid;
    grid-template-columns: 240px 1fr;
    gap: 1.25rem;
  }

  @media (max-width: 768px) {
    .summary-grid {
      grid-template-columns: 1fr;
    }
  }

  .score-card {
    background: #0d1724;
    border: 1px solid rgba(0, 240, 255, 0.15);
    border-radius: 6px;
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 1rem;
  }

  .score-dial {
    position: relative;
    width: 120px;
    height: 120px;
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
    font-size: 1.75rem;
    font-weight: 800;
    line-height: 1;
  }

  .score-label {
    font-family: var(--font-mono);
    font-size: 0.6rem;
    letter-spacing: 1.5px;
    color: var(--text-muted);
  }

  .status-pill {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    font-weight: 700;
    letter-spacing: 1.5px;
    padding: 4px 12px;
    border-radius: 12px;
  }

  .framework-matrix-card {
    background: #0d1724;
    border: 1px solid rgba(0, 240, 255, 0.15);
    border-radius: 6px;
    padding: 1.25rem 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .matrix-title {
    font-family: var(--font-mono);
    font-size: 0.72rem;
    letter-spacing: 2px;
    color: var(--cyan-muted);
    font-weight: 700;
  }

  .matrix-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 0.75rem;
  }

  .matrix-item {
    background: rgba(7, 13, 20, 0.6);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-left: 3px solid var(--fw-color);
    padding: 10px 12px;
    border-radius: 4px;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .matrix-item-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .fw-tag {
    font-family: var(--font-mono);
    font-size: 0.75rem;
    font-weight: 700;
  }

  .fw-status-badge {
    font-family: var(--font-mono);
    font-size: 0.6rem;
    color: #00ff88;
    background: rgba(0, 255, 136, 0.1);
    padding: 2px 6px;
    border-radius: 2px;
  }

  .fw-rules-info {
    font-family: var(--font-body);
    font-size: 0.68rem;
    color: var(--text-muted);
  }

  /* Findings List */
  .findings-card {
    background: #0d1724;
    border: 1px solid rgba(0, 240, 255, 0.15);
    border-radius: 6px;
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  .findings-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    padding-bottom: 0.75rem;
  }

  .findings-title {
    font-family: var(--font-mono);
    font-size: 0.75rem;
    letter-spacing: 2px;
    color: #ffffff;
    font-weight: 700;
  }

  .btn-download {
    background: var(--cyan-primary);
    color: #050b14;
    border: none;
    font-family: var(--font-mono);
    font-size: 0.68rem;
    font-weight: 700;
    letter-spacing: 1px;
    padding: 6px 14px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .btn-download:hover {
    filter: brightness(1.2);
    box-shadow: 0 0 10px rgba(0, 240, 255, 0.5);
  }

  .findings-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .finding-item {
    background: rgba(6, 11, 18, 0.8);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 4px;
    padding: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .finding-top {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }

  .badge-severity {
    font-family: var(--font-mono);
    font-size: 0.62rem;
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

  .badge-severity.severity-pass {
    background: rgba(0, 255, 136, 0.2);
    color: #00ff88;
    border: 1px solid #00ff88;
  }

  .finding-fw {
    font-family: var(--font-mono);
    font-size: 0.72rem;
    color: var(--cyan-muted);
    font-weight: 700;
  }

  .finding-rule-title {
    font-family: var(--font-title);
    font-size: 0.85rem;
    color: #ffffff;
    font-weight: 600;
  }

  .finding-desc {
    font-family: var(--font-body);
    font-size: 0.82rem;
    color: var(--text-muted);
    line-height: 1.4;
  }

  .finding-rec {
    font-family: var(--font-mono);
    font-size: 0.75rem;
    color: #a0b2c6;
    background: rgba(0, 240, 255, 0.04);
    border-left: 2px solid var(--cyan-primary);
    padding: 6px 10px;
    border-radius: 2px;
  }

  .rec-label {
    color: var(--cyan-primary);
    font-weight: 700;
  }
</style>
