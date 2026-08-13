import clickOneUrl from '$lib/assets/click-one.wav';
import clickTwoUrl from '$lib/assets/click-two-beu.wav';

let isMutedState = $state(false);
let clickOneAudio: HTMLAudioElement | null = null;
let clickTwoAudio: HTMLAudioElement | null = null;

if (typeof window !== 'undefined') {
  const saved = localStorage.getItem('kagua_sound_muted');
  if (saved !== null) {
    isMutedState = saved === 'true';
  }
  clickOneAudio = new Audio(clickOneUrl);
  clickTwoAudio = new Audio(clickTwoUrl);
}

export const soundState = {
  get isMuted() {
    return isMutedState;
  },
  toggleMute() {
    isMutedState = !isMutedState;
    if (typeof window !== 'undefined') {
      localStorage.setItem('kagua_sound_muted', String(isMutedState));
    }
  },
  playClick() {
    if (isMutedState || !clickOneAudio) return;
    try {
      clickOneAudio.currentTime = 0;
      clickOneAudio.play().catch(() => {});
    } catch (_) {}
  },
  playBrowse() {
    if (isMutedState || !clickTwoAudio) return;
    try {
      clickTwoAudio.currentTime = 0;
      clickTwoAudio.play().catch(() => {});
    } catch (_) {}
  }
};
