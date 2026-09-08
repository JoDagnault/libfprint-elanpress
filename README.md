# libfprint-elanpress

Arch Linux package: upstream [libfprint](https://fprint.freedesktop.org/) plus
the **elanpress** driver for the ELAN `04f3:0c6e` press-type fingerprint sensor
found in ASUS Vivobook, Zenbook and ROG Flow X13 laptops.

It is a drop-in replacement for the `libfprint` package (`provides`/`conflicts`),
so `fprintd` keeps working unchanged.

## Why

Stock libfprint lists `04f3:0c6e` in its image-based `elan` driver, which was
written for *swipe* sensors. On this sensor that driver:

* aborts with `The driver encountered a protocol error with the device`
  because the sensor answers the finger-wait command with status `0xaf`
  instead of the expected `0x55` (`libfprint/drivers/elan.c`, `CAPTURE_READ_DATA`);
* even when a capture succeeds, stitches near-identical frames of a resting
  finger into unusable images, so verification never matches.

Upstream issues:
[#814](https://gitlab.freedesktop.org/libfprint/libfprint/-/issues/814),
[#808](https://gitlab.freedesktop.org/libfprint/libfprint/-/issues/808),
[#759](https://gitlab.freedesktop.org/libfprint/libfprint/-/issues/759),
[#732](https://gitlab.freedesktop.org/libfprint/libfprint/-/issues/732).

The `elanpress` driver was written by Filip Spanne
([filip-rs/libfprint](https://github.com/filip-rs/libfprint), branch `elanpress`,
commit `34fc394`, also on the AUR as `libfprint-elanpress-git`). It treats the
sensor as a press sensor and does match-on-host with normalized cross-correlation
of stored touch images, the same approach the Windows driver uses.

This repository carries that commit as a patch on top of the exact upstream
tag Arch ships, rebased from v1.94.10 to v1.94.100, plus a second patch with
the fixes needed on the Vivobook M7400QC (see below), so the code is pinned
and the build follows Arch's libfprint rather than a third-party branch.

## What the second patch changes (0002)

The driver as published did not work on this laptop's sensor (firmware 0x0500):

* **Enrollment hung.** This firmware never answers the "finger present?" query
  while no finger is on the sensor; the read blocks until a touch, then answers
  "present" on every query. The driver waited for a "not present" byte that
  never comes. A timed-out query is now treated as "no finger", and the query
  is re-issued every 500 ms while waiting.
* **Another finger matched.** The correlation was dominated by the contact
  pressure envelope, so any two fingers scored 0.7-0.9. Images are now
  high-pass filtered and locally contrast-normalised before correlating, the
  sharpest frame of a touch is used (a heavy press drives the sensor into
  compression within a few hundred ms), and the threshold is 0.60. On 21
  genuine and 26 impostor presses over four sessions, impostors stayed at or
  below 0.52 (worst case: the other index finger) and genuine presses on an
  enrolled region scored 0.67-0.86.
* **Coverage.** The sensor images about 7.5 x 2.6 mm, so a press only verifies
  where it overlaps a stored touch. Enrollment takes 16 touches and rejects a
  touch too similar to one already stored, asking you to move the finger.

Enrollment tip: move the finger between touches (centre, left, right, tip,
lower, rolled slightly). A press on a part of the finger you never enrolled
will be rejected; pam_fprintd allows retries, or re-enroll with more variety.

## Build and install

```sh
git clone <this repo> && cd libfprint-elanpress
makepkg -si
```

`makepkg` will ask to replace `libfprint` with `libfprint-elanpress`; answer yes.
Then:

```sh
systemctl restart fprintd      # or just wait, it exits when idle
fprintd-list "$USER"           # should say "ElanTech press-type fingerprint sensor"
fprintd-enroll                 # 16 press-and-lift touches, move the finger around, do not swipe
fprintd-verify
```

### Omarchy note

Do **not** run `omarchy-setup-security-fingerprint` after installing this package.
It calls `omarchy-pkg-add libfprint`, which tries to reinstall the stock package
and aborts on the conflict. Enroll with `fprintd-enroll` directly, check with
`fprintd-verify`, then run `sudo ./setup-pam.sh`, which applies the same PAM
configuration that script would:

* `/etc/pam.d/sudo` and `/etc/pam.d/polkit-1`: at the top, add
  ```
  auth      [success=1 default=ignore] pam_exec.so quiet /usr/bin/omarchy-hw-laptop-closed
  auth      sufficient pam_fprintd.so
  ```
* `/etc/pam.d/omarchy-lock-fingerprint`:
  ```
  #%PAM-1.0
  auth       required                    pam_fprintd.so
  account    include                     system-local-login
  ```

## Updating to a new upstream release

1. Look up the new version and tag commit in Arch's PKGBUILD
   (`https://gitlab.archlinux.org/archlinux/packaging/packages/libfprint`).
2. Set `pkgver` and `_commit` in `PKGBUILD`, reset `pkgrel=1`.
3. Check the patch still applies:
   ```sh
   git clone --depth 1 --branch v<ver> https://gitlab.freedesktop.org/libfprint/libfprint.git /tmp/lf
   git -C /tmp/lf apply --check ../0001-elanpress-*.patch
   ```
   (check both patches, in order). If one fails, apply them by hand
   (`git am -3`), fix the conflicts, and export fresh patches with
   `git format-patch -2 --no-signature`. Outside the four new driver files the
   patches only touch three lines: the `0x0c6e` entry in
   `libfprint/drivers/elan.h`, `driver_sources` in `libfprint/meson.build`, and
   `drivers_info` in `meson.build`.
4. Refresh the checksum: `updpkgsums` (from `pacman-contrib`), then
   `makepkg --printsrcinfo > .SRCINFO`.
5. `makepkg -si`.

## Security notes

* The added code (about 1,000 lines) only talks to the sensor over libfprint's
  USB API; it has no file, network or process access. It was reviewed line by
  line before being packaged here. The base commit is byte-identical to the
  upstream tag.
* Matching is image correlation with a fixed threshold (0.60), validated on
  one person's fingers (three fingers, four sessions, 47 presses). That is far
  from a proper biometric evaluation; the false-accept rate against other
  people is unknown. If fingerprint is `sufficient` in PAM, a false accept
  grants access; keep the password as the fallback and treat this as
  convenience-grade authentication.
* Enrolled prints are stored as processed images in `/var/lib/fprint`
  (root-only), which is more revealing than a minutiae template if leaked.

## Upstreaming

Nobody has submitted this driver to libfprint yet. If it works for you, linking
this from upstream issue #814 would help other owners of this sensor.
