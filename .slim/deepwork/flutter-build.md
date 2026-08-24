# Deepwork: Flutter App Build

## Goal
Build complete Flutter mobile app for FinanceAI with Chat, Laporan, Profile screens.

## Current State
- Backend: Laravel 13, complete (Phases 0-4)
- API: RESTful JSON API with Sanctum auth
- No Flutter code exists yet

## API Endpoints (for Flutter consumption)
- POST /auth/register, /auth/login, /auth/logout
- GET /me
- GET/POST /sessions, DELETE /sessions/{id}
- GET /sessions/{id}/messages
- POST /chat
- GET/POST/PUT/DELETE /transactions
- GET/POST /categories
- GET /reports/summary, /reports/breakdown

## Implementation Phases

### Phase 1: Project Setup + API Layer
- Create Flutter project structure
- Set up dependencies (dio, riverpod, go_router, etc.)
- Create API service layer with dio
- Create models (User, Transaction, Category, ChatSession, Message, Report)
- Set up auth state management

### Phase 2: Auth Screens
- Login screen
- Register screen
- Auth flow with token storage

### Phase 3: Core Navigation + Layout
- Bottom navigation (Chat, Laporan, Profile)
- App theme and styling
- Persistent layout

### Phase 4: Chat Feature
- Chat session list
- Chat message interface
- Send message + poll for AI response
- Session management

### Phase 5: Laporan (Reports)
- Summary card
- Category breakdown list
- Period selector

### Phase 6: Profile + Settings
- Profile info
- Logout

## Status
- [ ] Phase 1: Project Setup + API Layer
