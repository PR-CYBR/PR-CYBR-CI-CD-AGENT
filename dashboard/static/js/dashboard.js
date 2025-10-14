(function () {
  function $(selector) {
    return document.querySelector(selector);
  }

  function showNotification(element, message, type) {
    element.classList.remove('is-hidden');
    element.className = 'notification ' + type;
    element.textContent = message;
  }

  function hideNotification(element) {
    element.className = 'notification is-hidden';
    element.textContent = '';
  }

  async function fetchActivity() {
    const feed = $('#activity-feed');
    if (!feed) return;
    try {
      const response = await fetch('/api/activity');
      if (!response.ok) return;
      const data = await response.json();
      feed.innerHTML = data.activity
        .slice()
        .reverse()
        .map((item) => {
          const timestamp = new Date(item.timestamp * 1000).toLocaleTimeString();
          if (item.type === 'builder_registered') {
            return `<p><strong>[${timestamp}]</strong> Builder registered: ${item.name}</p>`;
          }
          if (item.type === 'execution_created') {
            return `<p><strong>[${timestamp}]</strong> Execution created: ${item.execution_id}</p>`;
          }
          if (item.type === 'log') {
            return `<p><strong>[${timestamp}]</strong> ${item.message}</p>`;
          }
          return `<p><strong>[${timestamp}]</strong> ${item.type}</p>`;
        })
        .join('');
    } catch (error) {
      console.error('Failed to fetch activity', error);
    }
  }

  async function fetchExecutions() {
    const table = $('#executions-table');
    if (!table) return;
    try {
      const response = await fetch('/api/executions');
      if (!response.ok) return;
      const data = await response.json();
      table.innerHTML = data.executions
        .slice()
        .sort((a, b) => b.updated_at - a.updated_at)
        .map((exec) => {
          const shortId = exec.id.substring(0, 8) + '…';
          return `<tr>
            <td><a href="/status/${exec.id}">${shortId}</a></td>
            <td>${exec.builder_id}</td>
            <td>${exec.status}</td>
            <td>${exec.updated_at.toFixed(2)}</td>
          </tr>`;
        })
        .join('');
    } catch (error) {
      console.error('Failed to fetch executions', error);
    }
  }

  async function pollStatusPage() {
    const box = document.querySelector('[data-execution-id]');
    if (!box) return;
    const executionId = box.getAttribute('data-execution-id');
    try {
      const response = await fetch(`/api/status/${executionId}`);
      if (!response.ok) return;
      const data = await response.json();
      const execution = data.execution;
      $('#status-label').textContent = execution.status;
      $('#status-updated').textContent = execution.updated_at;
      $('#status-logs').textContent = execution.logs.join('\n');
    } catch (error) {
      console.error('Failed to fetch execution status', error);
    }
  }

  function setupExecuteForm() {
    const executeBtn = $('#execute-btn');
    const notification = $('#execute-notification');
    if (!executeBtn) return;
    executeBtn.addEventListener('click', async () => {
      hideNotification(notification);
      const builderId = $('#builder-select').value;
      const backend = $('#backend-select').value;
      let payload = {};
      const payloadText = $('#payload').value.trim();
      if (payloadText) {
        try {
          payload = JSON.parse(payloadText);
        } catch (error) {
          showNotification(notification, 'Payload must be valid JSON', 'is-danger');
          return;
        }
      }
      try {
        const response = await fetch('/api/execute', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ builder_id: builderId, backend, payload }),
        });
        const data = await response.json();
        if (!response.ok) {
          throw new Error(data.error || 'Failed to trigger execution');
        }
        showNotification(notification, `Execution ${data.execution.id} started`, 'is-success');
        fetchExecutions();
        fetchActivity();
      } catch (error) {
        showNotification(notification, error.message, 'is-danger');
      }
    });
  }

  function setupBuilderForm() {
    const button = $('#register-builder');
    const notification = $('#builder-notification');
    if (!button) return;
    button.addEventListener('click', async () => {
      hideNotification(notification);
      const name = $('#builder-name').value.trim();
      const description = $('#builder-description').value.trim();
      if (!name) {
        showNotification(notification, 'Name is required', 'is-danger');
        return;
      }
      try {
        const response = await fetch('/api/builders', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name, description }),
        });
        const data = await response.json();
        if (!response.ok) {
          throw new Error(data.error || 'Failed to register builder');
        }
        showNotification(notification, `Builder ${data.builder.name} created`, 'is-success');
        fetchActivity();
      } catch (error) {
        showNotification(notification, error.message, 'is-danger');
      }
    });
  }

  function init() {
    setupExecuteForm();
    setupBuilderForm();
    fetchActivity();
    fetchExecutions();
    pollStatusPage();
    setInterval(fetchActivity, 5000);
    setInterval(fetchExecutions, 7000);
    setInterval(pollStatusPage, 5000);
  }

  document.addEventListener('DOMContentLoaded', init);
})();

