#!/bin/sh
# Этот скрипт устанавливает или удаляет TorrServer на системе OpenWRT.

# Каталог для TorrServer
dir="/opt/torrserver"
binary="${dir}/torrserver"
init_script="/etc/init.d/torrserver"

# Переменная для управления сжатием
compress=false

echo "Проверяем наличие TorrServer..."

# Функция для проверки, запущен ли скрипт в интерактивном режиме
is_interactive() {
    if [ -t 0 ]; then
        return 0  # Интерактивный режим
    else
        return 1  # Неинтерактивный режим
    fi
}

# Функция для установки TorrServer
install_torrserver() {
    # Проверяем, установлен ли TorrServer
    if [ -f "${binary}" ]; then
        echo "TorrServer уже установлен в ${binary}."
        echo "Для удаления скачайте скрипт и используйте: $0 --remove или -r"
        exit 0
    fi

    # Создаем каталог для TorrServer
    mkdir -p ${dir}

    # Определяем архитектуру системы
    echo "Проверяем архитектуру..."
    architecture=""
    case $(uname -m) in
        x86_64) architecture="amd64" ;;
        i*86) architecture="386" ;;
        armv7*) architecture="arm7" ;;
        armv5*) architecture="arm5" ;;
        aarch64) architecture="arm64" ;;
        mips) architecture="mips" ;;
        mips64) architecture="mips64" ;;
        mips64el) architecture="mips64le" ;;
        mipsel) architecture="mipsle" ;;
        *) echo "Архитектура не поддерживается"; exit 1 ;;
    esac

    # Загружаем TorrServer
    url="https://github.com/YouROK/TorrServer/releases/latest/download/TorrServer-linux-${architecture}"
    echo "Загружаем TorrServer для ${architecture}..."
    curl -L -o ${binary} ${url} || { echo "Ошибка загрузки TorrServer"; exit 1; }
    chmod +x ${binary}

    # Управление сжатием
    if [ "$compress" = true ]; then
        # Устанавливаем UPX, если он не установлен
        if ! command -v upx &> /dev/null; then
            echo "Устанавливаем UPX..."
            if opkg update && opkg install upx; then
                echo "UPX успешно установлен."
            else
                echo "Не удалось установить UPX. Продолжаем установку без сжатия."
                compress=false
            fi
        fi

        # Сжимаем бинарный файл TorrServer с использованием UPX
        if [ "$compress" = true ]; then
            echo "Сжимаем бинарный файл TorrServer с использованием UPX..."
            if upx --lzma --best ${binary}; then
                echo "Бинарный файл TorrServer успешно сжат."
            else
                echo "Ошибка сжатия TorrServer. Продолжаем установку без сжатия."
            fi
        fi
    elif [ "$compress" = false ]; then
        echo "Сжатие бинарного файла TorrServer пропущено."
    else
        # Если параметр сжатия не задан, спрашиваем пользователя (только в интерактивном режиме)
        if is_interactive; then
            read -p "Хотите сжать бинарный файл TorrServer с помощью UPX? (y/n): " compress_choice
            if [ "$compress_choice" = "y" ] || [ "$compress_choice" = "Y" ]; then
                # Устанавливаем UPX, если он не установлен
                if ! command -v upx &> /dev/null; then
                    echo "Устанавливаем UPX..."
                    if opkg update && opkg install upx; then
                        echo "UPX успешно установлен."
                    else
                        echo "Не удалось установить UPX. Продолжаем установку без сжатия."
                        compress_choice="n"
                    fi
                fi

                # Сжимаем бинарный файл TorrServer с использованием UPX
                if [ "$compress_choice" = "y" ] || [ "$compress_choice" = "Y" ]; then
                    echo "Сжимаем бинарный файл TorrServer с использованием UPX..."
                    if upx --lzma --best ${binary}; then
                        echo "Бинарный файл TorrServer успешно сжат."
                    else
                        echo "Ошибка сжатия TorrServer. Продолжаем установку без сжатия."
                    fi
                else
                    echo "Сжатие бинарного файла TorrServer пропущено по вашему выбору."
                fi
            else
                echo "Сжатие бинарного файла TorrServer пропущено по вашему выбору."
            fi
        else
            echo "Скрипт запущен в неинтерактивном режиме. Сжатие бинарного файла TorrServer пропущено."
        fi
    fi

    # Создаем скрипт init.d для управления службой
    cat << EOF > ${init_script}
#!/bin/sh /etc/rc.common
# Скрипт запуска Torrent сервера

START=95
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command ${binary} -d ${dir} -p 8090 --logpath /tmp/log/torrserver/torrserver.log
    procd_set_param respawn
    procd_close_instance
}
EOF

    # Делаем скрипт init.d исполняемым и запускаем службу
    chmod +x ${init_script}
    ${init_script} enable
    ${init_script} start

    echo "TorrServer успешно установлен и запущен."
}

# Функция для удаления TorrServer
remove_torrserver() {
    # Останавливаем службу, если она запущена
    if [ -f "${init_script}" ]; then
        ${init_script} stop
        ${init_script} disable
    fi

    # Удаляем файлы TorrServer
    if [ -f "${binary}" ]; then
        rm -f ${binary}
        echo "Удален бинарный файл TorrServer: ${binary}"
    fi

    if [ -d "${dir}" ]; then
        rm -rf ${dir}
        echo "Удален каталог TorrServer: ${dir}"
    fi

    if [ -f "${init_script}" ]; then
        rm -f ${init_script}
        echo "Удален init.d скрипт: ${init_script}"
    fi

    echo "TorrServer успешно удален."
}

# Парсинг аргументов командной строки
while [ "$#" -gt 0 ]; do
    case "$1" in
        --compress)
            compress=true
            shift
            ;;
        --no-compress)
            compress=false
            shift
            ;;
        --remove|-r)
            remove_torrserver
            exit 0
            ;;
        *)
            echo "Использование: $0 [--compress|--no-compress] [--remove|-r]"
            exit 1
            ;;
    esac
done

# Основная логика скрипта
install_torrserver
