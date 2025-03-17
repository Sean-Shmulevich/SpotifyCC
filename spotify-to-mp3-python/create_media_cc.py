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
            "User-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                "Cookie": (
        "__Secure-YEC=Cgs2NGtpTS1Ra3NvQSjc15m2BjIKCgJDSBIEGgAgEg%3D%3D; "
        "LOGIN_INFO=AFmmF2swRgIhAIAOj6rwLZlKCO9zck2ysLSTx8nav9ti3rEcCEc44kKjAiEA_pWoffpqcv7ElfNp8CUWf_23zbG4gmSs6CmLk4yw02s:QUQ3MjNmeURwOHVrMU5CTzNBbjNyb3ZfZGxiME9vMndrdTR5cnRRZjZLcGZ1dW8ySTlvZ1V5djlndkdTb09aVm5HZ0sxRDVvTmIzNHdEZTNCR1JjNXFkYTdOSzYydkJRV1U3SUhBQ1pHZnRUVGxWdGZiQmFmUzhvYklWVms0ZXF1ZDBiNllaUTlDSWRwakFsNU1EZlVwVTU2WG9hdjhVSERn; "
        "SID=g.a000uwh2nZl7I6_-VxD5spD1_06rYbcUcqb1B0G6RATAlNbkGrqPJuQXpovm_KI0CW_h1pL__QACgYKAR0SAQ4SFQHGX2MizBQ6MvwcuLg5-g-mkR7yIBoVAUF8yKqC2Xu5P2KVu10iFHl-Px870076; "
        "__Secure-1PSID=g.a000uwh2nZl7I6_-VxD5spD1_06rYbcUcqb1B0G6RATAlNbkGrqP5N4jbvhuONoeVLowLA6ZDgACgYKAccSAQ4SFQHGX2MiWl2Vy155pgJJMu-8mXQekBoVAUF8yKoy4vrCmRTviA94CgNpe_a40076; "
        "__Secure-3PSID=g.a000uwh2nZl7I6_-VxD5spD1_06rYbcUcqb1B0G6RATAlNbkGrqPGqjnU2N6uiUrsphkhwjjNQACgYKAVQSAQ4SFQHGX2Miezc9H9_cBqROFooAltKXThoVAUF8yKokp1p-8RESnw7KFoFvreit0076; "
        "APISID=KwZ0lyykZIECZvpU/AZZSBUKs466YWJ1Xk; "
        "SAPISID=WA6CazOdglP-xZqz/Aep7LPLmZFot3M8wM; "
        "__Secure-1PAPISID=WA6CazOdglP-xZqz/Aep7LPLmZFot3M8wM; "
        "__Secure-3PAPISID=WA6CazOdglP-xZqz/Aep7LPLmZFot3M8wM; "
        "YSC=jXPxaTWxmu0; "
        "VISITOR_INFO1_LIVE=ZVlH9yVAM88; "
        "VISITOR_PRIVACY_METADATA=CgJVUxIEGgAgSA%3D%3D"
    ),
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
