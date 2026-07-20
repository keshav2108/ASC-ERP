import logging
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.exceptions import AppException


logger = logging.getLogger(__name__)


def error_response(
    *,
    status_code: int,
    message: str,
    details: Any | None = None,
) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={
            "success": False,
            "message": message,
            "details": details,
        },
    )


async def app_exception_handler(
    request: Request,
    exception: AppException,
) -> JSONResponse:
    return error_response(
        status_code=exception.status_code,
        message=exception.message,
        details=exception.details,
    )


async def http_exception_handler(
    request: Request,
    exception: StarletteHTTPException,
) -> JSONResponse:
    return error_response(
        status_code=exception.status_code,
        message=str(exception.detail),
    )


async def validation_exception_handler(
    request: Request,
    exception: RequestValidationError,
) -> JSONResponse:
    errors = []

    for error in exception.errors():
        errors.append(
            {
                "field": ".".join(
                    str(location)
                    for location in error.get("loc", [])
                ),
                "message": error.get("msg"),
                "type": error.get("type"),
            }
        )

    return error_response(
        status_code=422,
        message="Request validation failed",
        details=errors,
    )


async def integrity_exception_handler(
    request: Request,
    exception: IntegrityError,
) -> JSONResponse:
    logger.exception(
        "Database integrity error: %s",
        exception,
    )

    return error_response(
        status_code=409,
        message=(
            "A record with the same username, mobile number, "
            "email, or identifier already exists."
        ),
    )


async def sqlalchemy_exception_handler(
    request: Request,
    exception: SQLAlchemyError,
) -> JSONResponse:
    logger.exception(
        "Database error: %s",
        exception,
    )

    return error_response(
        status_code=500,
        message="A database error occurred.",
    )


async def unexpected_exception_handler(
    request: Request,
    exception: Exception,
) -> JSONResponse:
    logger.exception(
        "Unhandled error while processing %s %s",
        request.method,
        request.url.path,
    )

    return error_response(
        status_code=500,
        message="An unexpected server error occurred.",
    )


def register_exception_handlers(
    app: FastAPI,
) -> None:
    app.add_exception_handler(
        AppException,
        app_exception_handler,
    )

    app.add_exception_handler(
        StarletteHTTPException,
        http_exception_handler,
    )

    app.add_exception_handler(
        RequestValidationError,
        validation_exception_handler,
    )

    app.add_exception_handler(
        IntegrityError,
        integrity_exception_handler,
    )

    app.add_exception_handler(
        SQLAlchemyError,
        sqlalchemy_exception_handler,
    )

    app.add_exception_handler(
        Exception,
        unexpected_exception_handler,
    )
