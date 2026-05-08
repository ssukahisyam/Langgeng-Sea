/**
 * Langgeng Sea - Prototype Theme Switcher
 * Simple toggle between light/dark modes, persisted to localStorage
 */

(function () {
  const STORAGE_KEY = 'lsea-theme';
  const body = document.body;
  const sw = document.getElementById('themeSwitch');
  const label = sw.querySelector('.theme-switch-label');
  const thumb = sw.querySelector('.theme-switch-thumb i');

  // Load saved theme (fallback to system pref)
  const saved = localStorage.getItem(STORAGE_KEY);
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const initial = saved || (prefersDark ? 'dark' : 'light');
  setTheme(initial);

  sw.addEventListener('click', () => {
    const current = body.getAttribute('data-theme');
    setTheme(current === 'dark' ? 'light' : 'dark');
  });

  function setTheme(mode) {
    body.setAttribute('data-theme', mode);
    localStorage.setItem(STORAGE_KEY, mode);
    if (mode === 'dark') {
      label.textContent = 'Dark';
      thumb.className = 'ph ph-moon';
    } else {
      label.textContent = 'Light';
      thumb.className = 'ph ph-sun';
    }
  }
})();
