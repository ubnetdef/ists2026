pull it down, e.g.
curl https://raw.githubusercontent.com/ubnetdef/ists2026/refs/heads/main/pfsenseConfigRestore/pfsenseConfigRestore.sh -o lockconfig.sh

put it in /root/lockconfig.sh

@reboot nohup /root/lockconfig.sh > /var/log/lockconfig.log 2>&1 &



Note: doesn't recreate the backup if already exists