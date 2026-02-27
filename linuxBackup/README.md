sudo apt update
sudo apt install timeshift -y

use
timeshift --create (took 150s in testing)

then use
timeshift --restore

by default, doesn't backup some folders (e.g. home directories)