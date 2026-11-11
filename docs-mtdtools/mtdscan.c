// mtdscan: печать eraseblock-ов раздела MTD и пометка битых блоков

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <mtd/mtd-user.h>
int main(int argc, char **argv) {
    if (argc < 2) { printf("usage: mtdscan /dev/mtdN\n"); return 1; }
    int fd = open(argv[1], O_RDONLY);
    if (fd < 0) { perror("open"); return 1; }
    mtd_info_t mi;
    if (ioctl(fd, MEMGETINFO, &mi)) { perror("MEMGETINFO"); return 1; }
    printf("type=%d size=%u erasesize=%u writesize=%u oob=%u blocks=%u\n",
        mi.type, mi.size, mi.erasesize, mi.writesize, mi.oobsize, mi.size/mi.erasesize);
    unsigned bad = 0;
    for (unsigned i = 0; i < mi.size/mi.erasesize; i++) {
        long long off = (long long)i * mi.erasesize;
        int r = ioctl(fd, MEMGETBADBLOCK, (void*)&off);
        if (r > 0) { printf("block %u @ 0x%llx BAD\n", i, (unsigned long long)off); bad++; }
        else if (r < 0) { perror("MEMGETBADBLOCK"); break; }
    }
    printf("bad blocks: %u\n", bad);
    return 0;
}
