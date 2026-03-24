---
inclusion: always
---

## Steering Document

## Project Goal
To develop a high-performance, web-based Administrative and Teacher Management System for the ASL Learning Platform. The primary objective is to enable teachers to manage classes, lessons, and quizzes while providing administrators with high-level data insights through optimized PostgreSQL views.

## Non-Goals
- Database Schema Modification: Do not suggest ALTER TABLE or CREATE TABLE commands; the database schema is managed externally.
## Tech Stack
- Frontend: Flutter (Web) using the supabase_flutter package.
- Backend: Supabase (PostgreSQL).
- State Management: Provider (for global auth and theme) and FutureBuilders (for view-based data).
- Navigation: GoRouter or standard Flutter Navigator 2.0.

## Architecture Rules
- Reactive Auth: Use Supabase.instance.client.auth.onAuthStateChange to manage navigation. Do not rely on one-time session checks in build methods.
- Service Layer Isolation: All Supabase interactions must reside in a SupabaseService or Repository class.
- View Integration: Always use the from('view_name') syntax for reports.
- ID Handling: Use String (UUID) for user IDs and int for table IDs. Avoid passing hardcoded 0 values for teacherId.
- Atomic Operations: Prioritize using PostgreSQL RPCs (Functions) for multi-table operations (like duplicating lessons with cards) to ensure data atomicity and reduce frontend complexity.
## Quality Rules
- Type Safety: Define Dart Models (classes) for every SQL View response to ensure strict typing across the app.
- Async Safety: Ensure all Supabase calls handle loading states and "No Data Found" scenarios gracefully with custom UI components.
- Strict Formatting: Maintain a formal coding style; use final for immutable variables and follow the official Flutter linting rules.
- Widget Modularity: Break down the Teacher Dashboard into smaller, reusable components (e.g., PerformanceCard, LessonListTile).
-Explicit Mapping: All Dart Models must use factory Model.fromJson(Map<String, dynamic> json) to ensure the naming conventions in the PostgreSQL Views (like average_accuracy) are correctly mapped to Dart camelCase (averageAccuracy).
- Conditional UI: Ensure Admin-only features are hidden from Teacher accounts by checking roletype from the profiles table.
