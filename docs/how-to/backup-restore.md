# Back up and restore progress

Hatch's data — every profile, its answer history, and its engine state —
lives only on your device. The backup is a single encrypted `.ohbk` file
that you keep wherever you keep files.

## Back up

1. Open **Settings** (from the profile picker or home).
2. In the **Backup** section, choose **Export backup**.
3. Pick where to save the `.ohbk` file (your files app, a USB drive, a
   family NAS — anywhere the system file picker can reach).

The file is encrypted with the fleet's shared backup format (ChaCha20-
Poly1305 under an app-scoped key; a Hatch backup cannot be restored into a
different OpenHearth app, and vice versa). One file carries **all** profiles
on the device.

## Restore

1. On the new device (or fresh install), open **Settings** — reachable
   before any profile exists, precisely for this moment.
2. **Restore backup**, pick your `.ohbk` file.
3. Read the confirmation carefully: restore **replaces** everything currently
   in the app with the backup's contents. It says so before it does it.
4. The app returns to the profile picker; every hatched critter, every
   scheduled review, and the calendar spacing history arrive intact —
   reviews that came due while the backup sat in a drawer are simply waiting,
   never penalized.

## Moving between devices

Export on the old device, move the file however you like (the app itself
never touches a network), restore on the new one. That's the whole story.
