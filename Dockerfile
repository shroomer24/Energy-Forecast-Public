FROM python:3.11-slim

# Install system dependencies for XGBoost (OpenMP)
RUN apt-get update && apt-get install -y \
    libgomp1 \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY api/ ./api/
COPY frontend/ ./frontend/

# Copy pre-trained model artifacts (committed to git via scripts/export_models.py)
COPY models/ ./models/

# Ensure data & logs directories exist
RUN mkdir -p data/charts logs mlruns models

# Environment
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Hugging Face Spaces requires the app to run on port 7860
EXPOSE 7860

# Non-root user required by Hugging Face Spaces
RUN useradd -m -u 1000 appuser && chown -R appuser /app
USER appuser

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "7860"]
