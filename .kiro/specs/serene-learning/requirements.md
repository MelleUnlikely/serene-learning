# Requirements Document

## Introduction

The Library feature adds a shared lesson repository to the Serene Learning platform. Teachers can browse lessons that have been made publicly available (visibility: `public`) or shared within their school (visibility: `school`), and import them directly into one of their classes. The import is handled server-side via a Supabase RPC that deep-copies the lesson and its flashcards, resetting visibility to `private` on the new copy. The existing per-lesson "copy to another class" workflow is removed and replaced by this centralized Library flow.

## Glossary

- **LessonManagementScreen**: The Flutter screen that lists lessons for a given class and allows CRUD operations on them.
- **Library**: The shared repository of lessons with `public` or `school` visibility that any teacher can browse and import from.
- **Lesson**: A record in the `lesson` table containing a title, a `classid`, and a `visibility` field (`private`, `school`, or `public`).
- **Flashcard**: A record in the `flashcard` table linked to a lesson, containing a sign meaning, image URL, and video URL.
- **RPC**: The Supabase remote procedure call `duplicate_lesson_with_flashcards` that deep-copies a lesson and its flashcards into a target class.
- **School**: An organizational unit identified by `schoolid`; teachers and classes belong to a school.
- **Visibility**: A field on the `lesson` table with values `private`, `school`, or `public` that controls lesson discoverability.

---

## Requirements

### Requirement 1: Remove Legacy Import Logic

**User Story:** As a developer, I want to remove the old per-lesson copy workflow, so that the codebase is clean and the Library feature is the single import path.

#### Acceptance Criteria

1. THE `LessonManagementScreen` SHALL NOT contain the `_duplicateLessonWithContent` method.
2. THE `LessonManagementScreen` SHALL NOT contain the `_copyFile` method.
3. THE `LessonManagementScreen` SHALL NOT render the `Icons.content_copy` action segment on lesson list cards.

---

### Requirement 2: Add Library Entry Point to the UI

**User Story:** As a teacher, I want an "Add from Library" button near the "Add Lesson" button, so that I can easily discover and import shared lessons.

#### Acceptance Criteria

1. THE `LessonManagementScreen` SHALL display an `IconButton` with icon `Icons.add_circle_outline` and label "Add from Library" adjacent to the existing "Add Lesson" `FloatingActionButton`.
2. WHEN the teacher taps the "Add from Library" button, THE `LessonManagementScreen` SHALL open the Library Dialog.

---

### Requirement 3: Library Dialog — Fetch and Display Shared Lessons

**User Story:** As a teacher, I want to browse lessons available in the Library, so that I can find relevant content to import.

#### Acceptance Criteria

1. WHEN the Library Dialog opens, THE `Library_Dialog` SHALL query the `lesson` table for all rows where `visibility = 'public'`.
2. WHEN the Library Dialog opens, THE `Library_Dialog` SHALL also query the `lesson` table for all rows where `visibility = 'school'` AND the lesson's class belongs to the same `schoolid` as the current teacher.
3. THE `Library_Dialog` SHALL display the combined result set of public and school-scoped lessons as a scrollable list.
4. IF the query returns no results, THEN THE `Library_Dialog` SHALL display a message indicating that no shared lessons are available.
5. IF the query fails, THEN THE `Library_Dialog` SHALL display an error message and allow the teacher to dismiss the dialog.

---

### Requirement 4: Import a Lesson via RPC

**User Story:** As a teacher, I want to select a lesson from the Library and import it into my current class, so that I can reuse existing content without manual re-entry.

#### Acceptance Criteria

1. WHEN the teacher selects a lesson from the Library Dialog, THE `Library_Dialog` SHALL call the `duplicate_lesson_with_flashcards` RPC with `target_lesson_id` set to the selected lesson's ID and `target_class_id` set to the current class's ID.
2. THE `LessonManagementScreen` SHALL NOT implement duplication, flashcard copying, or visibility-reset logic in Dart; THE `duplicate_lesson_with_flashcards` RPC SHALL be solely responsible for those operations.
3. WHILE the RPC call is in progress, THE `Library_Dialog` SHALL display a loading indicator and prevent the teacher from selecting another lesson.
4. WHEN the RPC call succeeds, THE `LessonManagementScreen` SHALL dismiss the Library Dialog, display a success `SnackBar`, and call `_fetchLessons()` to refresh the lesson list.
5. IF the RPC call fails, THEN THE `Library_Dialog` SHALL display an error `SnackBar` and remain open so the teacher can retry or dismiss.

### Requirement 5: Preservation of Established Lesson CRUD
- User Story: As a teacher, I want to continue managing my existing lessons even after the Library feature is added, so that my daily workflow remains uninterrupted.

#### Acceptance Criteria
1. Title Management: THE LessonManagementScreen SHALL maintain the _updateLessonTitle functionality and the associated _showEditLessonDialog.
2. Deletion Safety: THE LessonManagementScreen SHALL maintain the _deleteLesson functionality and the _showDeleteConfirmDialog.
3.Instructional Navigation: Tapping on a Lesson card SHALL continue to navigate the user to the CreateFlashcardScreen with the correct lessonId and lessontitle.
4.Assessment Navigation: THE LessonManagementScreen SHALL maintain the Icons.quiz action segment, navigating the user to the QuizScreen.
5.UI Consistency: The Library Dialog and new buttons SHALL strictly adhere to the established color palette:
    -Primary Header: 0xFFD0EDF9
    -Primary Text/Icons: 0xFF1D5A71
    -Card Background: 0xFFA5CEEB

### Requirement 6: State & Loading Management
User Story: As a teacher, I want to see clear feedback when the app is communicating with the database, so that I know my actions are being processed.

#### Acceptance Criteria
- Global Overlay: THE _buildLoadingOverlay() SHALL be triggered during _fetchLessons(), _createNewLesson(), and the new Library RPC call.
- Reactive Refresh: THE _fetchLessons() method SHALL be the single source of truth for updating the UI state after any Create, Update, Delete, or Library Import action.
- Empty State: THE _buildEmptyState() SHALL remain visible if the current class has no lessons, even if the Library contains available lessons.

### Requirement 7: School-Scoped Discovery
User Story: As a teacher, I want to see lessons from my own school but not from other schools, to maintain institutional privacy.

#### Acceptance Criteria:

1. THE Library_Dialog SHALL fetch the schoolid from the active user profile.
2. THE Query for "School" visibility SHALL be restricted: SELECT * FROM lesson WHERE visibility = 'school' AND schoolid = [user_school_id].
3. THE Query for "Public" visibility SHALL remain unrestricted: SELECT * FROM lesson WHERE visibility = 'public'.

### Requirement 8: Global Style Alignment
User Story: As a user, I want the Library interface to feel like a native part of the Serene Learning app.

#### Acceptance Criteria:

1. THE Library_Dialog SHALL use a BoxDecoration with Colors.white.withOpacity(0.9) and a blurRadius of 20 to match the RegistrationScreen.
2. All headers in the dialog SHALL use the Color(0xFF1D5A71) with FontWeight.bold.
3. Buttons inside the dialog SHALL use the Color(0xFFa5ceeb) background and Color(0xFF006064) foreground.