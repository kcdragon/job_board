(function () {
  "use strict";

  var chart = document.getElementById("throughput-chart");
  if (!chart) return;

  var metricsUrl = chart.dataset.metricsUrl;
  var pollIntervalMs = parseInt(chart.dataset.pollInterval, 10) * 1000;
  var maxVisiblePoints = parseInt(chart.dataset.maxPoints, 10) || 120;
  if (!metricsUrl || !pollIntervalMs || pollIntervalMs <= 0) return;

  var viewBox = chart.querySelector(".throughput-chart__svg").viewBox.baseVal;
  var enqueuedLine = chart.querySelector(".tp-line--enqueued");
  var completedLine = chart.querySelector(".tp-line--completed");
  var latestLabels = {
    enqueued: chart.querySelector('[data-tp-latest="enqueued"]'),
    completed: chart.querySelector('[data-tp-latest="completed"]')
  };

  var samplesOldestToNewest = [];
  var previousServerTime = null;

  function ignoreTransientError() {}

  function fetchMetrics(query) {
    return fetch(metricsUrl + query, {
      headers: { "Accept": "application/json" },
      credentials: "same-origin"
    }).then(function (response) {
      if (!response.ok) throw new Error("metrics fetch failed");
      return response.json();
    });
  }

  function resetBaselineWithoutPlotting() {
    return fetchMetrics("").then(function (data) { previousServerTime = data.now; });
  }

  function highestValue() {
    var peak = 1;
    samplesOldestToNewest.forEach(function (sample) {
      if (sample.enqueued > peak) peak = sample.enqueued;
      if (sample.completed > peak) peak = sample.completed;
    });
    return peak;
  }

  function pointsFor(series) {
    if (samplesOldestToNewest.length === 0) return "";
    var peak = highestValue();
    var horizontalStep = samplesOldestToNewest.length > 1 ? viewBox.width / (samplesOldestToNewest.length - 1) : 0;
    return samplesOldestToNewest.map(function (sample, index) {
      var stepsFromRightEdge = samplesOldestToNewest.length - 1 - index;
      var x = viewBox.width - stepsFromRightEdge * horizontalStep;
      var y = viewBox.height - (sample[series] / peak) * viewBox.height;
      return x.toFixed(1) + "," + y.toFixed(1);
    }).join(" ");
  }

  function redraw() {
    enqueuedLine.setAttribute("points", pointsFor("enqueued"));
    completedLine.setAttribute("points", pointsFor("completed"));
    var newestSample = samplesOldestToNewest[samplesOldestToNewest.length - 1];
    if (newestSample) {
      latestLabels.enqueued.textContent = newestSample.enqueued;
      latestLabels.completed.textContent = newestSample.completed;
    }
  }

  function collectSample() {
    var baselineReady = previousServerTime !== null;
    if (document.hidden || !baselineReady) return;
    fetchMetrics("?since=" + encodeURIComponent(previousServerTime)).then(function (data) {
      samplesOldestToNewest.push({ enqueued: data.enqueued, completed: data.completed });
      if (samplesOldestToNewest.length > maxVisiblePoints) samplesOldestToNewest.shift();
      previousServerTime = data.now;
      redraw();
    }).catch(ignoreTransientError);
  }

  function reBaselineWhenTabBecomesVisible() {
    if (!document.hidden) resetBaselineWithoutPlotting();
  }

  document.addEventListener("visibilitychange", reBaselineWhenTabBecomesVisible);

  resetBaselineWithoutPlotting().catch(ignoreTransientError);
  setInterval(collectSample, pollIntervalMs);
})();
