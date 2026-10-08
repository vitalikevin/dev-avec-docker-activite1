# ---------- Étape 1 : builder (installe les dépendances dans un venv) ----------
FROM alpine:3.22 AS builder

RUN apk add --no-cache python3=~3.12

WORKDIR /build
COPY requirements.txt .

# pip n'est utile qu'au build : on le retire du venv avant de le copier
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --no-compile -r requirements.txt \
    && /opt/venv/bin/pip uninstall -y pip

# ---------- Étape 2 : runtime (image finale minimale) ----------
FROM alpine:3.22

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Python seul (sans pip) + utilisateur système sans privilèges, sans home ni shell.
# "!pyc" n'installe rien : il EXCLUT les .pyc précompilés (~10 Mo). DL3018 le prend
# à tort pour un paquet non versionné, d'où l'exception ciblée sur cette seule ligne.
# hadolint ignore=DL3018
RUN apk add --no-cache python3=~3.12 "!pyc" \
    && addgroup -S -g 10001 app \
    && adduser -S -u 10001 -G app -H -s /sbin/nologin app

WORKDIR /app

# Uniquement le résultat du builder : ni pip, ni cache, ni fichiers temporaires
COPY --from=builder /opt/venv /opt/venv
COPY app/ ./app/

USER 10001:10001

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--chdir", "app", "app:app"]
