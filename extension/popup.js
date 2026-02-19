// Popup script for Brain extension

document.addEventListener('DOMContentLoaded', async () => {
  const titleEl = document.getElementById('title');
  const contentEl = document.getElementById('content');
  const noteEl = document.getElementById('note');
  const urlEl = document.getElementById('pageUrl');
  const sendBtn = document.getElementById('send');
  const statusEl = document.getElementById('status');
  const serverUrlEl = document.getElementById('serverUrl');

  // Load server URL
  const { serverUrl } = await chrome.storage.local.get('serverUrl');
  serverUrlEl.value = serverUrl || 'http://localhost:3141';

  // Save server URL on change
  serverUrlEl.addEventListener('change', () => {
    chrome.storage.local.set({ serverUrl: serverUrlEl.value });
  });

  // Get current tab info
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (tab) {
    titleEl.value = tab.title || '';
    urlEl.textContent = tab.url || '';

    // Try to get selected text
    try {
      const [result] = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: () => window.getSelection().toString(),
      });
      if (result && result.result) {
        contentEl.value = result.result;
      }
    } catch (e) {
      // Can't access page (chrome:// pages, etc.)
    }
  }

  // Send to brain
  sendBtn.addEventListener('click', async () => {
    sendBtn.disabled = true;
    statusEl.textContent = 'Sending...';
    statusEl.className = 'status';

    const data = {
      source: 'web',
      title: titleEl.value,
      url: urlEl.textContent,
      content: contentEl.value,
      note: noteEl.value,
    };

    try {
      const response = await fetch(`${serverUrlEl.value}/api/inbox`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      });

      if (response.ok) {
        statusEl.textContent = 'Added to brain!';
        statusEl.className = 'status success';
        setTimeout(() => window.close(), 1000);
      } else {
        const err = await response.json();
        statusEl.textContent = `Error: ${err.error || 'unknown'}`;
        statusEl.className = 'status error';
        sendBtn.disabled = false;
      }
    } catch (e) {
      statusEl.textContent = 'Cannot reach server. Is it running?';
      statusEl.className = 'status error';
      sendBtn.disabled = false;
    }
  });
});
