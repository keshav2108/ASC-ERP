from typing import Any


class AppException(Exception):
    """Base exception for expected application errors."""

    def __init__(
        self,
        message: str,
        status_code: int = 400,
        details: Any | None = None,
    ) -> None:
        self.message = message
        self.status_code = status_code
        self.details = details

        super().__init__(message)


class NotFoundException(AppException):
    def __init__(
        self,
        message: str = "Resource not found",
        details: Any | None = None,
    ) -> None:
        super().__init__(
            message=message,
            status_code=404,
            details=details,
        )


class ConflictException(AppException):
    def __init__(
        self,
        message: str = "Resource already exists",
        details: Any | None = None,
    ) -> None:
        super().__init__(
            message=message,
            status_code=409,
            details=details,
        )


class UnauthorizedException(AppException):
    def __init__(
        self,
        message: str = "Authentication required",
        details: Any | None = None,
    ) -> None:
        super().__init__(
            message=message,
            status_code=401,
            details=details,
        )


class ForbiddenException(AppException):
    def __init__(
        self,
        message: str = "You are not allowed to perform this action",
        details: Any | None = None,
    ) -> None:
        super().__init__(
            message=message,
            status_code=403,
            details=details,
        )
