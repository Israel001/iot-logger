async function fetchJSON(url, options = {}, timeoutMs = 8000) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    if (!response.ok) throw new Error(await response.text() || `Request failed: ${response.status}`);
    return response.json();
  } catch (error) {
    if (error.name === "AbortError") {
      throw new Error(`Request timed out for ${url}`);
    }
    throw error;
  } finally {
    clearTimeout(timeoutId);
  }
}

function renderRows(targetId, rows, formatter, emptyCols = 6) {
  const el = document.getElementById(targetId);
  el.innerHTML = rows.map(formatter).join("") || `<tr><td colspan="${emptyCols}">No data</td></tr>`;
}

function setResult(targetId, value) {
  document.getElementById(targetId).textContent = typeof value === "string" ? value : JSON.stringify(value, null, 2);
}

function setSelectMessage(targetId, message) {
  const el = document.getElementById(targetId);
  el.innerHTML = `<option value="">${message}</option>`;
  el.value = "";
  el.disabled = true;
}

function populateSelect(targetId, items, valueKey, labelFormatter, emptyLabel) {
  const el = document.getElementById(targetId);
  if (!items.length) {
    setSelectMessage(targetId, emptyLabel);
    return;
  }
  const previousValue = el.value;
  el.innerHTML = items.map(item => `<option value="${item[valueKey]}">${labelFormatter(item)}</option>`).join("");
  el.disabled = false;
  if (items.some(item => String(item[valueKey]) === previousValue)) {
    el.value = previousValue;
  } else {
    el.selectedIndex = 0;
  }
}

async function loadReferenceData() {
  const [locationsResult, sensorsResult] = await Promise.allSettled([
    fetchJSON('/api/locations'),
    fetchJSON('/api/sensors'),
  ]);

  if (locationsResult.status === 'fulfilled') {
    populateSelect('sensorLocationId', locationsResult.value, 'id', location => location.name, 'Add a location first');
  } else {
    setSelectMessage('sensorLocationId', 'Unable to load locations');
    setResult('locationResult', locationsResult.reason?.message ?? 'Unable to load locations');
  }

  if (sensorsResult.status === 'fulfilled') {
    renderRows('sensorsBody', sensorsResult.value, row => `<tr><td>${row.sensor_code}</td><td>${row.location_name}</td><td>${row.temperature_min}</td><td>${row.temperature_max}</td><td>${row.humidity_min}</td><td>${row.humidity_max}</td><td>${row.is_active ? 'Active' : 'Inactive'}</td></tr>`, 7);
    populateSelect('readingSensorCode', sensorsResult.value, 'sensor_code', sensor => `${sensor.sensor_code} - ${sensor.location_name}`, 'Add a sensor first');
  } else {
    renderRows('sensorsBody', [], () => "", 7);
    setSelectMessage('readingSensorCode', 'Unable to load sensors');
    setResult('sensorResult', sensorsResult.reason?.message ?? 'Unable to load sensors');
  }
}

async function loadDashboard() {
  const today = new Date().toISOString().slice(0, 10);
  await loadReferenceData();
  const [summaryResult, readingsResult, anomaliesResult, dailyAveragesResult] = await Promise.allSettled([
    fetchJSON('/api/reports/summary'),
    fetchJSON('/api/readings?limit=10'),
    fetchJSON('/api/reports/anomalies'),
    fetchJSON(`/api/reports/daily-averages?start_date=${today}&end_date=${today}`),
  ]);

  if (summaryResult.status === 'fulfilled') {
    const summary = summaryResult.value;
    document.getElementById('totalReadings').textContent = summary.headline.total_readings ?? 0;
    document.getElementById('activeSensors').textContent = summary.headline.active_sensors ?? 0;
    document.getElementById('avgTemperature').textContent = `${summary.headline.avg_temperature ?? '-'} °C`;
    document.getElementById('avgHumidity').textContent = `${summary.headline.avg_humidity ?? '-'} %`;
  } else {
    document.getElementById('totalReadings').textContent = '-';
    document.getElementById('activeSensors').textContent = '-';
    document.getElementById('avgTemperature').textContent = '-';
    document.getElementById('avgHumidity').textContent = '-';
  }

  if (readingsResult.status === 'fulfilled') {
    renderRows('readingsBody', readingsResult.value, row => `<tr><td>${new Date(row.recorded_at).toLocaleString()}</td><td>${row.sensor_code}</td><td>${row.location_name}</td><td>${row.temperature}</td><td>${row.humidity}</td></tr>`, 5);
  } else {
    renderRows('readingsBody', [], () => "", 5);
  }

  if (anomaliesResult.status === 'fulfilled') {
    renderRows('anomaliesBody', anomaliesResult.value.slice(0, 10), row => `<tr><td>${new Date(row.recorded_at).toLocaleString()}</td><td>${row.sensor_code}</td><td><span class="badge-bad">${row.anomaly_type}</span></td><td>${row.temperature}</td><td>${row.humidity}</td></tr>`, 5);
  } else {
    renderRows('anomaliesBody', [], () => "", 5);
  }

  if (dailyAveragesResult.status === 'fulfilled') {
    renderRows('dailyAveragesBody', dailyAveragesResult.value, row => `<tr><td>${row.reading_date}</td><td>${row.sensor_code}</td><td>${row.location_name}</td><td>${row.avg_temperature}</td><td>${row.avg_humidity}</td><td>${row.reading_count}</td></tr>`, 6);
  } else {
    renderRows('dailyAveragesBody', [], () => "", 6);
  }
}

document.getElementById('refreshBtn').addEventListener('click', () => loadDashboard().catch(err => alert(err.message)));

document.getElementById('locationForm').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.target;
  const payload = {
    name: form.name.value.trim(),
    description: form.description.value.trim() || null,
    latitude: form.latitude.value ? Number(form.latitude.value) : null,
    longitude: form.longitude.value ? Number(form.longitude.value) : null,
  };
  try {
    const result = await fetchJSON('/api/locations', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    setResult('locationResult', result);
    form.reset();
    await loadDashboard();
  } catch (error) {
    setResult('locationResult', error.message);
  }
});

document.getElementById('sensorForm').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.target;
  const payload = {
    sensor_code: form.sensor_code.value.trim(),
    location_id: Number(form.location_id.value),
    sensor_type: form.sensor_type.value.trim(),
    temperature_min: Number(form.temperature_min.value),
    temperature_max: Number(form.temperature_max.value),
    humidity_min: Number(form.humidity_min.value),
    humidity_max: Number(form.humidity_max.value),
  };
  try {
    const result = await fetchJSON('/api/sensors', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    setResult('sensorResult', result);
    form.reset();
    form.sensor_type.value = 'environment';
    form.temperature_min.value = '10';
    form.temperature_max.value = '40';
    form.humidity_min.value = '20';
    form.humidity_max.value = '80';
    await loadDashboard();
  } catch (error) {
    setResult('sensorResult', error.message);
  }
});

document.getElementById('readingForm').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.target;
  const payload = { sensor_code: form.sensor_code.value, recorded_at: form.recorded_at.value, temperature: Number(form.temperature.value), humidity: Number(form.humidity.value) };
  try {
    const result = await fetchJSON('/api/readings', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
    setResult('formResult', result);
    form.reset();
    await loadDashboard();
  } catch (error) {
    setResult('formResult', error.message);
  }
});
loadDashboard().catch(err => { document.getElementById('formResult').textContent = err.message; });
