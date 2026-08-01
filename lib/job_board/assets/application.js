(function () {
  "use strict";

  // Confirmation dialogs for destructive button_to forms (no Turbo/UJS assumed).
  document.addEventListener("submit", function (event) {
    var form = event.target;
    var message = form.dataset && form.dataset.confirm;
    if (message && !window.confirm(message)) {
      event.preventDefault();
    }
  });

  // Auto-refresh: re-fetch the current page and swap [data-poll-region] contents.
  var interval = parseInt(document.body.dataset.pollInterval, 10);
  if (!interval || interval <= 0) return;
  if (!document.querySelector("[data-poll-region]")) return;

  setInterval(function () {
    if (document.hidden) return;

    fetch(window.location.href, {
      headers: { "Accept": "text/html" },
      credentials: "same-origin"
    })
      .then(function (response) {
        if (!response.ok) throw new Error("poll failed");
        return response.text();
      })
      .then(function (html) {
        var fresh = new DOMParser().parseFromString(html, "text/html");
        document.querySelectorAll("[data-poll-region]").forEach(function (region) {
          var key = region.getAttribute("data-poll-region");
          var replacement = fresh.querySelector('[data-poll-region="' + key + '"]');
          if (!replacement) return;

          // Remember which <details data-persist> are open so the swap
          // doesn't collapse them.
          var open = {};
          region.querySelectorAll("details[data-persist]").forEach(function (details) {
            open[details.dataset.persist] = details.open;
          });

          region.innerHTML = replacement.innerHTML;

          region.querySelectorAll("details[data-persist]").forEach(function (details) {
            if (details.dataset.persist in open) details.open = open[details.dataset.persist];
          });
        });
      })
      .catch(function () { /* transient network errors are fine; try again next tick */ });
  }, interval * 1000);
})();
