# Role auto create consul policy and token

# Описание
* Роль принимает на вход массив имен политик, которые необходимо создать.
* Файл с именем политики, должен лежать в папке files роле, имя файла должно быть равно имени политики
* Имя файлов рекомендуется делать не более 1-2 слов, имя файлов/политики - регистро зависимое
* Имя токена всегда будет начинаться с префикса consul, в нижем регистре, через нижнее подчеркивание с суффиксом token. Например для политики test1, создасться  токен **consul_test1_token**

# Требования к месту запуску и ограничения
* поддержка работы через teleport, путем делегации выполнения задачи на localhost запуска задачи. **Требует** предварительного логина в приложения в teleport
* на месте откуда происходит запуск должна быть подключена роль vault-get-users-secrets-teleport
* Соотвественно - залогинится волтом в зависимосте от вашего терминала, нужно в том же табе где происходит запуск
* Для работы роли волта нужна установленная библиотека jq (bew install jq)

# config example support teleport
```commandline
tsh app login consul-example
export CONSUL_CLIENT_CERT="$(tsh app config --format=cert consul-example)"
export CONSUL_CLIENT_KEY="$(tsh app config --format=key consul-example)"
export CONSUL_HTTP_ADDR=https://consul.tp.example.com
export CONSUL_HTTP_TOKEN=token
```

# Deprecate
* ~~Из-за телепорт, используется консул на удаленом хосте. Так же подразумевается, что консул установлен юнитом, а не докером~~