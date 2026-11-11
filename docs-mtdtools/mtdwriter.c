// mtdwriter: erase -> write -> verify для MTD-раздела (NAND-safe).
// usage: mtdwriter /dev/mtdN file.img
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <mtd/mtd-user.h>

int main(int argc, char **argv) {
    if (argc < 3) { printf("usage: mtdwriter /dev/mtdN file.img\n"); return 1; }
    int fd = open(argv[1], O_RDWR);
    if (fd < 0) { perror("open mtd"); return 1; }
    FILE *f = fopen(argv[2], "rb");
    if (!f) { perror("open img"); return 1; }
    mtd_info_t mi;
    if (ioctl(fd, MEMGETINFO, &mi)) { perror("MEMGETINFO"); return 1; }
    printf("size=%u erasesize=%u writesize=%u blocks=%u\n",
        mi.size, mi.erasesize, mi.writesize, mi.size/mi.erasesize);

    long isz = 0; fseek(f, 0, SEEK_END); isz = ftell(f); fseek(f, 0, SEEK_SET);
    if (isz > mi.size) { printf("image too big\n"); return 1; }
    unsigned total = ((unsigned)isz + mi.erasesize - 1) / mi.erasesize * mi.erasesize;
    unsigned char *img = malloc(total);
    memset(img, 0xFF, total);
    if (fread(img, 1, isz, f) != (size_t)isz) { printf("read img fail\n"); return 1; }
    fclose(f);

    // 1) erase
    for (unsigned i = 0; i < total/mi.erasesize; i++) {
        erase_info_t ei; ei.start = i*mi.erasesize; ei.length = mi.erasesize;
        if (ioctl(fd, MEMERASE, &ei)) { printf("ERASE block %u fail: %s\n", i, strerror(errno)); return 1; }
    }
    printf("erased %u blocks\n", total/mi.erasesize);

    // 2) write (по writesize)
    unsigned char *p = img;
    for (unsigned off = 0; off < total; off += mi.writesize) {
        ssize_t w = write(fd, p, mi.writesize);
        if (w != (ssize_t)mi.writesize) { printf("WRITE @0x%x fail: %s (%zd)\n", off, strerror(errno), w); return 1; }
        p += mi.writesize;
    }
    printf("written %u bytes\n", total);

    // 3) verify
    unsigned char *rb = malloc(mi.erasesize);
    unsigned mism = 0;
    for (unsigned i = 0; i < total/mi.erasesize; i++) {
        ssize_t r = pread(fd, rb, mi.erasesize, (long)i*mi.erasesize);
        if (r != (ssize_t)mi.erasesize) { printf("READ block %u fail: %s (%zd)\n", i, strerror(errno), r); mism++; continue; }
        if (memcmp(rb, img + i*mi.erasesize, mi.erasesize)) { printf("MISMATCH block %u\n", i); mism++; }
    }
    if (mism) { printf("VERIFY FAIL: %u blocks bad\n", mism); return 2; }
    printf("VERIFY OK\n");
    return 0;
}
