# MyTaskKing

Complete Product Guide

Enterprise Collaboration & Workforce Management Platform

**Version:** 1.0 | **Date:** August 2026  
**Document type:** Product documentation

# Table of Contents

1. Introduction
2. Problem Statement
3. How MyTaskKing Solves It
4. Platform Overview
5. User Roles Summary
6. Role: EMPLOYEE
7. Role: MANAGER
8. Role: PROJECT_COORDINATOR_MANAGER
9. Role: ADMIN
10. Role: SUPER_ADMIN
11. Role: TELECALLER
12. Role: EXECUTIVE (Field Force)
13. Role: SALES_HEAD
14. Role: CLIENT
15. Shared Features (All Roles)
16. Desktop-Specific Features
17. Web Admin Console Features
18. Field Force Module Deep Dive
19. Backend Modules Summary
20. Review Checklist

# 1\. Introduction

MyTaskKing is a premium enterprise collaboration and company management platform designed for organizations that need a single, secure workspace for internal teams, field executives, telecallers, managers, and external clients. It unifies realtime chat, advanced task management, voice and video calls, scheduled meetings, telecaller CRM with click-to-call, field-force visit tracking, work-activity monitoring, attendance, analytics, and multi-tenant administration across mobile, web, and desktop clients.

The platform is built as a multi-tenant SaaS architecture where each organization (tenant) operates in an isolated data scope with its own branding, subscription, feature flags, and user roster. Administrators provision every account manually - there is no public self-signup for employees. Authentication uses tenant slug plus user ID plus password, with JWT access tokens, rotating refresh tokens, session risk scoring, and role-based access control enforced on every REST endpoint and Socket.IO event.

MyTaskKing ships as a monorepo containing a Node.js + Express + Prisma backend, a React 18 + TypeScript web admin console, and Flutter applications for Android, iOS, Windows, Linux, and macOS. Realtime collaboration is powered by Socket.IO; voice and meetings use WEB RTC; telecaller outbound calls integrate Phone call; files and images use Cloudflare R2 and Cloudinary; push notifications use Firebase Cloud Messaging.

This guide documents every user role, screen, route, and major feature as implemented in the completed application suite (August 2026 release), including work activity desktop agents, emergency buzzer alerts, organization text-to-speech (TTS), subscription billing, support tickets, employee GPS tracking, AI review, and the full Field Force / marketing module with offline-capable outlet visits and order capture.

# 2\. Problem Statement

Modern enterprises face fragmented tooling that creates operational drag, security gaps, and poor visibility. MyTaskKing was built to address these pain points:

- **Tool sprawl:** Teams juggle separate apps for chat, tasks, calls, CRM, and field reporting, causing context switching and lost information.
- **No unified client access:** External clients need controlled, time-limited access to project channels without exposing the entire organization.
- **Telecaller inefficiency:** Sales and support call centers lack integrated lead management, follow-up scheduling, and one-click outbound dialing tied to CRM records.
- **Field force blind spots:** Organizations with roaming sales executives cannot verify outlet visits, GPS compliance, or order capture in the field.
- **Weak accountability:** Managers lack desktop work-activity evidence, login audit trails, and attendance records to validate remote productivity.
- **Security and compliance gaps:** Ad-hoc messaging tools lack session management, permission grants, audit logs, and tenant isolation required by enterprise IT.
- **Role complexity:** A single "user" permission model cannot express managers, coordinators, telecallers, executives, sales heads, and platform super-admins.
- **Realtime coordination failures:** Missed calls, untracked meetings, and siloed notifications delay decisions across distributed teams.
- **Billing and subscription opacity:** Multi-tenant operators need per-organization subscription status, payment tracking, and feature gating without manual spreadsheets.
- **Emergency response latency:** Critical situations require immediate, acknowledged alerts to specific employees - not buried chat messages.

# 3\. How MyTaskKing Solves It

- **Unified workspace:** Chat, tasks, calls, meetings, calendar, reports, and files live in one platform with shared search, notifications, and presence.
- **Controlled client portal:** CLIENT role users see only assigned channels, displayed in brand-mandated red, with server-enforced access windows and automatic expiry.
- **Integrated telecaller CRM:** Lead lists, status pipelines, Phone Call click-to-call, call history, and daily follow-up queues are built into mobile and web.
- **Field Force module:** EXECUTIVE role on mobile provides route planning, outlet visits with GPS proof, product catalog, order capture, and manager dashboards.
- **Work activity & tracking:** Windows and Linux desktop agents capture periodic screenshots and location; admins review daily summaries, clips, and GPS trails.
- **Enterprise security:** Advanced RBAC with dot-namespaced permissions, session force-logout, login activity, audit logs, feature flags, and multi-tenant data scoping.
- **Nine distinct roles:** SUPER_ADMIN, SALES_HEAD, ADMIN, MANAGER, PROJECT_COORDINATOR_MANAGER, EMPLOYEE, TELECALLER, EXECUTIVE, and CLIENT each receive tailored navigation and API access.
- **Realtime everything:** Socket.IO drives live chat, typing indicators, call signaling, meeting joins, presence, notifications, and activity feeds without page refresh.
- **Subscription & billing:** Platform super-admins manage organizations, payments, and org-level subscription screens; billing module gates features per tenant plan.
- **Emergency buzzer:** Admins trigger high-priority push and socket alerts to employees with escalation to supervisors if unacknowledged within a configurable timeout.

# 4\. Platform Overview

| **Platform**               | **Technology**               | **Primary Purpose**                                              | **Key Capabilities**                                                                                                                                  |
| -------------------------- | ---------------------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Mobile** (Android + iOS) | Flutter                      | Primary workforce client for all roles                           | Full chat, tasks, calls, meetings, telecaller CRM, field force, attendance, GPS tracking, push notifications, selfie login, emergency alerts, org TTS |
| **Web**                    | React 18 + Vite + TypeScript | Admin console, manager dashboard, telecaller desk, client portal | Full RBAC navigation, analytics, permissions, flags, organizations, payments, field visits map, AI review, recordings, deleted chats, command palette |
| **Windows Desktop**        | Flutter + system tray        | Office chat + work activity agent                                | Chat-first sidebar workspace, system tray, autostart, periodic screenshot capture, session registration, no live calls on Windows workspace build     |
| **Linux Desktop**          | Flutter + system tray        | Office chat + work activity agent                                | Same as Windows: chat workspace, tray icon, autostart, work activity background agent with configurable capture intervals                             |
| **macOS Desktop**          | Flutter + menu bar           | Office chat + calls + work activity                              | Full chat, calls, meetings support; background work activity agent; macOS-native window and tray integration; clients blocked from desktop login      |

# 5\. User Roles Summary

| **Role**                    | **Scope**      | **Description**                                                                                    | **Default Home**                 | **Primary Platforms**    |
| --------------------------- | -------------- | -------------------------------------------------------------------------------------------------- | -------------------------------- | ------------------------ |
| SUPER_ADMIN                 | Platform       | MyTaskKing platform operator; manages all tenants, payments, support inbox, and global settings    | /dashboard (web), /chat (mobile) | Web, Mobile, Desktop     |
| SALES_HEAD                  | Platform sales | Platform-level sales lead; manages organization registrations, admin notes, and org pipeline       | /dashboard                       | Mobile primarily         |
| ADMIN                       | Organization   | Organization administrator; full org control except platform-only routes (organizations, payments) | /dashboard (web), /chat (mobile) | Web, Mobile, Desktop     |
| MANAGER                     | Organization   | Team lead with field visit oversight, client visibility, and leave request submission              | /chat (mobile), /dashboard (web) | Web, Mobile, Desktop     |
| PROJECT_COORDINATOR_MANAGER | Organization   | Project coordinator with manager-level task and field access but no client management              | /chat (mobile), /dashboard (web) | Web, Mobile, Desktop     |
| EMPLOYEE                    | Organization   | Standard internal team member for collaboration, tasks, calls, and attendance                      | /chat                            | Web, Mobile, Desktop     |
| TELECALLER                  | Organization   | Outbound sales/support agent with dedicated leads CRM and call history                             | /telecaller                      | Mobile, Web              |
| EXECUTIVE                   | Organization   | Field sales executive - part of mobile app, not a separate application                             | /field                           | Mobile only              |
| CLIENT                      | External       | External stakeholder with time-limited access to assigned channels only; shown in red UI           | /chat                            | Web, Mobile (no desktop) |

**Login identifier (all roles):** tenant slug + user ID + password. Example: tenant acmecorp, user ID priya.k, password set by admin. Mobile login also supports optional selfie capture on Android/iOS. Desktop login captures best-effort GPS location. No email or phone OTP login.

# 6\. Role: EMPLOYEE

### Who They Are

EMPLOYEE is the default internal role for team members who collaborate on projects, complete assigned tasks, participate in channels, join voice/video calls and meetings, submit attendance, and request leave. They do not manage other users, clients, or organization settings.

### Login Identifier

tenant slug + user ID (e.g., john.d) + password assigned by ADMIN.

### Default Home Page

Mobile: /chat (Chat list). Web: /dashboard. Desktop: /chat.

### Navigation Tabs / Pages

**Mobile bottom nav:** Chat · Tasks · Workday (Attendance) · Meet · More

**Web sidebar:** Dashboard, Chat, Channels, Tasks, Reports, Calendar, Calls, Meetings, Saved, Employees, Sessions, Request leave, Report a problem, Settings

**Desktop:** Chat workspace with profile, search, deleted chats

### Platforms Available

Mobile (Android/iOS), Web, Windows/Linux/macOS Desktop (chat-focused; clients blocked on desktop)

### Pages and Features

#### Login (/login)

- **Tenant slug field:** Identifies the organization workspace; combined with user ID to resolve the correct tenant database scope during authentication.
- **User ID + password:** Standard credential entry with shake-on-error animation and success-check celebration on successful authentication.
- **Selfie capture (mobile):** Blink-selfie verification on Android and iOS for additional login attestation; skipped automatically on desktop platforms.
- **Organization registration link:** Navigates to /register-organization for new tenant self-registration requests processed by SALES_HEAD.

#### Chat List (/chat)

- **Channel directory:** Shows all channels the employee is a member of with unread badge counts, pinned ordering, and realtime invalidation on new messages.
- **Channel search:** Full-screen search sheet to filter channels by name or participant without leaving the chat tab.
- **Unread indicators:** Per-channel unread counts update live via Socket.IO chat.message.created events and sync with push notification state.
- **Presence dots:** Shows online/away/busy/in-meeting/invisible status for channel members using combined socket and UserPresence data.

#### Chat Detail (/chat/:channelId)

- **Message bubbles:** Text, image, file, and voice-note messages with author avatars, timestamps, and edit/delete for own messages.
- **Thread replies:** Reply-to threading with denormalized thread root counters; thread side-panel shows independent typing indicators.
- **Reactions & pins:** Emoji reaction toggles and message pinning within channels the employee has permission to post in.
- **Composer attachments:** Upload images via Cloudinary direct-upload or documents via R2 presigned URLs; voice notes recorded in-app.
- **Call from chat:** Initiate one-to-one voice or video WEB calls directly from a DM channel via /call/:id route.
- **Mark read:** Automatically marks channel read on view; supports manual read cursor via POST /chat/channels/:id/read.

#### Tasks (/tasks)

- **Kanban board:** Drag-and-drop tasks between TODO, IN_PROGRESS, REVIEW, and DONE columns with optimistic POST /tasks/:id/move updates.
- **List view toggle:** Segmented control switches between kanban and paginated list views filtered by status, assignee, and search query.
- **New task sheet:** Bottom sheet to create tasks with title, description, due date, priority, and self-assign or request assignment from others.
- **Pending badge:** Bottom nav shows count of tasks assigned to the employee with PENDING assignee state.

#### Task Detail (/tasks/:id)

- **Full task view:** Displays description, status, priority, due date, assignees, subtasks, and comment thread in a focused full-screen layout.
- **Subtask checklist:** Add and toggle subtasks with PATCH /tasks/subtasks/:id; progress reflected immediately in parent task card.
- **Comments:** Threaded task comments with author attribution and realtime updates when teammates add notes.

#### Attendance / Workday (/attendance)

- **Clock in/out:** Daily attendance punch with timestamp, optional location, and visual workday timeline for the current day.
- **Attendance history:** Review past attendance records with status indicators for present, late, half-day, and absent entries.

#### Meetings (/meetings)

- **Create meeting:** Schedule voice, video, webinar, or livestream WEB rooms with slug-based join links shareable outside the app.
- **Join meeting:** Enter live room via /meeting/:slug with mode parameter for voice or video; token fetched from backend.
- **Meeting list:** Shows upcoming and active meetings with participant counts and realtime join notifications.

#### Calls (/calls - via More menu)

- **Call history:** Paginated list of past one-to-one and group calls with duration, participants, and missed/declined status.
- **Initiate call:** Start new WEB call by selecting colleagues; server returns per-participant RTC tokens and rings recipients.

#### Live Call (/call/:id)

- **WEB RTC room:** Real-time voice or video with mute toggle, participant list, and mid-call add-participant for group promotion.
- **Incoming call overlay:** Full-screen incoming call UI with accept/decline; also triggered by FCM push when app is backgrounded.
- **Ongoing call bar:** Minimized call indicator allows navigation to other screens while staying connected to the active session.

#### Dashboard (/dashboard - via More / Web default)

- **Personal stat grid:** Role-aware widgets showing assigned tasks, upcoming meetings, unread messages, and attendance summary for the employee.
- **Activity feed:** Recent workspace events relevant to the employee including task assignments, mentions, and channel invitations.

#### Calendar (/calendar)

- **Unified calendar:** Month/week views combining task due dates, meetings, telecaller follow-ups, and personal leave requests in one timeline.

#### Reports (/reports)

- **Personal reports:** View and download reports shared with the employee by managers or generated from assigned project channels.

#### Saved (/saved)

- **Bookmarked items:** Saved messages, tasks, and files collected via the saved-items feature for quick reference across the workspace.

#### Announcements (/announcements)

- **Org broadcasts:** Read organization-wide announcements published by admins; announcements also appear as top banner in web workspace.

#### Notifications (/notifications)

- **Grouped inbox:** Notifications categorized by chat, task, call, mention, and system with mark-all-read and realtime stream updates.

#### Employees (/employees)

- **Directory:** Searchable employee list with role, status, presence, and custom title; used to find colleagues for calls and task assignment.

#### Request Leave (/request-leave)

- **Leave submission:** Submit leave requests with date range, type, and reason; routed to ADMIN for approval via leave-approvals queue.

#### Sessions (/sessions)

- **Active sessions:** View all logged-in devices with IP, user agent, risk score badge, and ability to revoke individual sessions.
- **Sign out everywhere:** Force-logout all sessions except current from profile or sessions screen.

#### Profile (/profile)

- **Presence picker:** Set status to Active, Away, Busy, In Meeting, or Invisible with optional custom status message.
- **Theme switcher:** Toggle light/dark/system theme and select color palette (MyTaskKing Blue, Orange Milk, Forest Slate, etc.).
- **Font scale:** Adjust text size for accessibility; persisted locally across app restarts.

#### Settings (/settings)

- **Notification preferences:** Control push notification categories, sound, and per-channel mute/snooze durations.
- **Org branding:** Displays tenant logo and primary color tint applied to the default blue theme palette.

#### Search (/search)

- **Global search:** Full-screen search across messages, tasks, channels, users, and files with kind filter via ?k= query parameter.

#### Report a Problem (/report-problem)

- **Support ticket:** Submit bug reports or issues with description and optional screenshot; creates support ticket visible to platform assignees.

# 7\. Role: MANAGER

### Who They Are

MANAGER is a team lead responsible for overseeing employees, monitoring field visits, viewing client relationships, approving operational reports, and coordinating tasks across their team. They have broader web navigation than EMPLOYEE including Field Visits and Clients pages.

### Login Identifier

tenant slug + user ID + password.

### Default Home Page

Mobile: /chat. Web: /dashboard.

### Navigation Tabs / Pages

**Mobile bottom nav:** Chat · Tasks · Workday · Meet · More (includes Field team, Team visits if field manager, Clients)

**Web sidebar:** Dashboard, Chat, Channels, Tasks, Reports, Calendar, Calls, Meetings, Saved, Field visits, Employees, Clients, Sessions, Request leave, Report a problem, Settings

### Platforms Available

Mobile, Web, Desktop

### Pages and Features

#### Field Visits - Web (/field-visits)

- **Visit map dashboard:** Geographic map showing field executive visit locations, timestamps, and outlet associations for the manager's team.
- **Visit filters:** Filter by date range, executive, region, and visit outcome status to audit field activity compliance.

#### Field Team - Mobile (/field via More)

- **Field dashboard:** Manager view of team field metrics including visits completed, orders placed, and executives active today.
- **Team visits:** /field/manager screen listing all team member visits with drill-down to individual visit records.
- **Product catalog:** /marketing/catalog accessible to field managers for reviewing SKU list used by executives in the field.

#### Clients - Web & Mobile (/clients)

- **Client directory:** View external client accounts with company name, access window, and assigned channel memberships displayed in red.
- **Access status:** See ACTIVE or EXPIRED client status; managers can view but typically cannot extend access (ADMIN function).

#### Employees - Enhanced view

- **Team roster:** Full employee directory with role, department, presence, and GPS last-seen for field-enabled team members.
- **Employee detail:** View individual employee profile, assigned tasks, and recent activity without full admin edit permissions.

#### Dashboard - Manager widgets

- **Team stat grid:** Aggregated task completion, overdue count, active calls, and field visit summary for the manager's direct reports.
- **Realtime activity:** Live feed of team events including task moves, channel posts, and field visit check-ins.

#### Tasks - Team oversight

- **Assign to others:** Create and assign tasks to any team member with task.assign_others permission; kanban shows all team tasks.
- **Priority management:** Set task priority and due dates for direct reports; receive notifications on overdue team tasks.

#### Reports - Team reports

- **Generate & share:** Access team-level reports and export data for operational review meetings with leadership.

#### All EMPLOYEE features

- **Full collaboration:** Managers retain all EMPLOYEE capabilities including chat, calls, meetings, attendance, leave requests, saved items, and notifications.

# 8\. Role: PROJECT_COORDINATOR_MANAGER

### Who They Are

PROJECT_COORDINATOR_MANAGER coordinates projects and teams with manager-level task and field visibility but without client account management. Ideal for internal project coordinators who manage deliverables and field teams without external client access.

### Login Identifier

tenant slug + user ID + password.

### Default Home Page

Mobile: /chat. Web: /dashboard.

### Navigation Tabs / Pages

**Web sidebar:** Dashboard, Chat, Channels, Tasks, Reports, Calendar, Calls, Meetings, Saved, Field visits, Employees, Sessions, Request leave, Report a problem, Settings (no Clients)

**Mobile:** Same as MANAGER minus Clients in More menu

### Platforms Available

Mobile, Web, Desktop

### Pages and Features

#### Field Visits (/field-visits)

- **Project field oversight:** Monitor field executive visits related to assigned projects with map view and visit detail drill-down on web console.

#### Tasks - Project coordination

- **Cross-team assignment:** Create project-scoped tasks, assign multiple team members, and track kanban progress across project channels.
- **Subtask breakdown:** Decompose project milestones into subtasks with completion tracking visible to all project participants.

#### Channels - Project channels

- **PROJECT channels:** Create and manage project-type channels grouping all stakeholders for a specific deliverable or client engagement.

#### Field Team (/field, /field/manager)

- **Coordinator dashboard:** View field team performance metrics and visit completion rates for coordinated project territories.

#### Employees

- **Project roster:** View employees assigned to coordinated projects with presence and workload indicators for resource planning.

#### Calendar

- **Project timeline:** Unified view of project task deadlines, meetings, and field visit schedules for coordinated planning.

#### All MANAGER features except Clients

- **Near-manager access:** Retains field visits, team tasks, reports, calls, meetings, and leave requests without client directory access.

# 9\. Role: ADMIN (Organization Admin)

### Who They Are

ADMIN is the organization-level administrator who provisions employees, clients, and telecallers; configures workspace settings; reviews analytics, recordings, and work activity; manages permissions, feature flags, leave approvals, and emergency alerts. Does not access platform-only routes (organizations, payments) unless also SUPER_ADMIN.

### Login Identifier

tenant slug + user ID (e.g., admin) + password.

### Default Home Page

Web: /dashboard. Mobile: /chat.

### Navigation Tabs / Pages

**Web sidebar (full org admin):** Dashboard, Chat, Channels, Tasks, Reports, Calls, Meetings, Recordings, AI Review, Deleted chats, Telecaller, Saved, Field visits, Employees, Clients, Analytics, Talk time, Login activity, Leave requests, Activity, Feature flags, Permissions, My sessions, Settings (excludes platform-only: Organisations, Payments, Support inbox)

**Mobile More menu adds:** Recordings, Login activity, Leave approvals, Work activity, AI Review, Subscription, Clients, Telecaller

### Platforms Available

Web (primary admin console), Mobile, Desktop

### Pages and Features

#### Employees Management - Web (/employees)

- **Create employee:** Provision new accounts with user ID, password, role (ADMIN, EMPLOYEE, TELECALLER, MANAGER, etc.), name, and custom title.
- **Suspend/activate:** Toggle employee status; suspended users are rejected on next API call even with valid JWT.
- **Role assignment:** Change employee role and reset password via PATCH; changes take effect on next token refresh.

#### Clients Management - Web (/clients)

- **Create client:** Provision external client with user ID, password, company name, and access start/end datetime window.
- **Extend access:** POST /clients/:id/extend pushes accessEndsAt forward; expired clients receive HTTP 410 on all requests.
- **Disable client:** Immediately suspend client access; client name renders in red across all UI surfaces.

#### Analytics - Web (/analytics)

- **Productivity charts:** Tasks completed per user over configurable date range with CSV export via ?format=csv.
- **Telecaller metrics:** Calls per minute, leads won, and agent performance comparison for the organization.
- **Workspace health:** Message volume, active users, call counts, and client engagement scores.

#### Activity - Web (/activity)

- **Audit stream:** Live activity log of auth events, permission changes, file downloads, automation runs, and emergency alerts.

#### Permissions - Web (/permissions)

- **RBAC grants:** Assign explicit allow/deny permission grants to users or roles using dot-namespaced keys like task.delete.
- **Permission matrix:** View DEFAULT_MATRIX role defaults and override with granular grants without database migrations.

#### Feature Flags - Web (/flags)

- **Toggle features:** Enable or disable platform features per tenant such as field force, work activity, AI review, and emergency buzzer.

#### Recordings - Web (/recordings)

- **Call recordings:** Browse WEB call recordings stored in R2 with playback links, duration, and participant metadata.

#### AI Review - Web & Mobile (/ai-review)

- **AI analysis queue:** Review AI-generated summaries and transcriptions of calls and meetings processed by the MyTaskKing AI server.

#### Deleted Chats - Web (/deleted-chats)

- **Recovery audit:** View administratively deleted messages and channels for compliance review and potential restoration.

#### Talk Time - Web (/talk-time)

- **Call duration analytics:** Per-user and per-team talk time aggregation for telecaller and internal call volume reporting.

#### Login Activity - Web & Mobile (/login-activity)

- **Auth audit:** Chronological log of login successes, failures, IP addresses, devices, and geolocation for security review.

#### Leave Approvals - Web (/leave-approvals)

- **Approval queue:** Review pending leave requests from employees, telecallers, and managers; approve or reject with optional comment.

#### Work Activity - Mobile & Desktop (/work-activity)

- **Daily summary:** Per-employee work activity summary showing active time, idle time, and capture count for selected date.
- **Screenshot clips:** Review periodic desktop screenshot captures with timestamp and open-in-browser for detailed inspection.
- **GPS on map:** View employee location points on Google Maps for field and desktop login location registration events.

#### Telecaller - Web (/telecaller)

- **Org-wide leads:** Admin view of all telecaller leads across agents with status filter, owner assignment, and bulk import.

#### Subscription - Mobile (/subscription)

- **Org billing status:** View current subscription plan, renewal date, feature entitlements, and upgrade options for the organization.

#### Emergency Buzzer (Admin action)

- **Trigger alert:** POST /emergency/alert sends high-priority push and socket alert to selected employees with custom message.
- **Escalation:** If employee does not acknowledge within escalateAfter seconds, alert escalates to their supervisors automatically.

#### Settings - Org configuration

- **Workspace settings:** Configure org name, branding, primary color, TTS voice settings, work activity capture interval, and notification policies.
- **Org TTS:** Text-to-speech settings for organization-wide voice announcements read aloud on employee devices when configured.

#### Sessions - Force logout

- **Admin session control:** POST /sessions/users/:userId/force-logout revokes all active sessions for any employee instantly.

# 10\. Role: SUPER_ADMIN (Platform Admin)

### Who They Are

SUPER_ADMIN is the MyTaskKing platform operator with access to all organizations, payment records, support inbox, and every org-level admin feature. Manages multi-tenant infrastructure, onboarding new organizations, and resolving cross-tenant support issues.

### Login Identifier

Platform tenant slug (e.g., platform or default tenant) + superadmin + password set during npm run setup.

### Default Home Page

Web: /dashboard. Mobile: /chat.

### Navigation Tabs / Pages

**Web sidebar (full platform):** All ADMIN routes plus Organisations, Payments, Support inbox, and platform-scoped Issues view

**Mobile More menu adds:** Requests (/admin-notes), Payments (/payments), Organizations (/organizations)

### Platforms Available

Web (primary), Mobile, Desktop

### Pages and Features

#### Organizations - Web (/organizations)

- **Tenant directory:** List all registered organizations with slug, name, status, user count, subscription tier, and creation date.
- **Create organization:** Provision new tenant with slug, branding, storage prefix, and initial ADMIN user account.
- **Tenant settings:** Edit organization metadata, toggle MULTI_TENANT features, and manage per-tenant feature flag overrides.

#### Organizations - Mobile (/organizations)

- **Mobile org management:** SALES_HEAD and SUPER_ADMIN can browse and manage organization registrations from mobile Organizations tab.

#### Payments - Web & Mobile (/payments)

- **Payment ledger:** Track subscription payments, invoices, and payment status across all tenants with filtering by date and organization.
- **Revenue dashboard:** Platform-level revenue metrics and outstanding payment alerts for billing operations team.

#### Support Inbox - Web (/support-issues)

- **Ticket queue:** Platform support inbox showing all Report a Problem submissions and support tickets across tenants.
- **Assign & resolve:** Assign tickets to platform support staff, add internal notes, and mark resolved with resolution summary.

#### Admin Notes / Requests - Mobile (/admin-notes)

- **Sales requests:** Review organization registration requests and sales pipeline notes submitted by SALES_HEAD or prospects.

#### Organization Registration - Public (/register-organization)

- **Self-service intake:** Public form for new organizations to request onboarding; creates admin note for SUPER_ADMIN/SALES_HEAD review.

#### All ADMIN features

- **Full org admin:** SUPER_ADMIN inherits every organization admin capability including analytics, permissions, flags, recordings, work activity, and emergency alerts.

#### Platform Analytics

- **Cross-tenant metrics:** Aggregate analytics across all organizations for platform health monitoring and capacity planning.

#### Default Tenant Support Assignee

- **Issues nav item:** Default tenant support assignees see Issues in web sidebar linking to /support-issues for their assigned tickets.

# 11\. Role: TELECALLER

### Who They Are

TELECALLER is an outbound sales or support agent who works primarily from the leads CRM, making Phone Call-powered click-to-call connections, logging call outcomes, and managing daily follow-up queues. Onboarding requires call recording setup before accessing the leads screen.

### Login Identifier

tenant slug + user ID + password.

### Default Home Page

Mobile: /telecaller (after recording setup). Web: /telecaller.

### Navigation Tabs / Pages

**Mobile bottom nav:** Chat · Leads · Home · Meet · Calls · More

**Web sidebar:** Dashboard, Telecaller, Chat, Reports, Calendar, Saved, Employees, Sessions, Request leave, Report a problem, Settings

### Platforms Available

Mobile (primary), Web

### Pages and Features

#### Telecaller Onboarding (/telecaller/setup)

- **Recording setup gate:** First-login wizard configures call recording permissions and Phone Call integration; redirects to leads only when complete.
- **Device permissions:** Requests microphone and phone permissions required for click-to-call and automatic call logging on Android.

#### Telecaller / Leads (/telecaller)

- **Lead list:** Paginated leads owned by the telecaller with status filter (NEW, CONTACTED, QUALIFIED, WON, LOST) and search.
- **Lead detail:** View contact info, notes, call history, next follow-up date, and status change timeline for each lead.
- **Click-to-call:** POST /telecaller/leads/:id/call initiates Phone Call outbound call bridging agent phone to lead number.
- **Create lead:** Add new lead with name, phone, email, source, and initial notes; auto-assigned to current telecaller.
- **Status update:** Move leads through pipeline stages; triggers automations like NOTIFY_MANAGER on status change.

#### Follow-ups Today

- **Daily queue:** GET /telecaller/followups/today returns leads with follow-up date matching today for prioritized outreach.

#### Call History (/calls tab)

- **Telecaller calls:** GET /telecaller/calls shows Phone Call call log with duration, disposition, and linked lead record.

#### Chat

- **Team coordination:** Chat with managers and teammates for lead handoffs, script updates, and real-time coaching during calling sessions.

#### Dashboard (/dashboard - Home tab)

- **Telecaller stats:** Daily call count, leads contacted, conversion rate, and follow-ups due widgets on the home dashboard.

#### Calendar

- **Follow-up calendar:** Visual calendar of scheduled lead follow-ups with tap-to-open lead detail for quick callback.

#### Reports

- **Performance reports:** Personal telecaller performance reports including talk time and lead conversion metrics.

#### Bulk Lead Import (Admin)

- **Excel import:** Admins can bulk import leads via sample Excel template (sample_telecaller_leads_100.xlsx) for campaign distribution.

# 12\. Role: EXECUTIVE (Field Force - Mobile Only)

### Who They Are

EXECUTIVE is a field sales representative who visits retail outlets, captures orders, searches for new shops, and follows planned routes. This role is integrated into the mobile app - it is NOT a separate application. Executives use a dedicated bottom navigation optimized for field workflows.

### Login Identifier

tenant slug + user ID + password.

### Default Home Page

Mobile: /field (Field Dashboard).

### Navigation Tabs / Pages

**Mobile bottom nav:** Home · Route · Outlets · Shops · Chat · Meet · Settings

**Additional routes:** /field/visits, /field/gps, /field/export, /field/hr, /marketing/outlets/:id, /marketing/orders, /marketing/catalog

### Platforms Available

Mobile (Android/iOS) only - no web or desktop EXECUTIVE shell

### Pages and Features

#### Field Dashboard (/field)

- **Today's summary:** Visits planned vs completed, orders placed, distance traveled, and targets for the current workday.
- **Quick actions:** Start visit, view route, search shops, and open catalog from the field home screen.

#### Route Planning (/field/route)

- **Daily route:** Ordered list of outlets to visit today with map preview, estimated travel time, and completion checkboxes.
- **Route optimization:** Suggested visit sequence based on geographic proximity and priority outlets assigned by manager.

#### Outlets (/marketing/outlets)

- **Outlet directory:** Searchable list of assigned retail outlets with address, contact, last visit date, and outstanding order status.
- **Outlet detail:** Tap outlet to open visit screen or view historical visit records and order history for that location.

#### Outlet Visit (/marketing/outlets/:id)

- **Check-in visit:** GPS-verified visit check-in with timestamp, photo capture, and notes; works offline with sync on reconnect.
- **Visit outcome:** Record visit result (productive, closed, rescheduled) with mandatory GPS coordinates for compliance.
- **Order capture:** Create order from catalog during visit with quantity, pricing, and delivery instructions.

#### Shop Search (/marketing/shops)

- **New shop discovery:** Search external business data API for potential new outlets near current GPS location to expand territory.
- **Add to pipeline:** Convert discovered shop into outlet record for manager approval and route assignment.

#### My Visits (/field/visits)

- **Visit history:** Personal log of all completed visits with date, outlet, outcome, and order value for self-review.

#### GPS Tracking (/field/gps)

- **Location trail:** View own GPS breadcrumb trail for the day; background GPS lifecycle service reports location to employeeTracking module.

#### Product Catalog (/marketing/catalog)

- **SKU browser:** Searchable product catalog with images, pricing, MOQ, and availability for order entry during visits.
- **Offline catalog:** Catalog data cached locally for field use in areas with poor network connectivity.

#### Orders (/marketing/orders)

- **Order list:** All orders placed by the executive with status (pending, confirmed, delivered) and outlet association.
- **Order detail:** /marketing/orders/:id shows line items, totals, visit link, and order status timeline.

#### Marketing Export (/field/export)

- **Data export:** Generate Excel export of visit and order data for personal records or manager submission.

#### Field HR (/field/hr)

- **HR self-service:** Field-specific HR information including leave balance, attendance summary, and HR announcements.

#### Chat & Meetings

- **Field communication:** Chat with managers and team; join meetings for daily field briefings without leaving the field app shell.

#### Employee GPS Lifecycle

- **Background tracking:** Automatic GPS reporting while app is active; integrates with employeeTracking backend for manager map view.

# 13\. Role: SALES_HEAD

### Who They Are

SALES_HEAD is a platform-level sales role responsible for managing organization registrations, reviewing sales pipeline requests, and coordinating new tenant onboarding. Uses a dedicated mobile navigation without chat as primary tab.

### Login Identifier

Platform tenant tenant slug + user ID + password with isSalesHead flag.

### Default Home Page

Mobile: /dashboard. Redirects away from /chat to dashboard.

### Navigation Tabs / Pages

**Mobile bottom nav:** Home · Organisations · Meet · Notes · Settings

### Platforms Available

Mobile primarily; limited web access to dashboard and organizations

### Pages and Features

#### Dashboard (/dashboard)

- **Sales pipeline:** Overview of pending organization registrations, conversion metrics, and recent onboarding activity.

#### Organizations (/organizations)

- **Org pipeline:** Browse prospective and active organizations; review registration requests and initiate provisioning workflow.

#### Admin Notes (/admin-notes)

- **Sales notes:** Create and review sales notes, follow-up reminders, and organization registration request details.

#### Meetings (/meetings)

- **Sales calls:** Schedule and join video meetings with prospects for product demos and onboarding discussions.

#### Settings (/settings)

- **Profile & preferences:** Manage personal profile, notification settings, and app appearance for the sales workflow.

#### Organization Registration Review

- **Intake processing:** Review submissions from /register-organization public form and coordinate with SUPER_ADMIN for tenant creation.

# 14\. Role: CLIENT

### Who They Are

CLIENT is an external stakeholder (customer, vendor, partner) with restricted, time-limited access to specific project channels. Client names and avatars render in brand-mandated red across all platforms. Desktop login is blocked - clients are automatically logged out on Windows/Linux/macOS.

### Login Identifier

tenant slug + user ID + password with access window enforced server-side.

### Default Home Page

Mobile & Web: /chat.

### Navigation Tabs / Pages

**Mobile bottom nav:** Chat · Home · More

**Web sidebar:** Dashboard, Channels, Saved, Sessions, Report a problem, Settings

### Platforms Available

Web, Mobile (Android/iOS) - NOT desktop

### Pages and Features

#### Chat (/chat)

- **Assigned channels only:** Clients see only channels they are explicitly added to; no access to internal employee channels or DMs.
- **Red identity:** Client's own name displays in red; other clients in shared channels also render in red per platform contract.

#### Channels (/channels - Web)

- **Project channels:** View CLIENT-type and assigned PROJECT channels with read/post permissions as configured by admin.

#### Dashboard (/dashboard)

- **Client overview:** Limited dashboard showing assigned channel activity, shared files, and project status summaries.

#### Saved (/saved)

- **Bookmarked content:** Save important messages and shared files from client channels for personal reference.

#### Files - Client visibility

- **Controlled file access:** Files with file.view_client permission or CHANNEL visibility in client channels are accessible via signed R2 URLs.

#### Access Expiry

- **Time-limited access:** Server enforces accessEndsAt on every request; expired clients receive HTTP 410 Gone and are redirected to login.

#### Sessions (/sessions)

- **Device management:** View and revoke own active sessions across mobile and web devices.

#### Report a Problem (/report-problem)

- **Client support:** Submit issues or questions to organization support team via support ticket module.

# 15\. Shared Features (All Roles)

### Authentication & Security

- **JWT + refresh tokens:** 15-minute access tokens with 30-day rotating refresh tokens; reuse of old refresh token revokes entire chain.
- **Session management:** Every login creates Session row with risk score; new IP adds 20-30 risk points shown as badge in UI.
- **Socket auth:** Socket.IO handshake validates same access token; client expiry checked on every connect.
- **Device registration:** FCM device tokens registered per platform (ANDROID, IOS, WEB, WINDOWS, MACOS) for push delivery.

### Realtime Chat

- **Channel types:** DM, GROUP, PROJECT, ANNOUNCEMENT, and CLIENT channels with role-appropriate creation permissions.
- **Typing indicators:** Realtime typing with threadRootId support for independent thread panel indicators.
- **Message kinds:** TEXT, IMAGE, FILE, VOICE_NOTE with Cloudinary/R2 storage and FileAsset tracking.
- **Reactions & threads:** Emoji reactions, reply threading, message edit/delete, and pin/unpin per channel permissions.

### Presence & Notifications

- **Dual presence:** Socket.IO for online-now; UserPresence table for declared status (ACTIVE, AWAY, BUSY, IN_MEETING, INVISIBLE).
- **Push notifications:** FCM for chat, tasks, calls, mentions, emergency alerts with actionable reply on Android.
- **Notification center:** Grouped notification inbox with mark-all-read and realtime invalidation on new events.

### Search & Command Palette

- **Global search:** Postgres-backed search adapter with future Meilisearch upgrade path; searches messages, tasks, leads, files.
- **Command palette (web):** Cmd+K quick navigation to any page, user, or channel with keyboard shortcuts overlay.

### Files & Storage

- **File permissions:** PRIVATE, CHANNEL, TENANT, PUBLIC visibility with FileAccessPolicy and per-user FileGrant overrides.
- **Storage routing:** Images to Cloudinary; PDFs, docs, voice notes, recordings to Cloudflare R2 with 15-minute presigned URLs.

### Voice & Video

- **WEB RTC:** One-to-one and group calls with mute, add participant, call history, and optional recording to R2.
- **Meetings:** Slug-based meeting rooms supporting voice, video, webinar, and livestream modes with public join links.

### Theme & Branding

- **Theme modes:** Light, dark, and system with multiple color palettes and org primary color tint on default blue theme.
- **Announcement banner:** Organization-wide banner displayed at top of web workspace and mobile for important broadcasts.

# 16\. Desktop-Specific Features

### Windows Desktop

- **Chat-first workspace:** Windows desktop uses chat-focused sidebar shell; live calls and meetings routes redirect - Windows workspace is chat + history only per kWindowsWorkspaceNoCalls.
- **System tray:** Minimize to system tray with tray icon; right-click menu for show/hide and quit options.
- **Autostart:** Optional launch-at-login via desktop local settings; starts minimized to tray when enabled.
- **Work activity agent:** Background timer captures periodic screenshots at admin-configured intervals (120s-3600s); uploads to workActivity module.
- **Session registration:** On login, registers desktop work session with GPS coordinates and address via registerDesktopWorkSession.
- **Single instance:** Desktop runtime prevents multiple instances; second launch focuses existing window.

### Linux Desktop

- **Same as Windows:** Chat-first workspace, system tray, autostart, work activity agent, and session registration with identical capabilities.
- **Work activity intervals:** Configurable capture intervals polled every 60 seconds from server settings; supports 2min, 5min, 15min, 30min, 60min.
- **Native integration:** Linux-specific desktop native bridge for screenshot capture and system tray on GTK-based desktop environments.

### macOS Desktop

- **Full chat + calls:** Unlike Windows, macOS desktop supports live calls and meetings in addition to chat workspace.
- **Menu bar integration:** macOS-native window management and menu bar presence for background operation.
- **Work activity agent:** Background screenshot capture agent same as Windows/Linux with macOS-native capture APIs.
- **Client blocked:** CLIENT role users are automatically logged out on desktop startup - clients must use web or mobile.

### Desktop Work Activity (All Desktop Platforms)

- **Embedded admin view:** Work activity screen embeds in desktop settings as sub-route for admins reviewing captures without separate window.
- **Privacy logging:** All capture events logged to audit trail; employees see capture indicator in desktop agent status.

# 17\. Web Admin Console Features

### Analytics Dashboard (/analytics)

- **Productivity endpoint:** Tasks completed per user with date range filter defaulting to last 30 days.
- **Telecaller endpoint:** Calls per minute and leads-won per agent for call center performance review.
- **Workspace endpoint:** Message volume, active user count, and call statistics for org health monitoring.
- **CSV export:** All analytics endpoints support ?format=csv for spreadsheet download.

### Permissions Management (/permissions)

- **Grant editor:** UI for assigning allow/deny grants to users and roles with wildcard pattern support.
- **My permissions API:** GET /permissions/mine returns defaults and grants for frontend button visibility hints.

### Feature Flags (/flags)

- **Per-tenant toggles:** Enable/disable modules and experimental features without code deployment.

### Automations (referenced in nav)

- **Task automations:** Scheduled (node-cron) and event-triggered automations for task creation, overdue notification, and lead status changes.

### Field Visits Map (/field-visits)

- **Manager map view:** Web-only geographic visualization of field executive visits with filtering and export.

### Meeting Join - Public (/meetings/join/:slug)

- **Guest join:** Public meeting join page accessible without authentication for external participants with meeting slug.

### Privacy Policy (/privacy-policy)

- **Legal page:** Public privacy policy accessible at /privacy-policy and /privacy redirect.

### Support Tickets (/support-issues)

- **Platform inbox:** SUPER_ADMIN and default tenant support assignees manage cross-tenant support issues.

### Employee Tracking

- **GPS dashboard:** Real-time and historical employee location data from mobile GPS lifecycle and desktop login registration.

### Org TTS Settings

- **Text-to-speech:** Organization-level TTS configuration for voice announcements; loaded via orgTtsSettingsProvider on mobile startup.

### Billing & Subscription

- **Billing module:** Backend billing routes gate feature access per subscription plan; org admins view status on mobile subscription screen.

# 18\. Field Force Module Deep Dive

The Field Force module (marketing API) powers the EXECUTIVE mobile experience and manager oversight tools. It integrates with an external business data API at data.mytaskking.com for shop search and territory intelligence.

### API Architecture

- **Access control:** All /marketing/\* routes require authentication and assertFieldAccess permission check on user.
- **Field settings:** GET /marketing/settings returns org-specific field configuration including regions, targets, and catalog sync settings.
- **Dashboard:** GET /marketing/dashboard returns executive or manager dashboard metrics for the current period.

### Regions & Territories

- **Region CRUD:** Create and list geographic regions for organizing outlets and assigning executives to territories.

### Outlets

- **Outlet management:** Full CRUD for retail outlets with address, GPS coordinates, contact, category, and assigned executive.
- **Visit recording:** Check-in/check-out with GPS proof, photos, notes, and outcome status stored per visit record.

### Orders

- **Order capture:** Create orders during visits with line items from catalog, pricing, discounts, and delivery scheduling.
- **Order status:** Track orders through pending, confirmed, dispatched, and delivered lifecycle states.

### Product Catalog

- **SKU management:** Product catalog with images, descriptions, unit pricing, pack sizes, and stock availability flags.
- **Offline sync:** Mobile caches catalog locally for field use without continuous network connectivity.

### GPS & Employee Tracking

- **Background GPS:** EmployeeGpsLifecycle widget reports location while app is active; data flows to employeeTracking module.
- **Visit GPS:** Mandatory GPS coordinates on visit check-in for compliance verification by managers on field-visits map.

### Shop Search (External API)

- **Business data API:** Search nearby businesses from external data service to discover new outlet opportunities in the field.

### Export

- **Excel export:** GET /marketing/export.xlsx generates spreadsheet with visit and order data; response includes row count headers.

### Offline Capability

- **Offline visits:** Visit data queued locally when offline and synced to server on network reconnect with conflict resolution.
- **Offline orders:** Order drafts saved locally and submitted when connectivity returns to prevent data loss in remote areas.

### Manager Operations

- **Ops service:** marketing.ops.service provides manager-level operations including executive assignment, target setting, and visit approval.
- **Web field-visits:** Managers and coordinators view team visits on web map; admins have full export and analytics access.

# 19\. Backend Modules Summary (39 Modules)

| **#** | **Module**       | **Purpose**                                                                         |
| ----- | ---------------- | ----------------------------------------------------------------------------------- |
| 1     | auth             | Login, logout, refresh token rotation, JWT issuance, and /auth/me user payload      |
| 2     | employees        | Employee CRUD, suspend/activate, role assignment, and paginated directory           |
| 3     | clients          | Client CRUD, access window management, extend/disable, and expiry enforcement       |
| 4     | channels         | Channel creation, membership, pin/archive, and CLIENT channel flagging              |
| 5     | chat             | Messages, reactions, threads, read cursors, edit/delete, and realtime socket events |
| 6     | tasks            | Task CRUD, kanban move, subtasks, comments, assignees, and automations trigger      |
| 7     | reports          | Report generation, sharing, and download for team and personal reports              |
| 8     | calls            | WEB call initiate/join/leave, token refresh, history, and group promotion           |
| 9     | telecaller       | Lead CRM, Phone Call click-to-call, follow-ups, webhook, and call history           |
| 10    | notifications    | FCM push, device registration, grouped inbox, and actionable notification replies   |
| 11    | dashboard        | Role-aware dashboard overview stats and activity feed aggregation                   |
| 12    | files            | Upload, Cloudinary/R2 signing, FileAsset registration, and signed download URLs     |
| 13    | audit            | Activity log recording for auth, permissions, files, automations, and emergencies   |
| 14    | search           | Full-text search adapter (Postgres today, Meilisearch-ready) across entities        |
| 15    | saved            | Bookmark/save messages, tasks, and files for quick personal reference               |
| 16    | settings         | Workspace settings, org branding, TTS config, and work activity intervals           |
| 17    | calendar         | Calendar events aggregating tasks, meetings, follow-ups, and leave                  |
| 18    | attendance       | Clock in/out, attendance records, and workday timeline                              |
| 19    | announcements    | Organization-wide announcement publish and banner delivery                          |
| 20    | sessions         | Session tracking, risk scoring, force-logout, and refresh token management          |
| 21    | permissions      | Advanced RBAC grants, DEFAULT_MATRIX, and /permissions/mine endpoint                |
| 22    | presence         | UserPresence status (ACTIVE/AWAY/BUSY/IN_MEETING/INVISIBLE) management              |
| 23    | analytics        | Admin analytics: productivity, telecaller, tasks, workspace, calls, CSV export      |
| 24    | automations      | Scheduled and event-triggered task automations with node-cron registration          |
| 25    | openapi          | Curated OpenAPI spec served at /api/v1/docs and /api/v1/openapi.json                |
| 26    | flags            | Per-tenant feature flag toggles for module enablement                               |
| 27    | meetings         | WEB meeting rooms with slug, token, join/leave, and public lobby                    |
| 28    | workspace        | Workspace customization and organization-level configuration                        |
| 29    | unfurl           | URL preview/unfurl for link attachments in chat messages                            |
| 30    | recordings       | Call recording storage in R2 with metadata and playback URL generation              |
| 31    | ai-review        | AI-generated call/meeting summaries and transcription review queue                  |
| 32    | tenants          | Multi-tenant organization CRUD, slug, branding, and storage prefix                  |
| 33    | billing          | Subscription plans, payment tracking, and feature gating per tenant                 |
| 34    | adminNotes       | Sales notes and organization registration request tracking                          |
| 35    | emergency        | Emergency buzzer alert, ack, and supervisor escalation with FCM push                |
| 36    | workActivity     | Desktop screenshot capture, daily summary, clips, and admin review API              |
| 37    | marketing        | Field force: outlets, visits, orders, catalog, regions, GPS, and export             |
| 38    | supportTickets   | Report a problem submissions and platform support inbox management                  |
| 39    | employeeTracking | Employee GPS location reporting, trails, and manager tracking dashboard             |

# 20\. Review Checklist

Use this checklist to confirm complete coverage of the MyTaskKing product suite before final DOCX conversion.

| **✓** | **Category**  | **Item**                                                                  | **Status** |
| ----- | ------------- | ------------------------------------------------------------------------- | ---------- |
| ☑     | Apps          | Mobile App (Android + iOS) - Flutter                                      | Documented |
| ☑     | Apps          | Web Admin Console - React 18 + TypeScript                                 | Documented |
| ☑     | Apps          | Windows Desktop - Flutter + tray + work activity                          | Documented |
| ☑     | Apps          | Linux Desktop - Flutter + tray + work activity                            | Documented |
| ☑     | Apps          | macOS Desktop - Flutter + calls + work activity                           | Documented |
| ☑     | Roles         | SUPER_ADMIN - platform admin                                              | Documented |
| ☑     | Roles         | SALES_HEAD - platform sales                                               | Documented |
| ☑     | Roles         | ADMIN - organization admin                                                | Documented |
| ☑     | Roles         | MANAGER - team lead                                                       | Documented |
| ☑     | Roles         | PROJECT_COORDINATOR_MANAGER - project coordinator                         | Documented |
| ☑     | Roles         | EMPLOYEE - standard team member                                           | Documented |
| ☑     | Roles         | TELECALLER - outbound CRM agent                                           | Documented |
| ☑     | Roles         | EXECUTIVE - field force (mobile integrated)                               | Documented |
| ☑     | Roles         | CLIENT - external limited access                                          | Documented |
| ☑     | Mobile Routes | All router.dart routes (login, shell, field, marketing, telecaller, etc.) | Documented |
| ☑     | Web Routes    | All App.tsx routes (dashboard through support-issues)                     | Documented |
| ☑     | Features      | Work activity desktop agent                                               | Documented |
| ☑     | Features      | Emergency buzzer with escalation                                          | Documented |
| ☑     | Features      | Org TTS (text-to-speech)                                                  | Documented |
| ☑     | Features      | Subscription & billing                                                    | Documented |
| ☑     | Features      | Support tickets / report a problem                                        | Documented |
| ☑     | Features      | Employee GPS tracking                                                     | Documented |
| ☑     | Features      | Field Force module (marketing API)                                        | Documented |
| ☑     | Features      | AI Review                                                                 | Documented |
| ☑     | Features      | Telecaller CRM + Phone Call                                               | Documented |
| ☑     | Features      | Attendance / Workday                                                      | Documented |
| ☑     | Features      | Leave request & approvals                                                 | Documented |
| ☑     | Backend       | All 39 backend modules listed                                             | Documented |
| ☑     | Content       | 150+ feature bullets with descriptions                                    | Documented |

End of MyTaskKing Complete Product Guide - August 2026