#!/usr/bin/env python3
from PIL import Image
im = Image.open("./pixmap.bmp")
im.load()
width, height = im.size
# read 95 7x6 pixel chars
cnt = 95
pheight = 7
pwidth = 6
begin_ascii = 0x20
if (height != pheight or width != pwidth*cnt):
    print("Wrong image format!")
p = []
for col in range(height):
    p.append([])
    for row in range(width):
        p[-1].append('1' if im.getpixel((row, col))[0] == 255 else '0')

for i in range(cnt):
    pix = []
    for h in range(pheight):
        for w in range(pwidth):
            pix.append(p[h][w+i*pwidth])
    pix_bin = int(''.join(pix), 2)
    print(str(i*4+0) + ':%04x' % (int(pix_bin/0x100000000) % 0x10000))
    print(str(i*4+1) + ':%04x' % (int(pix_bin/0x10000) % 0x10000))
    print(str(i*4+2) + ':%04x' % (pix_bin % 0x10000))
    print(str(i*4+3) + ':%04x' % 0xdead)
    # print('\t\tchar == 8\'h' + hex(begin_ascii+i)[2:] + \
            # ' ? 42\'b' + ''.join(pix) + ' :')

