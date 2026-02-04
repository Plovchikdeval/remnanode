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

print_step "1" "Установка Docker"
echo "Это займет несколько минут..."

if curl -fsSL https://get.docker.com | sh; then
    print_success "Docker успешно установлен"
else
    print_error "Не удалось установить Docker"
    exit 1
fi

print_step "2" "Создание рабочей директории"

if mkdir -p /opt/remnanode; then
    print_success "Директория /opt/remnanode создана"
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
echo "Ваш SECRET_KEY (введите значение и нажмите Enter):"

read -r SECRET_KEY

while [ -z "$SECRET_KEY" ]; do
    echo ""
    echo "Поле не может быть пустым. Пожалуйста, введите SECRET_KEY:"
    read -r SECRET_KEY
done

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
    echo "Содержимое файла:"
    echo "────────────────────────────────────────────────────────"
    cat /opt/remnanode/docker-compose.yml
    echo "────────────────────────────────────────────────────────"
else
    print_error "Не удалось создать конфигурационный файл"
    exit 1
fi

print_step "5" "Запуск Remnanode"
echo "Загрузка и запуск контейнера..."

cd /opt/remnanode || exit 1

if docker compose up -d; then
    print_success "Контейнер успешно запущен"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║          REMNANODE УСПЕШНО ЗАПУЩЕН!                  ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "Статус контейнера:"
    echo "────────────────────────────────────────────────────────"
    docker ps --filter "name=remnanode"
    echo "────────────────────────────────────────────────────────"
    
    echo ""
    print_info "Для просмотра логов выполните:"
    echo "    cd /opt/remnanode && docker compose logs -f"
    echo ""
    print_info "Для остановки контейнера:"
    echo "    cd /opt/remnanode && docker compose down"
    
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
