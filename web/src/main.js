import { sendToSwift, onSwiftMessage } from './bridge.js';
import { showReader } from './reader.js';
import { createEditor, destroyEditor, setupToolbar } from './editor.js';
import { findInDocument, findNext, findPrevious, clearHighlights } from './search.js';
import './styles.css';

const readerEl = document.getElementById('reader');
const editorEl = document.getElementById('editor');
const toolbarEl = document.getElementById('toolbar');

let currentMode = 'read';
let currentContent = '';

setupToolbar(toolbarEl);

onSwiftMessage('loadContent', (msg) => {
    currentContent = msg.content;
    if (currentMode === 'read') {
        showReader(readerEl, currentContent);
    }
});

onSwiftMessage('setMode', async (msg) => {
    currentMode = msg.mode;
    if (currentMode === 'read') {
        await destroyEditor();
        showReader(readerEl, currentContent);
        readerEl.classList.remove('hidden');
        editorEl.classList.add('hidden');
        toolbarEl.classList.add('hidden');
    } else {
        readerEl.classList.add('hidden');
        editorEl.classList.remove('hidden');
        toolbarEl.classList.remove('hidden');
        await createEditor(editorEl, currentContent, (markdown) => {
            currentContent = markdown;
            sendToSwift('contentChanged', { content: markdown });
        });
    }
});

onSwiftMessage('getContent', () => {
    sendToSwift('contentResult', { content: currentContent });
});

onSwiftMessage('setBaseURL', (msg) => {
    document.querySelector('base')?.remove();
    const base = document.createElement('base');
    base.href = msg.url;
    document.head.prepend(base);
});

readerEl.addEventListener('dblclick', () => {
    sendToSwift('requestEdit');
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && currentMode === 'edit') {
        sendToSwift('requestRead');
    }
});

onSwiftMessage('search', (msg) => {
    const count = findInDocument(msg.query);
    sendToSwift('searchResult', { count });
});

onSwiftMessage('searchNext', () => findNext());
onSwiftMessage('searchPrevious', () => findPrevious());
onSwiftMessage('clearSearch', () => clearHighlights());

sendToSwift('ready');
