from pydantic import BaseModel


class MeOut(BaseModel):
    user_id: str
    username: str
