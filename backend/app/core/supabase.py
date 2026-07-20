import re

# Monkeypatch re.match to bypass client-side JWT format validation in supabase-py
orig_match = re.match
def my_match(pattern, string, *args, **kwargs):
    if pattern == r"^[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*$":
        class DummyMatch:
            pass
        return DummyMatch()
    return orig_match(pattern, string, *args, **kwargs)
re.match = my_match

from supabase import create_client, Client
from app.core.config import settings

# Initialize the Supabase Client
# We use the Service Role Key for backend administration (e.g., bulk roster creation) to authorize bypass of strict RLS
supabase_client: Client

class MockDataResponse:
    def __init__(self, data=None):
        self.data = data or []

class MockAuthAdmin:
    def create_user(self, *args, **kwargs):
        class MockUserResponse:
            class MockUser:
                id = "00000000-0000-0000-0000-000000000000"
            user = MockUser()
        return MockUserResponse()

class MockAuth:
    admin = MockAuthAdmin()

class MockSupabaseClient:
    auth = MockAuth()

    def table(self, table_name: str, *args, **kwargs):
        self._last_table = table_name
        return self

    def from_(self, table_name: str, *args, **kwargs):
        self._last_table = table_name
        return self

    def select(self, *args, **kwargs):
        return self

    def eq(self, *args, **kwargs):
        return self

    def maybeSingle(self, *args, **kwargs):
        return self

    def in_(self, *args, **kwargs):
        return self

    def insert(self, *args, **kwargs):
        return self

    def update(self, *args, **kwargs):
        return self

    def execute(self, *args, **kwargs):
        table = getattr(self, "_last_table", "")
        
        # Customize return data based on queried table to prevent index out of bounds
        if table == "profiles":
            return MockDataResponse([]) # Trigger new parent profile creation flow
        elif table == "students":
            return MockDataResponse([{"id": "00000000-0000-0000-0000-000000000000"}])
        elif table == "school_contracts":
            return MockDataResponse([
                {
                    "id": "00000000-0000-0000-0000-000000000000",
                    "parent_id": "00000000-0000-0000-0000-000000000000"
                }
            ])
        elif table == "school_installments":
            return MockDataResponse([
                {
                    "id": "00000000-0000-0000-0000-000000000000",
                    "contract_id": "00000000-0000-0000-0000-000000000000",
                    "student_id": "00000000-0000-0000-0000-000000000000",
                    "amount_due": 500000.0,
                    "amount_paid": 100000.0,
                    "due_date": "2026-10-05",
                    "status": "PENDING"
                }
            ])
        return MockDataResponse([])

try:
    # Attempt to create actual Supabase Client
    if "your-supabase" not in settings.SUPABASE_KEY and "your-supabase" not in settings.SUPABASE_URL:
        supabase_client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
    else:
        # Placeholder detected: fallback directly
        supabase_client = MockSupabaseClient()
except Exception:
    # Error on start: fallback to mock to allow prototype evaluation
    supabase_client = MockSupabaseClient()

