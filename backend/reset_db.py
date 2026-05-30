"""
One-time script to drop all existing ENUM types and tables from Neon,
then let the app recreate them cleanly on next startup.

Run: python reset_db.py
"""
import asyncio
import asyncpg
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "")
# asyncpg uses postgresql:// not postgresql+asyncpg://
PG_URL = DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://").replace("?ssl=require", "")


async def reset():
    print(f"Connecting to: {PG_URL[:40]}...")
    conn = await asyncpg.connect(PG_URL, ssl="require")

    print("Dropping all tables...")
    await conn.execute("""
        DO $$ DECLARE
            r RECORD;
        BEGIN
            FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
                EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
            END LOOP;
        END $$;
    """)

    print("Dropping all custom ENUM types...")
    await conn.execute("""
        DO $$ DECLARE
            r RECORD;
        BEGIN
            FOR r IN (SELECT typname FROM pg_type
                      JOIN pg_namespace ON pg_namespace.oid = pg_type.typnamespace
                      WHERE pg_namespace.nspname = 'public' AND pg_type.typtype = 'e') LOOP
                EXECUTE 'DROP TYPE IF EXISTS ' || quote_ident(r.typname) || ' CASCADE';
            END LOOP;
        END $$;
    """)

    await conn.close()
    print("✅ Database reset complete! Now run: uvicorn app.main:app --reload --port 8000")


asyncio.run(reset())
