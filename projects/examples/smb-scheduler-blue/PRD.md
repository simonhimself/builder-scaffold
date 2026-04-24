# Product Requirements Document: SMB Scheduler

**Project Name:** SMB Scheduler  
**Version:** 1.3  
**Date:** March 2026  
**Status:** Customer Readiness Execution

---

## Executive Summary

SMB Scheduler is a multi-tenant appointment scheduling platform designed for small and medium businesses in the DACH region (Germany, Austria, Switzerland). The platform provides an affordable, modern alternative to expensive legacy scheduling software, targeting service-based businesses such as hair salons, nail salons, barber shops, and similar appointment-based operations.

The system consists of three main components:

- **Customer Booking App**: Public-facing interface for customers to book appointments
- **Admin Dashboard**: Business management interface for owners/staff
- **API**: Cloudflare Workers-based backend with D1 database

The platform emphasizes simplicity, bilingual support (German/English), and a mobile-friendly experience that reduces phone-based booking overhead for business owners.

## Go-Live Scope Update (March 2026)

This PRD now tracks the transition from "feature-complete codebase" to "customer-usable product".

### Updated Payment Scope

Payments are **SaaS billing for businesses using SMB Scheduler**, not consumer checkout during appointment booking.

- In-scope: business subscription billing (plans, trial, checkout, billing portal)
- Out-of-scope for current launch: end-customer payment collection, deposits, and POS-style payment flows

### Customer Readiness Definition

The product is considered customer-ready when:

1. A new business can self-onboard and create its first admin account.
2. A subscribed business can complete end-to-end workflows (set up services/staff/schedules, receive bookings, manage bookings).
3. The deployed production environment is secure by default (no demo credentials, no unsafe admin paths, production CORS/auth/secrets configured).
4. Core communication flows (transactional email confirmations/reminders) work on real infrastructure.

---

## Goals and Objectives

### Primary Goals

- **Democratize scheduling software**: Provide enterprise-grade scheduling at SMB-friendly pricing
- **Reduce administrative burden**: Enable customer self-service booking, reducing phone calls and manual scheduling
- **Modernize legacy workflows**: Replace paper calendars and outdated software with intuitive web-based tools
- **Serve the DACH market**: Native German language support with European timezone and currency defaults

### Business Objectives

- Achieve product-market fit with hair/nail salons in Switzerland
- Validate pricing model before expanding to broader DACH market
- Implement SaaS subscription billing for businesses (recurring revenue from platform usage)

### Technical Objectives

- Demonstrate Cloudflare Workers + D1 as viable stack for SaaS applications
- Maintain sub-200ms API response times at edge
- Support multi-tenant architecture from day one

---

## Target Audience

### Primary Users: Business Owners/Operators

**Profile:**

- Small business owners (1-10 employees)
- Hair salons, nail salons, barber shops, beauty studios
- Located in DACH region
- Currently using paper calendars, spreadsheets, or expensive legacy software
- Limited technical expertise
- Value simplicity over feature abundance

**Jobs to Be Done:**

- Manage daily appointment schedule efficiently
- Track customer information and history
- Understand business performance (bookings, revenue)
- Reduce no-shows and last-minute cancellations

### Secondary Users: Customers

**Profile:**

- Customers of the businesses above
- Mix of ages, varying technical comfort
- Prefer self-service over phone calls
- Expect mobile-friendly experience
- May speak German or English

**Jobs to Be Done:**

- Book appointments at convenient times
- View and manage existing bookings
- Reschedule or cancel when plans change
- Receive reminders before appointments

---

## Core Concepts

### Business (Tenant)

The top-level entity representing a single business using the platform.

| Field    | Description                                 |
| -------- | ------------------------------------------- |
| id       | Unique identifier (UUID)                    |
| name     | Business display name                       |
| slug     | URL-friendly identifier for booking pages   |
| email    | Contact email                               |
| phone    | Contact phone                               |
| address  | Physical location                           |
| timezone | Business timezone (default: Europe/Zurich)  |
| currency | Display currency (default: CHF)             |
| locale   | Primary language (en/de)                    |
| settings | JSON configuration (booking policies, etc.) |

### Service

A bookable offering provided by the business.

| Field               | Description                             |
| ------------------- | --------------------------------------- |
| id                  | Unique identifier                       |
| business_id         | Parent business                         |
| name                | Service name (supports EN/DE)           |
| description         | Service description (supports EN/DE)    |
| duration            | Length in minutes                       |
| price               | Cost in business currency               |
| buffer_before       | Minutes blocked before appointment      |
| buffer_after        | Minutes blocked after appointment       |
| min_advance_booking | Minimum hours before booking allowed    |
| max_advance_booking | Maximum days in advance booking allowed |
| active              | Whether service is bookable             |

### Staff

An employee who performs services.

| Field         | Description                             |
| ------------- | --------------------------------------- |
| id            | Unique identifier                       |
| business_id   | Parent business                         |
| name          | Staff member name                       |
| email         | Contact email                           |
| phone         | Contact phone                           |
| color         | Calendar display color                  |
| can_be_booked | Whether customers can select this staff |
| active        | Whether staff is active                 |

### Schedule

Weekly recurring working hours for staff.

| Field       | Description                 |
| ----------- | --------------------------- |
| staff_id    | Associated staff member     |
| day_of_week | 0-6 (Sunday-Saturday)       |
| start_time  | Shift start (HH:MM)         |
| end_time    | Shift end (HH:MM)           |
| breaks      | JSON array of break periods |

### Schedule Exception

Overrides to regular schedule (holidays, sick days, special hours).

| Field       | Description                                  |
| ----------- | -------------------------------------------- |
| id          | Unique identifier                            |
| business_id | Parent business (for business-wide closures) |
| staff_id    | Specific staff (for individual exceptions)   |
| date        | Date of exception                            |
| type        | closed / special_hours                       |
| start_time  | Override start (if special_hours)            |
| end_time    | Override end (if special_hours)              |

### Customer

A person who books appointments.

| Field             | Description                                      |
| ----------------- | ------------------------------------------------ |
| id                | Unique identifier                                |
| business_id       | Parent business                                  |
| first_name        | Customer first name                              |
| last_name         | Customer last name                               |
| email             | Contact email                                    |
| phone             | Contact phone                                    |
| notes             | Admin notes about customer                       |
| tags              | JSON array for categorization                    |
| source            | How customer was acquired (online/phone/walk-in) |
| gdpr_consent      | Data processing consent                          |
| marketing_consent | Marketing communications consent                 |

### Appointment

A scheduled booking.

| Field              | Description                                   |
| ------------------ | --------------------------------------------- |
| id                 | Unique identifier                             |
| business_id        | Parent business                               |
| service_id         | Booked service                                |
| staff_id           | Assigned staff member                         |
| customer_id        | Booking customer                              |
| start_time         | Appointment start (UTC)                       |
| end_time           | Appointment end (UTC)                         |
| status             | pending/confirmed/cancelled/completed/no_show |
| price              | Actual price charged                          |
| notes              | Customer-provided notes                       |
| internal_notes     | Admin-only notes                              |
| confirmation_token | Unique token for customer access              |
| source             | Booking origin (online/admin)                 |

---

## Feature Requirements

### P0: Must Have (MVP)

#### F1: Customer Booking Flow

Customers can book appointments through a multi-step wizard.

**Requirements:**

- Select from available services
- Choose date and available time slot
- Optionally select preferred staff member
- Enter contact information (name, email/phone)
- Receive confirmation with booking details
- Access booking via confirmation token URL

**Acceptance Criteria:**

- Booking completes in 4 steps or fewer
- Only active services displayed
- Only available time slots shown
- Confirmation token generated and displayed
- Booking persisted to database

#### F2: Availability Engine

Calculate available time slots based on schedules and existing appointments.

**Requirements:**

- Generate slots from staff working hours
- Exclude times with existing appointments
- Account for service duration and buffers
- Respect min/max advance booking settings
- Handle schedule exceptions (holidays, special hours)

**Acceptance Criteria:**

- No double-booking possible for same staff
- Buffer times respected between appointments
- Closed days show no availability
- Past times never shown as available

#### F3: Admin Service Management

Business owners can manage their service offerings.

**Requirements:**

- Create, edit, archive services
- Set pricing, duration, buffers
- Assign staff to services
- Support bilingual content (EN/DE)

**Acceptance Criteria:**

- Services appear in booking flow when active
- Archived services hidden from booking
- Existing appointments unaffected by archive

#### F4: Admin Staff Management

Business owners can manage staff and schedules.

**Requirements:**

- Create, edit, archive staff members
- Set weekly recurring schedules
- Add schedule exceptions (vacation, sick days)
- Assign services staff can perform

**Acceptance Criteria:**

- Staff schedules reflected in availability
- Exceptions override regular schedule
- Staff without schedule shows no availability

#### F5: Admin Appointment Management

Business owners can view and manage appointments.

**Requirements:**

- View appointments in list and calendar views
- Create appointments manually (walk-ins, phone bookings)
- Edit appointment details
- Change appointment status
- Cancel appointments

**Acceptance Criteria:**

- Calendar supports both day and week views for appointments
- Manual booking checks availability
- Status changes reflected immediately
- Cancelled appointments free the time slot

### P1: Should Have

#### F6: Email Notifications

Automated email communication for booking lifecycle.

**Requirements:**

- Send confirmation email on booking
- Send cancellation confirmation
- Send reschedule confirmation
- Include ICS calendar attachment
- Include manage booking link
- Use per-business, template-driven notification content (EN/DE)
- Send notifications asynchronously through a queue with retry support

**Acceptance Criteria:**

- Emails sent within 60 seconds of trigger
- ICS file opens in common calendar apps
- Links in email functional
- Email content is generated from configured templates, not hardcoded strings
- Failed sends are retried and routed to dead-letter handling after retry exhaustion

#### F7: Customer Booking Management

Customers can manage their existing bookings.

**Requirements:**

- View booking details via token URL
- Cancel booking (respecting policy)
- Reschedule booking (respecting policy)
- See cancellation/reschedule policy

**Acceptance Criteria:**

- Cancel button disabled if within policy window
- Reschedule shows available alternative times
- Policy hours displayed match enforced policy

#### F8: Customer CRM

Track customer information and history.

**Requirements:**

- Automatic customer creation on booking
- Match returning customers by email/phone
- View customer booking history
- Add notes and tags
- Track customer analytics (visits, revenue)

**Acceptance Criteria:**

- Repeat customers linked to same record
- Booking history accurate and complete
- Analytics calculated correctly

#### F9: Business Settings

Configure business behavior and policies.

**Requirements:**

- Set business information
- Configure timezone, currency, locale
- Set booking policies (cancellation, rescheduling)
- Configure notification preferences
- Enable/disable reminder notifications per business

**Acceptance Criteria:**

- Settings changes take effect immediately
- Timezone affects all time displays
- Policies enforced in booking flow
- When reminders are disabled, no reminder notifications are sent

#### F10: Business Subscription Billing (Launch Scope)

Charge businesses for access to SMB Scheduler.

**Requirements:**

- Plan configuration (monthly/yearly, trial period)
- Hosted checkout for subscription start
- Billing portal access for plan updates/cancellations/payment method changes
- Subscription status persisted per business (trialing/active/past_due/canceled)
- Access control for admin usage based on subscription status

**Acceptance Criteria:**

- A newly registered business can start a trial and activate subscription through checkout
- Billing webhooks update subscription state reliably and idempotently
- Past-due or canceled accounts are restricted according to defined policy
- Billing settings are visible and actionable in the admin app

### P2: Nice to Have

#### F11: Admin Dashboard

Overview of business performance.

**Requirements:**

- Display key metrics (bookings, revenue)
- Show upcoming appointments
- Visualize trends over time
- Staff utilization summary

**Acceptance Criteria:**

- Metrics accurate for selected period
- Charts render without errors
- Data refreshes appropriately

#### F12: Reminder Notifications

Proactive reminders before appointments.

**Requirements:**

- Send reminder emails at configured intervals
- Configurable reminder timing (24h, 2h before)
- Include appointment details and manage link
- Respect per-business reminder enable/disable preference

**Acceptance Criteria:**

- Reminders sent at configured times
- No reminders for cancelled appointments
- No reminders sent when reminder notifications are disabled

### P3: Future (Out of Scope for v1.0)

- **End-customer payments**: Online payment collection, deposits
- **Recurring Appointments**: Standing appointments
- **Multi-location**: Businesses with multiple venues
- **Mobile App**: Native iOS/Android applications
- **SMS Notifications**: Text message reminders
- **Waitlist**: Notification when slots open
- **Reviews**: Customer feedback collection
- **Integrations**: Google Calendar, external calendars
- **Advanced Analytics**: Detailed reporting, exports
- **Resource Booking**: Rooms, equipment management

---

## Technical Architecture

### Stack Overview

| Layer            | Technology                                 |
| ---------------- | ------------------------------------------ |
| Frontend         | React 18, Vite, TypeScript, TailwindCSS    |
| UI Components    | shadcn/ui (Radix primitives)               |
| State Management | Zustand, TanStack Query                    |
| API              | Cloudflare Workers, Hono framework         |
| Database         | Cloudflare D1 (SQLite)                     |
| Deployment       | Cloudflare Pages (frontend), Workers (API) |

### Cloudflare-First Platform Decisions

- Core platform is Cloudflare-native for runtime, data, caching, scheduling, and async processing.
- Notification dispatch should run through Cloudflare Queues with retries and dead-letter handling.
- Transactional email should use Cloudflare-native email capabilities when available for the deployment setup.
- If a fully Cloudflare-native email path is not available for a specific environment, use a swappable provider adapter without changing product behavior.
- SMS remains an external-provider integration behind the same notification adapter boundary.

### Monorepo Structure

```
smb-scheduler/
├── apps/
│   ├── web/          # Customer booking (port 5173)
│   └── admin/        # Admin dashboard (port 5174)
├── packages/
│   ├── api/          # Cloudflare Workers API (includes migrations/)
│   ├── db/           # Database seed scripts
│   ├── shared/       # Shared types and utilities
│   └── ui/           # Shared UI components
├── e2e/              # End-to-end tests (Playwright)
├── specs/            # Feature specifications
├── AGENTS.md         # Development guidelines
├── PRD.md            # This document
└── IMPLEMENTATION_PLAN.md
```

### API Design

RESTful API with consistent response format:

```typescript
interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}
```

### Multi-tenancy

- All data tables include `business_id` column
- API routes scoped to authenticated business
- Customer booking routes use business `slug` for identification
- Strict data isolation between tenants

### Data Conventions

- **Primary keys**: UUID (crypto.randomUUID())
- **Timestamps**: UTC, ISO-8601 format
- **Soft deletes**: `deleted_at` timestamp, never hard delete
- **Database columns**: snake_case
- **API/Frontend**: camelCase (transform at boundary)

---

## Non-Functional Requirements

### Performance

| Metric                  | Target       |
| ----------------------- | ------------ |
| API response time (p95) | < 200ms      |
| Time to first byte      | < 100ms      |
| Booking flow completion | < 30 seconds |
| Dashboard load time     | < 3 seconds  |

### Scalability

- Support 1000+ businesses (tenants)
- Support 100+ concurrent bookings per business
- Handle burst traffic (Monday morning syndrome)

### Security

- JWT-based authentication for admin
- Cryptographically signed tokens
- Password hashing with a modern, secure, Workers-compatible algorithm and migration path
- Input validation on all endpoints
- CORS configuration for allowed origins
- No hardcoded credentials in production

### Localization

- Full UI translation: English, German
- Date/time formatting per locale
- Currency formatting per business setting
- Timezone-aware time display

### Reliability

- Zero data loss for confirmed bookings
- Graceful degradation on service issues
- Clear error messages for users
- Notification delivery is idempotent and resilient (queue retries + dead-letter handling)

### Compliance

- GDPR-compliant data handling
- Consent tracking for customers
- Data export capability
- Right to deletion support

---

## Conformance and Definition of Done

- A task is complete only when implementation behavior matches both this PRD and `specs/*`.
- Marking work as complete requires passing tests that verify the relevant acceptance criteria.
- `IMPLEMENTATION_PLAN.md` should list only remaining conformance gaps and remove completed items.
- If PRD/spec and implementation conflict, update plan priorities to resolve the conflict before new feature work.

### Release Readiness Gate (v1.2)

- Before launch, the plan must prioritize ship blockers over feature expansion.
- Release blocking validation must include full project checks (`type-check`, `lint`, unit tests, build) and E2E coverage.
- At least one E2E path must validate real backend behavior (not only mocked responses).
- Cloudflare environment readiness (queue bindings, required vars, and deployment docs) must be validated for staging and production.
- PRD, specs, README, and implementation behavior must agree on what is implemented and what is deferred.
- Remaining items at release decision time must be explicitly classified as `ship-blocker` or `post-launch`.

---

## Success Metrics

### Product Metrics

| Metric                     | Target            |
| -------------------------- | ----------------- |
| Booking completion rate    | > 80%             |
| Customer return rate       | > 50%             |
| Admin daily active usage   | > 70%             |
| Customer self-service rate | > 60% of bookings |

### Technical Metrics

| Metric      | Target  |
| ----------- | ------- |
| API uptime  | > 99.5% |
| Error rate  | < 1%    |
| P95 latency | < 200ms |

### Business Metrics (Future)

- Monthly recurring revenue
- Customer acquisition cost
- Churn rate
- Net promoter score

---

## Glossary

| Term            | Definition                                                   |
| --------------- | ------------------------------------------------------------ |
| **Tenant**      | A business using the platform (multi-tenant architecture)    |
| **Booking**     | An appointment created by a customer                         |
| **Appointment** | A scheduled time slot (includes bookings and manual entries) |
| **Slot**        | An available time period for booking                         |
| **Buffer**      | Time blocked before/after appointments for preparation       |
| **Policy**      | Business rules for cancellation, rescheduling                |
| **Token**       | Unique identifier for customer booking access                |

---

## Appendix

### Example API Endpoints

```
# Public (Customer)
GET    /api/services?business=:slug
POST   /api/availability
POST   /api/bookings
GET    /api/bookings/:token
PUT    /api/bookings/:token/reschedule
DELETE /api/bookings/:token

# Admin (Authenticated)
GET    /api/admin/dashboard/stats
GET    /api/admin/appointments
POST   /api/admin/appointments
PUT    /api/admin/appointments/:id
GET    /api/admin/services
POST   /api/admin/services
PUT    /api/admin/services/:id
DELETE /api/admin/services/:id
GET    /api/admin/staff
POST   /api/admin/staff
PUT    /api/admin/staff/:id
DELETE /api/admin/staff/:id
GET    /api/admin/customers
POST   /api/admin/customers
PUT    /api/admin/customers/:id
GET    /api/admin/business
PUT    /api/admin/business
```

### Example Booking Request

```json
POST /api/bookings
{
  "businessSlug": "elegant-salon",
  "serviceId": "srv-123",
  "staffId": "staff-456",
  "startTime": "2026-01-15T10:00:00Z",
  "customer": {
    "firstName": "Maria",
    "lastName": "Mueller",
    "email": "maria@example.com",
    "phone": "+41 79 123 4567"
  },
  "notes": "First time customer"
}
```

### Example Booking Response

```json
{
  "success": true,
  "data": {
    "id": "apt-789",
    "confirmationToken": "abc123xyz",
    "service": {
      "name": "Women's Cut & Style",
      "duration": 60
    },
    "staff": {
      "name": "Anna Schmidt"
    },
    "startTime": "2026-01-15T10:00:00Z",
    "endTime": "2026-01-15T11:00:00Z",
    "status": "confirmed"
  }
}
```

---

## Document History

| Version | Date     | Author | Changes                                                                                                                                              |
| ------- | -------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1.2     | Feb 2026 | -      | Added release readiness gate criteria and blockers-first launch guidance                                                                             |
| 1.1     | Feb 2026 | -      | Clarified Cloudflare-first notification architecture, conformance definition of done, and acceptance criteria for reminders/templates/calendar views |
| 1.0     | Jan 2026 | -      | Initial PRD                                                                                                                                          |
