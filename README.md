# RemnaNode Install Script

Скрипт автоматической установки [Remnawave Node](https://github.com/remnawave/node) через Docker.

---

## Требования

- ОС: Ubuntu / Debian / CentOS
- Права: `root` или `sudo`
- Docker: устанавливается автоматически при отсутствии

---

## Использование

### Интерактивный режим

```bash
sudo bash install.sh
```

Скрипт запросит `SECRET_KEY` и при необходимости задаст уточняющие вопросы.

### Non-interactive (pipe / CI)

```bash
curl -sSL https://github.com/Plovchikdeval/remnanode/raw/main/install.sh | sudo bash -s -- 'YOUR_SECRET_KEY'
```

#### Флаги

| Флаг | Описание |
|------|----------|
| `--remove-marzban` | Автоматически удалить контейнер `marzban-node` без подтверждения |

```bash
# С удалением marzban-node
curl -sSL https://github.com/Plovchikdeval/remnanode/raw/main/install.sh | sudo bash -s -- 'YOUR_SECRET_KEY' --remove-marzban
```

---

## Что делает скрипт

| Шаг | Действие |
|-----|----------|
| 0 | Проверка и опциональное удаление `marzban-node` |
| 1 | Проверка / установка Docker |
| 2 | Создание директории `/opt/remnanode` |
| 3 | Получение `SECRET_KEY` |
| 4 | Генерация `docker-compose.yml` |
| 5 | Запуск контейнера `remnanode` |

---

## Поведение при обнаружении marzban-node

| Режим | Флаг | Поведение |
|-------|------|-----------|
| Интерактивный | — | Спрашивает `y/N` |
| Non-interactive | — | Оставляет без изменений |
| Non-interactive | `--remove-marzban` | Удаляет автоматически |
| Docker не установлен | — | Пропускает проверку |

---

## Docker Compose

Итоговый `docker-compose.yml` в `/opt/remnanode/`:

```yaml
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:latest
    network_mode: host
    restart: always
    cap_add:
      - NET_ADMIN
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    environment:
      - NODE_PORT=2222
      - SECRET_KEY="..."
```

---

## Управление

```bash
cd /opt/remnanode

# Логи
docker compose logs -f

# Остановка
docker compose down

# Перезапуск
docker compose restart
```

---

## Порт

Нода слушает на порту `2222` (`network_mode: host`).
