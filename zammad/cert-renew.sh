#!/bin/bash
# Description:  Принудительное обновление сертификата Letsencrypt
# Author:       Alex Zubkov
# Version:      0.1

######################
##### ПЕРЕМЕННЫЕ #####
######################

# домашняя директория (куда хранить временные файлы)
HOMEDIR=/home/ubuntu
# какой сервер проверяем
CHECKSERVER="zammad.domain.ru"

# тема письма в кавычках, тело письма в кавычках
# получатели в кавычках через пробел
MAILSUBJECT="Обновление сертификата ZAMMAD"
MAILBODYTOP="Информация о сертификате для ${CHECKSERVER}:\n"
RECIPIENTS="user1@domain.ru user2@domain.ru"

#################
##### BEGIN #####
#################

# принудительно обновить сертификат
sudo certbot renew --quiet --force-renewal

# перегрузить nginx, чтоб перечитал новый сертификат
sudo systemctl reload nginx

# Формируем тело письма, считываем данные из сертификата и отправляем письмо
echo -e ${MAILBODYTOP} > ${HOMEDIR}/message_body.txt
echo | openssl s_client -servername ${CHECKSERVER} -connect ${CHECKSERVER}:443 2>/dev/null | openssl x509 -noout -subject -serial -dates -issuer >> ${HOMEDIR}/message_body.txt
mpack -s "${MAILSUBJECT}" ${HOMEDIR}/message_body.txt ${RECIPIENTS}

# чистим за собой
rm ${HOMEDIR}/message_body.txt