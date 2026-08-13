<script lang="ts">
  import type { Framework } from '$lib/data/sampleDocs';
  import SoundToggle from './SoundToggle.svelte';
  import { soundState } from '$lib/services/sound.svelte';

  interface Props {
    frameworks: Framework[];
    onToggleFramework: (id: string) => void;
  }

  let { frameworks, onToggleFramework }: Props = $props();

  let activeCount = $derived(frameworks.filter(f => f.active).length);
</script>

<header class="header-container">
  <div class="top-header-row">
    <!-- Tag line with vertical pink line accent -->
    <div class="tag-row">
      <span class="pink-line"></span>
      <span class="tag-text">ETHIOPIAN LABOUR COMPLIANCE ENGINE</span>
    </div>

    <!-- Top Right Sound Toggle -->
    <SoundToggle />
  </div>

  <!-- Main Headline -->
  <h1 class="main-title">
    <span class="text-kagua">KAGUA</span>
  </h1>

  <!-- Subtitle / Description -->
  <p class="description">
    Automated zero-persistence compliance engine for employment contracts under Federal Democratic Republic of Ethiopia Labour Proclamation No. 1156/2019. Powered by spaCy NER, In-Memory RAG, and SWI-Prolog legal reasoning.
  </p>

  <!-- Active Frameworks Badges -->
  <div class="frameworks-section">
    <div class="frameworks-label">
      <span class="bullet">•</span> ACTIVE FRAMEWORKS
      <span class="count">({activeCount}/{frameworks.length})</span>
    </div>

    <div class="badges-row">
      {#each frameworks as fw (fw.id)}
        <button
          type="button"
          class="framework-badge"
          class:inactive={!fw.active}
          style="
            --fw-color: {fw.color};
            --fw-bg: {fw.bg};
            --fw-border: {fw.border};
            --fw-glow: {fw.glow};
          "
          onclick={() => {
            onToggleFramework(fw.id);
            soundState.playClick();
          }}
          title="{fw.description} — Click to {fw.active ? 'deactivate' : 'activate'}"
        >
          <span class="badge-dot"></span>
          <span class="badge-name">{fw.name}</span>
        </button>
      {/each}
    </div>
  </div>
</header>

<style>
  .header-container {
    width: 100%;
    margin-bottom: 2rem;
    text-align: left;
  }

  .top-header-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    margin-bottom: 0.75rem;
  }

  .tag-row {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 0.75rem;
  }

  .pink-line {
    display: inline-block;
    width: 3px;
    height: 14px;
    background: #ff2a70;
    box-shadow: 0 0 8px rgba(255, 42, 112, 0.7);
    border-radius: 1px;
  }

  .tag-text {
    font-family: var(--font-mono);
    font-size: 0.72rem;
    font-weight: 600;
    letter-spacing: 3px;
    color: var(--cyan-primary);
    text-shadow: 0 0 10px rgba(0, 240, 255, 0.4);
    text-transform: uppercase;
  }

  .main-title {
    margin-bottom: 0.75rem;
  }

  .text-kagua {
    font-family: var(--font-title);
    font-size: 1.8rem;
    font-weight: 800;
    letter-spacing: 5px;
    color: #ffffff;
    text-shadow: 0 0 15px rgba(0, 240, 255, 0.4);
  }

  .description {
    font-family: var(--font-body);
    font-size: 0.95rem;
    line-height: 1.6;
    color: var(--text-muted);
    max-width: 540px;
    margin-bottom: 2rem;
  }

  .frameworks-section {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .frameworks-label {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    font-weight: 600;
    letter-spacing: 2.5px;
    color: #556c80;
    text-transform: uppercase;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .bullet {
    color: var(--cyan-primary);
    font-size: 0.9rem;
  }

  .count {
    color: #3b4e60;
    font-size: 0.65rem;
  }

  .badges-row {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    align-items: center;
  }

  .framework-badge {
    position: relative;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 5px 12px;
    background: var(--fw-bg);
    border: 1px solid var(--fw-border);
    border-radius: 4px;
    color: var(--fw-color);
    font-family: var(--font-mono);
    font-size: 0.72rem;
    font-weight: 700;
    letter-spacing: 1px;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
    box-shadow: var(--fw-glow);
    user-select: none;
  }

  .framework-badge:hover {
    transform: translateY(-2px);
  }

  .framework-badge.inactive {
    opacity: 0.35;
    border-color: rgba(255, 255, 255, 0.1);
    background: rgba(255, 255, 255, 0.03);
    color: #5d6f80;
    box-shadow: none;
    filter: grayscale(0.8);
  }

  .badge-dot {
    width: 4px;
    height: 4px;
    background-color: currentColor;
    border-radius: 50%;
    box-shadow: 0 0 6px currentColor;
  }
</style>
