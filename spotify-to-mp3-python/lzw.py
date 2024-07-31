def lzw_compress(input_string):
    if not isinstance(input_string, str):
        raise TypeError(f"string expected, got {type(input_string).__name__}")

    length = len(input_string)
    if length <= 1:
        return "u" + input_string

    basedict_compress = {chr(i): chr(i) + chr(0) for i in range(256)}
    dict_size = 256
    dict_a, dict_b = 0, 1
    dict_custom = {}
    result = ["c"]
    result_len = 1
    word = ""

    for c in input_string:
        wc = word + c
        if wc not in basedict_compress and wc not in dict_custom:
            write = basedict_compress.get(word, dict_custom.get(word))
            if write is None:
                raise ValueError("algorithm error, could not fetch word")
            result.append(write)
            result_len += len(write)
            if length <= result_len:
                return "u" + input_string
            dict_custom, dict_a, dict_b = dict_add(wc, dict_custom, dict_a, dict_b)
            word = c
        else:
            word = wc

    write = basedict_compress.get(word, dict_custom.get(word))
    result.append(write)
    result_len += len(write)
    if length <= result_len:
        return "u" + input_string

    return "".join(result)

def dict_add(string, dictionary, a, b):
    if a >= 256:
        a, b = 0, b + 1
        if b >= 256:
            dictionary.clear()
            b = 1
    dictionary[string] = chr(a) + chr(b)
    a += 1
    return dictionary, a, b
