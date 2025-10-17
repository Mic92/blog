---
title: "ZFS ate my RAM: Understanding the ARC cache"
date: 2025-10-17T11:36:00+00:00
categories: ["zfs", "linux", "memory"]
author: "Jörg Thalheim"
---

If you're running ZFS on Linux and checking your system's memory usage, you
might be shocked to see that most of your RAM appears to be consumed. Don't
panic! This is actually by design, and it's a good thing.

## The confusion

When you run `free -h`, you might see something like this:

```console
$ free -h
              total        used        free      shared  buff/cache   available
Mem:           31Gi        28Gi       512Mi       128Mi       2.5Gi       2.8Gi
Swap:         8.0Gi       1.2Gi       6.8Gi
```

It looks like your system is using 28GB out of 31GB! But before you start
hunting for memory leaks, you need to understand how ZFS works.

## What is the ARC?

ZFS uses an **Adaptive Replacement Cache (ARC)** to store frequently accessed
data in RAM. This cache dramatically improves read performance by keeping hot
data in memory instead of repeatedly reading from disk.

The key thing to understand is: **ZFS is supposed to use most of your available
RAM for the ARC**. It's not a memory leak; it's a feature!

The ARC behaves similarly to the Linux page cache (what you might know from
[linuxatemyram.com](https://www.linuxatemyram.com/)), but with some important
differences:

- The ARC is managed by ZFS itself, not the kernel
- It can store compressed data, making it even more efficient
- It includes metadata caching for faster file operations
- It has sophisticated algorithms to keep the most useful data cached

## How to check actual memory pressure

The memory shown as "used" includes the ARC, which is **reclaimable**. When
applications need memory, ZFS will shrink the ARC to make room.

### Check ZFS ARC usage

To see how much RAM the ARC is actually using:

```console
$ cat /proc/spl/kstat/zfs/arcstats | grep "^size" | head -1
size                            4    26843545600
```

The second number is in bytes. To make it human-readable:

```console
$ awk '/^size/ { printf "ARC size: %.2f GB\n", $3/1024/1024/1024; exit }' \
  /proc/spl/kstat/zfs/arcstats
ARC size: 25.00 GB
```

Or use the `arc_summary` tool if available:

```console
$ arc_summary | head -20
```

### Check actual available memory

The "available" column in `free` already accounts for reclaimable memory,
including some of the ARC. So in our earlier example:

```console
$ free -h
              total        used        free      shared  buff/cache   available
Mem:           31Gi        28Gi       512Mi       128Mi       2.5Gi       2.8Gi
```

The **2.8Gi available** is what actually matters. This is the memory that can be
immediately used by applications without swapping. If this number gets low, then
you might have actual memory pressure.

### Monitor ARC efficiency

Check if the ARC is actually helping performance:

```console
$ awk '/^hits/ { hits=$3 } /^misses/ { misses=$3 } \
  END { printf "Hit rate: %.2f%%\n", hits*100/(hits+misses) }' \
  /proc/spl/kstat/zfs/arcstats
Hit rate: 94.23%
```

A high hit rate (above 80-90%) means the ARC is doing its job well.

## Tuning the ARC

### Set maximum ARC size

If you really want to limit the ARC (for example, if you're running memory-heavy
applications), you can set a maximum size.

Add to `/etc/modprobe.d/zfs.conf`:

```
options zfs zfs_arc_max=17179869184
```

This limits the ARC to 16GB (value is in bytes). Apply with:

```console
$ echo 17179869184 > /sys/module/zfs/parameters/zfs_arc_max
```

Or reboot for the modprobe setting to take effect.

### Set minimum ARC size

You can also set a minimum to ensure ZFS always has some cache:

```
options zfs zfs_arc_min=4294967296
```

This ensures at least 4GB is always reserved for the ARC.

## Best practices

1. **Don't limit the ARC unless necessary**: ZFS is designed to use available
   memory efficiently. The default behavior is usually optimal.

2. **Monitor the "available" memory**: This is your real indicator of memory
   pressure, not "used" memory.

3. **Watch for swap usage**: If your system starts swapping while the ARC is
   large, you might need to limit the ARC size.

4. **Use `htop` or similar tools**: They often show memory usage in a more
   intuitive way, with better breakdowns of cache vs. active memory.

5. **Check ARC hit rate**: If your hit rate is low, you might benefit from more
   RAM or need to optimize your workload.

## The bottom line

Just like the page cache in Linux, **ZFS using most of your RAM is normal and
beneficial**. The ARC makes your file system faster by caching data in memory.

Remember:

- **High "used" memory**: Normal, includes ARC cache
- **Low "available" memory**: This is when you should worry
- **The ARC shrinks automatically**: When applications need memory, ZFS gives it
  back

So next time you see `free` showing high memory usage on a ZFS system, take a
deep breath and check the "available" column instead. Your RAM isn't being
eaten—it's being put to good use!

## Further reading

- [ZFS on Linux ARC documentation](https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Module%20Parameters.html#arc)
- [Linux ate my RAM](https://www.linuxatemyram.com/) - Understanding general Linux memory usage
- [OpenZFS ARC tuning guide](https://wiki.freebsd.org/ZFSTuningGuide#ARC)
