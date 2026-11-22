(() => {
  "use strict";

  const { defaults, normalizeSite } = caraxesSettings;
  const enabled = document.querySelector("#enabled");
  const size = document.querySelector("#size");
  const label = document.querySelector("#size-label");
  const form = document.querySelector("#sites-form");
  const sites = document.querySelector("#sites");
  const save = document.querySelector("#save");
  const status = document.querySelector("#status");

  async function store(values, message = "") {
    try {
      await chrome.storage.local.set(values);
      status.textContent = message;
      return true;
    } catch {
      status.textContent = "Could not save settings.";
      return false;
    }
  }

  chrome.storage.local.get(defaults).then(settings => {
    enabled.checked = settings.enabled;
    size.value = settings.size;
    label.value = size.value + " px";
    sites.value = settings.disabledSites.join("\n");
    for (const control of [enabled, size, sites, save]) control.disabled = false;
  }).catch(() => {
    status.textContent = "Could not load settings.";
  });

  enabled.addEventListener("change", () => store({ enabled: enabled.checked }));
  size.addEventListener("input", () => { label.value = size.value + " px"; });
  size.addEventListener("change", () => store({ size: Number(size.value) }));

  form.addEventListener("submit", async event => {
    event.preventDefault();
    const lines = sites.value.split(/\r?\n/).map(line => line.trim()).filter(Boolean);
    const domains = lines.map(normalizeSite);
    if (domains.includes(null)) {
      status.textContent = "Enter a valid domain on each line.";
      return;
    }
    const disabledSites = [...new Set(domains)];
    if (await store({ disabledSites }, "Sites saved.")) sites.value = disabledSites.join("\n");
  });
})();
