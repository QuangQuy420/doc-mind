"""Liveness endpoint. Unauthenticated on purpose: the load balancer, the Docker
HEALTHCHECK and EC2 user_data all poll it."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.deps import get_health_service
from app.schemas.health import HealthOut
from app.schemas.response import ApiResponse
from app.services.health import HealthService

router = APIRouter(tags=["health"])


@router.get("/health", response_model=ApiResponse[HealthOut])
def get_health(
    service: Annotated[HealthService, Depends(get_health_service)],
) -> ApiResponse[HealthOut]:
    return ApiResponse(data=service.check())
