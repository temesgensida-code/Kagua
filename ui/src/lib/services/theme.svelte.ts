let isDarkState = $state(true);

if (typeof window !== 'undefined') {
  const saved = localStorage.getItem('kagua_theme');
  if (saved === 'light') {
    isDarkState = false;
  }
  // Apply immediately on load
  document.documentElement.setAttribute('data-theme', isDarkState ? 'dark' : 'light');
}

export const themeState = {
  get isDark() {
    return isDarkState;
  },
  toggle() {
    isDarkState = !isDarkState;
    if (typeof window !== 'undefined') {
      const theme = isDarkState ? 'dark' : 'light';
      localStorage.setItem('kagua_theme', theme);
      document.documentElement.setAttribute('data-theme', theme);
    }
  }
};
