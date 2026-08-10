<script lang="ts">
  import { SAMPLE_DOCS, type SampleDoc } from '$lib/data/sampleDocs';

  interface Props {
    isScanning: boolean;
    onFileSelected: (file: { name: string; size: string; type: string; content?: string; sampleId?: string }) => void;
  }

  let { isScanning = false, onFileSelected }: Props = $props();

  let isDragging = $state(false);
  let fileInput: HTMLInputElement;

  function handleDragOver(e: DragEvent) {
    e.preventDefault();
    isDragging = true;
  }

  function handleDragLeave(e: DragEvent) {
    e.preventDefault();
    isDragging = false;
  }

  function handleDrop(e: DragEvent) {
    e.preventDefault();
    isDragging = false;
    if (e.dataTransfer?.files && e.dataTransfer.files.length > 0) {
      const file = e.dataTransfer.files[0];
      const sizeMB = (file.size / (1024 * 1024)).toFixed(1) + ' MB';
      const ext = file.name.split('.').pop()?.toUpperCase() || 'DOC';
      onFileSelected({
        name: file.name,
        size: sizeMB,
        type: ext
      });
    }
  }

  function handleFileInputChange(e: Event) {
    const input = e.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      const file = input.files[0];
      const sizeMB = (file.size / (1024 * 1024)).toFixed(1) + ' MB';
      const ext = file.name.split('.').pop()?.toUpperCase() || 'DOC';
      onFileSelected({
        name: file.name,
        size: sizeMB,
        type: ext
      });
    }
  }

  function triggerBrowse() {
    fileInput?.click();
  }

  function selectSample(sample: SampleDoc) {
    onFileSelected({
      name: sample.filename,
      size: sample.size,
      type: sample.type,
      content: sample.content,
      sampleId: sample.id
    });
  }
</script>

<div class="dropzone-wrapper">
  <div
    class="dropzone-panel"
    class:dragging={isDragging}
    class:scanning={isScanning}
    ondragover={handleDragOver}
    ondragleave={handleDragLeave}
    ondrop={handleDrop}
    role="region"
    aria-label="Document Drop Zone"
  >
    <!-- Cyberpunk Corner Brackets -->
    <div class="corner-bracket top-left"></div>
    <div class="corner-bracket bottom-right"></div>

    <!-- Hidden native file input -->
    <input
      type="file"
      bind:this={fileInput}
      onchange={handleFileInputChange}
      accept=".txt,.pdf,.doc,.docx,.md"
      class="hidden-input"
    />

    <!-- Scanning Overlay Bar -->
    {#if isScanning}
      <div class="scan-laser"></div>
      <div class="scanning-hud">
        <div class="spinner"></div>
        <span class="scan-text">ANALYZING DOCUMENT STRUCTURAL COMPLIANCE...</span>
      </div>
    {/if}

    <div class="dropzone-content" class:fade={isScanning}>
      <!-- Cyan Document Icon -->
      <div class="icon-container">
        <svg class="doc-icon" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path
            d="M14 2H6C4.89543 2 4 2.89543 4 4V20C4 21.1046 4.89543 22 6 22H18C19.1046 22 20 21.1046 20 20V8L14 2Z"
            stroke="#00f0ff"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M14 2V8H20"
            stroke="#00f0ff"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <!-- Upward Arrow inside -->
          <path
            d="M12 17V11M12 11L9.5 13.5M12 11L14.5 13.5"
            stroke="#00f0ff"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </div>

      <!-- Main Action Text -->
      <h2 class="drop-title">DROP DOCUMENT HERE</h2>

      <!-- Supported File Types -->
      <p class="file-specs">
        .TXT &bull; .PDF &bull; .DOC &bull; .DOCX &bull; .MD &mdash; MAX 19MB
      </p>

      <!-- Browse Files Solid Cyan Button -->
      <button type="button" class="btn-browse" onclick={triggerBrowse}>
        BROWSE FILES
      </button>
    </div>
  </div>

  <!-- Quick Test Sample Bar -->
  <div class="samples-bar">
    <span class="samples-label">TRY WITH SAMPLE DOCS:</span>
    <div class="samples-list">
      {#each SAMPLE_DOCS as sample}
        <button type="button" class="sample-btn" onclick={() => selectSample(sample)}>
          <span class="sample-ext">{sample.type}</span>
          <span class="sample-name">{sample.filename}</span>
        </button>
      {/each}
    </div>
  </div>
</div>

<style>
  .dropzone-wrapper {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .dropzone-panel {
    position: relative;
    width: 100%;
    min-height: 280px;
    background: #0d1724;
    background: radial-gradient(circle at center, #111d2e 0%, #0b1420 100%);
    border: 1px solid rgba(0, 240, 255, 0.15);
    border-radius: 6px;
    padding: 3rem 2rem;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5), inset 0 0 20px rgba(0, 240, 255, 0.02);
    transition: all 0.25s ease;
    overflow: hidden;
  }

  .dropzone-panel.dragging {
    border-color: var(--cyan-primary);
    background: rgba(0, 240, 255, 0.08);
    box-shadow: 0 0 30px rgba(0, 240, 255, 0.3);
  }

  /* Cyberpunk Glowing Corner Brackets */
  .corner-bracket {
    position: absolute;
    width: 14px;
    height: 14px;
    pointer-events: none;
    z-index: 2;
  }

  .corner-bracket.top-left {
    top: -1px;
    left: -1px;
    border-top: 2px solid var(--cyan-primary);
    border-left: 2px solid var(--cyan-primary);
    box-shadow: -2px -2px 8px var(--cyan-primary);
  }

  .corner-bracket.bottom-right {
    bottom: -1px;
    right: -1px;
    border-bottom: 2px solid var(--cyan-primary);
    border-right: 2px solid var(--cyan-primary);
    box-shadow: 2px 2px 8px var(--cyan-primary);
  }

  .hidden-input {
    display: none;
  }

  .dropzone-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    z-index: 1;
    transition: opacity 0.3s ease;
  }

  .dropzone-content.fade {
    opacity: 0.2;
    pointer-events: none;
  }

  .icon-container {
    width: 64px;
    height: 64px;
    background: rgba(0, 240, 255, 0.06);
    border: 1px solid rgba(0, 240, 255, 0.2);
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 1.5rem;
    box-shadow: inset 0 0 12px rgba(0, 240, 255, 0.15);
    transition: transform 0.3s ease, box-shadow 0.3s ease;
  }

  .dropzone-panel:hover .icon-container {
    transform: translateY(-4px);
    box-shadow: 0 0 20px rgba(0, 240, 255, 0.3);
  }

  .doc-icon {
    width: 32px;
    height: 32px;
    filter: drop-shadow(0 0 6px rgba(0, 240, 255, 0.6));
  }

  .drop-title {
    font-family: var(--font-title);
    font-size: 1.15rem;
    font-weight: 700;
    letter-spacing: 2.5px;
    color: #ffffff;
    margin-bottom: 0.5rem;
    text-shadow: 0 0 10px rgba(255, 255, 255, 0.2);
  }

  .file-specs {
    font-family: var(--font-mono);
    font-size: 0.72rem;
    font-weight: 500;
    letter-spacing: 1.5px;
    color: var(--text-muted);
    margin-bottom: 1.75rem;
  }

  .btn-browse {
    font-family: var(--font-title);
    font-size: 0.85rem;
    font-weight: 700;
    letter-spacing: 2px;
    color: #050b14;
    background: var(--cyan-primary);
    border: none;
    border-radius: 4px;
    padding: 12px 34px;
    cursor: pointer;
    box-shadow: 0 0 20px rgba(0, 240, 255, 0.4);
    transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .btn-browse:hover {
    background: #5ce1e6;
    box-shadow: 0 0 30px rgba(0, 240, 255, 0.7);
    transform: translateY(-2px) scale(1.02);
  }

  .btn-browse:active {
    transform: translateY(0) scale(0.98);
  }

  /* Scan Laser Animation */
  .scan-laser {
    position: absolute;
    left: 0;
    right: 0;
    height: 3px;
    background: linear-gradient(90deg, transparent 0%, var(--cyan-primary) 50%, transparent 100%);
    box-shadow: 0 0 15px var(--cyan-primary), 0 0 30px var(--cyan-primary);
    animation: scanline 1.8s ease-in-out infinite alternate;
    z-index: 5;
  }

  .scanning-hud {
    position: absolute;
    z-index: 6;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }

  .spinner {
    width: 36px;
    height: 36px;
    border: 3px solid rgba(0, 240, 255, 0.2);
    border-top-color: var(--cyan-primary);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .scan-text {
    font-family: var(--font-mono);
    font-size: 0.75rem;
    letter-spacing: 2px;
    color: var(--cyan-primary);
    text-shadow: 0 0 10px rgba(0, 240, 255, 0.8);
  }

  /* Preset Samples Bar */
  .samples-bar {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 0.5rem 0.25rem;
    flex-wrap: wrap;
  }

  .samples-label {
    font-family: var(--font-mono);
    font-size: 0.65rem;
    letter-spacing: 1.5px;
    color: #4a5d6e;
    font-weight: 600;
  }

  .samples-list {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }

  .sample-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    background: rgba(14, 25, 38, 0.8);
    border: 1px solid rgba(0, 240, 255, 0.15);
    border-radius: 4px;
    color: var(--text-muted);
    font-family: var(--font-mono);
    font-size: 0.7rem;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .sample-btn:hover {
    border-color: var(--cyan-primary);
    color: var(--cyan-primary);
    background: rgba(0, 240, 255, 0.08);
  }

  .sample-ext {
    font-weight: 700;
    color: var(--cyan-muted);
    font-size: 0.6rem;
    padding: 1px 4px;
    background: rgba(0, 240, 255, 0.12);
    border-radius: 2px;
  }

  .sample-name {
    text-overflow: ellipsis;
    overflow: hidden;
    white-space: nowrap;
    max-width: 180px;
  }
</style>
