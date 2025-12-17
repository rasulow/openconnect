### Ubuntu Server (OpenConnect) — подключение AnyConnect‑совместимого VPN (DTLS/UDP)

На Ubuntu Server используйте **OpenConnect**, который поддерживает VPN, совместимые с AnyConnect, и может использовать **DTLS (UDP)**, если сервер/сеть это разрешают (иначе будет fallback на TLS/TCP).

В этом репозитории есть `openconnect_udp.py` для Ubuntu/Linux.

### Требования

- Ubuntu Server
- Python 3
- Установленный `openconnect`

### Использование

Установить OpenConnect:

```bash
sudo apt-get update
sudo apt-get install -y openconnect
```

Подключиться (DTLS/UDP используется, если доступен; иначе будет fallback на TLS/TCP):

```bash
sudo python3 openconnect_udp.py connect vpn.example.com
```

Отключиться:

```bash
sudo python3 openconnect_udp.py disconnect
```

Статус:

```bash
python3 openconnect_udp.py status
```

Рекомендуется: закрепить (pin) сертификат сервера (попросите pin у администратора), например:

```bash
sudo python3 openconnect_udp.py connect vpn.example.com --servercert "pin-sha256:BASE64..."
```

Если нужно принудительно использовать TCP (отключить DTLS/UDP):

```bash
sudo python3 openconnect_udp.py connect vpn.example.com --no-dtls
```

### Примечания / устранение проблем

- Для подключения обычно нужны права root (используйте `sudo`), т.к. создаётся TUN‑интерфейс.
- Если UDP/DTLS недоступен (блокируется сетью или выключен на сервере), OpenConnect автоматически будет работать по TLS/TCP.


