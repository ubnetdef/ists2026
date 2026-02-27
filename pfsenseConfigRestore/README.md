put it in /root/lockconfig.sh

@reboot nohup /root/lockconfig.sh > /var/log/lockconfig.log 2>&1 &