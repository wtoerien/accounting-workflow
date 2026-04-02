@AGENTS.md

# Accounting Workflow — Codebase Guide for AI Assistants

## Critical: Read Next.js Docs First

Before writing any Next.js code, read the relevant guide in `node_modules/next/dist/docs/`. This project uses **Next.js 16.2.1** — APIs, conventions, and file structure differ significantly from your training data. Heed all deprecation notices.

---

## Project Overview

A full-featured accounting practice management application for Australian accounting firms. Features: multi-user support, role-based access control, job templating, client management, and workflow step tracking.

**Stack:**
- **Framework:** Next.js 16.2.1 (App Router)
- **UI:** React 19 + TypeScript 5 + Tailwind CSS v4
- **ORM:** Prisma 7 with LibSQL adapter
- **Database:** SQLite (`prisma/dev.db`)
- **Auth:** Cookie-based sessions + bcryptjs

---

## Directory Structure

```
src/
├── app/
│   ├── (app)/                  # Protected route group (requires auth)
│   │   ├── dashboard/          # Stats overview
│   │   ├── clients/            # Client CRUD
│   │   ├── jobs/               # Job CRUD + step tracking
│   │   ├── templates/          # Job template CRUD
│   │   ├── users/              # User management (ADMIN/MANAGER only)
│   │   ├── practice/           # Practice settings (ADMIN only)
│   │   ├── layout.tsx          # Auth guard + sidebar layout
│   │   └── actions.ts          # logout action
│   ├── login/                  # Public auth route
│   │   ├── page.tsx
│   │   ├── login-form.tsx
│   │   └── actions.ts
│   ├── layout.tsx              # Root layout
│   └── page.tsx                # Redirects to /dashboard or /login
├── components/                 # Reusable client components
│   ├── sidebar.tsx
│   ├── job-form.tsx
│   ├── job-edit-form.tsx
│   ├── job-steps-panel.tsx
│   ├── client-form.tsx
│   ├── user-form.tsx
│   ├── template-form.tsx
│   └── practice-form.tsx
└── lib/
    ├── auth.ts                 # Session management + login logic
    ├── db.ts                   # Prisma client singleton
    └── seed.ts                 # Demo data seeder
prisma/
├── schema.prisma               # Database models
├── migrations/                 # Migration history
└── dev.db                      # SQLite file (not committed)
```

---

## Key Conventions

### Server Actions Pattern

All mutations use Next.js Server Actions with this signature:

```typescript
"use server";
export async function actionName(_prev: string | null, formData: FormData) {
  const session = await getSession();
  if (!session) return "Unauthorized";
  // validate, DB operation, then:
  revalidatePath("/path");
  redirect("/path");
}
```

Errors are returned as strings (never thrown). Success triggers `redirect()`.

### Form Components Pattern

Client components wire to server actions via `useActionState`:

```typescript
"use client";
const [error, formAction, pending] = useActionState(serverAction, null);
// <form action={formAction}>
// {error && <p className="text-red-600">{error}</p>}
// <button disabled={pending}>
```

### Data Fetching

- All data fetched **server-side** in `page.tsx` files (never in client components)
- Use `Promise.all()` for parallel queries
- Route params are `async`: `const { id } = await params`
- Include related data directly in Prisma queries via `include`

### Path Alias

Import using `@/` which maps to `src/`:
```typescript
import { getSession } from "@/lib/auth";
import { db } from "@/lib/db";
```

---

## Authentication & Authorization

**Session:** Cookie `userId` (7-day, httpOnly, secure in production, sameSite: lax).

```typescript
// src/lib/auth.ts
type SessionUser = { id, email, firstName, lastName, role, practiceId }
getSession()   // reads userId cookie → returns SessionUser or null
login(email, password)   // validates + returns SessionUser or null
hashPassword(password)   // bcrypt hash
```

**Role hierarchy:**
| Role | Permissions |
|------|-------------|
| `ADMIN` | Full access including practice settings and all user management |
| `MANAGER` | Can create/edit users with STAFF or MANAGER roles |
| `STAFF` | Can manage clients, jobs, templates (default role) |

Check authorization inside server actions:
```typescript
if (session.role !== "ADMIN") return "Unauthorized";
```

**Default seed credentials:**
- Email: `admin@demopractice.com`
- Password: `password`

Auto-seeding runs on first login if no Practice records exist.

---

## Database Schema

Models and their key relationships:

```
Practice (1) ─── (many) User
Practice (1) ─── (many) Client (via jobs)
Client    (1) ─── (many) Job
JobTemplate (1) ─── (many) TemplateStep
JobTemplate (1) ─── (many) Job
Job       (1) ─── (many) JobStep
TemplateStep (1) ─── (many) JobStep
```

**Enums:**
- `JobStatus`: `NOT_STARTED` | `IN_PROGRESS` | `ON_HOLD` | `COMPLETED` | `CANCELLED`
- `JobPriority`: `LOW` | `MEDIUM` | `HIGH` | `URGENT`
- `JobStepStatus`: `PENDING` | `IN_PROGRESS` | `COMPLETED` | `SKIPPED`
- `ClientType`: `INDIVIDUAL` | `BUSINESS`
- `UserRole`: `STAFF` | `MANAGER` | `ADMIN`

**Auto-status logic** (in `jobs/actions.ts`): when a step status is updated:
- All steps COMPLETED/SKIPPED → job status set to `COMPLETED`
- Any step IN_PROGRESS → job status set to `IN_PROGRESS`

---

## Styling Conventions

- **Tailwind CSS v4** utility classes only — no CSS modules or styled components
- Color coding: blue = primary/actions, green = completed/success, orange = in-progress/warning, red = errors/cancelled/urgent
- Status and priority are always rendered as color-coded inline badges
- Responsive via Tailwind grid/flex utilities

---

## Development Commands

```bash
npm run dev      # Start dev server at http://localhost:5000
npm run build    # Production build
npm run start    # Production server (port $PORT or 3000)
npm run lint     # ESLint (flat config, v9)
```

**Database:**
```bash
npx prisma migrate dev    # Run migrations (creates/updates dev.db)
npx prisma studio         # GUI database browser
npx prisma generate       # Regenerate Prisma client after schema changes
```

---

## Environment & Hosting

- Hosted on **Replit** (detected via `REPLIT_DEV_DOMAIN` env var)
- Node.js 20 (via `replit.nix`)
- No `.env` file required for local dev — database path is hardcoded as `file:prisma/dev.db`
- `next.config.ts` dynamically sets `allowedDevOrigins` for Replit preview domains

---

## What NOT to Do

- Do not add client-side data fetching (`useEffect` + `fetch`) — use server components
- Do not use `useState` for form state — use `useActionState` with server actions
- Do not import Prisma client directly in client components (`"use client"`)
- Do not use CSS modules or inline styles — Tailwind only
- Do not skip the `getSession()` auth check in any server action
- Do not read `node_modules/next/dist/docs/` path aliases — the docs live there but note that `node_modules` may not be installed in all environments
