from pydantic import BaseModel, Field
from typing import Optional


class ProfileUpdateSchema(BaseModel):
    """
    Allowlist of fields a merchant may update on their own account.
    balance, status, user_id, role are deliberately absent.
    """
    full_name:    Optional[str] = Field(None, max_length=255)
    phone_number: Optional[str] = Field(None, max_length=20)


class RegisterSchema(BaseModel):
    """
    Registration request schema.
    role is deliberately absent — always set server-side to 'merchant'.
    """
    email:     str = Field(..., max_length=255)
    password:  str = Field(..., min_length=8)
    full_name: str = Field("", max_length=255)