let currentHighlights = [];
let currentIndex = -1;

export function findInDocument(query) {
    clearHighlights();
    if (!query) return 0;

    const container = document.getElementById('reader');
    const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT);
    const matches = [];

    while (walker.nextNode()) {
        const node = walker.currentNode;
        const text = node.textContent;
        let idx = text.toLowerCase().indexOf(query.toLowerCase());
        while (idx !== -1) {
            matches.push({ node, index: idx, length: query.length });
            idx = text.toLowerCase().indexOf(query.toLowerCase(), idx + 1);
        }
    }

    for (let i = matches.length - 1; i >= 0; i--) {
        const { node, index, length } = matches[i];
        const range = document.createRange();
        range.setStart(node, index);
        range.setEnd(node, index + length);
        const mark = document.createElement('mark');
        mark.style.background = 'rgba(255, 200, 0, 0.4)';
        mark.style.borderRadius = '2px';
        range.surroundContents(mark);
        currentHighlights.unshift(mark);
    }

    if (currentHighlights.length > 0) {
        currentIndex = 0;
        updateHighlight();
    }

    return currentHighlights.length;
}

function updateHighlight() {
    currentHighlights.forEach((m, i) => {
        m.style.background = i === currentIndex
            ? 'rgba(255, 150, 0, 0.6)'
            : 'rgba(255, 200, 0, 0.4)';
    });
    currentHighlights[currentIndex]?.scrollIntoView({ block: 'center' });
}

export function findNext() {
    if (currentHighlights.length === 0) return;
    currentIndex = (currentIndex + 1) % currentHighlights.length;
    updateHighlight();
}

export function findPrevious() {
    if (currentHighlights.length === 0) return;
    currentIndex = (currentIndex - 1 + currentHighlights.length) % currentHighlights.length;
    updateHighlight();
}

export function clearHighlights() {
    for (const mark of currentHighlights) {
        const parent = mark.parentNode;
        if (parent) {
            parent.replaceChild(document.createTextNode(mark.textContent), mark);
            parent.normalize();
        }
    }
    currentHighlights = [];
    currentIndex = -1;
}
