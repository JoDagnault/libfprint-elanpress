# Maintainer: Jo Dagnault <jdagnault@gmail.com>
# Based on the Arch Linux libfprint PKGBUILD by Jan Alexander Steffens (heftig)
#
# Stock libfprint plus the "elanpress" driver for the ELAN 04f3:0c6e
# press-type fingerprint sensor (ASUS Vivobook / Zenbook / ROG Flow X13).
# Upstream libfprint drives that sensor with the image-based "elan" swipe
# driver, which fails with a protocol error and cannot match presses.
# See README.md for background and the update procedure.

pkgname=libfprint-elanpress
_pkgname=libfprint
pkgver=1.94.100
pkgrel=2
pkgdesc="Library for fingerprint readers, with the elanpress driver for the ELAN 04f3:0c6e press sensor"
url="https://fprint.freedesktop.org/"
arch=(x86_64)
license=(LGPL-2.1-or-later)
depends=(
  libgcc
  glib2
  glibc
  libgudev
  libgusb
  openssl
  pixman
)
makedepends=(
  git
  glib2-devel
  gobject-introspection
  meson
  systemd
)
# Drop-in replacement for the Arch package: fprintd depends on libfprint.
provides=("libfprint=$pkgver" libfprint-2.so)
conflicts=(libfprint libfprint-elanpress-git)
groups=(fprint)

# Upstream tag v1.94.100, pinned by commit hash so the source cannot change
# underneath us. To update: set pkgver, put the new tag's commit here, and
# check that the patch still applies (see README.md).
_commit=80a4b5ec612892c5c056c48dddaa561452cf37ec
source=(
  "git+https://gitlab.freedesktop.org/libfprint/libfprint.git#commit=$_commit"
  0001-elanpress-Add-driver-for-ELAN-press-type-sensors-04f.patch
  0002-elanpress-Handle-blocking-finger-queries-and-sharpen.patch
)
b2sums=('SKIP'
        '1370c148ded9b5d46fecda65067ef00c378558653f697b5495f7fe679ff9791b1d09453e5d27feb39b156492446d9389572574e9544e86d1c6211380f40f6aac'
        'b6f3f29fe5e49926f2e707a9348d46c9c4fbf74b39450cf45b9622d8678d309e6f7521d9240ab33e67e4ac21f1bcf2f88e75832aae39b8146339882dc753f665')

prepare() {
  cd $_pkgname
  # makepkg reuses the working copy and only resets tracked files, so drop
  # the files a previous run's patch added before applying it again.
  git clean -fdxq
  local p
  for p in "$srcdir"/0*.patch; do
    git apply -v "$p"
  done
}

build() {
  local meson_options=(
    # Same as Arch: include the virtual drivers used by fprintd's tests
    -D drivers=all
    -D doc=false
    -D installed-tests=false
  )

  arch-meson $_pkgname build "${meson_options[@]}"
  meson compile -C build
}

package() {
  meson install -C build --destdir "$pkgdir"
}

# vim:set sw=2 sts=-1 et:
