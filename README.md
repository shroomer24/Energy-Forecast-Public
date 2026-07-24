---
title: Energy Demand Forecast
emoji: ⚡
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
license: mit
short_description: Hourly PJM electricity demand forecasting — XGBoost vs SARIMA
---

# Energy Demand Forecasting Pipeline

**End-to-end ML pipeline for hourly electricity demand forecasting on the PJM Interconnection grid.**

Built by **Ram Aligave** · Business Analytics BBA · University of North Texas · Dec 2027

---

## Live Demo

The interactive dashboard is served at the root URL of this Space. It displays a 72-hour ahead
forecast with 80% prediction intervals, powered by a pre-trained XGBoost model.

> **Note:** The first request after a period of inactivity may take a few seconds while the
> container initialises and loads the model artifacts.

---

## Project Summary

This project benchmarks XGBoost against SARIMA for short-term energy demand forecasting using
three years (2022–2026) of real hourly demand data from the U.S. Energy Information
Administration (EIA) API. Key results:

| Model   | MAE (GW) | RMSE (GW) | MAPE   |
|---------|----------|-----------|--------|
| XGBoost | **0.576**    | **0.751**     | **1.52%** |
| SARIMA  | 2.591    | 2.970     | 7.10%  |

XGBoost achieves **4.7× lower MAPE** by leveraging 26 engineered features including lag windows,
Fourier time encodings, and a data-center load growth proxy.

---

## Why This Matters (2026 Context)

AI data centers are adding unprecedented load to the grid. PJM — the largest electricity market
in North America — is managing the fastest demand growth in 20 years. Accurate short-term
forecasting directly impacts:

- **Reserve margin planning** — prevents blackouts during demand spikes
- **Renewable curtailment** — wind and solar generation scheduling
- **Real-time pricing** — LMP (locational marginal price) signals

---

## Architecture

```
EIA API (real data)
      │
      ▼
data_pipeline_eia.py   ─── Fetches 26,000+ hourly rows · PJM 2022-2024
      │
      ▼
features.py            ─── 26 engineered features: lags, Fourier, calendar, temp
      │
      ├──▶ train_xgboost.py    ─── 700-tree XGBoost · MLflow tracking · MAE 0.576 GW
      ├──▶ train_sarima.py     ─── SARIMA(1,1,1)(1,1,1,7) baseline · MAE 2.591 GW
      ├──▶ train_intervals.py  ─── Quantile regression (10th/90th pct) · 80% CI
      ├──▶ backtest.py         ─── Walk-forward validation · 30-day rolling windows
      ├──▶ evaluate.py         ─── 5 evaluation charts
      └──▶ retrain.py          ─── Automated retraining · MAPE gate (5% tolerance)
                                        │
                                        ▼
                               api/main.py          ─── FastAPI · port 7860 · CORS
                                        │
                                        ▼
                               frontend/index.html  ─── Chart.js dashboard · CI band
```

---

## Quick Start (Local)

### 1. Clone and install

```bash
git clone https://github.com/ramaligave/energy-forecast.git
cd energy-forecast
python -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

**macOS (Apple Silicon / Intel) — XGBoost requires OpenMP:**
```bash
brew install libomp
sudo ln -s $(brew --prefix libomp)/lib/libomp.dylib /usr/local/lib/libomp.dylib
```

### 2. Configure API keys

```bash
cp .env.example .env
# Edit .env — set EIA_API_KEY for live data fetching (optional for inference)
```

### 3. Run the full pipeline

```bash
chmod +x run_all.sh
./run_all.sh
```

### 4. Open the dashboard

Navigate to [http://localhost:7860](http://localhost:7860)

---

## Docker

```bash
docker build -t energy-forecast .
docker run -p 7860:7860 --env-file .env energy-forecast
```

---

## API Endpoints

| Method | Endpoint              | Description                                     |
|--------|-----------------------|-------------------------------------------------|
| GET    | `/health`             | Liveness probe                                  |
| GET    | `/model/info`         | Model metadata and feature count                |
| POST   | `/forecast`           | Point forecast for N hours                      |
| POST   | `/forecast/intervals` | Forecast with 80% prediction interval band      |
| GET    | `/forecast/latest`    | Most recent 72-hour interval forecast           |
| GET    | `/docs`               | Interactive Swagger UI                          |

**Example request:**
```bash
curl -X POST https://<your-space>.hf.space/forecast/intervals \
  -H "Content-Type: application/json" \
  -d '{"hours": 72}'
```

---

## Environment Variables

Set these as **Space Secrets** in the HF Space settings (Settings → Variables and secrets):

| Variable | Required | Description |
|---|---|---|
| `EIA_API_KEY` | Optional | EIA Open Data API key — only needed to retrain on fresh data |
| `TABPFN_API_KEY` | Optional | TabPFN-3 API key — enables live TabPFN inference |

The Space runs fully without either key: inference uses the pre-trained model artifacts
committed in `models/`, and temperature data comes from the free Open-Meteo API.

---

## Features (26 total)

| Category | Features |
|----------|----------|
| Calendar | hour, dayofweek, month, dayofyear, is_weekend, is_holiday |
| Fourier  | hour_sin, hour_cos, dow_sin, dow_cos, month_sin, month_cos |
| Lags     | demand_lag_1h, 2h, 24h, 48h, 168h (1-week) |
| Rolling  | roll_mean_24h, roll_std_24h, roll_mean_168h |
| Temperature | temp_sq, temp_cooling (>65°F), temp_heating (<45°F) |
| Trend    | data_center_load_gw (AI load growth proxy) |

---

## MLflow Tracking

All experiments are logged to `./mlruns/`.

```bash
mlflow ui --port 5001
# Open http://localhost:5001
```

---

## Project Structure

```
energy-forecast/
├── src/
│   ├── data_pipeline_eia.py   # EIA API fetch + preprocessing
│   ├── features.py            # Feature engineering
│   ├── tracker.py             # MLflow experiment tracker
│   ├── train_xgboost.py       # XGBoost training
│   ├── train_sarima.py        # SARIMA training
│   ├── train_intervals.py     # Quantile regression intervals
│   ├── backtest.py            # Walk-forward validation
│   ├── evaluate.py            # Evaluation charts
│   └── retrain.py             # Automated retraining + gate
├── api/
│   └── main.py                # FastAPI inference server
├── frontend/
│   └── index.html             # Chart.js dashboard
├── models/                    # Pre-trained artifacts (tracked in git)
│   ├── xgb_model.pkl
│   ├── interval_models.pkl
│   ├── demand_seed.csv
│   ├── shap_importance.png
│   └── shap_summary.png
├── data/                      # Generated (gitignored)
├── mlruns/                    # MLflow runs (gitignored)
├── logs/                      # Retrain logs (gitignored)
├── run_all.sh
├── requirements.txt
├── Dockerfile
├── .env.example
└── .gitignore
```

---

## Resume Bullet

> Built an end-to-end hourly electricity demand forecasting pipeline benchmarking SARIMA against
> XGBoost across 26 engineered features, achieving 1.52% MAPE. Tracked experiments with MLflow
> and deployed a FastAPI inference endpoint — targeting PJM-style grid load forecasting under
> data center growth scenarios.

---

## Skills Demonstrated

- **Time series forecasting**: SARIMA, XGBoost with lag features, Fourier encodings
- **Production ML patterns**: walk-forward backtesting, quantile regression, automated retraining with model gate
- **MLOps**: MLflow experiment tracking, artifact logging, model promotion workflow
- **API development**: FastAPI, Pydantic v2, CORS, static file serving
- **Data engineering**: EIA REST API, real-world data cleaning, feature pipelines
- **Visualization**: Matplotlib, Chart.js, confidence interval bands

---

## Data Source

U.S. Energy Information Administration (EIA) Open Data API
Respondent: PJM Interconnection (largest U.S. electricity market)
Type: D (Demand)
Frequency: Hourly
Period: 2022–2024
License: Public domain (U.S. government data)

EIA API registration: [https://www.eia.gov/opendata/](https://www.eia.gov/opendata/)
