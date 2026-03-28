import { sendToSwift, onSwiftMessage } from './bridge.js';
import { showReader } from './reader.js';
import './styles.css';

const readerEl = document.getElementById('reader');
const editorEl = document.getElementById('editor');
const toolbarEl = document.getElementById('toolbar');

let currentMode = 'read';
let currentContent = '';

onSwiftMessage('loadContent', (msg) => {
    currentContent = msg.content;
    if (currentMode === 'read') {
        showReader(readerEl, currentContent);
    }
});

onSwiftMessage('setMode', (msg) => {
    currentMode = msg.mode;
    if (currentMode === 'read') {
        showReader(readerEl, currentContent);
        readerEl.classList.remove('hidden');
        editorEl.classList.add('hidden');
        toolbarEl.classList.add('hidden');
    } else {
        readerEl.classList.add('hidden');
        editorEl.classList.remove('hidden');
        toolbarEl.classList.remove('hidden');
        // Milkdown editor activation added in Task 8
    }
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

sendToSwift('ready');
