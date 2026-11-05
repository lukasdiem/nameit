// Points every "download" link to the newest nameIT APK.
//
// Markup:  <a data-latest-apk href="https://github.com/lukasdiem/nameit/releases">…</a>
//          <span data-latest-apk-version></span>   (optional, shows e.g. "0.1.0 (build 22)")
//
// Prefers the newest full release, falls back to the newest pre-release. The
// href in the markup (the releases page) stays as fallback if GitHub can't be
// reached. Nothing is stored in the browser.
(function () {
  const REPO = "lukasdiem/nameit";

  async function latestApk() {
    const res = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=30`, {
      headers: { Accept: "application/vnd.github+json" },
    });
    if (!res.ok) throw new Error(`GitHub API ${res.status}`);
    const releases = (await res.json()).filter((r) => !r.draft);
    const withApk = releases.filter((r) => r.assets.some((a) => a.name.endsWith(".apk")));
    const release = withApk.find((r) => !r.prerelease) || withApk[0];
    if (!release) return null;

    const asset =
      release.assets.find((a) => a.name === "nameit.apk") ||
      release.assets.find((a) => a.name.endsWith(".apk"));
    return {
      url: asset.browser_download_url,
      label: release.name || release.tag_name,
      prerelease: release.prerelease,
    };
  }

  function apply() {
    const links = document.querySelectorAll("a[data-latest-apk]");
    const labels = document.querySelectorAll("[data-latest-apk-version]");
    if (!links.length && !labels.length) return;

    latestApk()
      .then((info) => {
        if (!info) return;
        links.forEach((a) => {
          a.href = info.url;
          a.setAttribute("download", "");
        });
        labels.forEach((el) => {
          el.textContent = info.label.replace(/^nameIT\s*/, "") + (info.prerelease ? " · test build" : "");
        });
      })
      .catch(() => {
        // Keep the fallback link to the releases page.
      });
  }

  // Material's instant navigation swaps pages without a reload.
  if (typeof document$ !== "undefined") {
    document$.subscribe(apply);
  } else {
    document.addEventListener("DOMContentLoaded", apply);
  }
})();
