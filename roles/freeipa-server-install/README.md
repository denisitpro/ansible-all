###https://denisitpro.wordpress.com/2019/10/09/freeipa-nginx-%d0%be%d1%82%d0%ba%d0%bb%d1%8e%d1%87%d0%b0%d0%b5%d0%bc-%d1%80%d0%b5%d0%b4%d0%b8%d1%80%d0%b5%d0%ba%d1%82/
Чтобы отключить редирект непосредственно на реальный хост freeipa находим в /opt/docker/ipadata/etc/httpd/conf.d/ipa-rewrite.conf и комментируем строку:
RewriteRule ^/ipa/(.*)      http://ipa-01.example.com/ipa/$1 [L,R=301]
После этого перезапускаем сервисы ipa
