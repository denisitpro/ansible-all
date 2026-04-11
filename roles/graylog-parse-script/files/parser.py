#!/usr/bin/env python3
"""
Выгрузка production.nginx логов из OpenSearch в CSV (со сжатием)
Парсит JSON из поля message
Использование:
  ./dump_graylog_prod_nginx.py <начало> <конец> [опции]

Примеры:
  ./dump_graylog_prod_nginx.py "2026-01-20 00:00:00" "2026-01-25 00:00:00"
  ./dump_graylog_prod_nginx.py "2026-01-20 00:00:00" "2026-01-25 00:00:00" --tags "weu1,weu2"
  ./dump_graylog_prod_nginx.py "2026-01-20 00:00:00" "2026-01-25 00:00:00" --index "logs_*" --output-dir /tmp/logs --tag-field "source"
"""

import sys
import gzip
import csv
import json
import os
import argparse
import time
from datetime import datetime, timedelta
from opensearchpy import OpenSearch
from opensearchpy.helpers import scan
from opensearchpy.exceptions import ConnectionTimeout, TransportError

# Конфигурация по умолчанию
ES_URL = "127.0.0.1"
ES_PORT = 9200
BATCH_SIZE = 5000
SCROLL_TIME = "10m"
REQUEST_TIMEOUT = 60  # Таймаут для запросов в секундах
MAX_RETRIES = 15  # Максимальное количество попыток
RETRY_DELAY = 5  # Задержка между попытками в секундах

# Поля для CSV
CSV_FIELDS = ['timestamp', 'IP', 'ua', 'host', 'request', 'verb', 'response']


def format_timestamp(ts):
    """Добавляет .000 если нет миллисекунд"""
    if '.' not in ts:
        return f"{ts}.000"
    return ts


def parse_datetime(ts_str):
    """Парсит дату-время в datetime объект"""
    ts_str = ts_str.strip()
    # Убираем миллисекунды для парсинга
    if '.' in ts_str:
        ts_str = ts_str.split('.')[0]
    return datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S")


def make_filename(tags, start_dt, end_dt, output_dir):
    """Формирует имя файла для периода"""
    if len(tags) > 3:
        tags_safe = '_'.join([t.replace('*', '') for t in tags[:2]]) + f'_and_{len(tags)-2}_more'
    else:
        tags_safe = '_'.join([t.replace('*', '') for t in tags])

    start_label = start_dt.strftime("%Y-%m-%d_%H%M")
    end_label = end_dt.strftime("%Y-%m-%d_%H%M")

    filename = f"prod_nginx_{tags_safe}_{start_label}_to_{end_label}.csv.gz"
    return os.path.join(output_dir, filename)


def build_source_query(tags, tag_field):
    """Строит запрос для source с поддержкой wildcard паттернов"""
    exact_tags = [t for t in tags if '*' not in t]
    wildcard_tags = [t for t in tags if '*' in t]

    clauses = []

    if exact_tags:
        if len(exact_tags) == 1:
            clauses.append({"term": {tag_field: exact_tags[0]}})
        else:
            clauses.append({"terms": {tag_field: exact_tags}})

    for tag in wildcard_tags:
        clauses.append({"wildcard": {tag_field: tag}})

    if len(clauses) == 1:
        return clauses[0]

    return {"bool": {"should": clauses, "minimum_should_match": 1}}


def extract_row_from_source(source):
    """
    Извлекает данные для CSV из source документа
    Парсит JSON из поля message если он есть
    """
    row = {
        'timestamp': '',
        'IP': '',
        'ua': '',
        'host': '',
        'request': '',
        'verb': '',
        'response': ''
    }

    # Проверяем есть ли поле message с JSON
    if 'message' in source:
        try:
            # Парсим JSON из message
            message_data = json.loads(source['message'])

            # Извлекаем данные из JSON внутри message
            row['timestamp'] = source.get('timestamp', '')
            row['IP'] = message_data.get('remote_addr', '')
            row['ua'] = message_data.get('http_user_agent', '')
            row['host'] = message_data.get('host', '')
            row['request'] = message_data.get('request_uri', '')
            row['verb'] = message_data.get('request_method', '')
            row['response'] = message_data.get('status', '')

        except (json.JSONDecodeError, TypeError):
            # Если не удалось распарсить JSON, берём из прямых полей
            row['timestamp'] = source.get('timestamp', '')
            row['IP'] = source.get('IP', source.get('remote_addr', ''))
            row['ua'] = source.get('ua', source.get('http_user_agent', ''))
            row['host'] = source.get('host', '')
            row['request'] = source.get('request', source.get('request_uri', ''))
            row['verb'] = source.get('verb', source.get('request_method', ''))
            row['response'] = source.get('response', source.get('status', ''))
    else:
        # Нет поля message - берём напрямую из source
        row['timestamp'] = source.get('timestamp', '')
        row['IP'] = source.get('IP', source.get('remote_addr', ''))
        row['ua'] = source.get('ua', source.get('http_user_agent', ''))
        row['host'] = source.get('host', '')
        row['request'] = source.get('request', source.get('request_uri', ''))
        row['verb'] = source.get('verb', source.get('request_method', ''))
        row['response'] = source.get('response', source.get('status', ''))

    return row


def scan_with_retry(client, index, query, batch_size, scroll_time, max_retries=MAX_RETRIES):
    """
    Выполняет scan с автоматическими повторными попытками при таймаутах
    """
    retry_count = 0

    while retry_count < max_retries:
        try:
            for doc in scan(
                    client,
                    index=index,
                    query=query,
                    size=batch_size,
                    scroll=scroll_time,
                    request_timeout=REQUEST_TIMEOUT
            ):
                yield doc
            break  # Успешно завершено

        except (ConnectionTimeout, TransportError) as e:
            retry_count += 1
            if retry_count >= max_retries:
                print(f"\nОШИБКА: Превышено максимальное количество попыток ({max_retries})")
                raise

            print(f"\nТаймаут соединения (попытка {retry_count}/{max_retries}). Повтор через {RETRY_DELAY} сек...")
            time.sleep(RETRY_DELAY)

            # Увеличиваем задержку экспоненциально
            time.sleep(RETRY_DELAY * retry_count)


def dump_all(client, index, start_ts, end_ts, tags, tag_field, output_file):
    """Выгружает все данные за период в один файл"""
    source_query = build_source_query(tags, tag_field)
    query = {
        "query": {
            "bool": {
                "must": [
                    source_query,
                    {"range": {"timestamp": {"gte": start_ts, "lt": end_ts}}}
                ]
            }
        },
        "sort": [{"timestamp": "asc"}]
    }

    # Выгрузка
    total = 0
    parse_errors = 0
    connection_errors = 0

    try:
        with gzip.open(output_file, 'wt', encoding='utf-8', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
            writer.writeheader()

            try:
                for doc in scan_with_retry(client, index, query, BATCH_SIZE, SCROLL_TIME):
                    try:
                        source = doc['_source']
                        row = extract_row_from_source(source)
                        writer.writerow(row)
                        total += 1

                    except Exception as e:
                        parse_errors += 1
                        if parse_errors <= 5:  # Показываем первые 5 ошибок
                            print(f"Ошибка парсинга записи: {e}")

            except (ConnectionTimeout, TransportError) as e:
                connection_errors += 1
                print(f"\nОШИБКА соединения после всех попыток: {e}")
                print(f"Сохранено записей до ошибки: {total:,}")
                return total

        if parse_errors > 0:
            print(f"⚠ Ошибок парсинга: {parse_errors}")

        return total

    except Exception as e:
        print(f"ОШИБКА: {e}")
        return total  # Возвращаем количество сохранённых записей


def format_time_duration(seconds):
    """Форматирует время в читаемый вид"""
    if seconds < 60:
        return f"{seconds:.0f} сек"
    elif seconds < 3600:
        return f"{seconds/60:.1f} мин"
    else:
        hours = int(seconds / 3600)
        minutes = int((seconds % 3600) / 60)
        return f"{hours}ч {minutes}м"


def parse_args():
    """Парсит аргументы командной строки"""
    parser = argparse.ArgumentParser(
        description='Выгрузка production.nginx логов из OpenSearch в CSV',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Примеры использования:
  # Базовое использование с дефолтными настройками
  %(prog)s "2026-01-20 00:00:00" "2026-01-25 00:00:00"
  
  # С указанием тегов
  %(prog)s "2026-01-20 00:00:00" "2026-01-25 00:00:00" --tags "weu1,weu2"
  
  # С указанием индекса и директории
  %(prog)s "2026-01-20 00:00:00" "2026-01-25 00:00:00" --index "logs_*" --output-dir /tmp/logs
  
  # С другим полем для тега
  %(prog)s "2026-01-20 00:00:00" "2026-01-25 00:00:00" --tag-field "source"
  
  # Все параметры
  %(prog)s "2026-01-20 00:00:00" "2026-01-25 00:00:00" \\
    --tags "production.nginx,staging.nginx" \\
    --index "graylog_2026*" \\
    --output-dir ./output \\
    --tag-field "tag"
        """
    )

    # Позиционные аргументы
    parser.add_argument('start_time',
                        help='Начало периода (формат: "YYYY-MM-DD HH:MM:SS")')
    parser.add_argument('end_time',
                        help='Конец периода (формат: "YYYY-MM-DD HH:MM:SS")')

    # Опциональные аргументы
    parser.add_argument('--tags', '-t',
                        default='production.nginx',
                        help='Теги для фильтрации (через запятую). По умолчанию: production.nginx')
    parser.add_argument('--index', '-i',
                        default='graylog_*',
                        help='Индекс OpenSearch для поиска. По умолчанию: graylog_*')
    parser.add_argument('--output-dir', '-o',
                        default='.',
                        help='Директория для сохранения файлов. По умолчанию: текущая директория')
    parser.add_argument('--tag-field', '-f',
                        default='tag',
                        help='Имя поля для фильтрации по тегам. По умолчанию: tag')

    return parser.parse_args()


def main():
    start_time = datetime.now()

    # Парсинг аргументов
    args = parse_args()

    start_ts_input = args.start_time
    end_ts_input = args.end_time
    index = args.index
    output_dir = args.output_dir
    tag_field = args.tag_field

    # Парсим теги
    tags = [t.strip() for t in args.tags.split(',')]

    # Создаём директорию если её нет
    if not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir)
        except Exception as e:
            print(f"ОШИБКА: Не удалось создать директорию {output_dir}: {e}")
            sys.exit(1)

    start_ts = format_timestamp(start_ts_input)
    end_ts = format_timestamp(end_ts_input)

    start_dt = parse_datetime(start_ts_input)
    end_dt = parse_datetime(end_ts_input)

    # Подключение к OpenSearch с увеличенными таймаутами
    client = OpenSearch(
        hosts=[{'host': ES_URL, 'port': ES_PORT}],
        http_compress=True,
        use_ssl=False,
        verify_certs=False,
        ssl_assert_hostname=False,
        ssl_show_warn=False,
        timeout=REQUEST_TIMEOUT,
        max_retries=3,
        retry_on_timeout=True
    )

    # Формируем имя файла
    output_file = make_filename(tags, start_dt, end_dt, output_dir)

    # Выгрузка
    total_records = dump_all(client, index, start_ts, end_ts, tags, tag_field, output_file)

    # Итоги
    duration = (datetime.now() - start_time).total_seconds()

    if total_records > 0:
        # Размер файла
        size = os.path.getsize(output_file)
        if size < 1024 * 1024:
            size_str = f"{size / 1024:.1f} KB"
        elif size < 1024 * 1024 * 1024:
            size_str = f"{size / (1024 * 1024):.1f} MB"
        else:
            size_str = f"{size / (1024 * 1024 * 1024):.1f} GB"

        print(f"Записей: {total_records:,} | Размер: {size_str} | Время: {format_time_duration(duration)}")
        print(f"Файл: {output_file}")
    else:
        print("Нет записей для выгрузки")


if __name__ == "__main__":
    main()