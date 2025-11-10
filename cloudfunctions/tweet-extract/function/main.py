# main.py
"""
Cloud Function: Twitter Poller
- Consulta múltiples cuentas en UN SOLO REQUEST usando OR
- Solo guarda tweets que YA cumplen: >200 caracteres Y >=1000 likes
- Si tweet existe: actualiza métricas (likes, retweets, etc)
"""

import tweepy
import pendulum
from google.cloud import firestore, secretmanager
import functions_framework
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ═══════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════

PROJECT_ID = os.environ.get('GCP_PROJECT')
if not PROJECT_ID:
    raise ValueError("GCP_PROJECT no configurado en variables de entorno")

# Obtener cuentas desde variable de entorno (separadas por ;)
TWITTER_ACCOUNTS_STR = os.environ.get('TWITTER_ACCOUNTS', 'InvictosSomos;Juezcentral;2010MisterChip')
if not TWITTER_ACCOUNTS_STR:
    raise ValueError("TWITTER_ACCOUNTS no configurado en variables de entorno")
ACCOUNTS_TO_MONITOR = [account.strip() for account in TWITTER_ACCOUNTS_STR.split(';') if account.strip()]
if not ACCOUNTS_TO_MONITOR:
    raise ValueError("TWITTER_ACCOUNTS está vacío o mal formateado")

# Filtros
MIN_CHARACTERS = int(os.environ.get('MIN_CHARACTERS', '200'))
if not MIN_CHARACTERS:
    raise ValueError("MIN_CHARACTERS no configurado en variables de entorno")

MIN_LIKES = int(os.environ.get('MIN_LIKES', '1000'))
if not MIN_LIKES:
    raise ValueError("MIN_LIKES no configurado en variables de entorno")
    
# ═══════════════════════════════════════════════════════════
# FUNCIONES AUXILIARES
# ═══════════════════════════════════════════════════════════

def get_twitter_bearer_token():
    """Obtiene Bearer Token desde Secret Manager"""
    try:
        client = secretmanager.SecretManagerServiceClient()
        secret_name = f"projects/{PROJECT_ID}/secrets/twitter-bearer-token/versions/latest"
        response = client.access_secret_version(request={"name": secret_name})
        token = response.payload.data.decode("UTF-8")
        logger.info("✅ Bearer Token obtenido")
        return token
    except Exception as e:
        logger.error(f"❌ Error obteniendo Bearer Token: {e}")
        raise

def create_twitter_client():
    """Crea cliente de Twitter API v2"""
    try:
        bearer_token = get_twitter_bearer_token()
        client = tweepy.Client(bearer_token=bearer_token)
        logger.info("✅ Cliente de Twitter creado")
        return client
    except Exception as e:
        logger.error(f"❌ Error creando cliente: {e}")
        raise

def get_firestore_client():
    """Crea cliente de Firestore"""
    try:
        db = firestore.Client(project=PROJECT_ID)
        logger.info("✅ Cliente de Firestore creado")
        return db
    except Exception as e:
        logger.error(f"❌ Error creando Firestore client: {e}")
        raise

# ═══════════════════════════════════════════════════════════
# BÚSQUEDA DE TWEETS - UN SOLO QUERY
# ═══════════════════════════════════════════════════════════

def search_tweets_multi_account(client, usernames, max_results=100):
    """
    Busca tweets de MÚLTIPLES usuarios en UN SOLO REQUEST
    
    Query: (from:user1 OR from:user2 OR from:user3)
    
    Args:
        client: Cliente de tweepy
        usernames: Lista ['InvictosSomos', 'Juezcentral', ...]
        max_results: Max resultados (10-100)
    
    Returns:
        dict: {username: [tweets]}
    """
    logger.info(f"🔍 Buscando tweets de {len(usernames)} cuentas en 1 REQUEST")
    
    # Construir query con OR
    query_parts = [f"from:{username}" for username in usernames]
    query = "(" + " OR ".join(query_parts) + ")"
    
    logger.info(f"   Query: {query}")
    
    try:
        response = client.search_recent_tweets(
            query=query,
            max_results=max_results,
            tweet_fields=['created_at', 'author_id', 'public_metrics', 'lang'],
            expansions=['author_id'],
            user_fields=['username', 'name', 'verified', 'description']
        )
        
        if not response.data:
            logger.info("   ⚠️  No hay tweets recientes")
            return {username: [] for username in usernames}
        
        # Crear diccionario de usuarios
        users_dict = {}
        if response.includes and 'users' in response.includes:
            users_dict = {user.id: user for user in response.includes['users']}
        
        # Agrupar tweets por usuario
        tweets_by_user = {username: [] for username in usernames}
        
        for tweet in response.data:
            author = users_dict.get(tweet.author_id)
            
            if not author:
                continue
            
            username = author.username
            
            # Solo agregar si está en nuestra lista
            if username not in tweets_by_user:
                continue
            
            tweet_data = {
                'tweet_id': str(tweet.id),
                'text': tweet.text,
                'text_length': len(tweet.text),
                'created_at': tweet.created_at,
                'author_id': str(tweet.author_id),
                'author_username': username,
                'author_name': author.name,
                'verified': author.verified,
                'retweets': tweet.public_metrics['retweet_count'],
                'likes': tweet.public_metrics['like_count'],
                'replies': tweet.public_metrics['reply_count'],
                'quotes': tweet.public_metrics['quote_count'],
                'lang': tweet.lang
            }
            
            tweets_by_user[username].append(tweet_data)
        
        # Log de resultados
        for username, tweets in tweets_by_user.items():
            logger.info(f"   @{username}: {len(tweets)} tweets")
        
        total = sum(len(tweets) for tweets in tweets_by_user.values())
        logger.info(f"   ✅ Total: {total} tweets en 1 request")
        
        return tweets_by_user
        
    except tweepy.TooManyRequests:
        logger.error("❌ Rate limit excedido")
        raise
    except Exception as e:
        logger.error(f"❌ Error buscando tweets: {e}")
        raise

# ═══════════════════════════════════════════════════════════
# FILTROS Y GUARDADO
# ═══════════════════════════════════════════════════════════

def filter_tweets(tweets):
    """
    Filtra tweets que cumplen AMBAS condiciones:
    - Más de MIN_CHARACTERS caracteres
    - Más de o igual a MIN_LIKES likes
    """
    filtered = []
    
    for tweet in tweets:
        # Filtro 1: Caracteres
        if tweet['text_length'] <= MIN_CHARACTERS:
            continue
        
        # Filtro 2: Likes
        if tweet['likes'] < MIN_LIKES:
            continue
        
        filtered.append(tweet)
    
    return filtered

def save_to_firestore(db, tweets, username):
    """
    Guarda o actualiza tweets en Firestore
    
    Document ID: username_tweet_id
    
    - Si NO existe: INSERT nuevo documento
    - Si SÍ existe: UPDATE solo métricas (likes, retweets, etc)
    """
    saved = 0
    updated = 0
    skipped = 0
    
    now = pendulum.now('UTC')
    
    for tweet in tweets:
        # Document ID: username_tweet_id
        doc_id = f"{username}_{tweet['tweet_id']}"
        doc_ref = db.collection('tweets').document(doc_id)
        
        doc = doc_ref.get()
        
        if doc.exists:
            # Tweet ya existe, actualizar métricas
            existing_data = doc.to_dict()
            
            # Solo actualizar si cambió alguna métrica
            if (existing_data.get('likes') != tweet['likes'] or
                existing_data.get('retweets') != tweet['retweets'] or
                existing_data.get('replies') != tweet['replies'] or
                existing_data.get('quotes') != tweet['quotes']):
                
                doc_ref.update({
                    'likes': tweet['likes'],
                    'retweets': tweet['retweets'],
                    'replies': tweet['replies'],
                    'quotes': tweet['quotes'],
                    'updated_at': now,
                    'last_check_at': now
                })
                updated += 1
                logger.info(f"   🔄 Actualizado {doc_id} (likes: {tweet['likes']})")
            else:
                # Sin cambios, solo actualizar timestamp de revisión
                doc_ref.update({'last_check_at': now})
                skipped += 1
        else:
            # Tweet nuevo, guardar completo
            doc_ref.set({
                'tweet_id': tweet['tweet_id'],
                'text': tweet['text'],
                'text_length': tweet['text_length'],
                'created_at': tweet['created_at'],
                'author_username': username,
                'author_name': tweet['author_name'],
                'verified': tweet['verified'],
                'likes': tweet['likes'],
                'retweets': tweet['retweets'],
                'replies': tweet['replies'],
                'quotes': tweet['quotes'],
                'lang': tweet['lang'],
                'discovered_at': now,
                'updated_at': now,
                'last_check_at': now,
                'schema_version': '1.0'
            })
            saved += 1
            logger.info(f"   ✅ Guardado {doc_id} (likes: {tweet['likes']})")
    
    return {'saved': saved, 'updated': updated, 'skipped': skipped}

def update_polling_state(db, username, stats):
    """Actualiza estado del polling para una cuenta"""
    now = pendulum.now('UTC')
    
    state_ref = db.collection('polling_state').document(username)
    state_ref.set({
        'username': username,
        'last_check_at': now,
        'last_stats': stats,
        'total_tweets_saved': firestore.Increment(stats['saved']),
        'total_tweets_updated': firestore.Increment(stats['updated'])
    }, merge=True)
    
    logger.info(f"   📝 Estado actualizado")

# ═══════════════════════════════════════════════════════════
# FUNCIÓN PRINCIPAL
# ═══════════════════════════════════════════════════════════

@functions_framework.http
def twitter_poller(request):
    """
    Cloud Function principal
    
    Proceso:
    1. Consulta Twitter API con query: (from:user1 OR from:user2 OR user3)
    2. Para cada tweet recibido:
       - Valida: >200 caracteres Y >=1000 likes
       - Si cumple Y NO existe: guarda nuevo
       - Si cumple Y SÍ existe: actualiza métricas
       - Si NO cumple: ignora (no guarda)
    """
    start_time = pendulum.now('UTC')
    logger.info("="*80)
    logger.info(f"🚀 INICIO: {start_time.to_datetime_string()}")
    logger.info("="*80)
    logger.info(f"📋 Cuentas ({len(ACCOUNTS_TO_MONITOR)}): {', '.join(ACCOUNTS_TO_MONITOR)}")
    logger.info(f"📋 Filtros: >{MIN_CHARACTERS} caracteres, >={MIN_LIKES} likes")
    logger.info("="*80)
    
    try:
        # Crear clientes
        twitter_client = create_twitter_client()
        db = get_firestore_client()
        
        global_stats = {
            'accounts_processed': 0,
            'tweets_found': 0,
            'tweets_filtered': 0,
            'tweets_saved': 0,
            'tweets_updated': 0,
            'tweets_skipped': 0,
            'tweets_ignored': 0
        }
        
        account_details = []
        
        # PASO 1: Buscar tweets de TODAS las cuentas (1 request)
        logger.info(f"\n{'─'*80}")
        logger.info("PASO 1: BÚSQUEDA DE TWEETS (1 REQUEST)")
        logger.info(f"{'─'*80}")
        
        tweets_by_user = search_tweets_multi_account(
            twitter_client, 
            ACCOUNTS_TO_MONITOR, 
            max_results=100
        )
        
        # PASO 2: Procesar cada cuenta
        logger.info(f"\n{'─'*80}")
        logger.info("PASO 2: PROCESAMIENTO POR CUENTA")
        logger.info(f"{'─'*80}")
        
        for username in ACCOUNTS_TO_MONITOR:
            logger.info(f"\n📊 Procesando @{username}")
            
            try:
                # Obtener tweets de esta cuenta
                tweets = tweets_by_user.get(username, [])
                global_stats['tweets_found'] += len(tweets)
                
                if not tweets:
                    logger.info("   ⚠️  Sin tweets recientes")
                    account_details.append({
                        'username': username,
                        'status': 'no_tweets',
                        'tweets_found': 0
                    })
                    continue
                
                logger.info(f"   📥 Encontrados: {len(tweets)} tweets")
                
                # Filtrar tweets que cumplen condiciones
                filtered_tweets = filter_tweets(tweets)
                global_stats['tweets_filtered'] += len(filtered_tweets)
                
                ignored = len(tweets) - len(filtered_tweets)
                global_stats['tweets_ignored'] += ignored
                
                logger.info(f"   ✅ Califican: {len(filtered_tweets)}")
                logger.info(f"   ❌ Ignorados: {ignored}")
                
                if not filtered_tweets:
                    logger.info("   ⚠️  Ningún tweet cumple criterios")
                    account_details.append({
                        'username': username,
                        'status': 'no_matches',
                        'tweets_found': len(tweets),
                        'tweets_ignored': ignored
                    })
                    continue
                
                # Guardar o actualizar tweets que califican
                save_stats = save_to_firestore(db, filtered_tweets, username)
                global_stats['tweets_saved'] += save_stats['saved']
                global_stats['tweets_updated'] += save_stats['updated']
                global_stats['tweets_skipped'] += save_stats['skipped']
                
                # Actualizar estado
                update_polling_state(db, username, save_stats)
                
                global_stats['accounts_processed'] += 1
                
                account_details.append({
                    'username': username,
                    'status': 'success',
                    'tweets_found': len(tweets),
                    'tweets_ignored': ignored,
                    'tweets_saved': save_stats['saved'],
                    'tweets_updated': save_stats['updated'],
                    'tweets_skipped': save_stats['skipped']
                })
                
            except tweepy.TooManyRequests:
                logger.error(f"❌ Rate limit para @{username}")
                account_details.append({
                    'username': username,
                    'status': 'rate_limit'
                })
                continue
            except Exception as e:
                logger.error(f"❌ Error con @{username}: {e}")
                account_details.append({
                    'username': username,
                    'status': 'error',
                    'error': str(e)
                })
                continue
        
        # Resumen final
        end_time = pendulum.now('UTC')
        duration = (end_time - start_time).total_seconds()
        
        logger.info("\n" + "="*80)
        logger.info("📊 RESUMEN FINAL")
        logger.info("="*80)
        logger.info(f"Twitter API calls: 1")
        logger.info(f"Cuentas procesadas: {global_stats['accounts_processed']}/{len(ACCOUNTS_TO_MONITOR)}")
        logger.info(f"Tweets encontrados: {global_stats['tweets_found']}")
        logger.info(f"Tweets que califican: {global_stats['tweets_filtered']}")
        logger.info(f"Tweets ignorados: {global_stats['tweets_ignored']}")
        logger.info(f"Tweets guardados (nuevos): {global_stats['tweets_saved']}")
        logger.info(f"Tweets actualizados: {global_stats['tweets_updated']}")
        logger.info(f"Duración: {duration:.2f}s")
        logger.info("="*80)
        
        response = {
            'status': 'success',
            'timestamp': end_time.to_iso8601_string(),
            'duration_seconds': duration,
            'twitter_api_calls': 1,
            'config': {
                'accounts': ACCOUNTS_TO_MONITOR,
                'min_characters': MIN_CHARACTERS,
                'min_likes': MIN_LIKES
            },
            'summary': global_stats,
            'accounts': account_details
        }
        
        return response, 200
        
    except Exception as e:
        logger.error(f"❌ ERROR CRÍTICO: {e}", exc_info=True)
        return {
            'status': 'error',
            'error': str(e),
            'timestamp': pendulum.now('UTC').to_iso8601_string()
        }, 500