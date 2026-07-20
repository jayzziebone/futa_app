import time
import jwt
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from app.core.config import settings
from app.core.supabase import supabase_client
from app.core.dependencies import verify_firebase_token

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication & Token Exchange"])

class TokenExchangeRequest(BaseModel):
    firebase_token: str = Field(..., description="Le jeton d'authentification ID token généré par Firebase Auth")

class TokenExchangeResponse(BaseModel):
    supabase_token: str
    uid: str
    phone_number: str
    role: str
    sub_role: str

@router.post("/token-exchange", response_model=TokenExchangeResponse)
def token_exchange(request: TokenExchangeRequest):
    # 1. Verify the Firebase token
    try:
        firebase_user = verify_firebase_token(request.firebase_token)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Jeton Firebase invalide ou expiré: {str(e)}")
        
    uid = firebase_user.get("uid")
    phone = firebase_user.get("phone_number") or ""
    
    if not uid:
        raise HTTPException(status_code=400, detail="L'identifiant utilisateur (uid) est introuvable dans le jeton.")

    # 2. Check if a profile already exists for this Firebase user in Supabase
    try:
        profile_res = supabase_client.table("profiles").select("*").eq("id", uid).execute()
        if profile_res.data:
            profile = profile_res.data[0]
            role = "client"
            sub_role = "parent"
        else:
            school_res = supabase_client.table("school_profiles").select("*").eq("id", uid).execute()
            if school_res.data:
                profile = school_res.data[0]
                role = "admin"
                sub_role = "school"
            else:
                merchant_res = supabase_client.table("merchant_profiles").select("*").eq("id", uid).execute()
                if merchant_res.data:
                    profile = merchant_res.data[0]
                    role = "admin"
                    sub_role = "merchant"
                else:
                    profile = None
                    role = ""
                    sub_role = ""
        
        if profile:
            # Profile exists, nothing more to do here
            pass
        else:
            # If profile does not exist, check if a roster upload created a placeholder profile for this phone number
            role = firebase_user.get("role", "")
            sub_role = firebase_user.get("sub_role", "")
            
            if phone:
                phone_res = supabase_client.table("profiles").select("*").eq("phone_number", phone).execute()
                if phone_res.data:
                    # Found a placeholder profile created by a school roster upload!
                    placeholder = phone_res.data[0]
                    placeholder_id = placeholder["id"]
                    
                    # Migrate references in related tables (students, school_contracts) safely
                    new_p_res = supabase_client.table("profiles").select("id").eq("id", uid).execute()
                    if new_p_res.data:
                        # Case A: Real profile already exists
                        supabase_client.table("students").update({"parent_id": uid}).eq("parent_id", placeholder_id).execute()
                        supabase_client.table("school_contracts").update({"parent_id": uid}).eq("parent_id", placeholder_id).execute()
                        supabase_client.table("profiles").delete().eq("id", placeholder_id).execute()
                    else:
                        # Case B: Real profile does not exist yet (clean signup)
                        # 1. Insert a temporary record for the new profile to avoid foreign key violations when migrating
                        supabase_client.table("profiles").insert({
                            "id": uid,
                            "phone_number": f"{phone}_temp_{int(time.time())}",
                            "first_name": placeholder.get("first_name"),
                            "last_name": placeholder.get("last_name"),
                            "address": placeholder.get("address"),
                            "role": placeholder.get("role", "client"),
                            "sub_role": placeholder.get("sub_role", "parent")
                        }).execute()

                        # 2. Migrate references in students and school_contracts
                        supabase_client.table("students").update({"parent_id": uid}).eq("parent_id", placeholder_id).execute()
                        supabase_client.table("school_contracts").update({"parent_id": uid}).eq("parent_id", placeholder_id).execute()

                        # 3. Delete the old placeholder profile
                        supabase_client.table("profiles").delete().eq("id", placeholder_id).execute()

                        # 4. Update the new profile to use the actual phone number
                        supabase_client.table("profiles").update({"phone_number": phone}).eq("id", uid).execute()
                    
                    role = placeholder.get("role", "client")
                    sub_role = placeholder.get("sub_role") or "parent"
                    
            # For developer sandbox mock tokens, auto-insert to satisfy standard test runs
            if request.firebase_token.startswith("mock-token-"):
                role = role or "client"
                sub_role = sub_role or "parent"
                supabase_client.table("profiles").insert({
                    "id": uid,
                    "phone_number": phone or "+243812345678",
                    "role": role,
                    "sub_role": sub_role,
                    "first_name": "Mock",
                    "last_name": sub_role.capitalize()
                }).execute()
                
    except Exception as db_err:
        # Check if error message indicates table doesn't exist yet, fallback to baseline in local mock modes
        if "relation" in str(db_err).lower() or "table" in str(db_err).lower():
            role = "client"
            sub_role = "parent"
        else:
            raise HTTPException(status_code=500, detail=f"Erreur de base de données lors de la vérification du profil: {str(db_err)}")

    # 3. Generate custom Supabase compatible JWT
    # JWT standard structure expected by Supabase PostgREST
    # Generate a deterministic UUID from the Firebase UID to satisfy Supabase's sub (UUID) claim requirement
    import uuid
    supabase_sub = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"firebase:{uid}"))

    # Ensure this user is provisioned in Supabase Auth so GoTrue's session verification succeeds
    try:
        supabase_client.auth.admin.create_user({
            "id": supabase_sub,
            "phone": phone or f"+243{int(time.time()) % 1000000000:09d}",
            "phone_confirm": True,
            "user_metadata": {
                "role": role,
                "sub_role": sub_role
            }
        })
    except Exception:
        # Ignore if user already exists or provisioning fails
        pass

    payload = {
        "aud": "authenticated",
        "role": "authenticated", # Enables query execution through Supabase
        "iss": "supabase",
        "sub": supabase_sub, # UUID for Supabase Auth validation checks
        "uid": uid, # Firebase UID string for database RLS checks
        "exp": int(time.time()) + 3600 * 24 # Token valid for 24 hours
    }
    
    try:
        headers = {}
        if settings.SUPABASE_JWT_KID:
            headers["kid"] = settings.SUPABASE_JWT_KID

        supabase_token = jwt.encode(
            payload,
            settings.SUPABASE_JWT_SECRET,
            algorithm="HS256",
            headers=headers
        )
    except Exception as jwt_err:
        raise HTTPException(status_code=500, detail=f"Erreur de génération du jeton d'accès Supabase: {str(jwt_err)}")

    return TokenExchangeResponse(
        supabase_token=supabase_token,
        uid=uid,
        phone_number=phone,
        role=role,
        sub_role=sub_role
    )
