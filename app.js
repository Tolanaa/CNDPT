const q = (selector, parent = document) => parent.querySelector(selector);
const qa = (selector, parent = document) => [...parent.querySelectorAll(selector)];

// Reveal content only when it enters the viewport.
const revealObserver = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
      revealObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.12 });
qa('.reveal').forEach((el, index) => {
  el.style.transitionDelay = `${Math.min(index % 3, 2) * 80}ms`;
  revealObserver.observe(el);
});

// Number animation in the opening frame.
const countUp = () => qa('.count').forEach(el => {
  const target = Number(el.dataset.target);
  const started = performance.now();
  const tick = now => {
    const progress = Math.min((now - started) / 1200, 1);
    el.textContent = Math.round(target * (1 - Math.pow(1 - progress, 3)));
    if (progress < 1) requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
});
setTimeout(countUp, 650);

// Compact navigation on mobile.
const menuButton = q('.menu-button');
menuButton.addEventListener('click', () => {
  const header = q('.site-header');
  const open = header.classList.toggle('menu-active');
  document.body.classList.toggle('menu-open', open);
  menuButton.setAttribute('aria-expanded', String(open));
});
qa('nav a').forEach(link => link.addEventListener('click', () => {
  q('.site-header').classList.remove('menu-active');
  document.body.classList.remove('menu-open');
  menuButton.setAttribute('aria-expanded', 'false');
}));

// Light magnetic response for the main CTA.
qa('.magnetic').forEach(button => {
  button.addEventListener('mousemove', event => {
    const rect = button.getBoundingClientRect();
    button.style.transform = `translate(${(event.clientX - rect.left - rect.width / 2) * .08}px, ${(event.clientY - rect.top - rect.height / 2) * .12}px)`;
  });
  button.addEventListener('mouseleave', () => button.style.transform = '');
});

// Validate the registration email, then open the visitor's email client.
qa('.email-cta-form').forEach(form => {
  form.addEventListener('submit', event => {
    event.preventDefault();
    const input = q('input[type="email"]', form);
    const status = q('.email-form-status', form);

    if (!input.validity.valid) {
      status.textContent = 'Vui lòng nhập một địa chỉ email hợp lệ.';
      status.classList.add('is-error');
      input.focus();
      return;
    }

    status.classList.remove('is-error');
    status.textContent = 'Đang mở ứng dụng email để hoàn tất đăng ký…';
    const recipient = form.dataset.recipient;
    const subject = encodeURIComponent('Đăng ký Bellionaire Investor');
    const body = encodeURIComponent(`Tôi muốn đăng ký Bellionaire Investor.\n\nEmail liên hệ: ${input.value.trim()}`);
    window.location.href = `mailto:${recipient}?subject=${subject}&body=${body}`;
  });
});
