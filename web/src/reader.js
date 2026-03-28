import MarkdownIt from 'markdown-it';
import DOMPurify from 'dompurify';
import hljs from 'highlight.js';
import 'highlight.js/styles/github.css';

const md = new MarkdownIt({
    html: true,
    linkify: true,
    typographer: true,
    highlight(str, lang) {
        if (lang && hljs.getLanguage(lang)) {
            try {
                return hljs.highlight(str, { language: lang }).value;
            } catch (_) {}
        }
        return '';
    }
});

const SANITIZE_CONFIG = {
    ADD_TAGS: ['input'],
    ADD_ATTR: ['type', 'checked', 'disabled']
};

export function renderMarkdown(content) {
    const rawHTML = md.render(content);
    return DOMPurify.sanitize(rawHTML, SANITIZE_CONFIG);
}

export function showReader(container, content) {
    container.textContent = '';
    const sanitizedHTML = renderMarkdown(content);
    const wrapper = document.createElement('div');
    // Safe: sanitizedHTML has been sanitized by DOMPurify above
    wrapper.innerHTML = DOMPurify.sanitize(sanitizedHTML, SANITIZE_CONFIG);
    container.appendChild(wrapper);
    container.classList.remove('hidden');
}
