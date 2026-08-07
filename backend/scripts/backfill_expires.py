import asyncio
import os
import asyncpg
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "")
PG_URL = DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://").replace("?ssl=require", "")

async def backfill_expires_at():
    print(f"Connecting to: {PG_URL[:40]}...")
    conn = await asyncpg.connect(PG_URL, ssl="require")
    try:
        # Update existing items that have no expires_at
        result = await conn.execute(
            "UPDATE items SET expires_at = created_at + interval '3 days' WHERE expires_at IS NULL;"
        )
        print(f"✅ Updated existing items: {result}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(backfill_expires_at())
