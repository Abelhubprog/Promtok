FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=on

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

# Copy the application code
COPY . /app

# Set environment variables
ENV PYTHONPATH=/app
ENV PORT=8080

# Expose port for Fly.io
EXPOSE 8080

# Run the FastAPI server
CMD ["python","-m","uvicorn","main:app","--host","0.0.0.0","--port","8080","--log-level","info"]
