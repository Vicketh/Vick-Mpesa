from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
from app.config import get_settings


def create_access_token(subject: str) -> str:
    settings = get_settings()
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes)
    return jwt.encode(
        {"sub": subject, "exp": expire},
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def decode_access_token(token: str) -> str:
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
        sub: str = payload.get("sub", "")
        if not sub:
            raise ValueError("Invalid token subject")
        return sub
    except JWTError as exc:
        raise ValueError("Invalid or expired token") from exc
