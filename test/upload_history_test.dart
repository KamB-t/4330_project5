import 'package:app5/models/syllabus.dart';
import 'package:app5/services/upload_history.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'History keeps the latest 20 submissions in newest-first order',
    () async {
      final store = MemoryUploadHistory();
      for (var i = 0; i < 25; i++) {
        await store.add(
          SyllabusUpload(
            file: PickedSyllabus(name: 'syllabus-$i.pdf', sizeBytes: 1024),
            semesterStart: DateTime(2026, 8, 24),
            timeZone: 'Central (CT)',
          ),
        );
      }
      final entries = await store.watch().first;
      expect(entries.length, 20);
      expect(entries.first.upload.file.name, 'syllabus-24.pdf');
      expect(entries.last.upload.file.name, 'syllabus-5.pdf');
    },
  );

  test('Firestore records restore the upload metadata', () {
    final entry = UploadHistoryEntry.fromFirestore({
      'fileName': 'biology.pdf',
      'sizeBytes': 4096,
      'semesterStart': Timestamp.fromDate(DateTime(2026, 8, 24)),
      'timeZone': 'Central (CT)',
      'uploadedAt': Timestamp.fromDate(DateTime(2026, 10, 21, 9)),
    });
    expect(entry.upload.file.name, 'biology.pdf');
    expect(entry.upload.file.sizeBytes, 4096);
    expect(entry.upload.semesterStart, DateTime(2026, 8, 24));
    expect(entry.uploadedAt, DateTime(2026, 10, 21, 9));
    expect(entry.toFirestore()['uploadedAt'], isA<FieldValue>());
  });
}
