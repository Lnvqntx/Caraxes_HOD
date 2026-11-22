const caraxesSettings = (() => {
  const minSize = 80;
  const maxSize = 280;
  const defaults = { enabled: true, size: 160, disabledSites: [] };

  function normalizeSite(value) {
    const entry = value.trim();
    if (!entry) return null;
    try {
      const url = new URL(entry.includes("://") ? entry : "https://" + entry);
      if (!["http:", "https:"].includes(url.protocol) || !url.hostname || url.username || url.password) {
        return null;
      }
      return url.hostname.toLowerCase().replace(/\.$/, "");
    } catch {
      return null;
    }
  }

  function allows(settings, hostname) {
    const host = hostname.toLowerCase().replace(/\.$/, "");
    return settings.enabled && !settings.disabledSites.some(site =>
      host === site || host.endsWith("." + site)
    );
  }

  return { minSize, maxSize, defaults, normalizeSite, allows };
})();
