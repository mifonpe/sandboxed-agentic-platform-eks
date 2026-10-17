FROM public.ecr.aws/docker/library/python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM public.ecr.aws/docker/library/python:3.12-slim
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY server.py sandbox.py ./
COPY manifests/ ./manifests/
CMD ["python", "server.py"]
