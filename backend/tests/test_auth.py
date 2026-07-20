import jwt
from fastapi.testclient import TestClient
from app.main import app
from app.core.dependencies import verify_firebase_token
from app.core.config import settings

client = TestClient(app)

def test_verify_firebase_token_mock():
    # Verify that verify_firebase_token correctly parses mock tokens
    payload = verify_firebase_token("mock-token-test-user-id-parent")
    assert payload["uid"] == "test-user-id"
    assert payload["role"] == "client"
    assert payload["sub_role"] == "parent"

    school_payload = verify_firebase_token("mock-token-test-school-id-school")
    assert school_payload["uid"] == "test-school-id"
    assert school_payload["role"] == "admin"
    assert school_payload["sub_role"] == "school"

def test_token_exchange_endpoint_mock():
    # Verify POST /api/v1/auth/token-exchange endpoint with mock token
    response = client.post(
        "/api/v1/auth/token-exchange",
        json={"firebase_token": "mock-token-test-user-id-parent"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "supabase_token" in data
    assert data["uid"] == "test-user-id"
    assert data["role"] == "client"
    assert data["sub_role"] == "parent"

    # Decode and verify claims in the signed Supabase JWT
    supabase_token = data["supabase_token"]
    decoded = jwt.decode(
        supabase_token,
        settings.SUPABASE_JWT_SECRET,
        algorithms=["HS256"],
        audience="authenticated"
    )
    assert decoded["uid"] == "test-user-id"
    assert decoded["role"] == "authenticated"

def test_secured_endpoint_access_denied():
    # Verify cash-adjustment fails without authorization header
    response = client.post(
        "/api/v1/payments/cash-adjustment",
        json={"installment_id": "00000000-0000-0000-0000-000000000000", "amount": 100.0}
    )
    assert response.status_code == 422 # missing header validation error in FastAPI

def test_secured_endpoint_access_invalid_token():
    # Verify cash-adjustment fails with invalid authorization header format
    response = client.post(
        "/api/v1/payments/cash-adjustment",
        json={"installment_id": "00000000-0000-0000-0000-000000000000", "amount": 100.0},
        headers={"Authorization": "InvalidFormat token-value"}
    )
    assert response.status_code == 401
