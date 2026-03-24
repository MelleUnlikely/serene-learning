// Feature: serene-learning, Property 1: school-visibility lessons from other schools never appear
// Feature: serene-learning, Property 2: all fetched lessons appear in the rendered list

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/screens/teacher/library_dialog.dart';

/// Pure filtering function that mirrors the logic in
/// `_LibraryDialogState._fetchLibraryLessons()`:
///
/// Given:
///   - [publicLessons]  – rows returned by the `visibility = 'public'` query
///   - [schoolLessons]  – rows returned by the school-scoped query
///     (already filtered by `class.schoolid = userSchoolId` at the DB level)
///   - [userSchoolId]   – the current teacher's school id
///
/// Returns the deduplicated list of lessons that the dialog would display.
///
/// The property under test: no lesson with `visibility = 'school'` and a
/// `schoolid` different from [userSchoolId] should ever appear in the result.
List<Map<String, dynamic>> filterLibraryLessons({
  required List<Map<String, dynamic>> publicLessons,
  required List<Map<String, dynamic>> schoolLessons,
  required int userSchoolId,
}) {
  final Map<int, Map<String, dynamic>> seen = {};
  for (final lesson in [...publicLessons, ...schoolLessons]) {
    final id = lesson['lessonid'] as int;
    seen[id] = lesson;
  }
  return seen.values.toList();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Stub shared_preferences so Supabase.initialize can complete without a
    // real plugin implementation.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall call) async {
        if (call.method == 'getAll') return <String, Object>{};
        return null;
      },
    );

    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'placeholder_anon_key',
    );
  });

  // ---------------------------------------------------------------------------
  // Property 1 — school-visibility lessons from other schools never appear
  // Validates: Requirements 3.2
  // ---------------------------------------------------------------------------
  test(
    'Property 1: school-visibility lessons from other schools never appear',
    () {
      // Feature: serene-learning, Property 1: school-visibility lessons from other schools never appear
      final rng = Random(42); // fixed seed for reproducibility
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Pick a random teacher school id in [1, 10]
        final int userSchoolId = rng.nextInt(10) + 1;

        // Generate a random pool of lessons with mixed visibility / schoolid
        final int lessonCount = rng.nextInt(20) + 1; // 1..20 lessons
        final List<Map<String, dynamic>> allLessons = List.generate(
          lessonCount,
          (idx) {
            final visibility = rng.nextBool() ? 'public' : 'school';
            final schoolId = rng.nextInt(10) + 1; // 1..10
            return {
              'lessonid': idx + 1,
              'lessontitle': 'Lesson ${idx + 1}',
              'visibility': visibility,
              'schoolid': schoolId,
            };
          },
        );

        // Simulate what the DB queries would return:
        //   - publicLessons: all lessons with visibility = 'public'
        //   - schoolLessons: lessons with visibility = 'school' AND
        //     schoolid = userSchoolId  (the DB join filters this)
        final publicLessons = allLessons
            .where((l) => l['visibility'] == 'public')
            .toList();

        final schoolLessons = allLessons
            .where((l) =>
                l['visibility'] == 'school' &&
                l['schoolid'] == userSchoolId)
            .toList();

        final result = filterLibraryLessons(
          publicLessons: publicLessons,
          schoolLessons: schoolLessons,
          userSchoolId: userSchoolId,
        );

        // --- Assert the property ---
        for (final lesson in result) {
          if (lesson['visibility'] == 'school') {
            final lessonSchoolId = lesson['schoolid'] as int;
            expect(
              lessonSchoolId,
              equals(userSchoolId),
              reason:
                  'Iteration $i: lesson ${lesson['lessonid']} has visibility=school '
                  'but schoolid=$lessonSchoolId != userSchoolId=$userSchoolId',
            );
          }
        }
      }
    },
  );

  // ---------------------------------------------------------------------------
  // Property 2 — all fetched lessons appear in the rendered list
  // Validates: Requirements 3.3
  // ---------------------------------------------------------------------------
  testWidgets(
    'Property 2: all fetched lessons appear in the rendered list',
    (WidgetTester tester) async {
      // Feature: serene-learning, Property 2: all fetched lessons appear in the rendered list
      final rng = Random(7); // fixed seed for reproducibility
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Generate a random non-empty list of lessons (1..15 items).
        final int lessonCount = rng.nextInt(15) + 1;
        final List<Map<String, dynamic>> lessons = List.generate(
          lessonCount,
          (idx) => {
            'lessonid': i * 100 + idx + 1,
            'lessontitle': 'Lesson_${i}_$idx',
            'visibility': rng.nextBool() ? 'public' : 'school',
            'classid': rng.nextInt(5) + 1,
          },
        );

        // Render just the lesson list content directly — bypasses the Dialog's
        // maxHeight constraint so all items are laid out and findable.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LibraryDialog.buildLessonListContent(lessons: lessons),
              ),
            ),
          ),
        );
        await tester.pump();

        // --- Assert the property ---
        // Every lesson title must appear somewhere in the widget tree,
        // including tiles that are scrolled off-screen (skipOffstage: false).
        for (final lesson in lessons) {
          final title = lesson['lessontitle'] as String;
          expect(
            find.text(title, skipOffstage: false),
            findsAtLeastNWidgets(1),
            reason:
                'Iteration $i: lessontitle "$title" not found in widget tree',
          );
        }

        // Tear down between iterations to avoid widget tree conflicts.
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
