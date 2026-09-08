"""Caller identity."""

from app.core.auth import CurrentUser
from app.schemas.me import MeOut


class MeService:
    def get_profile(self, user: CurrentUser) -> MeOut:
        """Phase 1: everything we know comes from the verified token claims."""
        return MeOut(user_id=user.user_id, username=user.username)
