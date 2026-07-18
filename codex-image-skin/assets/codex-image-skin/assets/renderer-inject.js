((cssText, artDataUrl) => {
  const STATE_KEY = "__CODEX_IMAGE_SKIN_STATE__";
  const STYLE_ID = "codex-image-skin-style";
  const CHROME_ID = "codex-image-skin-chrome";
  window.__CODEX_IMAGE_SKIN_DISABLED__ = false;

  const previous = window[STATE_KEY];
  previous?.observer?.disconnect();
  if (previous?.timer) clearInterval(previous.timer);
  if (previous?.scheduler?.timeout) clearTimeout(previous.scheduler.timeout);
  if (previous?.artUrl) URL.revokeObjectURL(previous.artUrl);

  const comma = artDataUrl.indexOf(",");
  const binary = atob(artDataUrl.slice(comma + 1));
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  const artUrl = URL.createObjectURL(new Blob([bytes], { type: "image/png" }));

  const ensure = () => {
    if (window.__CODEX_IMAGE_SKIN_DISABLED__) return;
    const root = document.documentElement;
    if (!root || !document.body) return;

    root.classList.add("codex-image-skin");
    root.style.setProperty("--image-skin-art", `url("${artUrl}")`);
    let style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement("style");
      style.id = STYLE_ID;
      (document.head || root).appendChild(style);
    }
    if (style.textContent !== cssText) style.textContent = cssText;

    const home = document.querySelector('[role="main"]:has([data-testid="home-icon"])');
    document.querySelectorAll(".image-skin-home").forEach((node) => {
      if (node !== home) node.classList.remove("image-skin-home");
    });
    document.querySelectorAll(".image-skin-hero").forEach((node) => node.classList.remove("image-skin-hero"));
    if (home) {
      home.classList.add("image-skin-home");
      home.firstElementChild?.firstElementChild?.firstElementChild?.classList.add("image-skin-hero");
    }

    const shell = document.querySelector("main.main-surface") || document.querySelector("main");
    let chrome = document.getElementById(CHROME_ID);
    if (!chrome || chrome.parentElement !== document.body) {
      chrome?.remove();
      chrome = document.createElement("div");
      chrome.id = CHROME_ID;
      chrome.setAttribute("aria-hidden", "true");
      chrome.innerHTML = '<div class="image-skin-label">Codex Image Theme</div>';
      document.body.appendChild(chrome);
    }
    if (!shell) return;
    const box = shell.getBoundingClientRect();
    chrome.style.left = `${Math.round(box.left)}px`;
    chrome.style.top = `${Math.round(box.top)}px`;
    chrome.style.width = `${Math.round(box.width)}px`;
    chrome.style.height = `${Math.round(box.height)}px`;
    chrome.classList.toggle("image-skin-home-shell", Boolean(home));
  };

  const cleanup = () => {
    window.__CODEX_IMAGE_SKIN_DISABLED__ = true;
    document.documentElement?.classList.remove("codex-image-skin");
    document.documentElement?.style.removeProperty("--image-skin-art");
    document.querySelectorAll(".image-skin-home, .image-skin-hero").forEach((node) => node.classList.remove("image-skin-home", "image-skin-hero"));
    document.getElementById(STYLE_ID)?.remove();
    document.getElementById(CHROME_ID)?.remove();
    observer.disconnect();
    clearInterval(timer);
    if (scheduler.timeout) clearTimeout(scheduler.timeout);
    URL.revokeObjectURL(artUrl);
    delete window[STATE_KEY];
    return true;
  };

  const scheduler = { timeout: null };
  const scheduleEnsure = () => {
    if (scheduler.timeout) clearTimeout(scheduler.timeout);
    scheduler.timeout = setTimeout(() => {
      scheduler.timeout = null;
      ensure();
    }, 180);
  };
  const observer = new MutationObserver(scheduleEnsure);
  observer.observe(document.documentElement, { childList: true, subtree: true });
  const timer = setInterval(ensure, 5000);
  window[STATE_KEY] = { ensure, cleanup, observer, timer, scheduler, artUrl, version: "1.0.0" };
  ensure();
  return { installed: true, version: "1.0.0" };
})(__IMAGE_SKIN_CSS_JSON__, __IMAGE_SKIN_ART_JSON__)
