FROM python:3.12.4

RUN apt-get update && \
    apt-get install -y ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

COPY ./spotify-to-mp3-python/requirements.txt /app/requirements.txt
 
RUN pip install --no-cache-dir --upgrade -r /app/requirements.txt

COPY ./spotify-to-mp3-python /app
# COPY ./spotify-to-mp3-python/static /code/static
# COPY ./spotify-to-mp3-python/static /code/spotify-to-mp3-python/static

# 
# COPY ./spotify-to-mp3-python /code/spotify-to-mp3-python

# Expose the port FastAPI will run on
EXPOSE 80

# 
# CMD ["fastapi", "run", "spotify-to-mp3-python/curr_playing.py", "--host", "0.0.0.0", "--port", "80"]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]
