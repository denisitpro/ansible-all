# Role auto create consul policy and token

# Russian version

## Описание

* Роль принимает на вход массив имен политик, которые необходимо создать.
* Файл с именем политики должен лежать в папке "files" роли, имя файла должно соответствовать имени политики.
* Рекомендуется использовать имена файлов, состоящие не более чем из 1-2 слов. Имена файлов/политик зависят от регистра.
* Имя токена всегда должно начинаться с префикса "consul" в нижнем регистре, с суффиксом "token" через символ подчеркивания. Например, для политики "test1" будет создан токен consul_test1_token.

**Требования к месту запуска и ограничения:**

* Из-за использования телепорта, консул используется на удаленном хосте. Также предполагается, что консул установлен как юнит, а не как докер-контейнер.
* Для запуска роли необходимо подключить роль "vault-get-users-secrets-teleport" на месте, откуда будет происходить запуск.
* Для входа в Vault необходимо использовать тот же терминал, где происходит запуск.
* Для работы роли Vault требуется установленная библиотека jq (brew install jq).

# English version

## Description:

* The role takes an input array of politician names to create.
* The politician file should be located in the "files" folder of the role, and the file name should match the politician name.
* It is recommended to use file names consisting of no more than 1-2 words. File/politician names are case-sensitive.
* The token name will always start with the prefix "consul" in lowercase, followed by an underscore and the suffix "token". For example, a token named consul_test1_token will be created for the policy "test1".

**Requirements for the execution environment:**

* Due to teleportation, Consul is used on a remote host. It is assumed that Consul is installed as a unit, not as a Docker container.
* The role "vault-get-users-secrets-teleport" must be connected from the location where the execution takes place.
* Therefore, to log in to Vault, depending on your terminal, you need to use the same tab where the execution is taking place.
* The jq library is required for the role to work (install with "brew install jq").