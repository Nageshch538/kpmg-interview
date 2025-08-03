FROM python:3.11-slim

WORKDIR /app

# Install curl, iproute2 (for ss), and procps (for ps)
RUN apt-get update && apt-get install -y curl iproute2 procps

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]
