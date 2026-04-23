"""
Servicio de envio de push notifications con Firebase Admin.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass

import firebase_admin
from firebase_admin import credentials, messaging

from app.config import get_settings


@dataclass
class PushSendResult:
    invalid_tokens: list[str]
    success_count: int
    failure_count: int


class PushNotificationService:
    def __init__(self):
        self.settings = get_settings()

    def initialize(self) -> bool:
        if not self.settings.FIREBASE_ENABLED:
            return False

        if firebase_admin._apps:
            return True

        credentials_path = self.settings.firebase_credentials_abspath
        if not credentials_path.exists():
            print(f"[PUSH] Firebase credentials no encontradas: {credentials_path}")
            return False

        try:
            cred = credentials.Certificate(str(credentials_path))
            firebase_admin.initialize_app(cred)
            print("[PUSH] Firebase Admin inicializado")
            return True
        except Exception as exc:
            print(f"[PUSH] Error inicializando Firebase Admin: {exc}")
            return False

    async def send_to_tokens(
        self,
        *,
        tokens: list[str],
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> PushSendResult:
        unique_tokens = list(dict.fromkeys(token for token in tokens if token))
        if not unique_tokens:
            return PushSendResult(invalid_tokens=[], success_count=0, failure_count=0)

        if not self.initialize():
            return PushSendResult(invalid_tokens=[], success_count=0, failure_count=0)

        return await asyncio.to_thread(
            self._send_to_tokens_sync,
            unique_tokens,
            title,
            body,
            data or {},
        )

    def _send_to_tokens_sync(
        self,
        tokens: list[str],
        title: str,
        body: str,
        data: dict[str, str],
    ) -> PushSendResult:
        invalid_tokens: list[str] = []
        success_count = 0
        failure_count = 0

        for token in tokens:
            message = messaging.Message(
                token=token,
                notification=messaging.Notification(title=title, body=body),
                data=data,
                webpush=messaging.WebpushConfig(
                    fcm_options=messaging.WebpushFCMOptions(
                        link=self.settings.FIREBASE_WEB_APP_URL,
                    ) if self.settings.FIREBASE_WEB_APP_URL.startswith("https://") else None,
                    notification=messaging.WebpushNotification(
                        title=title,
                        body=body,
                        icon="/icons/Icon-192.png",
                    ),
                ),
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="reservives_notifications",
                    ),
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(sound="default")
                    )
                ),
            )

            try:
                messaging.send(message)
                success_count += 1
            except Exception as exc:
                failure_count += 1
                code = getattr(exc, "code", "")
                text = str(exc)
                if code in {"registration-token-not-registered", "invalid-argument"} or (
                    "registration-token-not-registered" in text
                    or "Requested entity was not found" in text
                    or "The registration token is not a valid FCM registration token" in text
                ):
                    invalid_tokens.append(token)
                print(f"[PUSH] Error enviando push a token: {exc}")

        return PushSendResult(
            invalid_tokens=invalid_tokens,
            success_count=success_count,
            failure_count=failure_count,
        )


_push_service: PushNotificationService | None = None


def get_push_notification_service() -> PushNotificationService:
    global _push_service
    if _push_service is None:
        _push_service = PushNotificationService()
    return _push_service
