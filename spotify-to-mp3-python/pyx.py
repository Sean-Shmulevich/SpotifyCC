from io import BytesIO
import math
import requests
from PIL import Image, ImageFilter
from scipy.spatial import KDTree
import numpy as np
from sklearn.cluster import KMeans
from lzw import lzw_compress
from boto_client import put_obj_s3


# todo: catch errors
def download_image_to_memory(url):
    response = requests.get(url)
    response.raise_for_status()  # Check that the request was successful
    img = Image.open(BytesIO(response.content))
    return img

def find_most_common_colors(image, num_colors=16):
    # Load image
    # image = image.resize((image.width // 9, image.height // 9))  # Resize for faster processing
    image = image.resize((image.width, image.height))  # Resize for faster processing


    # Convert image to numpy array
    np_image = np.array(image)

    # Check if the image has an alpha channel (4th dimension), and remove it if necessary
    if np_image.shape[-1] == 4:
        np_image = np_image[:, :, :3]

    np_image = np_image.reshape((np_image.shape[0] * np_image.shape[1], 3))  # Reshape to list of RGB values



    # Use KMeans to find the most common colors
    kmeans = KMeans(n_clusters=num_colors, random_state=42)
    kmeans.fit(np_image)
    colors = kmeans.cluster_centers_

    # Convert colors to integers
    colors = colors.astype(int)

    return colors



def find_nearest_ansi_color_batch(pixels, tree, ansi_palette, original_shape):
    distance, index = tree.query((pixels))
    hex_indices = [format(i, 'x') for i in index]
    return np.array(hex_indices).reshape(original_shape[0], original_shape[1])


def rgb_to_hex(rgb):
    return "0x{:02x}{:02x}{:02x}".format(rgb[0], rgb[1], rgb[2])


def convert_colors_to_lua_hex(colors):
    hex_colors = [rgb_to_hex(color) for color in colors]
    lua_hex_array = "{" + ", ".join(hex_colors) + "}"
    return lua_hex_array


# this will be very fast becase the image will be pretty small it will be already processed.
def get_palette(image):

    ansi_palette = find_most_common_colors(image)
    return ansi_palette


def calculate_pixel_size(image, monitor_width, monitor_height):
    if (monitor_width == 0 or monitor_height == 0):
        return 3

    smaller_dimention = monitor_height
    image_height, image_width = image.size
    smaller_img_dimention = image_height
    if monitor_height > monitor_width:
        smaller_dimention = monitor_width
        smaller_img_dimention = image_width

    smaller_dimention = smaller_dimention*0.9

    return math.floor(smaller_img_dimention/smaller_dimention) + 1
    
def pixelate(ansi_palette, image, pixel_size):

    tree = KDTree(ansi_palette)
    
    image = image.resize(
        (image.size[0] // pixel_size, image.size[1] // pixel_size),
        Image.NEAREST
    )

    # Convert image to numpy array
    pixel_array = np.array(image)
    original_shape = pixel_array.shape

    # Reshape to a 2D array where each row is a pixel
    pixels = pixel_array.reshape((-1, 3))
    nearest_colors = find_nearest_ansi_color_batch(pixels[:, :3], tree, ansi_palette, original_shape)

    nearest_colors_str = '\n'.join([''.join(map(str, array)) for array in nearest_colors])

    # with open(output_file_path, "wb") as f:
    #     f.write()

    print("image converted")
    return lzw_compress(nearest_colors_str).encode('latin-1') 


def rgb_to_char(rgb):
    # Calculate the average brightness of the RGB values
    # Define thresholds for mapping
    char = "0"
    if rgb[0] > 200 and rgb[1] > 200 and rgb[2] > 200:
        char = 'f'  # Dark
    elif rgb[2] > 200:
        char = '5'  # Medium
    elif rgb[0] < 200 and rgb[1] < 200  and rgb[2] < 200:
        char = '0'  # Medium

    return char

def img_outline(img, file_name):
    # stroke_radius = 41
    stroke_radius = 25
    stroke_image = Image.new("RGBA", img.size, (0, 0, 255, 0))
    img_alpha = img.getchannel(3).point(lambda x: 255 if x>0 else 0)
    stroke_alpha = img_alpha.filter(ImageFilter.MaxFilter(stroke_radius))
    # optionally, smooth the result
    stroke_alpha = stroke_alpha.filter(ImageFilter.SMOOTH)
    stroke_image.putalpha(stroke_alpha)
    output = Image.alpha_composite(stroke_image, img)
    return output
    output.save(file_name)

def createOutlineImage(image, pixel_size, name, referenceImage):
    if image.mode != 'RGBA':
        image = image.convert('RGBA')
    # image = img_outline(image, f"./static/luaImages/{name}.png")
    # make it of a specified pixel size
    refHeight, refWidth = referenceImage.size


    image = image.resize(
        (pixel_size, pixel_size),
        Image.NEAREST
    )


    
    background = Image.new("RGB", image.size, (255, 255, 255))
    im1 = image.copy()
    alpha = im1.split()[3]  # Get the alpha channel
    background.paste(im1, (0, 0), alpha)

    # background.save(f"./luaImages/{name}_small.png")
    background.save(f"./luaImages/{name}_small.png")

def simple_pixelate(image, name):
    pixel_array = np.array(image)
    nfp_img = ""
    for row in pixel_array:
        nfp_img += ''.join(rgb_to_char(pixel) for pixel in row)
        nfp_img += "\n"
    print(nfp_img)
    with open(f"./luaImages/{name}.lzw", "wb") as f:
        f.write(lzw_compress(nfp_img).encode('latin-1'))


# with open("./luaImages/playing-paused-10.txt", "r") as f:
#     with open("./luaImages/paused_10.lzw", "wb") as lzw:
#         lzw.write(lzw_compress(f.read()).encode('latin-1'))
# for i in range(1,10):
#     bigImg = Image.open(f'luaImages/load{i}.png')
#     createOutlineImage(bigImg)
#     img = Image.open(f'luaImages/load{i}_small.png')
#     pixelated = simple_pixelate(img, 22, f"load{i}", True)
    # put_obj_s3(pixelated, f"load{i}", "lzw")
# media = [ "playing", "paused", "prev", "next"]
# for name in media:
#     bigImg = Image.open(f'{name}.png')
#     refImg = bigImg.copy()
#     for i in range(8,35):
#         createOutlineImage(bigImg, i, f"{name}_{i}", refImg)
#         img = Image.open(f'luaImages/{name}_{i}_small.png')
#         simple_pixelate(img, f"{name}_{i}")
        # bigImg = Image.open(f'luaImages/{name}_{i}_small.png')
# x*.1=12 x=120 
# x*.1=8 x=80
# img = Image.open(f'gif/load{7}.png')
# pixelated = simple_pixelate(img, 22, f"load{7}", True)
# pixelated = simple_pixelate(img, 22)
# put_obj_s3(pixelated, f"load{7}", "lzw")
# img = Image.open(f'gif/load{4}.png')
# pixelated = simple_pixelate(img, 22, f"load{4}", True)
# pixelated = simple_pixelate(img, 22)
# put_obj_s3(pixelated, f"load{4}", "lzw")
# palette = get_palette(img)
# pixelated = simple_pixelate(img, 13)
# put_obj_s3(pixelated, "prev", "lzw")
# print("added s3")
