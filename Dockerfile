FROM python:3.12.4

RUN apt-get update && \
    apt-get install -y ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /code

COPY ./spotify-to-mp3-python/requirements.txt /code/requirements.txt
 
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

COPY ./spotify-to-mp3-python/main.py /code/spotify-to-mp3-python/main.py
COPY ./spotify-to-mp3-python/static /code/static
COPY ./spotify-to-mp3-python /code

# 
# COPY ./spotify-to-mp3-python/ code/spotify-to-mp3-python

# Expose the port FastAPI will run on
EXPOSE 80

# 
# CMD ["fastapi", "run", "spotify-to-mp3-python/curr_playing.py", "--host", "0.0.0.0", "--port", "80"]
CMD ["uvicorn", "spotify-to-mp3-python.main:app", "--host", "0.0.0.0", "--port", "80"]
