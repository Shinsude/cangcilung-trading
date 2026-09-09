"""Firebase Cloud Messaging helpers.

Membaca kredensial service account dari env FCM_SERVICE_ACCOUNT_JSON (string JSON).
Jika tidak tersedia, semua operasi menjadi no-op (push nonaktif) tanpa error.
"""
import os
import threading

FCM_TOPIC = "signals"


def _credentials() -> dict | None:
    raw = os.getenv("FCM_SERVICE_ACCOUNT_JSON", "").strip()
    if not raw:
        return None
    try:
        import json

        return json.loads(raw)
    except Exception:  # noqa: BLE001
        return None


def _admin_app():
    import json

    from firebase_admin import credentials, initialize_app

    cred = _credentials()
    if cred is None:
        return None
    try:
        from firebase_admin import get_app

        return get_app(name="cangcilung")
    except ValueError:
        c = credentials.Certificate(cred)
        return initialize_app(c, name="cangcilung")


def push_enabled() -> bool:
    return _credentials() is not None


def send_message(title: str, body: str, symbol: str | None = None) -> bool:
    """Kirim ke topic 'signals' (semua perangkat). Mengirim per-simbol optional via data."""
    try:
        from firebase_admin import messaging

        app = _admin_app()
        if app is None:
            return False
        msg = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            topic=FCM_TOPIC,
            data={"type": "signal", **({"symbol": symbol} if symbol else {})},
        )
        messaging.send(msg, app=app)
        return True
    except Exception:  # noqa: BLE001
        return False
