#!/bin/bash
# Description: Восстановление ZAMMAD из резервной копии
# Author:       Alex Zubkov
# Version:      1.0.1

# ПЕРЕМЕННЫЕ

# Очистка переменных перед работой
TEMPDIR=""
TEMPDIRPATH=""
BACKUPNAME=""
SEARCHDIR=""
FOUNDDB=0
FOUNDFILE=0
DUMPDBPATH=""
DUMPFILEPATH=""
ZAMMADPATH=""
ZAMMADDIRNAME=""

#########################################
############### FUNCTIONS ###############
#########################################

# функция: Выводит на экан сообщение цветом
# входные: 1-цвет , 2-строка в кавычках
PrintStyle () {
    if [ "$1" == "b" ] ; then
        COLOR="96m";
    elif [ "$1" == "g" ] ; then
        COLOR="92m";
    elif [ "$1" == "y" ] ; then
        COLOR="93m";
    elif [ "$1" == "r" ] ; then
        COLOR="91m";
    else #default color
        COLOR="0m";
    fi

    STARTCOLOR="\e[${COLOR}";
    ENDCOLOR="\e[0m";

    printf "${STARTCOLOR}%b${ENDCOLOR}" "$2";
}

# функция: Создаёт директорию, если её нет
# входные: 1 Имя_каталога
function CreateDir {
    if [[ $# -eq 1 ]] # проверка на количество параметров
    then 
        if [[ ! -d "$1" ]] # проверка на существование каталога
        then
            PrintStyle y "Создается каталог ${PWD}/$1 \n"
            mkdir $1
        fi
        if [[ "$(ls -A $1)" ]] # проверка на пустой каталог
        then
            PrintStyle r "ВНИМАНИЕ! каталог ${PWD}/$1 не пустой. Очистить содержимое? [y/n]: "
            read CONFIRM
            case ${CONFIRM} in
                y | yes)
                    rm -Rf ${PWD}/$1/*
                    PrintStyle y "Содержимое каталога ${PWD}/$1 очищено \n"
                    ;;
                *)
                    PrintStyle y "Содержимое ${PWD}/$1 оставлено \n"
                    ;;
            esac
        fi

    fi
}

#####################################
############### BEGIN ###############
#####################################
clear
# указываем временный каталог
until [[ -d "${TEMPDIR}" ]]
do
    PrintStyle b "Укажите директорию в текущем каталоге для временного хранения файлов, или оставьте пустым \nдля использования имени по умолчанию [tempzammad]: "
    read TEMPDIR
    if [[ -z "${TEMPDIR}" ]] #если не ввёл ничего
    then
        TEMPDIR="tempzammad"
        PrintStyle y "Используется каталог по умолчанию ${TEMPDIR}\n"
    fi
    CreateDir ${TEMPDIR} #
    TEMPDIRPATH=${PWD}/${TEMPDIR}
    if [[ ! -d "${TEMPDIR}" ]] # если нету
    then
        PrintStyle r "Такой директории не существует. Возможно Вы ввели неправильное имя.\n"
    fi
done

# где ищем резервные копии. если не ввели ничего, то по дефолту /var/lib/docker/volumes
FOUNDDB=0
FOUNDFILE=0
until [[ FOUNDDB -gt 0 && FOUNDFILE -gt 0  ]]
do
    PrintStyle b "Укажите АБСОЛЮТНЫЙ путь, где искать резервные копии или оставьте пустым \nдля использования пути по умолчанию [/var/lib/docker/volumes]: "
    read SEARCHDIR
    if [[ -z "${SEARCHDIR}" ]] # если пустой ввод
    then
        SEARCHDIR="/var/lib/docker/volumes"
        PrintStyle y "Используется место поиска по умолчанию ${SEARCHDIR}\n"
    fi
    if [[ ! -d "${SEARCHDIR}" ]]
    then
        PrintStyle r "Такой директории не существует.\n"
    else # ищем файлы бекапов и копируем их
        FOUNDDB=$(sudo find ${SEARCHDIR} -type f -regextype posix-extended -regex ".*[0-9]{14}_zammad_db\.psql\.gz$" | wc -l)
        FOUNDFILE=$(find ${SEARCHDIR} -type f -regextype posix-extended -regex ".*[0-9]{14}_zammad_files\.tar\.gz$" | wc -l)
        if [[ FOUNDDB -ne 0 && FOUNDFILE -ne 0 ]] 
        then
            find ${SEARCHDIR} -type f -regextype posix-extended -regex ".*[0-9]{14}_zammad_db\.psql\.gz$" -exec cp {} ${TEMPDIRPATH} \;
            find ${SEARCHDIR} -type f -regextype posix-extended -regex ".*[0-9]{14}_zammad_files\.tar\.gz$" -exec cp {} ${TEMPDIRPATH} \;
        else
            PrintStyle r "Резервные копии не найдены. Укажите другое место поиска. \n"
        fi
    fi
done

# показать на экран найденные дамбы БД
# вводим имя, распаковываем и сохраняем полное имя файла РК (с абсолютным путем)
FOUNDFILE=0
until [[ FOUNDFILE -eq 1 ]]
do
    PrintStyle y "Найдены резервные копии БД: \n"
    find ${TEMPDIRPATH} -type f -regextype posix-extended -regex ".*[0-9]{14}_zammad_db\.psql\.gz$" -exec basename {} _zammad_db.psql.gz \;
    PrintStyle b "Введите имя резервной копии БД: "
    read BACKUPNAME
    if [[ ! -f "${TEMPDIRPATH}/${BACKUPNAME}_zammad_db.psql.gz" ]]
    then
        PrintStyle r "Нет такого файла. Возможно Вы ввели неправильное имя.\n"
    else
        FOUNDFILE=1
        gzip -dk ${TEMPDIRPATH}/${BACKUPNAME}_zammad_db.psql.gz
        DUMPDBPATH=$(find ${TEMPDIRPATH} -type f -regextype posix-extended -regex ".*\.psql$")
    fi
done

# показать на экран найденные дампы файлов
# вводим имя, распаковываем и сохраняем полное имя файла РК (с абсолютным путем)
FOUNDFILE=0
until [[ FOUNDFILE -eq 1 ]]
do
    PrintStyle y "Найдены резервные копии файлов: \n"
    find ${TEMPDIRPATH} -type f -regextype posix-extended -regex ".*[0-9]{14}_zammad_files\.tar\.gz$" -exec basename {} _zammad_files.tar.gz \;
    PrintStyle b "Введите имя резервной копии файлов: " 
    read BACKUPNAME
    if [[ ! -f "${TEMPDIRPATH}/${BACKUPNAME}_zammad_files.tar.gz" ]]
    then
        PrintStyle r "Нет такого файла. Возможно Вы ввели неправильное имя.\n"
    else
        FOUNDFILE=1
        tar -xzf ${TEMPDIRPATH}/${BACKUPNAME}_zammad_files.tar.gz -C ${TEMPDIRPATH}
        DUMPFILEPATH=${TEMPDIRPATH}/opt/zammad/
    fi
done


# ищем где заммад-композ
# переходим, останавливаем все контейнеры с удалением томов и директорий
CHOOSE=0
until [[ CHOOSE -eq 1  ]]
do
    PrintStyle y "Укажите имя каталога локального репозитория (проекта) ЗАММАДа или оставьте пустым \nдля использования по умолчанию [zammad-docker-compose]: "
    read ZAMMADDIRNAME
    if [[ -z "${ZAMMADDIRNAME}" ]]
    then
        ZAMMADDIRNAME="zammad-docker-compose"
        PrintStyle y "Используется имя каталога по умолчанию ${ZAMMADDIRNAME}\n"
    fi
    FOUNDCOUNT=$(find / -type d -regextype posix-extended -regex ".*\/${ZAMMADDIRNAME}" | wc -l)
    case ${FOUNDCOUNT} in
        0)
            PrintStyle r "Директории ${ZAMMADDIRNAME} не обнаружено. Возможно Вы ввели неправильное имя.\n"
        ;;
        1)
            ZAMMADPATH=$(find / -type d -regextype posix-extended -regex ".*\/${ZAMMADDIRNAME}")
            FOUNDYML=$(find ${ZAMMADPATH} -type f -regextype posix-extended -regex ".*\.yml" | wc -l)
            if [[ FOUNDYML -ne 0 ]] # если внутри есть YML файлы значит это репа
            then
                CHOOSE=1
            fi
        ;;
        *)
            until [[ CHOOSE -eq 1 ]]
            do
                PrintStyle y "Найдено несколько директорий: \n"
                find / -type d -regextype posix-extended -regex ".*\/${ZAMMADDIRNAME}"
                PrintStyle b "Введите полный путь локального репозитория ЗАММАД: "
                read ZAMMADPATH
                if [[ ! -d ${ZAMMADPATH} ]] # если не существует диры
                then
                    PrintStyle r "Некорректный ввод \n"
                else
                    FOUNDYML=$(find ${ZAMMADPATH} -type f -regextype posix-extended -regex ".*\.yml" | wc -l)
                    if [[ FOUNDYML -ne 0 ]] # если внутри есть YML файлы значит это репа
                    then
                        CHOOSE=1
                    else
                        PrintStyle r "В каталоге ${ZAMMADPATH} нет YML файлов. Вероятно это не репозиторий \n"
                    fi
                fi
            done
        ;;
    esac
done

### посленее китайское предупреждение
PrintStyle y "ВНИМАНИЕ!!! Будет удален локальный репозиторий ЗАММАДа. Вы уверены? [y/n]: "
read CONFIRM
case ${CONFIRM} in
    y | yes)
        PrintStyle y "\n"
    ;;
    *)
        PrintStyle b "Восстановление отменено. \n"
        sleep 5
        exit
    ;;
esac


# стопим контейнеры, удаляем тома
PrintStyle y "Остановка контейнеров и удаление томов \n"
cd ${ZAMMADPATH}
cp ${ZAMMADPATH}/{.env,docker-compose.override.yml} ${TEMPDIRPATH}/
docker-compose down -v
sleep 5
cd ..
rm -Rf zammad-docker-compose
sleep 5


##### подготовка системы
# клонируем репо, добавляем доп параметры, стартуем, ждём, стопим
PrintStyle y "Инициализация системы \n"
PrintStyle y "Клонирование репозитория проекта \n"
git clone https://github.com/zammad/zammad-docker-compose.git ${ZAMMADPATH}
cd ${ZAMMADPATH}
echo -e '\n  zammad-backup:\n    volumes:\n      - zammad-data:/opt/zammad\n      - zammad-backup:/var/tmp/zammad:ro\n      - postgresql-data:/var/lib/postgresql/data\n' >> docker-compose.override.yml

# восстановить конфиг YML ?
PrintStyle y "Восстановить предыдущие файлы .env и docker-compose.override.yml ? [y/n]: "
read CONFIRM
case ${CONFIRM} in
    y | yes)
        PrintStyle y "Восстановливаю предыдущие файлы .env и docker-compose.override.yml \n"
        cp ${TEMPDIRPATH}/{.env,docker-compose.override.yml} ${ZAMMADPATH}/
        PrintStyle y "\n"
    ;;
    *)
        PrintStyle y "Файлы .env и docker-compose.override.yml не будут восстановлены \n"
        sleep 5
    ;;
esac
PrintStyle y "Запуск контейнеров \n"
docker-compose up -d
sleep 30
PrintStyle y "Остановка контейнеров \n"
docker-compose down
sleep 5


##### восстановление дампа БД
# копируем дамп
PrintStyle y "Восстановление БД из дампа \n"
mv ${DUMPDBPATH} /var/lib/docker/volumes/zammad-docker-compose_postgresql-data/_data/backup_db.psql
cd ${ZAMMADPATH}
docker-compose up -d zammad-postgresql
# ДОБАВИТЬ проверку на поднятый контейнер
docker-compose exec -u root zammad-postgresql bash -c "dropdb zammad_production -U zammad"
docker-compose exec -u root zammad-postgresql bash -c "createdb zammad_production -U zammad"
docker-compose exec -u root zammad-postgresql bash -c "psql zammad_production < /var/lib/postgresql/data/backup_db.psql -U zammad"
docker-compose down
# удаляем хвосты
rm -f /var/lib/docker/volumes/zammad-docker-compose_zammad-postgresql-data/_data/backup_db.psql
PrintStyle g "Восстановление БД из дампа завершено \n"
sleep 5


##### восстановление дампа файлов
# копируем файлы
PrintStyle y "Восстанавливаем файлы системы из дампа \n"
sudo rm -Rf /var/lib/docker/volumes/zammad-docker-compose_zammad-data/_data/*
cp -R ${DUMPFILEPATH}/* /var/lib/docker/volumes/zammad-docker-compose_zammad-data/_data/
rm -Rf ${TEMPDIRPATH}/opt
PrintStyle y "Смена владельца файлов \n"
docker-compose up -d zammad-railsserver
# ДОБАВИТЬ проверку на поднятый контейнер
sleep 15
docker-compose exec -u root zammad-railsserver bash -c "chown -R zammad:zammad /opt/zammad"
PrintStyle g "Восстаноление файлов системы завершено \n"


##### поднимаем всё и фиксим индексы
PrintStyle y "Запуcк контейнеров \n"
cd ${ZAMMADPATH}
docker-compose up -d
PrintStyle y "Исправление индексов. Ждите... "
sleep 120 # ждём пока прогрузится контейнер. по хорошему, стоит проверять поднятие сервиса внутри контейнера в цикле (#фича)
docker-compose exec -u root zammad-scheduler bundle exec rake searchindex:rebuild
PrintStyle g "Восстановление системы из резервной копии завершено \n"
