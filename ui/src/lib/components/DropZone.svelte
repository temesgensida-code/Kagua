<script lang="ts">
  import { SAMPLE_DOCS, type SampleDoc } from "$lib/data/sampleDocs";
  import type { ProgressEvent } from "$lib/services/api";
  import { soundState } from '$lib/services/sound.svelte';

  interface Props {
    isScanning: boolean;
    progressEvents: ProgressEvent[];
    currentStageMessage: string;
    onFileSelected: (
      fileData: Blob | File,
      filename: string,
      sampleContent?: string,
    ) => void;
  }

  let {
    isScanning = false,
    progressEvents = [],
    currentStageMessage = "",
    onFileSelected,
  }: Props = $props();

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
      soundState.playBrowse();
      onFileSelected(file, file.name);
    }
  }

  function handleFileInputChange(e: Event) {
    const input = e.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      const file = input.files[0];
      onFileSelected(file, file.name);
      input.value = "";
    }
  }

  function triggerBrowse() {
    soundState.playBrowse();
    fileInput?.click();
  }

  function selectSample(sample: SampleDoc) {
    soundState.playClick();
    const blob = new Blob([sample.content], { type: "text/plain" });
    onFileSelected(blob, sample.filename, sample.content);
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

    <input
      type="file"
      bind:this={fileInput}
      onchange={handleFileInputChange}
      accept=".txt,.pdf,.doc,.docx,.md"
      class="hidden-input"
    />

    <!-- Real-time WebSocket Scanning Progress Overlay -->
    {#if isScanning}
      <div class="scan-laser"></div>
      <div class="scanning-hud">
        <div class="spinner"></div>
        <span class="scan-stage"
          >{currentStageMessage ||
            "CONNECTING TO RUST ANALYSIS PIPELINE..."}</span
        >

        <!-- Step-by-Step Progress Events Log -->
        <div class="progress-log">
          {#each progressEvents.slice(-4) as evt}
            <div class="log-line">
              <span class="log-stage">[{evt.stage}]</span>
              <span class="log-msg">{evt.message}</span>
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <div class="dropzone-content" class:fade={isScanning}>
      <div class="icon-container">
        <svg
          class="doc-icon"
          viewBox="0 0 24 24"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
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
          <path
            d="M12 17V11M12 11L9.5 13.5M12 11L14.5 13.5"
            stroke="#00f0ff"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </div>

      <h2 class="drop-title">DROP DOCUMENT FOR COMPLIANCE REASONING</h2>

      <p class="file-specs">
        .TXT &bull; .PDF &bull; .DOC &bull; .DOCX &bull; .MD &mdash; IN-MEMORY
        STREAMING (NO DISK PERSISTENCE)
      </p>

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
        <button
          type="button"
          class="sample-btn"
          onclick={() => selectSample(sample)}
        >
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
    max-width: 680px;
    margin: 0 auto;
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
    border: 2px dashed rgba(0, 240, 255, 0.35);
    border-radius: 8px;
    padding: 2.5rem 1.5rem;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow:
      0 10px 30px rgba(0, 0, 0, 0.5),
      inset 0 0 20px rgba(0, 240, 255, 0.02);
    transition: all 0.25s ease;
    overflow: hidden;
  }

  .dropzone-panel:hover {
    border-color: rgba(0, 240, 255, 0.65);
  }

  .dropzone-panel.dragging {
    border: 2px dashed var(--cyan-primary);
    background: rgba(0, 240, 255, 0.08);
    box-shadow: 0 0 30px rgba(0, 240, 255, 0.3);
  }

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
    opacity: 0.15;
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
    transition:
      transform 0.3s ease,
      box-shadow 0.3s ease;
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
    transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .btn-browse:hover {
    background: #5ce1e6;
    transform: translateY(-2px) scale(1.02);
  }

  /* Scan Laser Animation */
  .scan-laser {
    position: absolute;
    left: 0;
    right: 0;
    height: 3px;
    background: linear-gradient(
      90deg,
      transparent 0%,
      var(--cyan-primary) 50%,
      transparent 100%
    );
    box-shadow:
      0 0 15px var(--cyan-primary),
      0 0 30px var(--cyan-primary);
    animation: scanline 1.8s ease-in-out infinite alternate;
    z-index: 5;
  }

  @keyframes scanline {
    0% {
      top: 5%;
    }
    100% {
      top: 95%;
    }
  }

  .scanning-hud {
    position: absolute;
    z-index: 6;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    max-width: 90%;
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
    to {
      transform: rotate(360deg);
    }
  }

  .scan-stage {
    font-family: var(--font-mono);
    font-size: 0.82rem;
    font-weight: 700;
    letter-spacing: 2px;
    color: var(--cyan-primary);
    text-shadow: 0 0 10px rgba(0, 240, 255, 0.8);
    text-align: center;
  }

  .progress-log {
    display: flex;
    flex-direction: column;
    gap: 4px;
    background: rgba(4, 8, 14, 0.85);
    border: 1px solid rgba(0, 240, 255, 0.2);
    border-radius: 4px;
    padding: 8px 14px;
    max-width: 500px;
  }

  .log-line {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .log-stage {
    color: var(--cyan-primary);
    font-weight: 700;
  }

  .log-msg {
    color: var(--text-muted);
  }

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
