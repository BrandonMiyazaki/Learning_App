# 📚 Learning App

A kid-friendly, multi-tenant web application where children can pick topics they want to learn each day and choose from different types of lessons. Parents manage households, create available lessons/topics, and track progress. The UI is designed to be simple, colorful, and intuitive for kids.

---

## Features

- **Household-based multi-tenancy** — each family is a separate tenant with a unique join code
- **Kid-friendly lesson board** — large icons, bright colors, and tap-based interactions
- **Points & leaderboard** — kids earn points for completed lessons and compete on a family leaderboard
- **Parent dashboard** — create/edit lessons and topics, track completions, manage household members
- **Celebratory animations** — confetti and stars when a lesson is completed
- **Simple PIN-based auth** — kids log in with their name and a short PIN

---

## Tech Stack

| Layer            | Technology                | Azure Service              |
|------------------|---------------------------|----------------------------|
| Frontend         | React (Vite) + Tailwind   | Azure App Service          |
| Backend API      | Node.js + Express         | Azure App Service          |
| Database / ORM   | Prisma + SQL Server       | Azure SQL Database         |
| Monitoring       | Application Insights SDK  | Azure Application Insights |
| CI/CD            | GitHub Actions            | —                          |
| Infrastructure   | Bicep (IaC)               | Azure Resource Manager     |

---

## Project Structure

```
Learning_App/
├── client/                    # React frontend (Vite)
│   ├── src/
│   │   ├── components/        # LessonCard, Avatar, PointsBadge, Navbar, etc.
│   │   ├── pages/             # Login, LessonBoard, MyLessons, Leaderboard, ParentDashboard
│   │   ├── context/           # Auth & household context
│   │   ├── hooks/             # Custom hooks
│   │   └── services/          # API call functions
│   └── package.json
│
├── server/                    # Express backend
│   ├── prisma/
│   │   └── schema.prisma      # Database schema (Households, Users, Lessons, CompletedLessons)
│   ├── src/
│   │   ├── routes/            # auth, lessons, completedLessons, users, household, leaderboard
│   │   ├── middleware/        # JWT auth, tenant scoping
│   │   └── utils/             # Join code generator, helpers
│   └── package.json
│
├── infra/                     # Azure Infrastructure as Code (Bicep)
│   ├── main.bicep             # Root template — orchestrates all modules
│   ├── modules/
│   │   ├── appService.bicep   # App Service + Plan + staging slot + private endpoint
│   │   ├── sqlDatabase.bicep  # Azure SQL Server + Database + private endpoint
│   │   ├── networking.bicep   # VNet, subnets, private DNS zones
│   │   └── monitoring.bicep   # Application Insights
│   └── parameters/
│       ├── dev.bicepparam     # Dev environment parameters
│       └── prod.bicepparam    # Prod environment parameters
│
├── .github/workflows/
│   └── deploy.yml             # CI/CD: build → deploy to staging → swap to production
│
├── PLAN.md                    # Full project plan & design docs
├── README.md
└── LICENSE
```

---

## Azure Infrastructure

All resources are provisioned via **Bicep** templates in the `infra/` directory. Authentication uses **Entra ID managed identity** (no SQL passwords). All services are secured with **private endpoints** — no public internet access.

| Resource             | Name Pattern                    | Notes                                      |
|----------------------|---------------------------------|--------------------------------------------|
| Resource Group       | `rg-learningapp-<env>`          | Container for all resources                |
| Virtual Network      | `vnet-learningapp-<env>`        | 10.0.0.0/16 with app integration & PE subnets |
| App Service Plan     | `plan-learningapp-<env>`        | Linux, B1 tier (supports slots & SSL)      |
| App Service          | `app-learningapp-<env>`         | Node.js 20 LTS + VNet integration + private endpoint |
| SQL Server           | `sql-learningapp-<env>`         | Azure SQL with Entra-only auth, private endpoint |
| SQL Database         | `sqldb-learningapp-<env>`       | General Purpose Serverless (auto-pause)    |
| Application Insights | `appi-learningapp-<env>`        | Performance & error monitoring             |
| Private DNS Zones    | `privatelink.*.net`             | DNS resolution for private endpoints       |

### Deploy Infrastructure

```bash
# Create the resource group
az group create --name rg-learningapp-dev --location westus2

# Deploy all resources (only jwtSecret needed — no SQL password)
az deployment group create \
  --resource-group rg-learningapp-dev \
  --template-file infra/main.bicep \
  --parameters infra/parameters/dev.bicepparam \
  --parameters jwtSecret='<your-jwt-secret>'
```

---

## Getting Started

### Prerequisites

- **Node.js 20+**
- **Docker** (for local SQL Server) or **Azure SQL Database**
- **Azure CLI** (for infrastructure deployment)

### Local Development

```bash
# 1. Start a local SQL Server with Docker
docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=YourStrong!Passw0rd" \
  -p 1433:1433 --name sql-learningapp -d mcr.microsoft.com/mssql/server:2022-latest

# 2. Configure the server environment
cd server
cp .env.example .env
# Set DATABASE_URL in .env:
# DATABASE_URL="sqlserver://localhost:1433;database=LearningApp;user=sa;password=YourStrong!Passw0rd;trustServerCertificate=true"

# 3. Install dependencies & run migrations
npm install
npx prisma migrate dev

# 4. Start the backend
npm run dev

# 5. In a separate terminal, start the frontend
cd client
npm install
npm run dev
```

---

## CI/CD

The project uses **GitHub Actions** (`.github/workflows/deploy.yml`) to automate builds and deployments:

1. On push to `main`, the workflow builds the React client and Express server.
2. The build artifact is deployed to the **staging** App Service slot.
3. After verification, the staging slot is **swapped** to production for zero-downtime releases.

**Required GitHub secret:** `AZURE_WEBAPP_PUBLISH_PROFILE`

---

## Implementation Status

- [x] **Phase 1 — Azure Infrastructure** — Bicep templates for App Service (with managed identity), SQL Database (Entra-only auth), Application Insights, staging slot, and CI/CD workflow
- [ ] **Phase 2 — Foundation (MVP)** — Prisma schema, auth endpoints, lesson CRUD, login & lesson board pages
- [ ] **Phase 3 — Core Features** — Parent dashboard, approval flow, leaderboard, profile, animations
- [ ] **Phase 4 — Polish & Production** — Responsive design, error handling, Application Insights SDK, custom domain
- [ ] **Phase 5 — Stretch Goals** — Rewards store, streaks, push notifications, recurring lessons, themes

See [PLAN.md](PLAN.md) for the full project plan, database schema, API endpoints, and design details.

---

## License

This project is licensed under the terms in the [LICENSE](LICENSE) file.
