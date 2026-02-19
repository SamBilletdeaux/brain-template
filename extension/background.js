// Background service worker for Brain extension

// Create context menu on install
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'add-to-brain',
    title: 'Add to Brain',
    contexts: ['selection', 'page'],
  });

  // Set default server URL
  chrome.storage.local.get('serverUrl', (result) => {
    if (!result.serverUrl) {
      chrome.storage.local.set({ serverUrl: 'http://localhost:3141' });
    }
  });
});

// Handle context menu clicks
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== 'add-to-brain') return;

  const data = {
    source: 'web',
    title: tab.title || '',
    url: tab.url || '',
    content: info.selectionText || '',
    note: '',
  };

  const { serverUrl } = await chrome.storage.local.get('serverUrl');
  await sendToBrain(serverUrl, data);
});

async function sendToBrain(serverUrl, data) {
  try {
    const response = await fetch(`${serverUrl}/api/inbox`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });

    if (response.ok) {
      // Show success badge
      chrome.action.setBadgeText({ text: '✓' });
      chrome.action.setBadgeBackgroundColor({ color: '#3fb950' });
      setTimeout(() => chrome.action.setBadgeText({ text: '' }), 2000);
    } else {
      chrome.action.setBadgeText({ text: '!' });
      chrome.action.setBadgeBackgroundColor({ color: '#f85149' });
      setTimeout(() => chrome.action.setBadgeText({ text: '' }), 3000);
    }
  } catch (e) {
    console.error('Brain extension error:', e);
    chrome.action.setBadgeText({ text: '!' });
    chrome.action.setBadgeBackgroundColor({ color: '#f85149' });
    setTimeout(() => chrome.action.setBadgeText({ text: '' }), 3000);
  }
}

// Listen for messages from popup
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === 'send-to-brain') {
    chrome.storage.local.get('serverUrl', async (result) => {
      await sendToBrain(result.serverUrl || 'http://localhost:3141', msg.data);
      sendResponse({ ok: true });
    });
    return true; // keep channel open for async response
  }
});
