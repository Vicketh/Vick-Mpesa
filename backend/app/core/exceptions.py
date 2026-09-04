class VickMpesaError(Exception):
    """Base application error."""


class DarajaError(VickMpesaError):
    """Daraja API error — never expose raw provider details to clients."""
    def __init__(self, message: str, provider_code: str | None = None):
        super().__init__(message)
        self.provider_code = provider_code


class DarajaAuthError(DarajaError):
    """Authentication against Daraja failed."""


class DarajaTimeoutError(DarajaError):
    """Daraja did not respond in time."""


class TransactionNotFoundError(VickMpesaError):
    pass


class DuplicateTransactionError(VickMpesaError):
    pass


class ValidationError(VickMpesaError):
    pass
