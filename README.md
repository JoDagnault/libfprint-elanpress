# libfprint-elanpress

Arch Linux package for the ELAN `04f3:0c6e` fingerprint sensor (ASUS Vivobook,
Zenbook, ROG Flow X13). It is upstream libfprint 1.94.100 with a driver for
this sensor added as patches. It replaces the `libfprint` package; `fprintd`
works unchanged.

## Why

Upstream libfprint treats this sensor as a swipe sensor and fails with
"protocol error". It is a press sensor that only delivers raw images, so the
driver has to do the matching itself.

* `0001`: the `elanpress` driver by Filip Spanne
  ([filip-rs/libfprint](https://github.com/filip-rs/libfprint)), rebased on
  1.94.100.
* `0002`: fixes for the Vivobook M7400QC. The sensor's finger query blocks
  instead of answering "no finger", which hung enrollment, and the matcher
  accepted other fingers. Matching now uses high-pass, contrast-normalised
  images with a 0.60 threshold, and enrollment takes 16 touches.

## Install

```sh
makepkg -si
sudo fprintd-enroll $USER   # 16 touches, move the finger between touches, do not swipe
fprintd-verify
```

On Omarchy, then run `sudo ./setup-pam.sh` to enable fingerprint for sudo,
polkit and the lock screen. Do not use `omarchy-setup-security-fingerprint`;
it reinstalls stock libfprint.

## Notes

* The sensor sees about 7.5 x 2.6 mm. A press only matches where it overlaps
  an enrolled touch, so vary the position during enrollment.
* Matching was validated on one person's fingers only. Keep the password as
  fallback.
* To move to a new libfprint release: set `pkgver` and `_commit` in
  `PKGBUILD`, check the patches still apply, run `updpkgsums`.
