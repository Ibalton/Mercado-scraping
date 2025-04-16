<<<<<<< HEAD
FROM python:3.11

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

=======
FROM python:3.13-slim
RUN apt-get update && apt-get install -y build-essential
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "main.py"]
>>>>>>> edc66d8d8c4b4e2d1ce08d138da1d53314bb0f31
