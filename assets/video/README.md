# Thêm video vào website

Đặt file video chính tại:

`assets/video/bellionaire-intro.mp4`

Nếu dùng tên khác, WebM, URL bên ngoài, ảnh poster riêng hoặc phụ đề WebVTT, hãy sửa khối `VIDEO_CONFIG` ở đầu file `video.js`.

Ví dụ WebM:

```js
const VIDEO_CONFIG = {
  src: 'assets/video/gioi-thieu.webm',
  type: 'video/webm',
  poster: 'assets/video/poster.jpg',
  captions: 'assets/video/phu-de-vi.vtt',
  captionsLabel: 'Tiếng Việt'
};
```
