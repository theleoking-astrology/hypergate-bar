const preview = document.querySelector('#app-preview');
const dialog = document.querySelector('#screenshot-dialog');
document.querySelectorAll('[data-image]').forEach(button => {
  button.addEventListener('click', () => {
    document.querySelectorAll('[data-image]').forEach(tab => {
      tab.setAttribute('aria-pressed', String(tab === button));
      tab.classList.toggle('active', tab === button);
    });
    preview.src = button.dataset.image;
    preview.alt = button.dataset.description;
    document.querySelector('#preview-description').textContent = button.dataset.description;
  });
});
document.querySelector('[data-zoom]')?.addEventListener('click', () => {
  const enlarged = document.querySelector('#dialog-image');
  enlarged.src = preview.src;
  enlarged.alt = preview.alt;
  dialog.showModal();
});
document.querySelector('.dialog-close')?.addEventListener('click', () => dialog.close());
dialog?.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
document.querySelectorAll('[data-copy]').forEach(button => {
  button.addEventListener('click', async () => {
    const status = document.querySelector('[data-copy-status]');
    try {
      await navigator.clipboard.writeText(document.getElementById(button.dataset.copy).textContent);
      status.textContent = 'Commands copied. Paste them into Terminal.';
      button.textContent = 'Copied ✓';
    } catch {
      status.textContent = 'Select the commands above and copy them with your keyboard.';
    }
  });
});
