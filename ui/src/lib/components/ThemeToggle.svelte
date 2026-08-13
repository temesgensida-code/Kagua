<script lang="ts">
  import { Sun, Moon } from '@lucide/svelte';
  import { themeState } from '$lib/services/theme.svelte';
  import { soundState } from '$lib/services/sound.svelte';
</script>

<div class="theme-card-wrapper">
  <button
    type="button"
    class="theme-toggle-card"
    onclick={() => {
      themeState.toggle();
      soundState.playClick();
    }}
    title={themeState.isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'}
    aria-label="Toggle theme"
  >
    <!-- Sliding active indicator rectangle -->
    <div class="sliding-indicator" class:light={!themeState.isDark}></div>

    <!-- Dark Mode Icon -->
    <div class="icon-slot" class:active={themeState.isDark}>
      <Moon size={16} />
    </div>

    <!-- Light Mode Icon -->
    <div class="icon-slot" class:active={!themeState.isDark}>
      <Sun size={16} />
    </div>
  </button>
</div>

<style>
  .theme-card-wrapper {
    display: flex;
    align-items: center;
  }

  .theme-toggle-card {
    position: relative;
    display: flex;
    align-items: center;
    background: rgba(13, 23, 36, 0.95);
    border: 1px solid #132E35;
    border-radius: 6px;
    padding: 3px;
    gap: 3px;
    cursor: pointer;
    transition: all 0.25s ease;
    box-shadow: 0 4px 15px rgba(0, 0, 0, 0.4);
  }

  :global([data-theme="light"]) .theme-toggle-card {
    background: rgba(175, 179, 183, 0.95);
    border-color: #99a3ab;
  }

  .theme-toggle-card:hover {
    border-color: #1e434c;
  }

  :global([data-theme="light"]) .theme-toggle-card:hover {
    border-color: #69818d;
  }

  .sliding-indicator {
    position: absolute;
    top: 3px;
    left: 3px;
    width: 28px;
    height: 26px;
    background: #132E35;
    border: 1px solid #1e434c;
    border-radius: 4px;
    transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1), background 0.25s ease, border-color 0.25s ease;
    pointer-events: none;
  }

  .sliding-indicator.light {
    transform: translateX(31px);
    background: #69818d;
    border-color: #556c80;
  }

  .icon-slot {
    position: relative;
    z-index: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 26px;
    color: #556c80;
    transition: color 0.2s ease;
  }

  .icon-slot.active {
    color: #e2f1f8;
  }

  :global([data-theme="light"]) .icon-slot {
    color: #99a3ab;
  }

  :global([data-theme="light"]) .icon-slot.active {
    color: #ffffff;
  }
</style>
