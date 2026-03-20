async function fetchJSON(url, options = {}) {
  const response = await fetch(url, options);
  if (!response.ok) throw new Error(await response.text() || `Request failed: ${response.status}`);
  return response.json();
}
function renderRows(targetId, rows, formatter, emptyCols = 6) {
  const el = document.getElementById(targetId);
  el.innerHTML = rows.map(formatter).join("") || `<tr><td colspan="${emptyCols}">No data</td></tr>`;
}
async function loadDashboard() {
  const summary = await fetchJSON('/api/reports/summary');
  document.getElementById('totalReadings').textContent = summary.headline.total_readings ?? 0;
  document.getElementById('activeSensors').textContent = summary.headline.active_sensors ?? 0;
  document.getElementById('avgTemperature').textContent = `${summary.headline.avg_temperature ?? '-'} °C`;
  document.getElementById('avgHumidity').textContent = `${summary.headline.avg_humidity ?? '-'} %`;
  const readings = await fetchJSON('/api/readings?limit=10');
  renderRows('readingsBody', readings, row => `<tr><td>${new Date(row.recorded_at).toLocaleString()}</td><td>${row.sensor_code}</td><td>${row.location_name}</td><td>${row.temperature}</td><td>${row.humidity}</td></tr>`, 5);
  const anomalies = await fetchJSON('/api/reports/anomalies');
  renderRows('anomaliesBody', anomalies.slice(0, 10), row => `<tr><td>${new Date(row.recorded_at).toLocaleString()}</td><td>${row.sensor_code}</td><td><span class="badge-bad">${row.anomaly_type}</span></td><td>${row.temperature}</td><td>${row.humidity}</td></tr>`, 5);
  const today = new Date().toISOString().slice(0, 10);
  const dailyAverages = await fetchJSON(`/api/reports/daily-averages?start_date=${today}&end_date=${today}`);
  renderRows('dailyAveragesBody', dailyAverages, row => `<tr><td>${row.reading_date}</td><td>${row.sensor_code}</td><td>${row.location_name}</td><td>${row.avg_temperature}</td><td>${row.avg_humidity}</td><td>${row.reading_count}</td></tr>`, 6);
}
document.getElementById('refreshBtn').addEventListener('click', () => loadDashboard().catch(err => alert(err.message)));
document.getElementById('readingForm').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.target;
  const payload = { sensor_code: form.sensor_code.value, recorded_at: form.recorded_at.value, temperature: Number(form.temperature.value), humidity: Number(form.humidity.value) };
  try {
    const result = await fetchJSON('/api/readings', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
    document.getElementById('formResult').textContent = JSON.stringify(result, null, 2);
    form.reset();
    await loadDashboard();
  } catch (error) {
    document.getElementById('formResult').textContent = error.message;
  }
});
loadDashboard().catch(err => { document.getElementById('formResult').textContent = err.message; });
