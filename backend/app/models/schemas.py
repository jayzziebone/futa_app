from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date, datetime
from uuid import UUID

# 1. PROFILE SCHEMAS (Profiles IDs are now strings for Firebase UIDs)
class ProfileBase(BaseModel):
    phone_number: str = Field(..., description="Phone number, preferably formatted with +243")
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    address: Optional[str] = None
    role: str = Field(..., pattern="^(client|admin)$")
    sub_role: Optional[str] = Field(None, pattern="^(parent|school|merchant)$")

class ProfileCreate(ProfileBase):
    id: str = Field(..., description="Firebase Auth user unique UID (alphanumeric string)")

class ProfileResponse(ProfileBase):
    id: str
    created_at: datetime

    class Config:
        from_attributes = True

# 2. STUDENT SCHEMAS
class StudentBase(BaseModel):
    parent_id: str = Field(..., description="Parent profile ID (Firebase UID string)")
    school_id: Optional[str] = Field(None, description="School profile ID (Firebase UID string)")
    first_name: str
    last_name: str
    classroom: Optional[str] = None
    academic_score: float = Field(0.0, ge=0.0, le=20.0)
    attendance_rate: float = Field(100.0, ge=0.0, le=100.0)

class StudentCreate(StudentBase):
    pass

class StudentResponse(StudentBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

# 3. CONTRACT SCHEMAS
class SchoolContractBase(BaseModel):
    school_id: str = Field(..., description="School/Admin profile ID (Firebase UID string)")
    parent_id: str = Field(..., description="Parent profile ID (Firebase UID string)")
    total_tuition_due: float = Field(..., ge=0.0)
    status: str = Field("active", pattern="^(active|completed)$")

class SchoolContractCreate(SchoolContractBase):
    pass

class SchoolContractResponse(SchoolContractBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

# 4. INSTALLMENT SCHEMAS (Maintain UUID keys for table identifiers)
class ContractInstallmentBase(BaseModel):
    contract_id: UUID
    student_id: UUID
    amount_due: float = Field(..., ge=0.0)
    amount_paid: float = Field(0.0, ge=0.0)
    due_date: date
    status: str = Field("PENDING", pattern="^(PENDING|PARTIAL|PAID)$")

class ContractInstallmentCreate(ContractInstallmentBase):
    pass

class ContractInstallmentResponse(ContractInstallmentBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

# 5. INPUT/OUTPUT SCHEMAS FOR ADJUSTMENTS & PAYMENTS
class CashAdjustmentRequest(BaseModel):
    installment_id: UUID
    amount: float = Field(..., gt=0.0, description="Amount in cash to adjust/credit to this installment")

class MPesaPaymentRequest(BaseModel):
    installment_id: UUID
    phone_number: str = Field(..., description="Mobile money customer phone number (e.g. +243812345678)")
    amount: float = Field(..., gt=0.0, description="Amount to charge via M-Pesa push notification")
