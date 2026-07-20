# Use the official Python slim image for a lightweight footprint
FROM python:3.11-slim

# Prevent python from writing pyc files to disk and buffering stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory in the container
WORKDIR /app

# Install system dependencies if needed (e.g., git/compilers)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy only requirements first to leverage Docker caching layers
COPY requirements.txt .

# Install Python packages
RUN pip install --no-cache-dir --upgrade -r requirements.txt

# Copy the application source code
COPY . .

# Expose port 8080 (default target for Google Cloud Run)
EXPOSE 8080

# Start FastAPI application using uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
