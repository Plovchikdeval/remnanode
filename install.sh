#!/bin/bash

print_header() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║               УСТАНОВКА REMNANODE                    ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
}

print_step() {
    echo ""
    echo "▸ Шаг $1: $2"
    echo "────────────────────────────────────────────────────────"
}

print_success() {
    echo "✓ $1"
}

print_info() {
    echo "• $1"
}

print_error() {
    echo "✗ Ошибка: $1"
}

print_warning() {
    echo "⚠ $1"
}

if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║               ТРЕБУЮТСЯ ПРАВА ROOT                   ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "Пожалуйста, запустите скрипт с помощью команды:"
    echo ""
    echo "    sudo bash $0"
    echo ""
    exit 1
fi

print_header

print_step "0" "Проверка и удаление marzban-node"

if docker ps -a --format '{{.Names}}' | grep -q 'marzban-node'; then
    print_warning "Найден контейнер marzban-node"
    echo "Останавливаю и удаляю marzban-node..."
    
    docker stop marzban-node 2>/dev/null
    docker rm marzban-node 2>/dev/null
    
    docker volume rm $(docker volume ls -q --filter name=marzban) 2>/dev/null || true
    
    print_success "marzban-node удален"
else
    print_success "marzban-node не найден, пропускаю"
fi

print_step "1" "Проверка и установка Docker"

if command -v docker &> /dev/null && docker --version &> /dev/null; then
    print_success "Docker уже установлен"
    echo "Версия Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
else
    echo "Docker не найден. Установка..."
    
    if curl -fsSL https://get.docker.com | sh; then
        print_success "Docker успешно установлен"
        
        systemctl start docker 2>/dev/null
        systemctl enable docker 2>/dev/null
        
        if [ "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
            usermod -aG docker "$SUDO_USER"
            print_info "Пользователь $SUDO_USER добавлен в группу docker"
            print_info "Перелогиньтесь для применения изменений"
        fi
    else
        print_error "Не удалось установить Docker"
        exit 1
    fi
fi

print_step "2" "Создание рабочей директории"

if [ -d "/opt/remnanode" ]; then
    print_warning "Директория /opt/remnanode уже существует"
    read -p "Перезаписать конфигурацию? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Использую существующую директорию"
    else
        rm -rf /opt/remnanode/*
        print_success "Директория очищена"
    fi
fi

if mkdir -p /opt/remnanode; then
    print_success "Директория /opt/remnanode создана/используется"
    cd /opt/remnanode || exit 1
else
    print_error "Не удалось создать директорию"
    exit 1
fi

print_step "3" "Настройка конфигурации"
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              ВВЕДИТЕ ВАШ SECRET_KEY                  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

if [ -t 0 ]; then
    echo "Ваш SECRET_KEY (введите значение и нажмите Enter):"
    read -r SECRET_KEY
    
    while [ -z "$SECRET_KEY" ]; do
        echo ""
        echo "Поле не может быть пустым. Пожалуйста, введите SECRET_KEY:"
        read -r SECRET_KEY
    done
else
    print_warning "Неинтерактивный режим. Для ввода ключа используйте:"
    echo "    curl -sSL <url> | sudo bash -s -- 'YOUR_SECRET_KEY'"
    echo ""
    
    if [ -n "$1" ]; then
        SECRET_KEY="$1"
        print_success "Ключ получен из аргументов"
    else
        TEMP_KEY_FILE="/tmp/remnanode_key_$$"
        trap 'rm -f "$TEMP_KEY_FILE"' EXIT
        
        echo "Введите ваш SECRET_KEY и нажмите Ctrl+D для продолжения:"
        echo "--------------------------------------------------------"
        
        if cat > "$TEMP_KEY_FILE" 2>/dev/null; then
            SECRET_KEY=$(cat "$TEMP_KEY_FILE" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            rm -f "$TEMP_KEY_FILE"
        else
            print_error "Не удалось получить SECRET_KEY"
            echo ""
            echo "Альтернативные способы установки:"
            echo "1. Скачайте скрипт: curl -O <url>"
            echo "2. Запустите: sudo bash install.sh"
            echo "3. Или передайте ключ как аргумент: sudo bash install.sh 'ваш_ключ'"
            exit 1
        fi
    fi
fi

if [ -z "$SECRET_KEY" ]; then
    print_error "SECRET_KEY не может быть пустым!"
    exit 1
fi

print_success "SECRET_KEY получен"

print_step "4" "Создание конфигурационного файла"

cat > /opt/remnanode/docker-compose.yml << EOF
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:latest
    network_mode: host
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    environment:
      - NODE_PORT=2222
      - SECRET_KEY="$SECRET_KEY"
EOF

if [ -f "/opt/remnanode/docker-compose.yml" ]; then
    print_success "Файл docker-compose.yml создан"
    print_info "Расположение: /opt/remnanode/docker-compose.yml"
    
    echo ""
    echo "Содержимое файла (ключ скрыт):"
    echo "────────────────────────────────────────────────────────"
    sed '/SECRET_KEY/d' /opt/remnanode/docker-compose.yml
    echo "      - SECRET_KEY=\"***СЕКРЕТНЫЙ_КЛЮЧ***\""
    echo "────────────────────────────────────────────────────────"
else
    print_error "Не удалось создать конфигурационный файл"
    exit 1
fi

print_step "5" "Запуск Remnanode"
echo "Загрузка и запуск контейнера..."

cd /opt/remnanode || exit 1

if docker ps -a --format '{{.Names}}' | grep -q '^remnanode$'; then
    print_warning "Найден старый контейнер remnanode"
    echo "Останавливаю и удаляю..."
    docker stop remnanode 2>/dev/null
    docker rm remnanode 2>/dev/null
    print_success "Старый контейнер удален"
fi

print_info "Проверка обновлений образа..."
docker pull remnawave/node:latest 2>/dev/null || true

if docker compose up -d; then
    print_success "Контейнер успешно запущен"
    
    sleep 3
    
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║          REMNANODE УСПЕШНО ЗАПУЩЕН!                  ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "Статус контейнера:"
    echo "────────────────────────────────────────────────────────"
    docker ps --filter "name=remnanode" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo "────────────────────────────────────────────────────────"
    
    echo ""
    print_info "Порт ноды: 2222 (network_mode: host)"
    print_info "Для просмотра логов: cd /opt/remnanode && docker compose logs -f"
    print_info "Для остановки: cd /opt/remnanode && docker compose down"
    print_info "Для перезапуска: cd /opt/remnanode && docker compose restart"
    
else
    print_error "Не удалось запустить контейнер"
    echo ""
    print_info "Проверьте логи командой:"
    echo "    cd /opt/remnanode && docker compose logs"
    exit 1
fi

echo ""
echo "────────────────────────────────────────────────────────"
print_success "Установка завершена успешно!"
echo "────────────────────────────────────────────────────────"
