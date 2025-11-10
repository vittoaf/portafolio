"""
test_function_local.py
Test local de la función (sin desplegar)
"""

import os
import sys

# Agregar carpeta function al path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'function'))

def test_imports():
    """Test que las importaciones funcionen"""
    try:
        import tweepy
        import pendulum
        from google.cloud import firestore, secretmanager
        print("✅ Todas las imports funcionan")
        return True
    except ImportError as e:
        print(f"❌ Error en imports: {e}")
        return False

def test_env_vars():
    """Test que las variables de entorno estén configuradas"""
    from dotenv import load_dotenv
    load_dotenv()
    
    required_vars = [
        'GCP_PROJECT_ID',
        'TWITTER_BEARER_TOKEN',
        'TWITTER_ACCOUNTS'
    ]
    
    missing = []
    for var in required_vars:
        if not os.getenv(var):
            missing.append(var)
    
    if missing:
        print(f"❌ Variables faltantes: {', '.join(missing)}")
        return False
    else:
        print("✅ Todas las variables configuradas")
        return True

def test_twitter_connection():
    """Test de conexión a Twitter API"""
    from dotenv import load_dotenv
    import tweepy
    
    load_dotenv()
    
    try:
        bearer_token = os.getenv('TWITTER_BEARER_TOKEN')
        client = tweepy.Client(bearer_token=bearer_token)
        
        # Test simple: buscar un tweet
        response = client.search_recent_tweets(
            query="from:twitter",
            max_results=10
        )
        
        if response.data:
            print(f"✅ Twitter API funciona ({len(response.data)} tweets)")
            return True
        else:
            print("⚠️  Twitter API responde pero sin datos")
            return True
    except Exception as e:
        print(f"❌ Error en Twitter API: {e}")
        return False

if __name__ == "__main__":
    print("="*60)
    print("TEST LOCAL DE LA FUNCIÓN")
    print("="*60)
    
    print("\n1. Test de imports...")
    test_imports()
    
    print("\n2. Test de variables de entorno...")
    test_env_vars()
    
    print("\n3. Test de conexión a Twitter API...")
    test_twitter_connection()
    
    print("\n" + "="*60)
    print("Tests completados")
    print("="*60)