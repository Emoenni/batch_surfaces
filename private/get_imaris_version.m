%getting release date of current imaris version
function imaris_date_time = get_imaris_version(imaris)

imaris_version = char(imaris.GetVersion);
date_begin = find(imaris_version=='[');
date_end = find(imaris_version==']');
imaris_date = imaris_version((date_begin+1):(date_end-1));
imaris_date_time = datetime(datestr(imaris_date));
