import { Editor, rootCtx, defaultValueCtx } from '@milkdown/core';
import { commonmark } from '@milkdown/preset-commonmark';
import { gfm } from '@milkdown/preset-gfm';
import { listener, listenerCtx } from '@milkdown/plugin-listener';
import { nord } from '@milkdown/theme-nord';
import { callCommand } from '@milkdown/utils';

import {
    toggleStrongCommand,
    toggleEmphasisCommand,
    toggleInlineCodeCommand,
    wrapInHeadingCommand,
    wrapInBlockquoteCommand,
    wrapInBulletListCommand,
    wrapInOrderedListCommand,
    createCodeBlockCommand,
    insertHrCommand,
    toggleLinkCommand,
} from '@milkdown/preset-commonmark';

let editorInstance = null;

export async function createEditor(container, content, onChange) {
    if (editorInstance) {
        await editorInstance.destroy();
        editorInstance = null;
    }

    // Clear the container before creating a new editor
    container.textContent = '';

    editorInstance = await Editor.make()
        .config((ctx) => {
            ctx.set(rootCtx, container);
            ctx.set(defaultValueCtx, content);
        })
        .config((ctx) => {
            ctx.get(listenerCtx).markdownUpdated((_ctx, markdown, _prevMarkdown) => {
                onChange(markdown);
            });
        })
        .config(nord)
        .use(commonmark)
        .use(gfm)
        .use(listener)
        .create();

    return editorInstance;
}

export async function destroyEditor() {
    if (editorInstance) {
        await editorInstance.destroy();
        editorInstance = null;
    }
}

const toolbarActions = {
    bold: () => callCommand(toggleStrongCommand.key),
    italic: () => callCommand(toggleEmphasisCommand.key),
    code: () => callCommand(toggleInlineCodeCommand.key),
    h1: () => callCommand(wrapInHeadingCommand.key, 1),
    h2: () => callCommand(wrapInHeadingCommand.key, 2),
    h3: () => callCommand(wrapInHeadingCommand.key, 3),
    bullet: () => callCommand(wrapInBulletListCommand.key),
    ordered: () => callCommand(wrapInOrderedListCommand.key),
    codeBlock: () => callCommand(createCodeBlockCommand.key),
    quote: () => callCommand(wrapInBlockquoteCommand.key),
    hr: () => callCommand(insertHrCommand.key),
    link: () => callCommand(toggleLinkCommand.key, { href: '' }),
};

export function setupToolbar(toolbarEl) {
    toolbarEl.addEventListener('click', (e) => {
        const btn = e.target.closest('button');
        if (!btn || !editorInstance) return;

        const action = btn.dataset.action;
        const actionFn = toolbarActions[action];
        if (actionFn) {
            editorInstance.action(actionFn());
        }
    });
}
