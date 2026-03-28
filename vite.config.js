import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  root: 'web',
  build: {
    outDir: resolve(__dirname, 'Resources/WebEditor'),
    emptyOutDir: true,
    rollupOptions: {
      input: resolve(__dirname, 'web/index.html'),
    },
  },
  base: './',
  plugins: [
    {
      // WKWebView blocks crossorigin attributes on file:// URLs.
      // Vite adds them by default on module scripts and stylesheets.
      name: 'remove-crossorigin',
      enforce: 'post',
      transformIndexHtml(html) {
        return html.replace(/ crossorigin/g, '');
      },
    },
  ],
});
