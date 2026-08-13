<script lang="ts">
  import { Volume2, VolumeX } from '@lucide/svelte';
  import { soundState } from '$lib/services/sound.svelte';
</script>

<div class="sound-card-wrapper">
  <button
    type="button"
    class="sound-toggle-card"
    onclick={() => {
      soundState.toggleMute();
      if (!soundState.isMuted) soundState.playClick();
    }}
    title={soundState.isMuted ? 'Unmute sound effects' : 'Mute sound effects'}
    aria-label="Toggle sound"
  >
    <!-- Sliding active indicator rectangle -->
    <div class="sliding-indicator" class:muted={soundState.isMuted}></div>

    <!-- Volume On Icon -->
    <div class="icon-slot" class:active={!soundState.isMuted}>
      <Volume2 size={16} />
    </div>

    <!-- Volume Muted Icon -->
    <div class="icon-slot" class:active={soundState.isMuted}>
      <VolumeX size={16} />
    </div>
  </button>
</div>

<style>
  .sound-card-wrapper {
    display: flex;
    align-items: center;
  }

  .sound-toggle-card {
    position: relative;
    display: flex;
    align-items: center;
    background: rgba(13, 23, 36, 0.95);
    border: 1px solid rgba(0, 240, 255, 0.25);
    border-radius: 6px;
    padding: 3px;
    gap: 3px;
    cursor: pointer;
    transition: all 0.25s ease;
    box-shadow: 0 4px 15px rgba(0, 0, 0, 0.4);
  }

  .sound-toggle-card:hover {
    border-color: var(--cyan-primary);
  }

  .sliding-indicator {
    position: absolute;
    top: 3px;
    left: 3px;
    width: 28px;
    height: 26px;
    background: rgba(0, 240, 255, 0.2);
    border: 1px solid var(--cyan-primary);
    border-radius: 4px;
    transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1), background 0.25s ease, border-color 0.25s ease;
    pointer-events: none;
  }

  .sliding-indicator.muted {
    transform: translateX(31px);
    background: rgba(255, 42, 112, 0.2);
    border-color: #ff2a70;
  }

  .icon-slot {
    position: relative;
    z-index: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 26px;
    color: var(--text-muted);
    transition: color 0.2s ease;
  }

  .icon-slot.active {
    color: #ffffff;
  }
</style>
