export function sendToSwift(type, payload = {}) {
    if (window.webkit?.messageHandlers?.bridge) {
        window.webkit.messageHandlers.bridge.postMessage(
            JSON.stringify({ type, ...payload })
        );
    }
}

const handlers = {};

export function onSwiftMessage(type, handler) {
    handlers[type] = handler;
}

window.handleSwiftMessage = function(jsonString) {
    const msg = JSON.parse(jsonString);
    const handler = handlers[msg.type];
    if (handler) {
        handler(msg);
    }
};
