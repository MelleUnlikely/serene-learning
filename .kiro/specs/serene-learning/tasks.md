# Implementation Plan: Library Feature for Serene Learning

## Overview

Implement the Library Dialog feature by removing legacy copy logic, creating the new `LibraryDialog` widget, updating the `LessonManagementScreen` FAB area, and adding property-based tests.

## Tasks

- [x] 1. Remove legacy import logic from `LessonManagementScreen`
  - Delete `_copyFile()`, `_duplicateLessonWithContent()`, and `_showImportDialog()` methods from `lib/screens/teacher/lesson_screen.dart`
  - Remove the `Icons.content_copy` `_buildActionSegment` call from `_buildLessonList()`
  - _Requirements: 1.1, 1.2, 1.3_

  - [x] 1.1 Write widget test asserting legacy methods and icon are absent
    - Verify `Icons.content_copy` does not appear in the lesson card widget tree
    - _Requirements: 1.3_

- [x] 2. Create `LibraryDialog` widget
  - Create `lib/screens/teacher/library_dialog.dart` with `LibraryDialog extends StatefulWidget`
  - Add constructor params `classId` (int) and `onImportSuccess` (VoidCallback)
  - Add state fields: `_lessons`, `_isLoading`, `_errorMessage`
  - _Requirements: 3.1, 3.2, 3.3_

  - [x] 2.1 Implement `_fetchLibraryLessons()`
    - Fetch `schoolid` from `profile` for the current user
    - Run public query: `lesson` where `visibility = 'public'`
    - Run school-scoped query: `lesson` joined with `class` where `visibility = 'school'` and `class.schoolid = userSchoolId`
    - Deduplicate results by `lessonid` and set `_lessons`
    - On failure, set `_errorMessage`
    - _Requirements: 3.1, 3.2_

  - [x] 2.2 Write property test for school scoping exclusion
    - **Property 1: school-visibility lessons from other schools never appear**
    - **Validates: Requirements 3.2**
    - Tag: `// Feature: serene-learning, Property 1: school-visibility lessons from other schools never appear`

  - [x] 2.3 Implement `_importLesson(int lessonId)`
    - Call `duplicate_lesson_with_flashcards` RPC with `target_lesson_id` and `target_class_id`
    - Set `_isLoading = true` before call, reset after
    - On success: call `onImportSuccess()`
    - On failure: show error SnackBar via `ScaffoldMessenger`, keep dialog open
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [ ]* 2.4 Write property test for RPC parameter correctness
    - **Property 3: RPC called with correct target_lesson_id and target_class_id**
    - **Validates: Requirements 4.1**
    - Tag: `// Feature: serene-learning, Property 3: RPC called with correct target_lesson_id and target_class_id`

  - [x] 2.5 Implement UI builders
    - `_buildLessonList()`: scrollable `ListView` of lesson tiles with an import button per tile; disable taps when `_isLoading`
    - `_buildEmptyState()`: "No shared lessons available" message
    - `_buildErrorState()`: error message with dismiss button
    - `_buildLoadingIndicator()`: centered `CircularProgressIndicator`
    - Apply style: `Colors.white.withOpacity(0.9)` background, `blurRadius 20`, `Color(0xFF1D5A71)` headers, `Color(0xFFa5ceeb)` buttons
    - _Requirements: 3.3, 3.4, 3.5, 4.3_

  - [x] 2.6 Write property test for all fetched lessons displayed
    - **Property 2: all fetched lessons appear in the rendered list**
    - **Validates: Requirements 3.3**
    - Tag: `// Feature: serene-learning, Property 2: all fetched lessons appear in the rendered list`

- [ ] 3. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Update `LessonManagementScreen` FAB area
  - Add `_showLibraryDialog()` method that calls `showDialog` with `LibraryDialog(classId: widget.classId, onImportSuccess: () { Navigator.pop(context); _showSuccessSnackBar(); _fetchLessons(); })`
  - Replace the existing single FAB with a `Column` of two `FloatingActionButton.extended` widgets: "Add from Library" (heroTag: `'library'`, icon: `Icons.add_circle_outline`) above "Add Lesson" (heroTag: `'addLesson'`)
  - Both FABs use `backgroundColor: Color(0xFFa5ceeb)`, text/icon color `Color(0xFF1D5A71)`
  - _Requirements: 2.1, 2.2_

  - [ ]* 4.1 Write widget test for FAB area and dialog launch
    - Assert "Add from Library" button is present in the widget tree
    - Simulate tap and assert `LibraryDialog` opens
    - _Requirements: 2.1, 2.2_

- [ ] 5. Add integration property tests for RPC behavior
  - Create `test/library_feature_test.dart`
  - Add property tests 4, 5, and 6 against a Supabase emulator or test database

  - [ ]* 5.1 Write property test for import idempotency
    - **Property 4: two imports of the same lesson produce independent copies**
    - **Validates: Requirements 4.1, 4.2**
    - Tag: `// Feature: serene-learning, Property 4: two imports of the same lesson produce independent copies`

  - [ ]* 5.2 Write property test for visibility reset on import
    - **Property 5: imported lesson always has visibility = 'private'**
    - **Validates: Requirements 4.2**
    - Tag: `// Feature: serene-learning, Property 5: imported lesson always has visibility = 'private'`

  - [ ]* 5.3 Write property test for flashcard completeness on import
    - **Property 6: imported lesson has same flashcard count as original**
    - **Validates: Requirements 4.2**
    - Tag: `// Feature: serene-learning, Property 6: imported lesson has same flashcard count as original`

- [ ] 6. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Properties 1–3 are unit/widget tests with mocked Supabase; properties 4–6 require a Supabase emulator or test database
- Each property test should run a minimum of 100 iterations
- No new state management layer is introduced; the feature follows the existing direct Supabase SDK pattern
