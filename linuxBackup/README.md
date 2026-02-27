sudo apt update
sudo apt install timeshift -y

use
timeshift --create (took 150s in testing)

then use
timeshift --restore

by default, doesn't backup some folders (e.g. home directories)




Notes from claude

By default, Timeshift (in RSYNC mode) backs up:

All system files and directories — essentially everything under / including /etc, /usr, /bin, /lib, etc.

It excludes these by default:

/home/** — your personal files (home directories are excluded, though the /home folder itself is included)
/root/** — root user's home files
/media, /mnt — external/mounted drives
/tmp, /var/tmp — temporary files
/proc, /sys, /dev, /run — virtual/system runtime directories
Lost+found directories