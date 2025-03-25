FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Get username from build arg and store it
ARG USERNAME="unknown"
RUN echo "Built by: $USERNAME" > /app/build_info.txt

EXPOSE 5000

CMD ["python", "app.py"]
