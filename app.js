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

// 24-second native brand film: CSS imagery + Web Audio score + Vietnamese narration + captions.
const player = q('.film-player');
const playButtons = [q('.big-play'), q('.film-toggle')];
const progress = q('.timeline i');
const timeLabel = q('.film-controls time');
const subtitle = q('.subtitle');
const captionButton = q('.caption-toggle');
const soundButton = q('.sound-toggle');
const duration = 24;
let filmStart = 0;
let elapsed = 0;
let animationFrame = null;
let isPlaying = false;
let captionsOn = true;
let soundOn = true;
let audioContext = null;
let masterGain = null;

const script = [
  { from: 0, to: 5.5, text: 'Tương lai không tự nhiên mà đến.', scene: 0 },
  { from: 5.5, to: 11.5, text: 'Nó thuộc về người nhìn thấy tín hiệu giữa muôn vàn nhiễu động.', scene: 1 },
  { from: 11.5, to: 17.5, text: 'Người biến hiểu biết thành hành động, và hành động thành tài sản.', scene: 2 },
  { from: 17.5, to: 24, text: 'Bellionaire. Tỷ phú tương lai bắt đầu từ hôm nay.', scene: 3 }
];

function scheduleScore() {
  if (!soundOn) return;
  audioContext = audioContext || new (window.AudioContext || window.webkitAudioContext)();
  if (audioContext.state === 'suspended') audioContext.resume();
  masterGain = audioContext.createGain();
  masterGain.gain.setValueAtTime(0.0001, audioContext.currentTime);
  masterGain.gain.exponentialRampToValueAtTime(0.055, audioContext.currentTime + .8);
  masterGain.gain.exponentialRampToValueAtTime(0.0001, audioContext.currentTime + duration);
  masterGain.connect(audioContext.destination);
  [55, 82.41, 110].forEach((frequency, index) => {
    const oscillator = audioContext.createOscillator();
    const gain = audioContext.createGain();
    oscillator.type = index === 0 ? 'sine' : 'triangle';
    oscillator.frequency.value = frequency;
    gain.gain.value = index === 0 ? .75 : .18;
    oscillator.connect(gain).connect(masterGain);
    oscillator.start(); oscillator.stop(audioContext.currentTime + duration);
  });
  [0, 5.5, 11.5, 17.5].forEach((offset, index) => {
    const osc = audioContext.createOscillator();
    const gain = audioContext.createGain();
    osc.frequency.setValueAtTime(220 + index * 55, audioContext.currentTime + offset);
    osc.frequency.exponentialRampToValueAtTime(440 + index * 80, audioContext.currentTime + offset + 1.1);
    gain.gain.setValueAtTime(.001, audioContext.currentTime + offset);
    gain.gain.exponentialRampToValueAtTime(.09, audioContext.currentTime + offset + .08);
    gain.gain.exponentialRampToValueAtTime(.001, audioContext.currentTime + offset + 1.2);
    osc.connect(gain).connect(masterGain); osc.start(audioContext.currentTime + offset); osc.stop(audioContext.currentTime + offset + 1.3);
  });
}

function speakFilm() {
  if (!soundOn || !('speechSynthesis' in window)) return;
  speechSynthesis.cancel();
  script.forEach(line => {
    const utterance = new SpeechSynthesisUtterance(line.text);
    const voices = speechSynthesis.getVoices();
    utterance.voice = voices.find(v => v.lang.toLowerCase().startsWith('vi')) || null;
    utterance.lang = 'vi-VN'; utterance.rate = .92; utterance.pitch = .86; utterance.volume = .88;
    setTimeout(() => { if (isPlaying && soundOn) speechSynthesis.speak(utterance); }, line.from * 1000);
  });
}

function renderFilm(now) {
  if (!isPlaying) return;
  elapsed = Math.min((now - filmStart) / 1000, duration);
  const line = script.find(item => elapsed >= item.from && elapsed < item.to) || script.at(-1);
  qa('.film-scene', player).forEach((scene, index) => scene.classList.toggle('active', index === line.scene));
  subtitle.textContent = line.text;
  subtitle.style.display = captionsOn ? '' : 'none';
  progress.style.width = `${elapsed / duration * 100}%`;
  timeLabel.textContent = `00:${String(Math.floor(elapsed)).padStart(2, '0')} / 00:24`;
  if (elapsed >= duration) { stopFilm(true); return; }
  animationFrame = requestAnimationFrame(renderFilm);
}

function playFilm() {
  stopFilm(false);
  elapsed = 0; isPlaying = true; filmStart = performance.now();
  player.classList.add('playing'); q('.film-toggle').textContent = 'Ⅱ';
  scheduleScore(); speakFilm();
  animationFrame = requestAnimationFrame(renderFilm);
}

function stopFilm(ended = false) {
  isPlaying = false; cancelAnimationFrame(animationFrame);
  if ('speechSynthesis' in window) speechSynthesis.cancel();
  if (masterGain && audioContext) masterGain.gain.setTargetAtTime(.0001, audioContext.currentTime, .02);
  q('.film-toggle').textContent = '▶';
  if (ended) { player.classList.remove('playing'); elapsed = 0; progress.style.width = '0'; timeLabel.textContent = '00:00 / 00:24'; qa('.film-scene').forEach((s,i)=>s.classList.toggle('active',i===0)); }
}

playButtons.forEach(button => button.addEventListener('click', () => isPlaying ? stopFilm(false) : playFilm()));
qa('.play-trigger').forEach(button => button.addEventListener('click', () => { q('#phim').scrollIntoView({ behavior: 'smooth' }); setTimeout(playFilm, 650); }));
captionButton.addEventListener('click', () => { captionsOn = !captionsOn; captionButton.classList.toggle('is-on', captionsOn); subtitle.style.display = captionsOn ? '' : 'none'; });
soundButton.addEventListener('click', () => { soundOn = !soundOn; soundButton.textContent = soundOn ? '♪' : '×'; if (!soundOn && 'speechSynthesis' in window) speechSynthesis.cancel(); if (!soundOn && masterGain && audioContext) masterGain.gain.setTargetAtTime(.0001, audioContext.currentTime, .02); });
q('.timeline').addEventListener('click', event => {
  const rect = event.currentTarget.getBoundingClientRect();
  const next = Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width)) * duration;
  if (!isPlaying) playFilm();
  filmStart = performance.now() - next * 1000;
});

// Friendly local form confirmation (no data leaves the browser).
q('.lead-form').addEventListener('submit', event => {
  event.preventDefault();
  const input = q('input', event.currentTarget);
  const status = q('.form-status', event.currentTarget);
  if (!input.validity.valid) { status.textContent = 'Hãy nhập một địa chỉ email hợp lệ.'; input.focus(); return; }
  status.textContent = 'Đã ghi danh — hành trình Bellionaire của bạn bắt đầu từ đây.';
  event.currentTarget.reset();
});
