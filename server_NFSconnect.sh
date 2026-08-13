#!/usr/bin/env bash
# NFS Manager для ArchLinux
# Работает в bash и zsh

# Конфигурация
SERVER_IP="192.168.1.30"
MOUNT_BASE="/mnt/SHARE"
LOG_FILE="/var/log/nfs_manager.log"

# Функция логирования
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$LOG_FILE"
}

# Функция проверки и настройки NFS-клиента
setup_nfs_client() {
    echo "Настройка NFS-клиента..."
    
    # Проверка наличия пакетов
    if ! command -v showmount &> /dev/null; then
        echo "Установка nfs-utils..."
        sudo pacman -S --noconfirm nfs-utils rpcbind
    fi
    
    # В ArchLinux для NFS-клиента используются следующие службы
    echo "Настройка системных служб..."
    
    # Включаем и запускаем rpcbind (уже есть)
    if ! systemctl is-enabled rpcbind &>/dev/null; then
        sudo systemctl enable rpcbind
    fi
    if ! systemctl is-active rpcbind &>/dev/null; then
        sudo systemctl start rpcbind
    fi
    
    # Включаем и запускаем необходимые службы для NFS
    # В ArchLinux это делается через nfs-client.target
    sudo systemctl enable nfs-client.target
    sudo systemctl start nfs-client.target
    
    # Также может потребоваться rpc-statd для NFSv3
    if systemctl list-unit-files | grep -q rpc-statd.service; then
        sudo systemctl enable rpc-statd
        sudo systemctl start rpc-statd
    fi
    
    # Запускаем rpc-idmapd для NFSv4
    if systemctl list-unit-files | grep -q rpc-idmapd.service; then
        sudo systemctl enable rpc-idmapd
        sudo systemctl start rpc-idmapd
    fi
    
    # Проверяем состояние
    echo "Состояние служб:"
    systemctl status rpcbind --no-pager | head -3
    systemctl status nfs-client.target --no-pager | head -3
    
    echo "NFS-клиент настроен"
    log_message "NFS-клиент настроен"
}

# Функция проверки доступности сервера
check_network() {
    echo "Проверка сети..."
    if ping -c 3 -W 2 "$SERVER_IP" > /dev/null 2>&1; then
        echo "✓ Сервер $SERVER_IP доступен"
        log_message "Сервер $SERVER_IP доступен"
        return 0
    else
        echo "✗ Сервер $SERVER_IP недоступен"
        log_message "Сервер $SERVER_IP недоступен"
        return 1
    fi
}

# Функция получения списка NFS-шаров
get_nfs_shares() {
    echo "Получение списка NFS-шаров..."
    
    if ! command -v showmount &> /dev/null; then
        echo "Ошибка: showmount не найден"
        return 1
    fi
    
    # Проверяем, работает ли rpcbind
    if ! rpcinfo -p localhost &>/dev/null; then
        echo "rpcbind не работает. Перезапуск..."
        sudo systemctl restart rpcbind
        sleep 2
    fi
    
    # Пробуем получить список шаров
    if showmount -e "$SERVER_IP" 2>/dev/null | grep -v "Export list" | grep -v "^$" > /tmp/nfs_shares.tmp; then
        echo "Найдены следующие шары:"
        cat /tmp/nfs_shares.tmp
        log_message "Получен список NFS-шаров"
        return 0
    else
        echo "Шары не найдены или сервер недоступен"
        echo "Проверьте:"
        echo "1. Доступность сервера $SERVER_IP"
        echo "2. Запущен ли NFS-сервер на DEBIAN"
        echo "3. Разрешены ли подключения в firewall"
        log_message "Ошибка получения списка NFS-шаров"
        return 1
    fi
}

# Функция создания базовой директории
create_base_dir() {
    if [ ! -d "$MOUNT_BASE" ]; then
        echo "Создание базовой директории $MOUNT_BASE..."
        sudo mkdir -p "$MOUNT_BASE"
        # Устанавливаем права на чтение/запись
        sudo chmod 755 "$MOUNT_BASE"
        log_message "Создана базовая директория $MOUNT_BASE"
    else
        echo "Базовая директория $MOUNT_BASE уже существует"
    fi
}

# Функция монтирования всех NFS-шаров
mount_all_shares() {
    echo "Монтирование NFS-шаров..."
    
    # Проверяем наличие списка шаров
    if [ ! -f /tmp/nfs_shares.tmp ] || [ ! -s /tmp/nfs_shares.tmp ]; then
        echo "Сначала получите список шаров (опция 1)"
        return 1
    fi
    
    # Создаем базовую директорию
    create_base_dir
    
    local mount_count=0
    while IFS= read -r line; do
        # Извлекаем имя шара
        share=$(echo "$line" | awk '{print $1}')
        
        if [ -n "$share" ]; then
            # Создаем имя поддиректории из пути шара
            subdir_name=$(echo "$share" | sed 's/^\///' | sed 's/\//_/g')
            if [ -z "$subdir_name" ]; then
                subdir_name="root"
            fi
            
            local mount_point="$MOUNT_BASE/$subdir_name"
            
            # Создаем директорию для монтирования
            if [ ! -d "$mount_point" ]; then
                sudo mkdir -p "$mount_point"
                echo "Создана директория: $mount_point"
            fi
            
            # Проверяем, не примонтирован ли уже
            if mount | grep -q "$mount_point"; then
                echo "Шар $share уже примонтирован в $mount_point"
            else
                echo "Монтирование $share в $mount_point..."
                # Параметры монтирования для лучшей совместимости
                if sudo mount -t nfs -o rw,hard,intr,timeo=600,vers=3 "$SERVER_IP:$share" "$mount_point"; then
                    echo "✓ Шар $share успешно примонтирован"
                    log_message "Примонтирован шар $share в $mount_point"
                    ((mount_count++))
                else
                    echo "✗ Ошибка монтирования шара $share"
                    log_message "Ошибка монтирования шара $share"
                fi
            fi
        fi
    done < /tmp/nfs_shares.tmp
    
    echo "Примонтировано $mount_count шаров"
}

# Функция отмонтирования всех NFS-шаров
unmount_all_shares() {
    echo "Отмонтирование NFS-шаров..."
    
    if [ ! -d "$MOUNT_BASE" ]; then
        echo "Базовая директория $MOUNT_BASE не существует"
        return 0
    fi
    
    local unmount_count=0
    for mount_point in $(find "$MOUNT_BASE" -maxdepth 1 -type d -mindepth 1 2>/dev/null); do
        if mount | grep -q "$mount_point"; then
            echo "Отмонтирование $mount_point..."
            if sudo umount "$mount_point" 2>/dev/null; then
                echo "✓ $mount_point отмонтирован"
                log_message "Отмонтирован $mount_point"
                ((unmount_count++))
            else
                echo "✗ Ошибка отмонтирования $mount_point"
                # Попытка принудительного отмонтирования
                echo "Попытка принудительного отмонтирования..."
                if sudo umount -l "$mount_point" 2>/dev/null; then
                    echo "✓ $mount_point принудительно отмонтирован"
                    log_message "Принудительно отмонтирован $mount_point"
                    ((unmount_count++))
                fi
            fi
        fi
    done
    
    echo "Отмонтировано $unmount_count шаров"
}

# Функция очистки
cleanup_directories() {
    echo "Очистка пустых директорий..."
    
    if [ -d "$MOUNT_BASE" ]; then
        for dir in "$MOUNT_BASE"/*; do
            if [ -d "$dir" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
                echo "Удаление пустой директории: $dir"
                sudo rmdir "$dir" 2>/dev/null
            fi
        done
        
        if [ -z "$(ls -A "$MOUNT_BASE" 2>/dev/null)" ]; then
            echo "Удаление пустой базовой директории: $MOUNT_BASE"
            sudo rmdir "$MOUNT_BASE" 2>/dev/null
        fi
    fi
}

# Функция показа статуса
show_status() {
    echo "=== СТАТУС NFS ==="
    echo "Сервер: $SERVER_IP"
    echo "База: $MOUNT_BASE"
    echo ""
    echo "Службы:"
    systemctl status rpcbind --no-pager | grep -E "Active:|Loaded:" | sed 's/^/  /'
    systemctl status nfs-client.target --no-pager | grep -E "Active:|Loaded:" | sed 's/^/  /'
    echo ""
    echo "Активные NFS-монтирования:"
    mount | grep -E "^$SERVER_IP:|nfs" | grep -v "grep" || echo "  Нет активных NFS-монтирований"
    echo ""
    echo "Директории в $MOUNT_BASE:"
    if [ -d "$MOUNT_BASE" ]; then
        ls -la "$MOUNT_BASE" 2>/dev/null | tail -n +2 || echo "  Директория пуста"
    else
        echo "  Базовая директория не существует"
    fi
}

# Функция диагностики
diagnostics() {
    echo "=== ДИАГНОСТИКА NFS ==="
    echo "1. Проверка пакетов:"
    pacman -Q nfs-utils rpcbind
    echo ""
    echo "2. Проверка служб:"
    systemctl list-units --type=service | grep -E "rpc|nfs|statd|idmapd"
    echo ""
    echo "3. Проверка rpcbind:"
    rpcinfo -p localhost 2>/dev/null | head -5
    echo ""
    echo "4. Проверка сетевых портов:"
    ss -tulpn | grep -E "111|2049"
    echo ""
    echo "5. Проверка NFS-сервера:"
    showmount -e "$SERVER_IP" 2>&1
    echo ""
    echo "6. Проверка ядра:"
    lsmod | grep nfs
    echo ""
    echo "7. Проверка прав:"
    ls -la /mnt/
    echo ""
    echo "Диагностика завершена"
}

# Функция выхода
clean_exit() {
    echo "Завершение работы..."
    rm -f /tmp/nfs_shares.tmp
    echo "Работа завершена"
    exit 0
}

# Меню
main_menu() {
    clear
    echo "========================================="
    echo "     УПРАВЛЕНИЕ NFS-ШАРАМИ (ArchLinux)"
    echo "========================================="
    echo "Сервер: $SERVER_IP"
    echo "База: $MOUNT_BASE"
    echo "-----------------------------------------"
    echo "1. Настроить NFS-клиент"
    echo "2. Проверить сеть и NFS-шары"
    echo "3. Смонтировать все шары"
    echo "4. Отмонтировать все шары"
    echo "5. Показать статус"
    echo "6. Очистка (отмонтировать + удалить пустые)"
    echo "7. Диагностика"
    echo "0. Выход"
    echo "========================================="
    echo -n "Выберите действие: "
}

# Основной цикл
main() {
    # Обработка сигналов
    trap clean_exit INT TERM
    
    while true; do
        main_menu
        read choice
        
        case "$choice" in
            1)
                echo "=== НАСТРОЙКА NFS-КЛИЕНТА ==="
                setup_nfs_client
                echo ""
                echo "Нажмите Enter для продолжения..."
                read
                ;;
            2)
                echo "=== ПРОВЕРКА СЕТИ И NFS-ШАРОВ ==="
                if check_network; then
                    get_nfs_shares
                fi
                echo ""
                echo "Нажмите Enter для продолжения..."
                read
                ;;
            3)
                echo "=== МОНТИРОВАНИЕ ==="
                mount_all_shares
                echo ""
                echo "Нажмите Enter для продолжения..."
                read
                ;;
            4)
                echo "=== ОТМОНТИРОВАНИЕ ==="
                unmount_all_shares
                echo ""
                echo "Нажмите Enter для продолжения..."
                read
                ;;
            5)
                echo "=== СТАТУС ==="
                show_status
                echo ""
                echo "Нажмите Enter для продолжения..."
                read
                ;;
            6)
                echo "=== ПОЛНАЯ ОЧИСТКА ==="
                unmount_all_shares
                cleanup_directories
                echo "Очистка завершена"
                echo ""
                echo "Нажмите Enter для продолжения..."
                read
                ;;
            7)
                echo "=== ДИАГНОСТИКА ==="
                diagnostics
                echo ""
                echo "Нажмите Enter для продолжения..."
                read
                ;;
            0)
                clean_exit
                ;;
            *)
                echo "Неверный выбор. Попробуйте снова."
                echo "Нажмите Enter для продолжения..."
                read
                ;;
        esac
    done
}

# Запуск
main