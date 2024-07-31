from youtube_search import YoutubeSearch
import time
import yt_dlp
import ffmpeg
from pyx import pixelate, get_palette, convert_colors_to_lua_hex, download_image_to_memory, calculate_pixel_size
import io
from contextlib import redirect_stdout
from boto_client import obj_exists, put_obj_s3


def convert_audio(input_data):
    process = (
        ffmpeg.input('pipe:')
        .output('pipe:', ac=1, c='dfpwm', ar='48k', format="dfpwm")
        .overwrite_output()
        .run_async(pipe_stdin=True, quiet=True)
    )

    output_data, error = process.communicate(input=input_data)

    if process.returncode != 0:
        raise RuntimeError(f"FFmpeg process failed with error: {error.decode()}")

    return output_data


async def download_cc_image_encoded(album_url, album_name, width, height):
    image = download_image_to_memory(album_url)
    cc_palette = get_palette(image)
    pixel_size = calculate_pixel_size(image, width, height)

    scaled_album = album_name + "_" + str(pixel_size)
    if not obj_exists(scaled_album, "lzw"):
        print("Made new album image for scale: "+str(pixel_size))
        img = pixelate(cc_palette, image, pixel_size)
        put_obj_s3(img, scaled_album, "lzw")

    cc_palette = convert_colors_to_lua_hex(cc_palette)
    return cc_palette, pixel_size


async def download_song(song_id, artist, name, extension="dfpwm"):
    output_file = f"songs/{song_id}.{extension}"

    if obj_exists(song_id, extension):
        return output_file

    print("Uploading to S3")
    text_to_search = f"{artist} {name}"

    best_url = search_yt(text_to_search)

    print("Initiating download for {}.".format(text_to_search))
    ydl_opts = {
        'format': 'ba.2',
        "http_headers": {
            "User-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
        },
        # 'outtmpl': "-",
        'outtmpl': "-",
        'embedthumbnail': False,
        'logtostderr': True,
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3'
        }],
        "postprocessor_args": ['-ac', '2', '-ar', '48k', '-sample_fmt', "s16"]
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        with io.BytesIO() as buf, redirect_stdout(buf):
            ydl.download([best_url])
            mp3 = buf.getvalue()

    # print(song_id+".dfpwm")
    dfpwm = convert_audio(mp3)
    put_obj_s3(dfpwm, song_id, extension)
    time.sleep(1.5)
    return output_file


def search_yt(text_to_search):
    TOTAL_ATTEMPTS = 10

    best_url = None
    attempts_left = TOTAL_ATTEMPTS

    while attempts_left > 0:
        try:
            results_list = YoutubeSearch(text_to_search, max_results=1).to_dict()
            best_url = "https://www.youtube.com{}".format(results_list[0]['url_suffix'])
            break
        except IndexError:
            attempts_left -= 1
            print("No valid URLs found for {}, trying again ({} attempts left).".format(
                text_to_search, attempts_left))
    if best_url is None:
        print("No valid URLs found for {}, skipping track.".format(text_to_search))

    return best_url
