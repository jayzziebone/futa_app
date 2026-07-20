import time
import httpx
import jwt
from fastapi import Header, HTTPException, Depends
from cryptography.hazmat.primitives import serialization
from cryptography.x509 import load_pem_x509_certificate
from app.core.config import settings

# Global cache for Google's public certificates
GOOGLE_CERTS_CACHE = {
    "certs": {},
    "expires_at": 0
}

def get_google_public_key(kid: str) -> bytes:
    global GOOGLE_CERTS_CACHE
    now = time.time()
    
    # Reload certificates if empty or expired
    if not GOOGLE_CERTS_CACHE["certs"] or now >= GOOGLE_CERTS_CACHE["expires_at"]:
        try:
            res = httpx.get("https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com")
            if res.status_code == 200:
                GOOGLE_CERTS_CACHE["certs"] = res.json()
                
                # Fetch cache headers if available, otherwise default to 1 hour cache
                cache_control = res.headers.get("Cache-Control", "")
                max_age = 3600
                for part in cache_control.split(","):
                    if "max-age" in part:
                        try:
                            max_age = int(part.split("=")[1].strip())
                        except Exception:
                            pass
                GOOGLE_CERTS_CACHE["expires_at"] = now + max_age
            else:
                raise HTTPException(status_code=500, detail="Impossible de récupérer les clés publiques d'authentification Google.")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Erreur réseau lors de la récupération des clés d'authentification: {str(e)}")
            
    cert_str = GOOGLE_CERTS_CACHE["certs"].get(kid)
    if not cert_str:
        raise HTTPException(status_code=401, detail="Identifiant de clé de jeton (kid) invalide.")
        
    # Convert x509 PEM certificate string to public key PEM bytes
    cert_obj = load_pem_x509_certificate(cert_str.encode("utf-8"))
    public_key = cert_obj.public_key()
    pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    return pem

def verify_firebase_token(token: str) -> dict:
    # Developer Sandbox / Mock token bypass for local evaluation
    if token.startswith("mock-token-"):
        uid = token.replace("mock-token-", "", 1)
        role = "client"
        sub_role = "parent"
        
        # Determine role based on mock token ending and slice the suffix off
        if uid.endswith("-school"):
            role = "admin"
            sub_role = "school"
            uid = uid[:-7]
        elif uid.endswith("-merchant"):
            role = "admin"
            sub_role = "merchant"
            uid = uid[:-9]
        elif uid.endswith("-parent"):
            role = "client"
            sub_role = "parent"
            uid = uid[:-7]
            
        return {
            "uid": uid,
            "sub": uid,
            "phone_number": "+243812345678",
            "name": f"Mock {sub_role.capitalize()}",
            "role": role,
            "sub_role": sub_role
        }

    try:
        # Decode JWT header to extract key identifier 'kid'
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")
        if not kid:
            raise HTTPException(status_code=401, detail="Header de jeton incomplet (kid manquant).")
            
        public_key = get_google_public_key(kid)
        
        # Verify and decode JWT signature and standard claims
        decoded_token = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=settings.FIREBASE_PROJECT_ID,
            issuer=f"https://securetoken.google.com/{settings.FIREBASE_PROJECT_ID}"
        )
        
        # Map user_id to uid for standard output consistency
        if "user_id" in decoded_token and "uid" not in decoded_token:
            decoded_token["uid"] = decoded_token["user_id"]

        # Fetch role and sub_role from Supabase profiles/school_profiles/merchant_profiles tables
        uid = decoded_token.get("uid")
        if uid:
            from app.core.supabase import supabase_client
            try:
                # 1. Check profiles (parent)
                profile_res = supabase_client.table("profiles").select("id").eq("id", uid).execute()
                if profile_res.data:
                    decoded_token["role"] = "client"
                    decoded_token["sub_role"] = "parent"
                else:
                    # 2. Check school_profiles (school admin)
                    school_res = supabase_client.table("school_profiles").select("id").eq("id", uid).execute()
                    if school_res.data:
                        decoded_token["role"] = "admin"
                        decoded_token["sub_role"] = "school"
                    else:
                        # 3. Check merchant_profiles (merchant admin)
                        merchant_res = supabase_client.table("merchant_profiles").select("id").eq("id", uid).execute()
                        if merchant_res.data:
                            decoded_token["role"] = "admin"
                            decoded_token["sub_role"] = "merchant"
                        else:
                            decoded_token["role"] = "client"
                            decoded_token["sub_role"] = "parent"
            except Exception as e:
                decoded_token["role"] = "client"
                decoded_token["sub_role"] = "parent"

        return decoded_token
        
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Le jeton de session a expiré. Veuillez vous reconnecter.")
    except jwt.InvalidTokenError as e:
        raise HTTPException(status_code=401, detail=f"Signature de jeton invalide: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Échec de l'authentification: {str(e)}")

def get_current_user(authorization: str = Header(..., description="Firebase Token Bearer Header")) -> dict:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="En-tête d'autorisation invalide. Doit commencer par 'Bearer '.")
    token = authorization.split(" ")[1]
    return verify_firebase_token(token)
