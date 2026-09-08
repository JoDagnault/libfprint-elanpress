#!/bin/bash
# Configure PAM for fingerprint auth the way omarchy-setup-security-fingerprint
# does (sudo, polkit, lock screen), without that script's package step that
# would try to reinstall stock libfprint. Run with sudo after a successful
# `fprintd-enroll` and `fprintd-verify`.
set -e
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }

gate='auth      [success=1 default=ignore] pam_exec.so quiet /usr/bin/omarchy-hw-laptop-closed'

for f in /etc/pam.d/sudo /etc/pam.d/polkit-1; do
  if [[ ! -f $f ]]; then
    printf '%s\nauth      sufficient pam_fprintd.so\nauth      required pam_unix.so\n\naccount   required pam_unix.so\npassword  required pam_unix.so\nsession   required pam_unix.so\n' "$gate" > "$f"
    echo "created $f"
    continue
  fi
  grep -q pam_fprintd.so "$f" || { sed -i '1i auth      sufficient pam_fprintd.so' "$f"; echo "added pam_fprintd to $f"; }
  grep -q omarchy-hw-laptop-closed "$f" || { sed -i "/pam_fprintd\.so/i $gate" "$f"; echo "added clamshell gate to $f"; }
done

cat > /etc/pam.d/omarchy-lock-fingerprint <<'PAM'
#%PAM-1.0
auth       required                    pam_fprintd.so
account    include                     system-local-login
PAM
echo "wrote /etc/pam.d/omarchy-lock-fingerprint"

# drop the fprintd debug logging enabled during driver development, if present
if [[ -f /etc/systemd/system/fprintd.service.d/debug.conf ]]; then
  rm -f /etc/systemd/system/fprintd.service.d/debug.conf
  rmdir /etc/systemd/system/fprintd.service.d 2>/dev/null || true
  systemctl daemon-reload
  echo "removed fprintd debug logging"
fi
echo "done: fingerprint is now accepted for sudo, polkit and the lock screen (Super+Ctrl+L)"
