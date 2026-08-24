(() => {
  const carousel = document.querySelector('[data-comparison-carousel]');
  if (!carousel) return;

  const slides = [...carousel.querySelectorAll('[data-comparison-slide]')];
  const dots = [...carousel.querySelectorAll('[data-carousel-dot]')];
  const previous = carousel.querySelector('[data-carousel-previous]');
  const next = carousel.querySelector('[data-carousel-next]');
  const reducedMotion = window.matchMedia(
    '(prefers-reduced-motion: reduce)',
  ).matches;
  let active = 0;
  let timer;
  let paused = false;

  function show(index) {
    active = (index + slides.length) % slides.length;
    for (const [position, slide] of slides.entries()) {
      const current = position === active;
      slide.classList.toggle('is-active', current);
      slide.setAttribute('aria-hidden', String(!current));
      slide.tabIndex = current ? 0 : -1;
    }
    for (const [position, dot] of dots.entries()) {
      const current = position === active;
      dot.classList.toggle('is-active', current);
      dot.setAttribute('aria-pressed', String(current));
    }
  }

  function stop() {
    window.clearInterval(timer);
    timer = undefined;
  }

  function start() {
    stop();
    if (reducedMotion || paused || document.hidden) return;
    timer = window.setInterval(() => show(active + 1), 7000);
  }

  function openSlide(slide) {
    const href = slide.dataset.editorHref;
    if (href) window.location.href = href;
  }

  previous.addEventListener('click', () => {
    show(active - 1);
    start();
  });
  next.addEventListener('click', () => {
    show(active + 1);
    start();
  });
  for (const [index, dot] of dots.entries()) {
    dot.addEventListener('click', () => {
      show(index);
      start();
    });
  }
  for (const slide of slides) {
    slide.addEventListener('click', (event) => {
      if (event.target.closest('a, button')) return;
      if (window.getSelection()?.toString()) return;
      openSlide(slide);
    });
    slide.addEventListener('keydown', (event) => {
      if (event.key === 'ArrowLeft') {
        event.preventDefault();
        show(active - 1);
      } else if (event.key === 'ArrowRight') {
        event.preventDefault();
        show(active + 1);
      } else if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        openSlide(slide);
      }
    });
  }
  carousel.addEventListener('mouseenter', () => {
    paused = true;
    stop();
  });
  carousel.addEventListener('mouseleave', () => {
    paused = false;
    start();
  });
  carousel.addEventListener('focusin', () => {
    paused = true;
    stop();
  });
  carousel.addEventListener('focusout', (event) => {
    if (carousel.contains(event.relatedTarget)) return;
    paused = false;
    start();
  });
  document.addEventListener('visibilitychange', start);

  show(0);
  start();
})();
