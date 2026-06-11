(function () {
  const dataUrl = "data/public/trees.geojson";
  const state = {
    features: [],
    markers: new Map(),
    layer: null,
    map: null,
  };

  const palette = [
    "#1f7a5a",
    "#b45f24",
    "#3f6fb5",
    "#8a5a9e",
    "#2f7f8f",
    "#9a6b1f",
    "#5b7f2a",
    "#b14e5c",
  ];

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function normalize(value) {
    return String(value || "").toLowerCase();
  }

  function colorForFeature(feature, index) {
    const color = feature.properties.marker_color;
    return color || palette[index % palette.length];
  }

  function popupHtml(feature) {
    const p = feature.properties;
    const lines = [
      ["ID", p.tree_id],
      ["学名", p.scientific_name],
      ["調査日", p.survey_date],
      ["精度", p.accuracy_m ? `${p.accuracy_m} m` : ""],
      ["メモ", p.note_public],
    ].filter((item) => item[1]);

    return `
      <div class="popup-title">${escapeHtml(p.species_jp || "樹種未設定")}</div>
      <div>${escapeHtml(p.family_jp || "")}</div>
      <div class="popup-meta">
        ${lines.map(([key, value]) => `<span><strong>${escapeHtml(key)}:</strong> ${escapeHtml(value)}</span>`).join("")}
      </div>
    `;
  }

  function featureSearchText(feature) {
    const p = feature.properties;
    return normalize([
      p.tree_id,
      p.species_jp,
      p.scientific_name,
      p.family_jp,
      p.survey_date,
      p.note_public,
    ].join(" "));
  }

  function currentFilters() {
    return {
      query: normalize(document.getElementById("tree-search").value.trim()),
      species: document.getElementById("species-filter").value,
    };
  }

  function filteredFeatures() {
    const filters = currentFilters();
    return state.features.filter((feature) => {
      const speciesMatch = !filters.species || feature.properties.species_jp === filters.species;
      const queryMatch = !filters.query || featureSearchText(feature).includes(filters.query);
      return speciesMatch && queryMatch;
    });
  }

  function renderMarkers(features) {
    state.layer.clearLayers();

    features.forEach((feature, index) => {
      const coords = feature.geometry.coordinates;
      const latlng = [coords[1], coords[0]];
      const marker = L.circleMarker(latlng, {
        radius: 7,
        color: "#ffffff",
        weight: 1.5,
        fillColor: colorForFeature(feature, index),
        fillOpacity: 0.9,
      }).bindPopup(popupHtml(feature));

      marker.addTo(state.layer);
      state.markers.set(feature.properties.tree_id, marker);
    });
  }

  function renderSpeciesFilter(features) {
    const select = document.getElementById("species-filter");
    const species = Array.from(new Set(features.map((feature) => feature.properties.species_jp).filter(Boolean))).sort();

    species.forEach((name) => {
      const option = document.createElement("option");
      option.value = name;
      option.textContent = name;
      select.appendChild(option);
    });
  }

  function renderLegend(features) {
    const legend = document.getElementById("legend");
    const bySpecies = new Map();

    features.forEach((feature, index) => {
      const name = feature.properties.species_jp || "未設定";
      if (!bySpecies.has(name)) {
        bySpecies.set(name, colorForFeature(feature, index));
      }
    });

    legend.innerHTML = "";
    bySpecies.forEach((color, name) => {
      const item = document.createElement("span");
      item.className = "legend-item";
      item.innerHTML = `<span class="legend-swatch" style="background:${escapeHtml(color)}"></span>${escapeHtml(name)}`;
      legend.appendChild(item);
    });
  }

  function renderTable(features) {
    const body = document.getElementById("tree-table-body");
    body.innerHTML = "";

    if (features.length === 0) {
      const row = document.createElement("tr");
      row.innerHTML = `<td colspan="3" class="empty-state">該当する樹木はありません。</td>`;
      body.appendChild(row);
      return;
    }

    features.forEach((feature) => {
      const p = feature.properties;
      const row = document.createElement("tr");
      row.innerHTML = `
        <td><button class="tree-row-button" type="button" data-tree-id="${escapeHtml(p.tree_id)}">${escapeHtml(p.tree_id)}</button></td>
        <td>${escapeHtml(p.species_jp)}</td>
        <td>${escapeHtml(p.scientific_name)}</td>
      `;
      body.appendChild(row);
    });

    body.querySelectorAll("button[data-tree-id]").forEach((button) => {
      button.addEventListener("click", () => {
        const marker = state.markers.get(button.dataset.treeId);
        if (!marker) return;
        state.map.setView(marker.getLatLng(), Math.max(state.map.getZoom(), 18));
        marker.openPopup();
      });
    });
  }

  function updateView() {
    state.markers.clear();
    const features = filteredFeatures();
    renderMarkers(features);
    renderTable(features);
    document.getElementById("tree-count").textContent = features.length.toLocaleString("ja-JP");
  }

  function fitToFeatures(features) {
    const latlngs = features.map((feature) => {
      const coords = feature.geometry.coordinates;
      return [coords[1], coords[0]];
    });

    if (latlngs.length === 0) {
      state.map.setView([35.681236, 139.767125], 16);
      return;
    }

    if (latlngs.length === 1) {
      state.map.setView(latlngs[0], 18);
      return;
    }

    state.map.fitBounds(latlngs, { padding: [28, 28] });
  }

  async function initialize() {
    state.map = L.map("map", {
      fadeAnimation: false,
      zoomControl: true,
      scrollWheelZoom: true,
    });

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 20,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(state.map);

    state.layer = L.layerGroup().addTo(state.map);

    const response = await fetch(dataUrl, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`GeoJSONを読み込めませんでした: ${response.status}`);
    }

    const geojson = await response.json();
    state.features = geojson.features || [];

    renderSpeciesFilter(state.features);
    renderLegend(state.features);
    updateView();
    state.map.invalidateSize();
    fitToFeatures(state.features);
    window.requestAnimationFrame(() => {
      state.map.invalidateSize();
      fitToFeatures(state.features);
    });

    const generatedAt = geojson.properties && geojson.properties.generated_at;
    document.getElementById("last-updated").textContent = generatedAt
      ? `更新: ${generatedAt.replace("T", " ").replace("Z", " UTC")}`
      : "更新日不明";

    document.getElementById("tree-search").addEventListener("input", updateView);
    document.getElementById("species-filter").addEventListener("change", updateView);
  }

  document.addEventListener("DOMContentLoaded", () => {
    initialize().catch((error) => {
      document.getElementById("map").innerHTML = `<p class="empty-state">${escapeHtml(error.message)}</p>`;
      document.getElementById("last-updated").textContent = "読み込み失敗";
    });
  });
})();
