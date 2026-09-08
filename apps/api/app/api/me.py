"""The caller's own profile."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.auth import CurrentUser, get_current_user
from app.core.deps import get_me_service
from app.schemas.me import MeOut
from app.schemas.response import ApiResponse
from app.services.me import MeService

router = APIRouter(tags=["me"])


@router.get("/me", response_model=ApiResponse[MeOut])
def get_me(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    service: Annotated[MeService, Depends(get_me_service)],
) -> ApiResponse[MeOut]:
    return ApiResponse(data=service.get_profile(user))
