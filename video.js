/*
 * CẤU HÌNH VIDEO
 * Video hiện tại nằm trong assets/video.
 * Đổi giá trị src bên dưới khi bạn muốn thay video khác.
 * Có thể để captions là chuỗi rỗng nếu chưa có phụ đề .vtt.
 */
const VIDEO_CONFIG = {
  src: 'assets/video/82203b0e4de64a24a1b0695fcce90fba.mp4',
  type: 'video/mp4',
  poster: 'assets/bellionaire-hero.png',
  captions: 'assets/video/phu-de-vi-v4.vtt',
  captionsLabel: 'Tiếng Việt'
};

const video = document.querySelector('.brand-video');
const videoShell = document.querySelector('.video-shell');

if (video && videoShell) {
  video.poster = VIDEO_CONFIG.poster;

  const source = document.createElement('source');
  source.src = VIDEO_CONFIG.src;
  source.type = VIDEO_CONFIG.type;
  video.prepend(source);

  if (VIDEO_CONFIG.captions) {
    const track = document.createElement('track');
    track.kind = 'captions';
    track.label = VIDEO_CONFIG.captionsLabel;
    track.srclang = 'vi';
    track.src = VIDEO_CONFIG.captions;
    track.default = true;
    video.append(track);
  }

  video.addEventListener('loadedmetadata', () => {
    videoShell.classList.add('video-ready');
  }, { once: true });

  video.addEventListener('error', () => {
    videoShell.classList.remove('video-ready');
  });

  document.querySelectorAll('.play-trigger').forEach(button => {
    button.addEventListener('click', () => {
      document.querySelector('#phim')?.scrollIntoView({ behavior: 'smooth' });
      if (video.readyState >= HTMLMediaElement.HAVE_METADATA) {
        window.setTimeout(() => video.play().catch(() => {}), 650);
      }
    });
  });

  video.load();
}
