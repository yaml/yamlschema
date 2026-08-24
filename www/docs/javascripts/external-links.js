document.addEventListener('DOMContentLoaded', () => {
  for (const link of document.querySelectorAll('a[href^="http"]')) {
    if (link.hostname === globalThis.location.hostname) continue;
    link.target = '_blank';
    link.rel = 'noopener';
  }
});
