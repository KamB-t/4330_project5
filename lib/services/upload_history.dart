import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/syllabus.dart';

class UploadHistoryEntry {
  const UploadHistoryEntry({required this.upload, required this.uploadedAt});

  final SyllabusUpload upload;
  final DateTime uploadedAt;

  Map<String, dynamic> toFirestore() => {
    'fileName': upload.file.name,
    'sizeBytes': upload.file.sizeBytes,
    'semesterStart': Timestamp.fromDate(upload.semesterStart),
    'timeZone': upload.timeZone,
    'uploadedAt': FieldValue.serverTimestamp(),
  };

  factory UploadHistoryEntry.fromFirestore(Map<String, dynamic> data) =>
      UploadHistoryEntry(
        upload: SyllabusUpload(
          file: PickedSyllabus(
            name: data['fileName'] as String,
            sizeBytes: data['sizeBytes'] as int,
          ),
          semesterStart: (data['semesterStart'] as Timestamp).toDate(),
          timeZone: data['timeZone'] as String,
        ),
        uploadedAt:
            (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

abstract interface class UploadHistoryStore {
  Stream<List<UploadHistoryEntry>> watch();
  Future<void> add(SyllabusUpload upload);
}

class FirestoreUploadHistory implements UploadHistoryStore {
  FirestoreUploadHistory(FirebaseFirestore firestore, String userId)
    : _uploads = firestore
          .collection('users')
          .doc(userId)
          .collection('uploads');

  final CollectionReference<Map<String, dynamic>> _uploads;

  @override
  Stream<List<UploadHistoryEntry>> watch() => _uploads
      .orderBy('uploadedAt', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => UploadHistoryEntry.fromFirestore(doc.data()))
            .toList(),
      );

  @override
  Future<void> add(SyllabusUpload upload) async {
    await _uploads.add(
      UploadHistoryEntry(
        upload: upload,
        uploadedAt: DateTime.now(),
      ).toFirestore(),
    );
  }
}

/// Explicitly used by widget tests, without contacting Firebase.
class MemoryUploadHistory implements UploadHistoryStore {
  final _entries = <UploadHistoryEntry>[];
  final _changes = StreamController<List<UploadHistoryEntry>>.broadcast();

  @override
  Stream<List<UploadHistoryEntry>> watch() async* {
    yield List.unmodifiable(_entries);
    yield* _changes.stream;
  }

  @override
  Future<void> add(SyllabusUpload upload) async {
    _entries.insert(
      0,
      UploadHistoryEntry(upload: upload, uploadedAt: DateTime.now()),
    );
    if (_entries.length > 20) _entries.removeLast();
    _changes.add(List.unmodifiable(_entries));
  }
}
