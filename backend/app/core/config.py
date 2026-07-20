import os
from dotenv import load_dotenv

# Load .env file if it exists
load_dotenv()

class Settings:
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "https://your-supabase-project.supabase.co")
    # For backend batch updates and administration, we typically use the service role key to bypass RLS when performing admin actions
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "your-supabase-service-key")
    
    # Supabase JWT Secret for signing client-side RLS JWTs
    SUPABASE_JWT_SECRET: str = os.getenv("SUPABASE_JWT_SECRET", "your-supabase-jwt-secret-placeholder-change-in-prod")
    SUPABASE_JWT_KID: str = os.getenv("SUPABASE_JWT_KID", "")
    
    # Firebase Project ID for token verification
    FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "futa-1c8d8")
    
    # M-PESA DRC/ROC API Sandbox configuration parameters (Mock or Real sandbox credentials)
    MPESA_API_HOST: str = os.getenv("MPESA_API_HOST", "https://api.mpesa.vodacom.cd")
    MPESA_PUBLIC_KEY: str = os.getenv("MPESA_PUBLIC_KEY", "mock-public-key")
    MPESA_API_KEY: str = os.getenv("MPESA_API_KEY", "mock-api-key")
    MPESA_SERVICE_PROVIDER_CODE: str = os.getenv("MPESA_SERVICE_PROVIDER_CODE", "000000")

settings = Settings()

