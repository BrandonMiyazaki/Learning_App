# Chore App - Project Plan

## Overview

A kid-friendly, multi-tenant web application where children can pick chores, complete them, and earn points. Parents/admins manage households, assign available chores, and track progress. The UI is simple, colorful, and intuitive for kids.

---

## 1. Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            Azure Cloud (Resource Group)                 │
│                                                                        │
│  ┌──────────────────────┐       ┌────────────────────────┐             │
│  │  Azure App Service   │──────▶│   Azure SQL Database   │             │
│  │  (Linux, Node.js 20) │       │   (General Purpose)    │             │
│  │                      │       │                        │             │
│  │  Frontend: React     │       │  - Households          │             │
│  │  (static, served by  │       │  - Users (kids/parents)│             │
│  │   Express)           │       │  - Chores              │             │
│  │  Backend: Express API│       │  - CompletedChores     │             │
│  │                      │       │  - Points              │             │
│  │  Staging Slot ──┐    │       └────────────────────────┘             │
│  └─────────────────┼────┘                                              │
│                    │                                                   │
│  ┌─────────────────▼──────┐     ┌────────────────────────┐             │
│  │  Deployment Slots      │     │  Application Insights  │             │
│  │  - Production          │     │  (Monitoring & Logs)   │             │
│  │  - Staging             │     └────────────────────────┘             │
│  └────────────────────────┘                                            │
│                                                                        │
│  ┌────────────────────────┐                                            │
│  │  GitHub Actions CI/CD  │                                            │
│  │  (Build → Deploy)      │                                            │
│  └────────────────────────┘                                            │
└──────────────────────────────────────────────────────────────────────────┘
```

| Component           | Technology                  | Azure Service              |
|---------------------|-----------------------------|----------------------------|
| Frontend            | React (Vite)                | Azure App Service          |
| Backend API         | Node.js + Express           | Azure App Service          |
| Database            | SQL Server                  | Azure SQL Database         |
| Monitoring          | Application Insights SDK    | Azure Application Insights |
| Authentication      | Simple PIN/password per kid | Built-in (app-level)       |
| ORM                 | Prisma                      | —                          |
| CI/CD               | GitHub Actions              | —                          |
| Infrastructure      | Azure CLI / Bicep           | Azure Resource Manager     |

---

## 2. Multi-Tenancy Model

Each **household** is a tenant. Isolation is achieved via a `householdId` foreign key on all data tables.

- **Parent/Admin** creates a household and gets a join code.
- **Kids** join a household using the join code.
- All queries are scoped to the authenticated user's `householdId`.

---

## 3. Database Schema

### Tables

#### `Households`
| Column        | Type         | Notes                    |
|---------------|--------------|--------------------------|
| id            | INT (PK)     | Auto-increment           |
| name          | NVARCHAR(100)| e.g. "The Smith Family"  |
| joinCode      | NVARCHAR(10) | Unique, for kids to join |
| createdAt     | DATETIME     | Default GETDATE()        |

#### `Users`
| Column        | Type         | Notes                         |
|---------------|--------------|-------------------------------|
| id            | INT (PK)     | Auto-increment                |
| householdId   | INT (FK)     | References Households.id      |
| name          | NVARCHAR(50) | Display name                  |
| avatarUrl     | NVARCHAR(255)| Kid's chosen avatar           |
| pin           | NVARCHAR(10) | Simple PIN for kid login      |
| role          | NVARCHAR(10) | 'parent' or 'kid'             |
| totalPoints   | INT          | Running total, default 0      |
| createdAt     | DATETIME     | Default GETDATE()             |

#### `Chores`
| Column        | Type         | Notes                         |
|---------------|--------------|-------------------------------|
| id            | INT (PK)     | Auto-increment                |
| householdId   | INT (FK)     | References Households.id      |
| title         | NVARCHAR(100)| e.g. "Make your bed"          |
| description   | NVARCHAR(255)| Optional details              |
| points        | INT          | Points awarded on completion  |
| icon          | NVARCHAR(50) | Emoji or icon name            |
| isActive      | BIT          | Soft-delete / disable         |
| createdAt     | DATETIME     | Default GETDATE()             |

#### `CompletedChores`
| Column        | Type         | Notes                              |
|---------------|--------------|------------------------------------|
| id            | INT (PK)     | Auto-increment                     |
| choreId       | INT (FK)     | References Chores.id               |
| userId        | INT (FK)     | References Users.id (the kid)      |
| householdId   | INT (FK)     | References Households.id           |
| completedAt   | DATETIME     | When the chore was completed       |
| approvedByUserId | INT (FK)  | Parent who approved (nullable)     |
| status        | NVARCHAR(20) | 'pending', 'approved', 'rejected'  |
| pointsAwarded | INT          | Points given (copied from Chore)   |

#### `Rewards` *(stretch goal)*
| Column        | Type         | Notes                         |
|---------------|--------------|-------------------------------|
| id            | INT (PK)     | Auto-increment                |
| householdId   | INT (FK)     | References Households.id      |
| title         | NVARCHAR(100)| e.g. "Extra screen time"      |
| pointsCost    | INT          | Points required to redeem     |
| icon          | NVARCHAR(50) | Emoji or icon name            |
| isActive      | BIT          | Soft-delete / disable         |

---

## 4. API Endpoints

### Auth
| Method | Endpoint              | Description                      |
|--------|-----------------------|----------------------------------|
| POST   | /api/auth/register    | Create household + parent user   |
| POST   | /api/auth/join        | Kid joins household via joinCode |
| POST   | /api/auth/login       | Login with name + PIN            |

### Households
| Method | Endpoint                    | Description                  |
|--------|-----------------------------|------------------------------|
| GET    | /api/household               | Get current household info   |
| PUT    | /api/household               | Update household (parent)    |

### Users
| Method | Endpoint                    | Description                  |
|--------|-----------------------------|------------------------------|
| GET    | /api/users                   | List users in household      |
| GET    | /api/users/:id               | Get user profile + points    |
| PUT    | /api/users/:id               | Update avatar/name           |

### Chores
| Method | Endpoint                    | Description                  |
|--------|-----------------------------|------------------------------|
| GET    | /api/chores                  | List active chores           |
| POST   | /api/chores                  | Create chore (parent only)   |
| PUT    | /api/chores/:id              | Edit chore (parent only)     |
| DELETE | /api/chores/:id              | Deactivate chore (parent)    |

### Completed Chores
| Method | Endpoint                          | Description                    |
|--------|-----------------------------------|--------------------------------|
| POST   | /api/chores/:id/complete          | Kid marks chore as done        |
| GET    | /api/completed-chores             | List completed (filterable)    |
| PUT    | /api/completed-chores/:id/approve | Parent approves completion     |
| PUT    | /api/completed-chores/:id/reject  | Parent rejects completion      |

### Leaderboard
| Method | Endpoint                    | Description                       |
|--------|-----------------------------|-----------------------------------|
| GET    | /api/leaderboard             | Points ranking within household  |

---

## 5. Frontend Pages & UI

All pages use large text, bright colors, rounded corners, and fun icons/emojis to be kid-friendly.

### Pages

| Page                | Route              | Description                                         |
|---------------------|--------------------|-----------------------------------------------------|
| **Welcome/Login**   | `/`                | Pick your name/avatar, enter PIN                    |
| **Chore Board**     | `/chores`          | Grid of available chores with icons & points        |
| **My Chores**       | `/my-chores`       | Kid's completed/pending chores history               |
| **Leaderboard**     | `/leaderboard`     | Fun scoreboard showing all kids' points             |
| **Profile**         | `/profile`         | Kid's avatar, total points, streaks                 |
| **Parent Dashboard**| `/parent`          | Manage chores, approve completions, manage kids     |
| **Setup Household** | `/setup`           | Create household, get join code                     |

### UI Design Principles
- **Large tap targets** (buttons ≥ 48px)
- **Bright, pastel color palette** (friendly, not overwhelming)
- **Emoji icons** for chores (🧹🛏️🍽️🐕🗑️)
- **Celebratory animations** when a chore is completed (confetti, stars)
- **Simple navigation** — bottom tab bar on mobile, sidebar on desktop
- **Avatar selection** for each kid (animals, characters)
- **Points displayed prominently** with fun counters
- **Minimal text input** — mostly tap-based interactions

### Wireframe Concepts

```
┌─────────────────────────────────┐
│  🏠 The Smith Family            │
│  ⭐ 45 points      [Avatar]    │
├─────────────────────────────────┤
│                                 │
│  Pick a Chore!                  │
│                                 │
│  ┌──────┐  ┌──────┐  ┌──────┐  │
│  │ 🛏️   │  │ 🧹   │  │ 🍽️   │  │
│  │ Make  │  │ Sweep│  │ Set  │  │
│  │ Bed   │  │ Floor│  │ Table│  │
│  │ 10pts │  │ 15pts│  │ 10pts│  │
│  │ [DO!] │  │ [DO!]│  │ [DO!]│  │
│  └──────┘  └──────┘  └──────┘  │
│                                 │
│  ┌──────┐  ┌──────┐  ┌──────┐  │
│  │ 🐕   │  │ 🗑️   │  │ 📚   │  │
│  │ Feed  │  │ Take │  │ Read │  │
│  │ Dog   │  │ Trash│  │ Book │  │
│  │ 15pts │  │ 10pts│  │ 20pts│  │
│  │ [DO!] │  │ [DO!]│  │ [DO!]│  │
│  └──────┘  └──────┘  └──────┘  │
│                                 │
├─────────────────────────────────┤
│  🏠 Home  📋 My Chores  🏆 Board│
└─────────────────────────────────┘
```

---

## 6. Project Structure

```
Chore_App/
├── client/                    # React frontend (Vite)
│   ├── public/
│   ├── src/
│   │   ├── assets/            # Images, icons, avatars
│   │   ├── components/        # Reusable UI components
│   │   │   ├── ChoreCard.jsx
│   │   │   ├── Avatar.jsx
│   │   │   ├── PointsBadge.jsx
│   │   │   ├── Navbar.jsx
│   │   │   └── ConfettiEffect.jsx
│   │   ├── pages/
│   │   │   ├── Login.jsx
│   │   │   ├── ChoreBoard.jsx
│   │   │   ├── MyChores.jsx
│   │   │   ├── Leaderboard.jsx
│   │   │   ├── Profile.jsx
│   │   │   ├── ParentDashboard.jsx
│   │   │   └── SetupHousehold.jsx
│   │   ├── context/           # Auth & household context
│   │   ├── hooks/             # Custom hooks
│   │   ├── services/          # API call functions
│   │   ├── App.jsx
│   │   └── main.jsx
│   ├── index.html
│   ├── vite.config.js
│   └── package.json
│
├── server/                    # Express backend
│   ├── prisma/
│   │   ├── schema.prisma      # Database schema
│   │   └── migrations/        # Prisma migration history
│   ├── src/
│   │   ├── routes/
│   │   │   ├── auth.js
│   │   │   ├── chores.js
│   │   │   ├── completedChores.js
│   │   │   ├── users.js
│   │   │   ├── household.js
│   │   │   └── leaderboard.js
│   │   ├── middleware/
│   │   │   ├── auth.js        # JWT/session verification
│   │   │   └── tenantScope.js # Ensure householdId scoping
│   │   ├── utils/
│   │   │   └── joinCode.js    # Generate unique join codes
│   │   ├── app.js
│   │   └── server.js
│   ├── package.json
│   └── .env                   # Local dev only — never commit
│
├── infra/                     # Azure Infrastructure as Code
│   ├── main.bicep             # Root Bicep template
│   ├── modules/
│   │   ├── appService.bicep   # App Service + Plan
│   │   ├── sqlDatabase.bicep  # Azure SQL Server + Database
│   │   └── monitoring.bicep   # Application Insights
│   └── parameters/
│       ├── dev.bicepparam      # Dev environment parameters
│       └── prod.bicepparam     # Prod environment parameters
│
├── .github/
│   └── workflows/
│       └── deploy.yml         # GitHub Actions CI/CD pipeline
│
├── .gitignore
├── README.md
├── PLAN.md
└── LICENSE
```

---

## 7. Implementation Phases

### Phase 1: Azure Infrastructure Setup ✅
- [x] Create Azure Resource Group (`rg-choreapp-<env>`) — defined in Bicep (main.bicep)
- [x] Provision Azure SQL Server and Database via Bicep/CLI — `infra/modules/sqlDatabase.bicep`
- [x] Configure Azure SQL firewall rules (allow Azure services, dev IPs) — firewall rule in sqlDatabase.bicep
- [x] Provision Azure App Service Plan (Linux, B1 tier) — `infra/modules/appService.bicep`
- [x] Provision Azure App Service (Node.js 20 LTS) — `infra/modules/appService.bicep`
- [x] Provision Application Insights and connect to App Service — `infra/modules/monitoring.bicep`
- [x] Configure App Service settings (connection string, JWT secret, Node env) — appService.bicep appSettings
- [x] Create staging deployment slot on App Service — staging slot in appService.bicep
- [x] Set up GitHub Actions CI/CD workflow with Azure deployment — `.github/workflows/deploy.yml`

### Phase 2: Foundation (MVP)
- [ ] Initialize React (Vite) frontend project
- [ ] Initialize Node.js/Express backend project
- [ ] Set up Prisma with Azure SQL DB connection string (`sqlserver://` provider)
- [ ] Create database schema and run Prisma migrations against Azure SQL
- [ ] Add health-check endpoint (`GET /api/health`) for App Service monitoring
- [ ] Build auth endpoints (register household, join, login with PIN)
- [ ] Build chore CRUD endpoints (parent-only create/edit/delete)
- [ ] Build chore completion endpoint (kid marks done)
- [ ] Build Login page (pick name, enter PIN)
- [ ] Build Chore Board page (grid of chore cards)
- [ ] Build basic navigation (bottom tab bar)
- [ ] Verify first deploy to Azure App Service staging slot

### Phase 3: Core Features
- [ ] Build Parent Dashboard (manage chores, see pending approvals)
- [ ] Build approval/rejection flow for completed chores
- [ ] Build My Chores page (kid's history)
- [ ] Build Leaderboard page (points ranking)
- [ ] Build Profile page (avatar, total points)
- [ ] Add celebratory animations (confetti on chore completion)
- [ ] Add avatar selection system

### Phase 4: Polish & Production Deploy
- [ ] Responsive design (mobile-first)
- [ ] Error handling & loading states
- [ ] Input validation (frontend + backend)
- [ ] Integrate Application Insights SDK for server-side telemetry
- [ ] Configure custom domain and managed SSL certificate on App Service
- [ ] Enable Azure SQL automated backups and geo-redundancy review
- [ ] Load-test and verify DTU/vCore scaling on Azure SQL
- [ ] Swap staging slot → production for zero-downtime release
- [ ] Add seed data (default chore templates)

### Phase 5: Stretch Goals
- [ ] Rewards store (kids spend points on rewards)
- [ ] Weekly/daily chore streaks
- [ ] Push notifications for pending approvals
- [ ] Chore scheduling (recurring chores)
- [ ] Dark mode / theme selection
- [ ] Sound effects for interactions
- [ ] Enable autoscaling on App Service Plan for traffic spikes

---

## 8. Azure Deployment Plan

### 8.1 Resource Naming Convention

| Resource               | Name Pattern                            |
|------------------------|-----------------------------------------|
| Resource Group         | `rg-choreapp-<env>`                     |
| App Service Plan       | `plan-choreapp-<env>`                   |
| App Service            | `app-choreapp-<env>`                    |
| SQL Server             | `sql-choreapp-<env>`                    |
| SQL Database           | `sqldb-choreapp-<env>`                  |
| Application Insights   | `appi-choreapp-<env>`                   |

> `<env>` = `dev`, `staging`, or `prod`

### 8.2 Azure SQL Database

- **SKU:** General Purpose — Serverless (auto-pause after inactivity to save cost; scales 0.5–2 vCores)
  - Alternative: Basic tier (5 DTU) for predictable low-traffic workloads
- **Firewall Rules:**
  - Allow Azure services (required for App Service connectivity)
  - Add developer IPs for local Prisma migrations
- **Connection String:** Stored as an **App Service Connection String** (type: `SQLAzure`), never in code
  - Format: `sqlserver://<server>.database.windows.net:1433;database=<db>;user=<user>;password=<pass>;encrypt=true;trustServerCertificate=false`
- **Prisma Provider:** `sqlserver` (Prisma supports Azure SQL natively)
- **Backups:** Azure SQL automated backups (7-day retention on Basic; 35-day on General Purpose)
- **Security:**
  - Enforce TLS 1.2 minimum
  - Use a strong admin password; rotate periodically
  - Consider Azure AD authentication for admin access

### 8.3 Azure App Service

- **Plan:** B1 (Basic) — supports custom domains, SSL, deployment slots
  - Scale up to S1/P1v3 if staging slots or autoscaling are needed
- **OS:** Linux
- **Stack:** Node.js 20 LTS
- **Startup Command:** `node server/src/server.js`
- **Deployment Slots:**
  - `production` — live traffic
  - `staging` — deploy here first, then swap for zero-downtime releases
- **Health Check:** Configure App Service health check to ping `GET /api/health`
- **Always On:** Enable to prevent cold starts
- **HTTPS Only:** Enable (redirect HTTP → HTTPS)

#### App Service Configuration (Environment Variables)

| Setting            | Source                     | Notes                              |
|--------------------|----------------------------|------------------------------------|
| `DATABASE_URL`     | Connection Strings (Azure) | Azure SQL connection string        |
| `JWT_SECRET`       | App Settings               | Secret for signing JWT tokens      |
| `NODE_ENV`         | App Settings               | `production`                       |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | App Settings | Auto-injected if AI is linked |
| `WEBSITE_NODE_DEFAULT_VERSION` | App Settings    | `~20`                              |
| `SCM_DO_BUILD_DURING_DEPLOYMENT` | App Settings  | `true` (run `npm install` on deploy) |

### 8.4 Application Insights (Monitoring)

- Provision an Application Insights resource linked to the App Service
- Install `applicationinsights` npm package in the server
- Track:
  - Request rates, response times, failure rates
  - Dependency calls (Azure SQL query performance)
  - Custom events (chore completions, approvals)
- Use **Live Metrics** for real-time monitoring
- Set up **Alerts** for error rate spikes or high response times

### 8.5 Infrastructure as Code (Bicep)

All Azure resources are defined in Bicep templates under `infra/`:

```bicep
// infra/main.bicep (simplified overview)
param environmentName string
param location string = resourceGroup().location

module appService 'modules/appService.bicep' = {
  name: 'appService'
  params: {
    appName: 'app-choreapp-${environmentName}'
    planName: 'plan-choreapp-${environmentName}'
    location: location
    nodeVersion: '20-lts'
  }
}

module sqlDatabase 'modules/sqlDatabase.bicep' = {
  name: 'sqlDatabase'
  params: {
    serverName: 'sql-choreapp-${environmentName}'
    databaseName: 'sqldb-choreapp-${environmentName}'
    location: location
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    appInsightsName: 'appi-choreapp-${environmentName}'
    location: location
  }
}
```

**Deploy infrastructure:**
```bash
az group create --name rg-choreapp-dev --location eastus
az deployment group create \
  --resource-group rg-choreapp-dev \
  --template-file infra/main.bicep \
  --parameters environmentName=dev
```

### 8.6 Deployment Steps

1. **Provision infrastructure** — Run Bicep deployment to create Resource Group, App Service, SQL Database, and Application Insights
2. **Configure SQL firewall** — Allow your dev IP and Azure services
3. **Set connection string** — Add Azure SQL connection string to App Service Configuration
4. **Run Prisma migrations** — `npx prisma migrate deploy` against Azure SQL from a local machine or CI
5. **Seed database** — `npx prisma db seed` for default chore templates
6. **Configure GitHub Actions** — Add `AZURE_WEBAPP_PUBLISH_PROFILE` secret to the GitHub repo
7. **Push to `main`** — GitHub Actions builds and deploys to the staging slot
8. **Verify staging** — Test the staging slot URL (`app-choreapp-dev-staging.azurewebsites.net`)
9. **Swap to production** — Swap staging → production slot for zero-downtime release

### 8.7 GitHub Actions CI/CD Workflow

```yaml
name: Build and Deploy to Azure App Service

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  AZURE_WEBAPP_NAME: app-choreapp-prod
  NODE_VERSION: '20.x'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: '**/package-lock.json'

      - name: Install client dependencies
        working-directory: ./client
        run: npm ci

      - name: Build React app
        working-directory: ./client
        run: npm run build

      - name: Copy client build to server/public
        run: cp -r client/dist server/public

      - name: Install server dependencies
        working-directory: ./server
        run: npm ci --omit=dev

      - name: Generate Prisma client
        working-directory: ./server
        run: npx prisma generate

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-package
          path: server/

  deploy:
    runs-on: ubuntu-latest
    needs: build
    environment:
      name: production
      url: ${{ steps.deploy.outputs.webapp-url }}
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: app-package
          path: server/

      - name: Deploy to Azure App Service (staging slot)
        id: deploy
        uses: azure/webapps-deploy@v3
        with:
          app-name: ${{ env.AZURE_WEBAPP_NAME }}
          slot-name: staging
          publish-profile: ${{ secrets.AZURE_WEBAPP_PUBLISH_PROFILE }}
          package: server/

      - name: Swap staging to production
        uses: azure/cli@v2
        with:
          inlineScript: |
            az webapp deployment slot swap \
              --resource-group rg-choreapp-prod \
              --name ${{ env.AZURE_WEBAPP_NAME }} \
              --slot staging \
              --target-slot production
```

### 8.8 Local Development vs. Azure

| Concern             | Local Development                        | Azure Production                          |
|---------------------|------------------------------------------|-------------------------------------------|
| Database            | SQL Server in Docker or LocalDB          | Azure SQL Database                        |
| Connection String   | `.env` file (`DATABASE_URL`)             | App Service Configuration (Connection Strings) |
| Node.js             | Installed locally (v20)                  | App Service runtime (Node 20 LTS)         |
| HTTPS               | Optional (http://localhost)              | Enforced (HTTPS Only enabled)             |
| Monitoring          | Console logs                             | Application Insights + Log Stream         |
| Deployment          | `npm run dev`                            | GitHub Actions → App Service              |

#### Running Locally with Docker (SQL Server)
```bash
# Start a local SQL Server for development
docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=YourStrong!Passw0rd" \
  -p 1433:1433 --name sql-choreapp -d mcr.microsoft.com/mssql/server:2022-latest

# Set DATABASE_URL in server/.env
# DATABASE_URL="sqlserver://localhost:1433;database=ChoreApp;user=sa;password=YourStrong!Passw0rd;trustServerCertificate=true"

# Run migrations
cd server && npx prisma migrate dev
```

---

## 9. Key Libraries & Dependencies

### Frontend (`client/`)
| Package              | Purpose                          |
|----------------------|----------------------------------|
| react                | UI framework                     |
| react-router-dom     | Client-side routing              |
| axios                | HTTP requests                    |
| canvas-confetti      | Celebration animations           |
| react-icons          | Icon library                     |
| tailwindcss          | Utility-first CSS styling        |

### Backend (`server/`)
| Package              | Purpose                          |
|----------------------|----------------------------------|
| express              | Web framework                    |
| @prisma/client       | ORM for Azure SQL                |
| prisma               | Schema & migrations (dev dep)    |
| jsonwebtoken         | JWT auth tokens                  |
| bcryptjs             | PIN hashing                      |
| cors                 | Cross-origin requests            |
| dotenv               | Environment variable loading     |
| helmet               | Security headers                 |
| express-rate-limit   | Rate limiting                    |
| applicationinsights  | Azure Application Insights SDK   |

---

## 10. Security Considerations

- All API routes scoped by `householdId` — no cross-tenant data access
- PINs hashed with bcrypt before storage
- JWT tokens with short expiry for session management
- Helmet for HTTP security headers
- Rate limiting on auth endpoints
- Input sanitization on all user inputs
- Parameterized queries via Prisma (SQL injection prevention)
- HTTPS enforced in production (Azure App Service "HTTPS Only" setting)
- Azure SQL connection encrypted with TLS 1.2
- Secrets stored in App Service Configuration — never committed to source control
- Deployment slots used for safe, zero-downtime releases
- App Service Managed Identity can be used for Azure SQL access (eliminates passwords in connection strings)
- Enable Azure SQL auditing and threat detection for production

---

## 11. Default Chore Templates (Seed Data)

| Chore             | Icon | Points |
|-------------------|------|--------|
| Make your bed     | 🛏️   | 10     |
| Sweep the floor   | 🧹   | 15     |
| Set the table     | 🍽️   | 10     |
| Feed the pet      | 🐕   | 15     |
| Take out trash    | 🗑️   | 10     |
| Read for 20 min   | 📚   | 20     |
| Clean your room   | 🧽   | 20     |
| Do the dishes     | 🫧   | 15     |
| Water the plants  | 🌱   | 10     |
| Put away laundry  | 👕   | 15     |

---

*Ready to start building? Begin with Phase 1!*
