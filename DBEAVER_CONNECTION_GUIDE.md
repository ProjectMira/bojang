# DBeaver Connection to Render PostgreSQL

## Step-by-Step Connection Guide

### 1. Get Connection Details from Render

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Navigate to your PostgreSQL service
3. Go to **Connect** tab
4. Copy the **External Database URL** (format: `postgresql://username:password@hostname:port/database`)

### 2. Parse the Connection String

From a URL like: `postgresql://bojang_user:abc123@dpg-xyz123-a.oregon-postgres.render.com:5432/bojang_db`

Extract:
- **Host**: `dpg-xyz123-a.oregon-postgres.render.com`
- **Port**: `5432`
- **Database**: `bojang_db`
- **Username**: `bojang_user`
- **Password**: `abc123`

### 3. Configure DBeaver

1. **Open DBeaver**
2. **New Database Connection** (+ icon or Ctrl+Shift+N)
3. **Select PostgreSQL** → Next
4. **Connection Settings**:
   - **Host**: [hostname from step 2]
   - **Port**: `5432`
   - **Database**: [database name from step 2]
   - **Username**: [username from step 2]
   - **Password**: [password from step 2]

### 4. SSL Configuration

1. Go to **SSL** tab in connection settings
2. **Use SSL**: Check this box
3. **SSL Mode**: Select `require` or `prefer`
4. Leave certificates empty (Render handles this)

### 5. Advanced Settings

1. Go to **Connection settings** → **Advanced**
2. Add parameter: `sslmode=require`

### 6. Test Connection

1. Click **Test Connection**
2. If prompted to download PostgreSQL driver, click **Download**
3. Connection should succeed

## Common Issues & Solutions

### Issue 1: Connection Timeout
**Solution**: 
- Check if your IP needs to be whitelisted
- Verify the hostname and port are correct
- Try connecting from a different network

### Issue 2: SSL Certificate Error
**Solution**:
- Set SSL mode to `require`
- Add `?sslmode=require` to connection string
- Don't specify SSL certificates (let Render handle it)

### Issue 3: Authentication Failed
**Solution**:
- Double-check username and password
- Ensure you're using the External Database URL, not Internal
- Copy-paste credentials to avoid typos

### Issue 4: Database Not Found
**Solution**:
- Verify database name in Render dashboard
- Make sure PostgreSQL service is running
- Check if database was created successfully

## Alternative: Using psql Command Line

If DBeaver doesn't work, try connecting via command line:

```bash
psql "postgresql://username:password@hostname:port/database"
```

## Firewall/Network Issues

If you're behind a corporate firewall:
1. Ask IT to whitelist Render's PostgreSQL ports
2. Try connecting from a different network
3. Use VPN if necessary

## Database Schema Verification

Once connected, verify your schema:

```sql
-- List all tables
\dt

-- Check if Prisma tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public';

-- Check if any data exists
SELECT COUNT(*) FROM "User";
SELECT COUNT(*) FROM "Category";
```

## Next Steps After Connection

1. **Run Prisma migrations** (if needed):
   ```bash
   npx prisma db push
   ```

2. **Seed the database**:
   ```bash
   npm run db:seed
   ```

3. **Verify data in DBeaver** by browsing tables
