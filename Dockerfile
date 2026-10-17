FROM python:3.12-alpine AS build

RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    mariadb-connector-c-dev \
    pkgconf

RUN python -m venv /venv
COPY requirements.txt /tmp/requirements.txt
RUN /venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt

FROM python:3.12-alpine

RUN apk add --no-cache libpq mariadb-connector-c

WORKDIR /app
COPY --from=build /venv /venv
ENV PATH="/venv/bin:$PATH"

COPY app.py .

ARG VERSION=5.0
RUN echo "$VERSION" > /app/VERSION

ENV PYTHONDONTWRITEBYTECODE=1

STOPSIGNAL SIGINT
CMD ["python", "app.py"]
