# Fermata render-service — WeasyPrint + 폰트 동봉
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# WeasyPrint 런타임 의존성 (Pango / GDK-Pixbuf / 이미지 / MIME)
RUN apt-get update && apt-get install -y --no-install-recommends \
      libpango-1.0-0 \
      libpangoft2-1.0-0 \
      libgdk-pixbuf-2.0-0 \
      libjpeg62-turbo \
      libffi8 \
      fontconfig \
      shared-mime-info \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
RUN pip install -r requirements.txt

COPY render.py app.py supabase_client.py ./
COPY templates ./templates
COPY fonts ./fonts

# 동봉 폰트를 fontconfig 에도 등록 (WeasyPrint 는 @font-face 로 직접 로드하지만 보조)
RUN fc-cache -f /app/fonts

EXPOSE 8080
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
