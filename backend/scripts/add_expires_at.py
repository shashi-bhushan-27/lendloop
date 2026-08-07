import asyncio
import os
import asyncpg
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "")
PG_URL = DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://").replace("?ssl=require", "")

async def add_column():
    print(f"Connecting to: {PG_URL[:40]}...")
    conn = await asyncpg.connect(PG_URL, ssl="require")
    try:
        await conn.execute("ALTER TABLE items ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE;")
        print("✅ Added expires_at column to items table.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(add_column())
